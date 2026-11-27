import 'dart:async';
import 'dart:math';

import 'package:deluge_engine_gui/backend/backend.dart';
import 'package:deluge_engine_gui/backend/fake_data.dart';
import 'package:deluge_engine_gui/backend/restart_policy.dart';
import 'package:deluge_engine_gui/proto/engine.pb.dart' as pb;

/// In-memory [Backend] for widget tests and developing GUI screens without the
/// native Engine binary (spec §8).
class FakeBackend extends Backend {
  FakeBackend({
    this.protocolVersionOverride,
    List<String>? capabilities,
    this.stepDelay = const Duration(milliseconds: 10),
    this.restartDelay = const Duration(milliseconds: 40),
    this.cardBuildSteps = 4,
    this.holdCardBuild = false,
    this.heartbeatInterval,
    RestartPolicy? restartPolicy,
    DateTime Function()? now,
  })  : _capabilities = capabilities ??
            const ['setups', 'audition', 'pieces', 'render'],
        _now = now ?? DateTime.now,
        _restartPolicy = restartPolicy ?? RestartPolicy(now: now),
        _catalog = buildFakeCatalog(),
        _genres = buildFakeGenres();

  /// Override the `Hello.protocol_version` to simulate a version mismatch.
  final int? protocolVersionOverride;
  final List<String> _capabilities;
  final Duration stepDelay;
  final Duration restartDelay;
  final int cardBuildSteps;

  /// When `true`, `SetCard` emits an initial `CardProgress` and waits for
  /// [advanceCardProgress], [completeCardBuild], or [failCardBuild].
  bool holdCardBuild;

  /// Optional periodic heartbeat timer (omitted by default in tests to avoid
  /// dangling timers).
  final Duration? heartbeatInterval;

  /// Optional per-channel errors returned by `SetSetup`.
  final Map<int, String> setupErrors = <int, String>{};

  /// Log of every `ToEngine` frame sent to this fake, for test assertions.
  final List<pb.ToEngine> sentMessages = <pb.ToEngine>[];

  final DateTime Function() _now;
  final RestartPolicy _restartPolicy;
  final pb.Catalog _catalog;
  final pb.Genres _genres;

  final StreamController<pb.FromEngine> _events =
      StreamController<pb.FromEngine>.broadcast();
  final StreamController<BackendLifecycleEvent> _lifecycle =
      StreamController<BackendLifecycleEvent>.broadcast(sync: true);

  final Set<String> _cancelledRenders = <String>{};
  final Map<int, String> _activeSetup = <int, String>{};

  BackendStatus _status = BackendStatus.stopped;
  pb.Hello? _hello;
  FreezeInfo? _lastFreeze;
  String? _versionMismatchMessage;
  String? _errorMessage;

  Timer? _heartbeatTimer;
  Timer? _restartTimer;
  bool _disposed = false;
  int _voices = 0;
  String? _playingWavPath;
  double _playingPositionS = 0.0;

  @override
  Stream<pb.FromEngine> get events => _events.stream;

  @override
  Stream<BackendLifecycleEvent> get lifecycle => _lifecycle.stream;

  @override
  BackendStatus get status => _status;

  @override
  pb.Hello? get hello => _hello;

  @override
  FreezeInfo? get lastFreeze => _lastFreeze;

  @override
  String? get versionMismatchMessage => _versionMismatchMessage;

  @override
  String? get errorMessage => _errorMessage;

  pb.Catalog get catalog => _catalog;
  pb.Genres get genres => _genres;

  @override
  Future<void> start() async {
    if (_disposed) return;
    if (_status == BackendStatus.running ||
        _status == BackendStatus.starting ||
        _status == BackendStatus.restarting) {
      return;
    }
    await _connect(isRestart: false);
  }

  @override
  Future<void> restart() async {
    if (_disposed) return;
    _restartTimer?.cancel();
    _restartTimer = null;
    _restartPolicy.reset();
    _voices = 0;
    _playingWavPath = null;
    _playingPositionS = 0.0;
    _activeSetup.clear();
    _cancelledRenders.clear();
    _versionMismatchMessage = null;
    _errorMessage = null;
    await _connect(isRestart: true);
  }

  Future<void> _connect({required bool isRestart}) async {
    _setStatus(
      isRestart ? BackendStatus.restarting : BackendStatus.starting,
      isRestart: isRestart,
    );

    final version = protocolVersionOverride ??
        pb.ProtocolVersion.PROTOCOL_VERSION_CURRENT.value;
    final expected = pb.ProtocolVersion.PROTOCOL_VERSION_CURRENT.value;
    if (version != expected) {
      _versionMismatchMessage =
          'Protocol version mismatch: Engine reports v$version, '
          'GUI expects v$expected.';
      _setStatus(
        BackendStatus.versionMismatch,
        errorMessage: _versionMismatchMessage,
      );
      return;
    }

    _hello = pb.Hello(
      protocolVersion: version,
      engineVersion: '0.1.0-fake',
      firmwareCommit: 'fake000000',
      capabilities: _capabilities,
    );
    _setStatus(BackendStatus.running, isRestart: isRestart);
    _emit(pb.FromEngine(hello: _hello));
    _emit(
      pb.FromEngine(
        devices: pb.Devices(
          audioOutputs: ['MacBook Pro Speakers', 'External Headphones'],
          midiInputs: ['KeyStep 37', 'Launchkey Mini', 'IAC Bus 1'],
        ),
      ),
    );
    _emitHeartbeat();
    _startHeartbeatTimer();
    await Future<void>.microtask(() {});
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    final interval = heartbeatInterval;
    if (interval == null) return;
    _heartbeatTimer = Timer.periodic(interval, (_) {
      if (_status == BackendStatus.running && !_disposed) {
        _emitHeartbeat();
      }
    });
  }

  void _emitHeartbeat() {
    _emit(
      pb.FromEngine(
        heartbeat: pb.Heartbeat(
          voices: _voices,
          cpuLoad: _voices * 0.02,
        ),
      ),
    );
  }

  /// Directly sets the reported voice count and emits a `Heartbeat` (for tests
  /// and goldens).
  void setVoices(int voices) {
    _voices = voices;
    if (_status == BackendStatus.running) {
      _emitHeartbeat();
    }
  }

  /// Advances a held `SetCard` build progress (when [holdCardBuild] is `true`).
  void advanceCardProgress(int done, int total) {
    _emit(
      pb.FromEngine(
        cardStatus: pb.CardStatus(
          progress: pb.CardProgress(done: done, total: total),
        ),
      ),
    );
  }

  /// Finishes a held `SetCard` build and sends `CardReady`, `Catalog`, `Genres`.
  void completeCardBuild() {
    _emit(pb.FromEngine(cardStatus: pb.CardStatus(ready: pb.CardReady())));
    _emit(pb.FromEngine(catalog: _catalog));
    _emit(pb.FromEngine(genres: _genres));
  }

  /// Fails a held `SetCard` build with [text].
  void failCardBuild(String text) {
    _emit(
      pb.FromEngine(
        cardStatus: pb.CardStatus(error: pb.CardError(text: text)),
      ),
    );
  }

  /// Simulates an Engine freeze (`Freeze` frame + restart policy of spec §7.7).
  Future<void> simulateFreeze({
    String code = 'E380',
    String message = 'Simulated firmware freeze',
    String loaded = 'SYNTHS/165 Acid Arp.XML',
  }) async {
    if (_disposed || _status != BackendStatus.running) return;
    _heartbeatTimer?.cancel();
    _voices = 0;
    _playingWavPath = null;
    _activeSetup.clear();
    _cancelledRenders.clear();

    final info = FreezeInfo(
      code: code,
      message: message,
      loaded: loaded,
      timestamp: _now(),
    );
    _emit(
      pb.FromEngine(
        freeze_9: pb.Freeze(code: code, message: message, loaded: loaded),
      ),
    );

    final shouldRestart = _restartPolicy.recordFailureAndShouldRestart();
    if (!shouldRestart) {
      _setStatus(BackendStatus.crashed, freeze: info);
      return;
    }

    _setStatus(BackendStatus.restarting, freeze: info);
    if (restartDelay == Duration.zero) {
      await _connect(isRestart: true);
      return;
    }
    _restartTimer?.cancel();
    _restartTimer = Timer(restartDelay, () {
      if (_disposed) return;
      unawaited(_connect(isRestart: true));
    });
  }

  @override
  Future<void> send(pb.ToEngine message) async {
    if (_disposed) return;
    if (_status != BackendStatus.running) {
      throw StateError('FakeBackend is not running (status: $_status)');
    }
    sentMessages.add(message);

    switch (message.whichKind()) {
      case pb.ToEngine_Kind.setCard:
        await _handleSetCard();
      case pb.ToEngine_Kind.setSetup:
        _handleSetSetup(message.setSetup);
      case pb.ToEngine_Kind.audition:
        final isSample =
            message.audition.path.toLowerCase().endsWith('.wav');
        if (!isSample && _activeSetup.length >= 16) {
          _emit(
            pb.FromEngine(
              error: pb.ErrorReply(
                command: 'audition',
                message: 'All 16 MIDI channels are bound; no channel free to audition preset',
              ),
            ),
          );
        } else {
          _voices = max(_voices, 2);
          _emitHeartbeat();
        }
      case pb.ToEngine_Kind.note:
        final n = message.note;
        if (n.on) {
          _voices = min(32, _voices + 1);
          _emit(pb.FromEngine(midiActivity: pb.MidiActivity(channel: n.channel)));
        } else {
          _voices = max(0, _voices - 1);
        }
        _emitHeartbeat();
      case pb.ToEngine_Kind.setDevices:
        // Stored implicitly; Devices list was already emitted on connect.
        break;
      case pb.ToEngine_Kind.renderPiece:
        unawaited(_handleRenderPiece(message.renderPiece));
      case pb.ToEngine_Kind.cancelRender:
        _cancelledRenders.add(message.cancelRender.id);
      case pb.ToEngine_Kind.play:
        _playingWavPath = message.play.wavPath;
        _playingPositionS = message.play.positionS;
        _emit(
          pb.FromEngine(
            position: pb.Position(
              wavPath: _playingWavPath!,
              timeS: _playingPositionS,
            ),
          ),
        );
      case pb.ToEngine_Kind.seek:
        _playingPositionS = message.seek.positionS;
        if (_playingWavPath != null) {
          _emit(
            pb.FromEngine(
              position: pb.Position(
                wavPath: _playingWavPath!,
                timeS: _playingPositionS,
              ),
            ),
          );
        }
      case pb.ToEngine_Kind.stop:
        _playingWavPath = null;
      case pb.ToEngine_Kind.playPiece:
        if (!hasCapability('play_live')) {
          _emit(
            pb.FromEngine(
              error: pb.ErrorReply(
                command: 'play_piece',
                message: "Capability 'play_live' is not supported",
              ),
            ),
          );
        } else {
          _voices = 9;
          _emitHeartbeat();
        }
      case pb.ToEngine_Kind.stopPiece:
        _voices = 0;
        _emitHeartbeat();
      case pb.ToEngine_Kind.shutdown:
        await shutdown();
      case pb.ToEngine_Kind.notSet:
        _emit(
          pb.FromEngine(
            error: pb.ErrorReply(
              command: 'unknown',
              message: 'Empty ToEngine message',
            ),
          ),
        );
    }
  }

  Future<void> _handleSetCard() async {
    if (holdCardBuild) {
      advanceCardProgress(0, cardBuildSteps);
      return;
    }
    for (var i = 0; i <= cardBuildSteps; i++) {
      if (_disposed || _status != BackendStatus.running) return;
      advanceCardProgress(i, cardBuildSteps);
      if (stepDelay > Duration.zero && i < cardBuildSteps) {
        await Future<void>.delayed(stepDelay);
      }
    }
    if (_disposed || _status != BackendStatus.running) return;
    completeCardBuild();
  }

  void _handleSetSetup(pb.SetSetup setup) {
    _activeSetup.clear();
    final results = <pb.BindingResult>[];
    for (final b in setup.bindings) {
      final err = setupErrors[b.channel];
      if (err != null) {
        results.add(
          pb.BindingResult(channel: b.channel, ok: false, error: err),
        );
      } else {
        _activeSetup[b.channel] = b.path;
        results.add(pb.BindingResult(channel: b.channel, ok: true));
      }
    }
    _emit(pb.FromEngine(setupApplied: pb.SetupApplied(results: results)));
  }

  Future<void> _handleRenderPiece(pb.RenderPiece req) async {
    _cancelledRenders.remove(req.id);
    final duration = req.lengthS > 0 ? req.lengthS : 60.0;
    final genre = _genres.genres.firstWhere(
      (g) => g.id == req.recipe.genre,
      orElse: () => _genres.genres.first,
    );

    const steps = 4;
    for (var i = 1; i <= steps; i++) {
      if (_disposed ||
          _status != BackendStatus.running ||
          _cancelledRenders.contains(req.id)) {
        return;
      }
      _emit(
        pb.FromEngine(
          renderProgress: pb.RenderProgress(
            id: req.id,
            doneS: duration * (i / steps),
            totalS: duration,
          ),
        ),
      );
      if (stepDelay > Duration.zero) {
        await Future<void>.delayed(stepDelay);
      }
    }

    if (_disposed ||
        _status != BackendStatus.running ||
        _cancelledRenders.contains(req.id)) {
      return;
    }

    final rolledRecipe = _fillRecipe(genre, req.recipe);
    final waveSeed = _deterministicWaveSeed(rolledRecipe);

    _emit(
      pb.FromEngine(
        renderDone: pb.RenderDone(
          id: req.id,
          wavPath: req.wavPath,
          durationS: duration,
          recipe: rolledRecipe,
          sections: buildFakeSections(duration),
          peaks: buildFakePeaks(waveSeed),
          notes: buildFakeNotes(genre, rolledRecipe.seed, duration),
          peakVoices: 8 + (rolledRecipe.seed % 10),
        ),
      ),
    );
  }

  pb.Recipe _fillRecipe(pb.GenreInfo genre, pb.Recipe input) {
    final rng = Random(input.seed);
    final existingParts = <int, String>{};
    final existingLanes = <int, String>{};
    for (final pick in input.picks) {
      if (pick.whichTarget() == pb.SoundPick_Target.part) {
        existingParts[pick.part] = pick.path;
      } else if (pick.whichTarget() == pb.SoundPick_Target.lane) {
        existingLanes[pick.lane] = pick.path;
      }
    }

    String rollPalette(List<pb.PaletteEntry> palette) {
      if (palette.isEmpty) return '';
      final total = palette.fold<int>(0, (a, e) => a + e.weight);
      if (total <= 0) return palette.first.path;
      var r = rng.nextInt(total);
      for (final e in palette) {
        r -= e.weight;
        if (r < 0) return e.path;
      }
      return palette.last.path;
    }

    final picks = <pb.SoundPick>[];
    for (final part in genre.parts) {
      if (part.lanes.isEmpty) {
        final chosen = existingParts[part.index] ?? rollPalette(part.palette);
        picks.add(pb.SoundPick(part: part.index, path: chosen));
      } else {
        for (final lane in part.lanes) {
          final chosen = existingLanes[lane.index] ?? rollPalette(lane.palette);
          picks.add(pb.SoundPick(lane: lane.index, path: chosen));
        }
      }
    }

    return pb.Recipe(
      genre: genre.id,
      seed: input.seed,
      entropy: input.hasEntropy() ? input.entropy : input.seed,
      macros: input.macros.isNotEmpty ? input.macros : [25, 25, 25, 25],
      tempo: input.hasTempo() ? input.tempo : 126.0 + (input.seed % 12),
      key: input.hasKey() ? input.key : (input.seed % 12),
      scale: input.hasScale() ? input.scale : 1,
      scaleName: input.hasScaleName() ? input.scaleName : 'Minor',
      swing: input.hasSwing() ? input.swing : 0,
      picks: picks,
    );
  }

  /// Deterministic FNV-1a 32-bit hash over recipe seed and picks so fake
  /// waveforms are identical across Dart VM invocations (spec §8 goldens).
  static int _deterministicWaveSeed(pb.Recipe recipe) {
    var hash = 0x811c9dc5 ^ (recipe.seed & 0xFFFFFFFF);
    for (final pick in recipe.picks) {
      for (final unit in pick.path.codeUnits) {
        hash ^= unit & 0xFF;
        hash = (hash * 0x01000193) & 0xFFFFFFFF;
      }
      hash ^= 0xFF;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  @override
  Future<void> shutdown() async {
    _heartbeatTimer?.cancel();
    _restartTimer?.cancel();
    _voices = 0;
    _playingWavPath = null;
    _playingPositionS = 0.0;
    _activeSetup.clear();
    _cancelledRenders.clear();
    _setStatus(BackendStatus.stopped);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _heartbeatTimer?.cancel();
    _restartTimer?.cancel();
    await _events.close();
    await _lifecycle.close();
  }

  void _emit(pb.FromEngine msg) {
    if (!_disposed && !_events.isClosed) {
      _events.add(msg);
    }
  }

  void _setStatus(
    BackendStatus next, {
    FreezeInfo? freeze,
    String? errorMessage,
    bool isRestart = false,
  }) {
    _status = next;
    if (freeze != null) _lastFreeze = freeze;
    if (errorMessage != null) _errorMessage = errorMessage;
    if (!_disposed && !_lifecycle.isClosed) {
      _lifecycle.add(
        BackendLifecycleEvent(
          status: next,
          freeze: freeze,
          errorMessage: errorMessage,
          isRestart: isRestart,
        ),
      );
    }
  }
}

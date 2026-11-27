import 'dart:async';
import 'dart:convert';

import 'package:deluge_engine_gui/backend/backend.dart';
import 'package:deluge_engine_gui/model/state_store.dart';
import 'package:deluge_engine_gui/proto/engine.pb.dart' as pb;
import 'package:flutter/foundation.dart';

/// Top-level screen switch in the top bar (spec §8).
enum AppMode { piece, setup }

/// The two views of one Piece (spec §8). Both share all view state in [AppModel].
enum PieceTab { compare, timeline }

/// State of the active card folder and its FAT32 card image (spec §3.6, §8).
enum CardState { unselected, building, ready, error }

/// Central application model: owns persistent documents, view state, and
/// synchronization with the [Backend] (spec §7.3, §7.7, §8).
///
/// Plain [ChangeNotifier] with no external state-management package (spec §8).
class AppModel extends ChangeNotifier {
  AppModel({
    required this.backend,
    required this.store,
  });

  final Backend backend;
  final StateStore store;

  StreamSubscription<pb.FromEngine>? _eventsSub;
  StreamSubscription<BackendLifecycleEvent>? _lifecycleSub;
  bool _initialized = false;
  bool _disposed = false;

  // ---- Backend & Engine status ----
  BackendStatus _backendStatus = BackendStatus.stopped;
  pb.Hello? _hello;
  int _voices = 0;
  double _cpuLoad = 0.0;
  int _underruns = 0;
  FreezeInfo? _lastFreeze;
  String? _versionMismatchMessage;
  String? _lastError;
  String _statusMessage = 'Starting Engine…';

  // ---- Card & Backend-supplied lists (spec §7.3, §7.4) ----
  String? _cardFolder;
  CardState _cardState = CardState.unselected;
  int _cardProgressDone = 0;
  int _cardProgressTotal = 0;
  String? _cardError;
  pb.Catalog _catalog = pb.Catalog();
  List<pb.GenreInfo> _genres = const [];

  // ---- Devices ----
  List<String> _audioOutputs = const [];
  List<String> _midiInputs = const [];
  String _selectedAudioOutput = '';
  List<String> _selectedMidiInputs = const [];

  // ---- Setup document & view state ----
  final Map<int, String> _setupBindings = <int, String>{};
  final Map<int, String> _channelErrors = <int, String>{};
  final Map<int, DateTime> _channelActivity = <int, DateTime>{};
  int _selectedChannel = 1;

  // ---- Piece document & shared view state (Compare + Timeline) ----
  AppMode _mode = AppMode.piece;
  PieceTab _pieceTab = PieceTab.compare;
  bool _pickerOpen = true;
  String? _genreId;
  int _seed = 12345;
  int _lengthSeconds = 60;
  final Map<String, String> _picks = <String, String>{};
  bool _autoRender = true;
  String? _selectedSlotKey;
  String _ab = 'A';
  double _playheadPositionS = 0.0;
  String? _playingWavPath;
  bool _livePlaying = false;
  String? _auditioningPath;

  // ---- Renders & settings ----
  int? _voiceWarningThreshold;
  final List<RenderRecord> _renders = <RenderRecord>[];
  final Map<String, pb.RenderDone> _renderDetails = <String, pb.RenderDone>{};
  final Map<String, pb.RenderProgress> _activeRenders =
      <String, pb.RenderProgress>{};
  String? _slotAId;
  String? _slotBId;

  // ---- Getters ----
  BackendStatus get backendStatus => _backendStatus;
  pb.Hello? get hello => _hello;
  int get voices => _voices;
  double get cpuLoad => _cpuLoad;
  int get underruns => _underruns;
  FreezeInfo? get lastFreeze => _lastFreeze;
  String? get versionMismatchMessage => _versionMismatchMessage;
  String? get lastError => _lastError;
  String get statusMessage => _statusMessage;

  bool hasCapability(String cap) =>
      _hello?.capabilities.contains(cap) ?? false;

  String? get cardFolder => _cardFolder;
  CardState get cardState => _cardState;
  int get cardProgressDone => _cardProgressDone;
  int get cardProgressTotal => _cardProgressTotal;
  String? get cardError => _cardError;
  pb.Catalog get catalog => _catalog;
  List<pb.GenreInfo> get genres => _genres;

  List<String> get audioOutputs => _audioOutputs;
  List<String> get midiInputs => _midiInputs;
  String get selectedAudioOutput => _selectedAudioOutput;
  List<String> get selectedMidiInputs => _selectedMidiInputs;

  Map<int, String> get setupBindings => Map.unmodifiable(_setupBindings);
  Map<int, String> get channelErrors => Map.unmodifiable(_channelErrors);
  Map<int, DateTime> get channelActivity => Map.unmodifiable(_channelActivity);
  int get selectedChannel => _selectedChannel;

  AppMode get mode => _mode;
  PieceTab get pieceTab => _pieceTab;
  bool get pickerOpen => _pickerOpen;
  String? get genreId => _genreId;
  int get seed => _seed;
  int get lengthSeconds => _lengthSeconds;
  Map<String, String> get picks => Map.unmodifiable(_picks);
  bool get autoRender => _autoRender;
  String? get selectedSlotKey => _selectedSlotKey;
  String get ab => _ab;
  double get playheadPositionS => _playheadPositionS;
  String? get playingWavPath => _playingWavPath;
  bool get livePlaying => _livePlaying;
  String? get auditioningPath => _auditioningPath;

  int? get voiceWarningThreshold => _voiceWarningThreshold;
  List<RenderRecord> get renders => List.unmodifiable(_renders);
  Map<String, pb.RenderDone> get renderDetails =>
      Map.unmodifiable(_renderDetails);
  Map<String, pb.RenderProgress> get activeRenders =>
      Map.unmodifiable(_activeRenders);
  String? get slotAId => _slotAId;
  String? get slotBId => _slotBId;

  pb.GenreInfo? get activeGenre {
    if (_genres.isEmpty) return null;
    if (_genreId != null) {
      for (final g in _genres) {
        if (g.id == _genreId) return g;
      }
    }
    return _genres.first;
  }

  /// Loads `state.json`, subscribes to [backend], and starts the Backend.
  Future<void> init() async {
    if (_initialized || _disposed) return;
    _initialized = true;

    final saved = await store.load();
    if (saved != null) {
      _cardFolder = saved.cardFolder;
      _setupBindings
        ..clear()
        ..addAll(saved.setupBindings);
      _genreId = saved.genreId;
      _seed = saved.seed;
      _lengthSeconds = saved.lengthSeconds;
      _picks
        ..clear()
        ..addAll(saved.picks);
      _autoRender = saved.autoRender;
      _selectedAudioOutput = saved.audioOutput;
      _selectedMidiInputs = List<String>.of(saved.midiInputs);
      _voiceWarningThreshold = saved.voiceWarningThreshold;
      _renders
        ..clear()
        ..addAll(saved.renders);
      _slotAId = saved.slotAId;
      _slotBId = saved.slotBId;
    }

    _eventsSub = backend.events.listen(_onBackendEvent);
    _lifecycleSub = backend.lifecycle.listen(_onLifecycleEvent);
    _backendStatus = backend.status;
    notifyListeners();

    await backend.start();
  }

  void _onLifecycleEvent(BackendLifecycleEvent event) {
    if (_disposed) return;
    _backendStatus = event.status;
    if (event.freeze != null) {
      _lastFreeze = event.freeze;
    }

    switch (event.status) {
      case BackendStatus.starting:
        _statusMessage = 'Starting Engine…';
      case BackendStatus.running:
        _hello = backend.hello;
        _versionMismatchMessage = null;
        if (event.isRestart) {
          _statusMessage = 'Engine restarted. Restoring card and Setup…';
        } else {
          _statusMessage =
              _cardFolder == null ? 'Choose a card folder' : 'Engine ready';
        }
        unawaited(_syncSessionToBackend());
      case BackendStatus.restarting:
        _voices = 0;
        _playingWavPath = null;
        _livePlaying = false;
        _activeRenders.clear();
        final code = _lastFreeze?.code ?? 'unknown';
        _lastError = 'Engine froze: ${_lastFreeze?.summary ?? code}';
        _statusMessage =
            'Engine froze ($code). Restarting and reloading your Setup…';
      case BackendStatus.crashed:
        _voices = 0;
        _playingWavPath = null;
        _livePlaying = false;
        _activeRenders.clear();
        final code = _lastFreeze?.code ?? 'unknown';
        _lastError = 'Engine froze: ${_lastFreeze?.summary ?? code}';
        _statusMessage =
            'Engine stopped after repeated freezes ($code). Tap Restart to try again.';
      case BackendStatus.versionMismatch:
        _versionMismatchMessage =
            event.errorMessage ?? backend.versionMismatchMessage;
        _lastError = _versionMismatchMessage;
        _statusMessage = _versionMismatchMessage ?? 'Protocol version mismatch';
      case BackendStatus.error:
        _lastError = event.errorMessage ?? backend.errorMessage;
        _statusMessage = _lastError ?? 'Engine error';
      case BackendStatus.stopped:
        _voices = 0;
        _playingWavPath = null;
        _livePlaying = false;
        _statusMessage = 'Engine stopped';
    }
    notifyListeners();
  }

  Future<void> _syncSessionToBackend() async {
    if (_disposed || _backendStatus != BackendStatus.running) return;
    try {
      await backend.setDevices(
        audioOutput: _selectedAudioOutput,
        midiInputs: _selectedMidiInputs,
      );
      final folder = _cardFolder;
      if (folder != null && folder.isNotEmpty) {
        _cardState = CardState.building;
        _cardProgressDone = 0;
        _cardProgressTotal = 0;
        _cardError = null;
        notifyListeners();
        await backend.setCard(folder);
      }
    } catch (e) {
      if (_disposed) return;
      _lastError = 'Failed to sync with Engine: $e';
      notifyListeners();
    }
  }

  void _onBackendEvent(pb.FromEngine msg) {
    if (_disposed) return;
    switch (msg.whichKind()) {
      case pb.FromEngine_Kind.hello:
        _hello = msg.hello;
      case pb.FromEngine_Kind.heartbeat:
        _voices = msg.heartbeat.voices;
        _cpuLoad = msg.heartbeat.cpuLoad;
        _underruns = msg.heartbeat.underruns.toInt();
      case pb.FromEngine_Kind.cardStatus:
        final cs = msg.cardStatus;
        switch (cs.whichState()) {
          case pb.CardStatus_State.progress:
            _cardState = CardState.building;
            _cardProgressDone = cs.progress.done;
            _cardProgressTotal = cs.progress.total;
            _cardError = null;
            _statusMessage = cs.progress.total > 0
                ? 'Building card image (${cs.progress.done}/${cs.progress.total})…'
                : 'Building card image…';
          case pb.CardStatus_State.ready:
            _cardState = CardState.ready;
            _cardError = null;
            _statusMessage = 'Engine ready';
            if (_setupBindings.isNotEmpty) {
              unawaited(_sendCurrentSetup());
            }
          case pb.CardStatus_State.error:
            _cardState = CardState.error;
            _cardError = cs.error.text;
            _lastError = cs.error.text;
            _statusMessage = 'Card error: ${cs.error.text}';
          case pb.CardStatus_State.notSet:
            break;
        }
      case pb.FromEngine_Kind.catalog:
        _catalog = msg.catalog;
      case pb.FromEngine_Kind.genres:
        _genres = List<pb.GenreInfo>.unmodifiable(msg.genres.genres);
        if (_genreId == null && _genres.isNotEmpty) {
          _genreId = _genres.first.id;
        }
      case pb.FromEngine_Kind.setupApplied:
        _channelErrors.clear();
        for (final r in msg.setupApplied.results) {
          if (!r.ok && r.error.isNotEmpty) {
            _channelErrors[r.channel] = r.error;
          }
        }
      case pb.FromEngine_Kind.midiActivity:
        _channelActivity[msg.midiActivity.channel] = DateTime.now();
      case pb.FromEngine_Kind.devices:
        _audioOutputs =
            List<String>.unmodifiable(msg.devices.audioOutputs);
        _midiInputs = List<String>.unmodifiable(msg.devices.midiInputs);
      case pb.FromEngine_Kind.freeze_9:
        final f = msg.freeze_9;
        _lastFreeze = FreezeInfo(
          code: f.code.isEmpty ? 'FREEZE' : f.code,
          message: f.message,
          loaded: f.loaded,
          timestamp: DateTime.now(),
        );
      case pb.FromEngine_Kind.renderProgress:
        _activeRenders[msg.renderProgress.id] = msg.renderProgress;
      case pb.FromEngine_Kind.renderDone:
        final done = msg.renderDone;
        _activeRenders.remove(done.id);
        _renderDetails[done.id] = done;
        final record = RenderRecord(
          id: done.id,
          wavPath: done.wavPath,
          genreId: done.recipe.genre,
          seed: done.recipe.seed,
          durationS: done.durationS,
          peakVoices: done.peakVoices,
          kept: false,
          createdAt: DateTime.now().toUtc(),
        );
        _renders.insert(0, record);
        if (_slotAId == null) {
          _slotAId = record.id;
          _ab = 'A';
        } else {
          _slotBId = record.id;
          _ab = 'B';
        }
        _statusMessage = 'Render complete (${done.durationS.toStringAsFixed(0)} s)';
        _saveDocumentStateInBackground();
      case pb.FromEngine_Kind.renderFailed:
        final rf = msg.renderFailed;
        _activeRenders.remove(rf.id);
        final code = rf.freezeCode.isNotEmpty ? ' (${rf.freezeCode})' : '';
        _lastError = 'Render failed$code: ${rf.error}';
        _statusMessage = _lastError!;
      case pb.FromEngine_Kind.position:
        _playingWavPath = msg.position.wavPath;
        _playheadPositionS = msg.position.timeS;
      case pb.FromEngine_Kind.error:
        _lastError = '${msg.error.command}: ${msg.error.message}';
        _statusMessage = _lastError!;
      case pb.FromEngine_Kind.notSet:
        break;
    }
    notifyListeners();
  }

  // ---- Document & View Actions ----

  /// Selects a new card folder, persists it to `state.json`, and sends `SetCard`.
  Future<void> setCardFolder(String folder) async {
    final trimmed = folder.trim();
    if (trimmed.isEmpty) return;
    _cardFolder = trimmed;
    _cardState = CardState.building;
    _cardProgressDone = 0;
    _cardProgressTotal = 0;
    _cardError = null;
    _statusMessage = 'Building card image from $trimmed…';
    notifyListeners();

    await saveDocumentState();
    if (_backendStatus == BackendStatus.running) {
      try {
        await backend.setCard(trimmed);
      } catch (e) {
        if (_disposed) return;
        _lastError = 'Failed to send card folder: $e';
        notifyListeners();
      }
    }
  }

  /// Triggers a manual Backend restart (after 3 freezes in 1 minute or error).
  Future<void> restartBackend() async {
    _statusMessage = 'Restarting Engine…';
    notifyListeners();
    await backend.restart();
  }

  void setMode(AppMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void setPieceTab(PieceTab tab) {
    if (_pieceTab == tab) return;
    _pieceTab = tab;
    notifyListeners();
  }

  void setPickerOpen(bool open) {
    if (_pickerOpen == open) return;
    _pickerOpen = open;
    notifyListeners();
  }

  void selectChannel(int channel) {
    if (channel < 1 || channel > 16 || _selectedChannel == channel) return;
    _selectedChannel = channel;
    notifyListeners();
  }

  Future<void> setBinding(int channel, String? path) async {
    if (channel < 1 || channel > 16) return;
    if (path == null || path.isEmpty) {
      _setupBindings.remove(channel);
      _channelErrors.remove(channel);
      _statusMessage = 'Channel $channel cleared';
    } else {
      _setupBindings[channel] = path;
      _statusMessage = 'Channel $channel ← $path';
    }
    notifyListeners();
    await saveDocumentState();
    await _sendCurrentSetup();
  }

  Future<void> _sendCurrentSetup() async {
    if (_disposed || _backendStatus != BackendStatus.running) return;
    try {
      await backend.setSetup(_setupBindings);
    } catch (e) {
      if (_disposed) return;
      _lastError = 'Failed to send Setup: $e';
      notifyListeners();
    }
  }

  Future<void> setDevices({
    String? audioOutput,
    List<String>? midiInputs,
  }) async {
    if (audioOutput != null) _selectedAudioOutput = audioOutput;
    if (midiInputs != null) _selectedMidiInputs = List<String>.of(midiInputs);
    notifyListeners();
    await saveDocumentState();
    if (_backendStatus == BackendStatus.running) {
      try {
        await backend.setDevices(
          audioOutput: _selectedAudioOutput,
          midiInputs: _selectedMidiInputs,
        );
      } catch (e) {
        if (_disposed) return;
        _lastError = 'Failed to set devices: $e';
        notifyListeners();
      }
    }
  }

  void selectSlot(String? slotKey) {
    if (_selectedSlotKey == slotKey) return;
    _selectedSlotKey = slotKey;
    notifyListeners();
  }

  void setAB(String ab) {
    if (ab != 'A' && ab != 'B') return;
    _ab = ab;
    notifyListeners();
  }

  void setPlayheadPosition(double seconds) {
    _playheadPositionS = seconds < 0 ? 0 : seconds;
    notifyListeners();
  }

  void setAutoRender(bool value) {
    if (_autoRender == value) return;
    _autoRender = value;
    notifyListeners();
    _saveDocumentStateInBackground();
  }

  void setVoiceWarningThreshold(int? threshold) {
    _voiceWarningThreshold = threshold;
    notifyListeners();
    _saveDocumentStateInBackground();
  }

  void setAuditioningPath(String? path) {
    _auditioningPath = path;
    notifyListeners();
  }

  AppDocumentState toDocumentState() => AppDocumentState(
        cardFolder: _cardFolder,
        setupBindings: Map<int, String>.of(_setupBindings),
        genreId: _genreId,
        seed: _seed,
        lengthSeconds: _lengthSeconds,
        picks: Map<String, String>.of(_picks),
        autoRender: _autoRender,
        audioOutput: _selectedAudioOutput,
        midiInputs: List<String>.of(_selectedMidiInputs),
        voiceWarningThreshold: _voiceWarningThreshold,
        renders: List<RenderRecord>.of(_renders),
        slotAId: _slotAId,
        slotBId: _slotBId,
      );

  Future<void> saveDocumentState() => store.save(toDocumentState());

  void _saveDocumentStateInBackground() {
    unawaited(
      saveDocumentState().catchError((Object e) {
        if (_disposed) return;
        _lastError = 'Failed to save state: $e';
        notifyListeners();
      }),
    );
  }

  /// Full state snapshot as pretty-printed JSON for the `{}` debug panel (spec §8).
  String toDebugJson() => const JsonEncoder.withIndent('  ').convert({
        'backendStatus': _backendStatus.name,
        'hello': _hello == null
            ? null
            : {
                'protocolVersion': _hello!.protocolVersion,
                'engineVersion': _hello!.engineVersion,
                'firmwareCommit': _hello!.firmwareCommit,
                'capabilities': _hello!.capabilities,
              },
        'voices': _voices,
        'cpuLoad': _cpuLoad,
        'underruns': _underruns,
        'lastFreeze': _lastFreeze?.toJson(),
        'lastError': _lastError,
        'statusMessage': _statusMessage,
        'cardFolder': _cardFolder,
        'cardState': _cardState.name,
        'cardProgress': {
          'done': _cardProgressDone,
          'total': _cardProgressTotal,
        },
        'catalogCounts': {
          'synths': _catalog.synths.length,
          'kits': _catalog.kits.length,
        },
        'genres': [for (final g in _genres) g.id],
        'mode': _mode.name,
        'pieceTab': _pieceTab.name,
        'pickerOpen': _pickerOpen,
        'selectedChannel': _selectedChannel,
        'selectedSlotKey': _selectedSlotKey,
        'ab': _ab,
        'playheadPositionS': _playheadPositionS,
        'playingWavPath': _playingWavPath,
        'livePlaying': _livePlaying,
        'document': toDocumentState().toJson(),
      });

  /// Cleanly shuts down subscriptions and the Backend.
  Future<void> disposeAsync() async {
    if (_disposed) return;
    _disposed = true;
    await _eventsSub?.cancel();
    await _lifecycleSub?.cancel();
    await backend.dispose();
    super.dispose();
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      unawaited(_eventsSub?.cancel());
      unawaited(_lifecycleSub?.cancel());
      unawaited(backend.dispose());
      super.dispose();
    }
  }
}

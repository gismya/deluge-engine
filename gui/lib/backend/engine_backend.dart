import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:deluge_engine_gui/backend/backend.dart';
import 'package:deluge_engine_gui/backend/framing.dart';
import 'package:deluge_engine_gui/backend/restart_policy.dart';
import 'package:deluge_engine_gui/proto/engine.pb.dart' as pb;
import 'package:path/path.dart' as p;

/// Maximum UTF-8 byte length for a Unix domain socket path under `$TMPDIR`
/// before falling back to `/tmp` (spec §7.1).
const int kMaxUnixSocketPathBytes = 100;

/// Real [Backend] implementation talking to `deluge-engine serve` over a Unix
/// domain socket using 4-byte little-endian protobuf framing (spec §7.1, §7.2,
/// §7.7, §12).
class EngineBackend extends Backend {
  EngineBackend({
    this.executablePath,
    this.audioBackend = 'default',
    this.trace = false,
    this.extraArgs = const [],
    this.socketPathOverride,
    this.spawnProcess = true,
    this.connectTimeout = const Duration(seconds: 5),
    this.heartbeatTimeout = const Duration(seconds: 2),
    this.restartDelay = const Duration(milliseconds: 250),
    this.shutdownTimeout = const Duration(seconds: 3),
    RestartPolicy? restartPolicy,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        _restartPolicy = restartPolicy ?? RestartPolicy(now: now);

  final String? executablePath;
  final String audioBackend;
  final bool trace;
  final List<String> extraArgs;

  /// Optional pre-determined socket path (used by tests with a fake Unix server).
  final String? socketPathOverride;

  /// When `false`, connects directly to [socketPathOverride] without spawning
  /// a child process (used by socket framing/restart tests).
  final bool spawnProcess;

  final Duration connectTimeout;
  final Duration heartbeatTimeout;
  final Duration restartDelay;
  final Duration shutdownTimeout;

  final DateTime Function() _now;
  final RestartPolicy _restartPolicy;

  final StreamController<pb.FromEngine> _events =
      StreamController<pb.FromEngine>.broadcast();
  final StreamController<BackendLifecycleEvent> _lifecycle =
      StreamController<BackendLifecycleEvent>.broadcast(sync: true);

  BackendStatus _status = BackendStatus.stopped;
  pb.Hello? _hello;
  FreezeInfo? _lastFreeze;
  String? _versionMismatchMessage;
  String? _errorMessage;

  Process? _process;
  Socket? _socket;
  StreamSubscription<List<int>>? _socketSub;
  Directory? _ownedSocketDir;
  Timer? _heartbeatTimer;
  Timer? _restartTimer;
  final FrameDecoder _decoder = FrameDecoder();
  final List<String> _stderrTail = <String>[];

  bool _disposed = false;
  bool _intentionalStop = false;
  bool _handlingFailure = false;
  bool _processExited = false;
  int? _processExitCode;
  int _sessionId = 0;

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

  /// Recent stderr lines from the Engine process, for diagnostics.
  List<String> get stderrTail => List.unmodifiable(_stderrTail);

  /// Resolves the `deluge-engine` binary path (spec §12).
  String resolveExecutablePath() {
    if (executablePath != null && executablePath!.isNotEmpty) {
      return executablePath!;
    }
    final envPath = Platform.environment['DELUGE_ENGINE_BIN'];
    if (envPath != null && envPath.isNotEmpty) {
      return envPath;
    }
    // Inside the macOS app bundle: Contents/MacOS/deluge-engine beside the runner.
    final exeDir = p.dirname(Platform.resolvedExecutable);
    return p.join(exeDir, 'deluge-engine');
  }

  /// Creates a short Unix socket path (< 100 UTF-8 bytes under `$TMPDIR`, else `/tmp`).
  static (String socketPath, Directory ownedDir) createSocketPath() {
    final tmpDirEnv = Platform.environment['TMPDIR'];
    if (tmpDirEnv != null && tmpDirEnv.isNotEmpty) {
      final base = Directory(tmpDirEnv);
      if (base.existsSync()) {
        final dir = base.createTempSync('deluge-engine-');
        final candidate = p.join(dir.path, 'e.sock');
        if (utf8.encode(candidate).length < kMaxUnixSocketPathBytes) {
          return (candidate, dir);
        }
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
    final fallback = Directory('/tmp').createTempSync('de-');
    return (p.join(fallback.path, 'e.sock'), fallback);
  }

  @override
  Future<void> start() async {
    if (_disposed) return;
    _intentionalStop = false;
    _versionMismatchMessage = null;
    _errorMessage = null;
    await _startSession(isRestart: false);
  }

  @override
  Future<void> restart() async {
    if (_disposed) return;
    _restartTimer?.cancel();
    _restartTimer = null;
    _restartPolicy.reset();
    _intentionalStop = false;
    _handlingFailure = false;
    _versionMismatchMessage = null;
    _errorMessage = null;
    await _cleanupConnection(killProcess: true);
    await _startSession(isRestart: true);
  }

  @override
  Future<void> send(pb.ToEngine message) async {
    final sock = _socket;
    if (sock == null || _status != BackendStatus.running) {
      throw StateError('EngineBackend is not running (status: $_status)');
    }
    sock.add(encodeFrame(message));
    await sock.flush();
  }

  @override
  Future<void> shutdown() async {
    _intentionalStop = true;
    _restartTimer?.cancel();
    _restartTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    final sock = _socket;
    if (sock != null) {
      try {
        sock.add(encodeFrame(pb.ToEngine(shutdown: pb.Shutdown())));
        await sock.flush();
      } catch (_) {
        // Best-effort clean shutdown.
      }
    }

    final proc = _process;
    if (proc != null) {
      try {
        await proc.exitCode.timeout(shutdownTimeout);
      } catch (_) {
        proc.kill(ProcessSignal.sigkill);
      }
    }

    await _cleanupConnection(killProcess: false);
    _setStatus(BackendStatus.stopped);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _intentionalStop = true;
    _restartTimer?.cancel();
    _heartbeatTimer?.cancel();
    await _cleanupConnection(killProcess: true);
    await _events.close();
    await _lifecycle.close();
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

  Future<void> _startSession({required bool isRestart}) async {
    final session = ++_sessionId;
    _handlingFailure = false;
    _processExited = false;
    _processExitCode = null;
    _hello = null;
    _decoder.reset();
    _setStatus(
      isRestart ? BackendStatus.restarting : BackendStatus.starting,
      isRestart: isRestart,
    );

    String sockPath;
    if (socketPathOverride != null) {
      sockPath = socketPathOverride!;
    } else {
      final (createdPath, dir) = createSocketPath();
      sockPath = createdPath;
      _ownedSocketDir = dir;
    }

    if (spawnProcess) {
      final exe = resolveExecutablePath();
      if (!File(exe).existsSync()) {
        final msg = 'Engine binary not found at $exe';
        _setStatus(BackendStatus.error, errorMessage: msg);
        return;
      }
      final args = <String>[
        'serve',
        '--socket',
        sockPath,
        '--audio',
        audioBackend,
        if (trace) '--trace',
        ...extraArgs,
      ];
      try {
        final proc = await Process.start(exe, args);
        _process = proc;
        _stderrTail.clear();
        proc.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          _stderrTail.add(line);
          if (_stderrTail.length > 50) _stderrTail.removeAt(0);
        });
        unawaited(proc.exitCode.then((code) {
          if (session != _sessionId || _intentionalStop || _disposed) return;
          _processExited = true;
          _processExitCode = code;
          if (_status == BackendStatus.running) {
            _onUnexpectedFailure(
              FreezeInfo(
                code: 'EXIT($code)',
                message: 'Engine exited unexpectedly with status $code',
                loaded: '',
                timestamp: _now(),
              ),
            );
          }
        }));
      } catch (e) {
        _setStatus(
          BackendStatus.error,
          errorMessage: 'Failed to start Engine: $e',
        );
        return;
      }
    }

    Socket socket;
    try {
      socket = await _connectWithRetry(sockPath, session);
    } catch (e) {
      if (session != _sessionId || _intentionalStop || _disposed) return;
      await _cleanupConnection(killProcess: true);
      if (isRestart) {
        _onUnexpectedFailure(
          FreezeInfo(
            code: 'CONNECT',
            message: 'Failed to reconnect to Engine: $e',
            loaded: '',
            timestamp: _now(),
          ),
        );
      } else {
        _setStatus(
          BackendStatus.error,
          errorMessage: 'Failed to connect to Engine socket: $e',
        );
      }
      return;
    }

    if (session != _sessionId || _intentionalStop || _disposed) {
      socket.destroy();
      return;
    }

    _socket = socket;
    final helloCompleter = Completer<pb.Hello>();

    _socketSub = socket.listen(
      (chunk) {
        if (session != _sessionId || _disposed) return;
        List<Uint8List> frames;
        try {
          frames = _decoder.addChunk(chunk);
        } on FramingException catch (e) {
          if (!helloCompleter.isCompleted) {
            helloCompleter.completeError(e);
          }
          _onUnexpectedFailure(
            FreezeInfo(
              code: 'FRAME',
              message: e.message,
              loaded: '',
              timestamp: _now(),
            ),
          );
          return;
        }

        for (final payload in frames) {
          pb.FromEngine msg;
          try {
            msg = pb.FromEngine.fromBuffer(payload);
          } catch (e) {
            if (!helloCompleter.isCompleted) {
              helloCompleter.completeError(e);
            }
            _onUnexpectedFailure(
              FreezeInfo(
                code: 'PARSE',
                message: 'Malformed protobuf frame from Engine: $e',
                loaded: '',
                timestamp: _now(),
              ),
            );
            return;
          }

          if (!helloCompleter.isCompleted) {
            if (msg.whichKind() != pb.FromEngine_Kind.hello) {
              helloCompleter.completeError(
                StateError(
                  'Expected Hello as first Engine frame, got ${msg.whichKind()}',
                ),
              );
              return;
            }
            helloCompleter.complete(msg.hello);
            continue;
          }

          _handleIncomingMessage(msg, session);
        }
      },
      onError: (Object error) {
        if (!helloCompleter.isCompleted) {
          helloCompleter.completeError(error);
        }
        if (session != _sessionId || _intentionalStop || _disposed) return;
        _onUnexpectedFailure(
          FreezeInfo(
            code: 'SOCKET',
            message: 'Engine socket error: $error',
            loaded: '',
            timestamp: _now(),
          ),
        );
      },
      onDone: () {
        if (!helloCompleter.isCompleted) {
          helloCompleter.completeError(
            StateError('Engine closed the socket before sending Hello'),
          );
        }
        if (session != _sessionId || _intentionalStop || _disposed) return;
        _onUnexpectedFailure(
          FreezeInfo(
            code: 'DISCONNECT',
            message: 'Engine closed the socket unexpectedly',
            loaded: '',
            timestamp: _now(),
          ),
        );
      },
    );

    pb.Hello receivedHello;
    try {
      receivedHello = await helloCompleter.future.timeout(connectTimeout);
    } catch (e) {
      if (session != _sessionId || _intentionalStop || _disposed) return;
      await _cleanupConnection(killProcess: true);
      _setStatus(
        BackendStatus.error,
        errorMessage: 'Engine handshake failed: $e',
      );
      return;
    }

    if (session != _sessionId || _intentionalStop || _disposed) return;

    final expectedVersion = pb.ProtocolVersion.PROTOCOL_VERSION_CURRENT.value;
    if (receivedHello.protocolVersion != expectedVersion) {
      _versionMismatchMessage =
          'Protocol version mismatch: Engine reports v${receivedHello.protocolVersion}, '
          'GUI expects v$expectedVersion.';
      await _cleanupConnection(killProcess: true);
      _setStatus(
        BackendStatus.versionMismatch,
        errorMessage: _versionMismatchMessage,
      );
      return;
    }

    _hello = receivedHello;
    _resetHeartbeatWatchdog(session);
    _setStatus(BackendStatus.running, isRestart: isRestart);
    if (!_events.isClosed) {
      _events.add(pb.FromEngine(hello: receivedHello));
    }
    await Future<void>.microtask(() {});
  }

  void _handleIncomingMessage(pb.FromEngine msg, int session) {
    if (session != _sessionId || _disposed) return;
    switch (msg.whichKind()) {
      case pb.FromEngine_Kind.heartbeat:
        _resetHeartbeatWatchdog(session);
        if (!_events.isClosed) _events.add(msg);
      case pb.FromEngine_Kind.freeze_9:
        final f = msg.freeze_9;
        final info = FreezeInfo(
          code: f.code.isEmpty ? 'FREEZE' : f.code,
          message: f.message,
          loaded: f.loaded,
          timestamp: _now(),
        );
        if (!_events.isClosed) _events.add(msg);
        _onUnexpectedFailure(info);
      default:
        if (!_events.isClosed) _events.add(msg);
    }
  }

  void _resetHeartbeatWatchdog(int session) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer(heartbeatTimeout, () {
      if (session != _sessionId ||
          _intentionalStop ||
          _disposed ||
          _status != BackendStatus.running) {
        return;
      }
      _onUnexpectedFailure(
        FreezeInfo(
          code: 'HANG',
          message:
              'No Heartbeat received from Engine for ${heartbeatTimeout.inMilliseconds} ms',
          loaded: '',
          timestamp: _now(),
        ),
      );
    });
  }

  void _onUnexpectedFailure(FreezeInfo freeze) {
    if (_handlingFailure || _intentionalStop || _disposed) return;
    _handlingFailure = true;
    _sessionId++;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    final shouldRestart = _restartPolicy.recordFailureAndShouldRestart();
    unawaited(_cleanupConnection(killProcess: true));

    if (!shouldRestart) {
      _setStatus(BackendStatus.crashed, freeze: freeze);
      return;
    }

    _setStatus(BackendStatus.restarting, freeze: freeze);
    _restartTimer?.cancel();
    _restartTimer = Timer(restartDelay, () {
      if (_disposed || _intentionalStop) return;
      unawaited(_startSession(isRestart: true));
    });
  }

  Future<Socket> _connectWithRetry(String socketPath, int session) async {
    final deadline = _now().add(connectTimeout);
    Object? lastError;
    while (true) {
      if (session != _sessionId || _intentionalStop || _disposed) {
        throw StateError('Connection cancelled');
      }
      if (_processExited) {
        throw ProcessException(
          resolveExecutablePath(),
          const ['serve'],
          'Engine exited early with status $_processExitCode before accepting',
          _processExitCode ?? -1,
        );
      }
      try {
        return await Socket.connect(
          InternetAddress(socketPath, type: InternetAddressType.unix),
          0,
        );
      } catch (e) {
        lastError = e;
        if (!_now().isBefore(deadline)) {
          throw SocketException(
            'Timed out connecting to $socketPath: $lastError',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  }

  Future<void> _cleanupConnection({required bool killProcess}) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    final sub = _socketSub;
    _socketSub = null;
    if (sub != null) {
      try {
        await sub.cancel();
      } catch (_) {}
    }

    final sock = _socket;
    _socket = null;
    if (sock != null) {
      try {
        sock.destroy();
      } catch (_) {}
    }

    final proc = _process;
    _process = null;
    if (proc != null && killProcess) {
      try {
        proc.kill(ProcessSignal.sigterm);
      } catch (_) {}
    }

    final ownedDir = _ownedSocketDir;
    _ownedSocketDir = null;
    if (ownedDir != null && ownedDir.existsSync()) {
      try {
        ownedDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}

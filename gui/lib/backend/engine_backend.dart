import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:deluge_engine_gui/backend/backend.dart';
import 'package:deluge_engine_gui/backend/framing.dart';
import 'package:deluge_engine_gui/backend/restart_policy.dart';
import 'package:deluge_engine_gui/proto/engine.pb.dart' as pb;
import 'package:flutter/foundation.dart' show visibleForTesting;
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
    this.killTermTimeout = const Duration(milliseconds: 500),
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
  final Duration killTermTimeout;

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
  StreamSubscription<List<int>>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  Directory? _ownedSocketDir;
  Timer? _heartbeatTimer;
  Timer? _restartTimer;
  Future<void>? _activeStart;
  Future<void>? _pendingCleanup;
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

  /// PID of the active child process, if any (exposed for orphan-cleanup tests).
  @visibleForTesting
  int? get activeProcessPid => _process?.pid;

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
  Future<void> start() {
    if (_disposed) return Future<void>.value();
    if (_activeStart != null) return _activeStart!;
    if (_status == BackendStatus.running ||
        _status == BackendStatus.starting ||
        _status == BackendStatus.restarting) {
      return Future<void>.value();
    }
    final s = ++_sessionId;
    _intentionalStop = false;
    _versionMismatchMessage = null;
    _errorMessage = null;
    final future = () async {
      await _awaitPendingCleanup();
      if (_disposed || _intentionalStop || _sessionId != s) return;
      await _startSession(isRestart: false);
    }();
    _activeStart = future;
    future.whenComplete(() {
      if (identical(_activeStart, future)) _activeStart = null;
    });
    return future;
  }

  @override
  Future<void> restart() async {
    if (_disposed) return;
    final s = ++_sessionId;
    _restartTimer?.cancel();
    _restartTimer = null;
    _restartPolicy.reset();
    _intentionalStop = false;
    _handlingFailure = false;
    _versionMismatchMessage = null;
    _errorMessage = null;
    await _runCleanup(killProcess: true);
    if (_disposed || _intentionalStop || _sessionId != s) return;
    final future = _startSession(isRestart: true);
    _activeStart = future;
    future.whenComplete(() {
      if (identical(_activeStart, future)) _activeStart = null;
    });
    await future;
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
    final s = ++_sessionId;
    _intentionalStop = true;
    _restartTimer?.cancel();
    _restartTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    // Capture session resources synchronously before any await.
    final sock = _socket;
    final proc = _process;
    final sub = _socketSub;
    final stdoutSub = _stdoutSub;
    final stderrSub = _stderrSub;
    final ownedDir = _ownedSocketDir;
    _socket = null;
    _process = null;
    _socketSub = null;
    _stdoutSub = null;
    _stderrSub = null;
    _ownedSocketDir = null;

    await _trackCleanup(() async {
      var shutdownSent = false;
      if (sock != null) {
        try {
          sock.add(encodeFrame(pb.ToEngine(shutdown: pb.Shutdown())));
          await sock.flush();
          shutdownSent = true;
        } catch (_) {
          shutdownSent = false;
        }
        try {
          sock.destroy();
        } catch (_) {}
      }

      await _cancelSub(sub);

      if (proc != null) {
        if (shutdownSent) {
          try {
            await proc.exitCode.timeout(shutdownTimeout);
          } on TimeoutException {
            await _terminateProcess(proc, termTimeout: killTermTimeout);
          } catch (_) {}
        } else {
          await _terminateProcess(proc, termTimeout: killTermTimeout);
        }
      }

      await _cancelSub(stdoutSub);
      await _cancelSub(stderrSub);
      _deleteDirBestEffort(ownedDir);
    }());

    if (_sessionId == s && !_disposed) {
      _setStatus(BackendStatus.stopped);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _intentionalStop = true;
    _sessionId++;
    _restartTimer?.cancel();
    _restartTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _runCleanup(killProcess: true);
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

    String? exe;
    if (spawnProcess) {
      exe = resolveExecutablePath();
      if (!File(exe).existsSync()) {
        final msg = 'Engine binary not found at $exe';
        _setStatus(BackendStatus.error, errorMessage: msg);
        return;
      }
    }

    String sockPath;
    Directory? createdDir;
    if (socketPathOverride != null) {
      sockPath = socketPathOverride!;
    } else {
      final (createdPath, dir) = createSocketPath();
      sockPath = createdPath;
      createdDir = dir;
    }

    if (spawnProcess) {
      final args = <String>[
        'serve',
        '--socket',
        sockPath,
        '--audio',
        audioBackend,
        if (trace) '--trace',
        ...extraArgs,
      ];
      Process proc;
      try {
        proc = await Process.start(exe!, args);
      } catch (e) {
        _deleteDirBestEffort(createdDir);
        if (session != _sessionId || _intentionalStop || _disposed) return;
        _setStatus(
          BackendStatus.error,
          errorMessage: 'Failed to start Engine: $e',
        );
        return;
      }

      // Always drain stdout/stderr so pipes never block the child process.
      final stdoutSub = proc.stdout.listen((_) {}, onError: (_) {});
      final stderrSub = proc.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (session != _sessionId || _disposed) return;
              _stderrTail.add(line);
              if (_stderrTail.length > 50) _stderrTail.removeAt(0);
            },
            onError: (_) {},
          );

      // If dispose/shutdown/restart ran while Process.start was in flight,
      // terminate this process under _pendingCleanup without touching state.
      if (session != _sessionId || _intentionalStop || _disposed) {
        await _trackCleanup(() async {
          await _terminateProcess(proc, termTimeout: killTermTimeout);
          await _cancelSub(stdoutSub);
          await _cancelSub(stderrSub);
          _deleteDirBestEffort(createdDir);
        }());
        return;
      }

      _ownedSocketDir = createdDir;
      _process = proc;
      _stdoutSub = stdoutSub;
      _stderrSub = stderrSub;
      _stderrTail.clear();

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
    } else {
      _ownedSocketDir = createdDir;
    }

    Socket socket;
    try {
      socket = await _connectWithRetry(sockPath, session);
    } catch (e) {
      if (session != _sessionId || _intentionalStop || _disposed) return;
      await _runCleanup(killProcess: true);
      if (session != _sessionId || _intentionalStop || _disposed) return;
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
      try {
        socket.destroy();
      } catch (_) {}
      return;
    }

    _socket = socket;
    final expectedVersion = pb.ProtocolVersion.PROTOCOL_VERSION_CURRENT.value;
    final helloCompleter = Completer<pb.Hello>();
    var handshakeDone = false;
    var versionValid = false;
    var versionInvalid = false;
    final preHandshakeFrames = <pb.FromEngine>[];

    _socketSub = socket.listen(
      (chunk) {
        if (session != _sessionId || _disposed || versionInvalid) return;
        List<Uint8List> frames;
        try {
          frames = _decoder.addChunk(chunk);
        } on FramingException catch (e) {
          if (!helloCompleter.isCompleted) {
            helloCompleter.completeError(e);
            return;
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
              return;
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
            versionValid = msg.hello.protocolVersion == expectedVersion;
            versionInvalid = !versionValid;
            helloCompleter.complete(msg.hello);
            if (versionInvalid) {
              // Drop any trailing frames in this chunk on version mismatch.
              return;
            }
            continue;
          }

          if (!handshakeDone) {
            if (versionValid) {
              preHandshakeFrames.add(msg);
            }
            continue;
          }

          _handleIncomingMessage(msg, session);
        }
      },
      onError: (Object error) {
        if (!helloCompleter.isCompleted) {
          helloCompleter.completeError(error);
          return;
        }
        if (session != _sessionId ||
            _intentionalStop ||
            _disposed ||
            versionInvalid) {
          return;
        }
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
          return;
        }
        if (session != _sessionId ||
            _intentionalStop ||
            _disposed ||
            versionInvalid) {
          return;
        }
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
      await _runCleanup(killProcess: true);
      if (session != _sessionId || _intentionalStop || _disposed) return;
      _setStatus(
        BackendStatus.error,
        errorMessage: 'Engine handshake failed: $e',
      );
      return;
    }

    if (session != _sessionId || _intentionalStop || _disposed) return;

    if (!versionValid) {
      final mismatchMsg =
          'Protocol version mismatch: Engine reports v${receivedHello.protocolVersion}, '
          'GUI expects v$expectedVersion.';
      await _runCleanup(killProcess: true);
      if (session != _sessionId || _intentionalStop || _disposed) return;
      _versionMismatchMessage = mismatchMsg;
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
    handshakeDone = true;

    for (final buffered in preHandshakeFrames) {
      if (session != _sessionId || _intentionalStop || _disposed) break;
      _handleIncomingMessage(buffered, session);
    }
    preHandshakeFrames.clear();
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
    final failureSession = ++_sessionId;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    final shouldRestart = _restartPolicy.recordFailureAndShouldRestart();
    final cleanupFuture = _runCleanup(killProcess: true);

    if (!shouldRestart) {
      _setStatus(BackendStatus.crashed, freeze: freeze);
      return;
    }

    _setStatus(BackendStatus.restarting, freeze: freeze);
    _restartTimer?.cancel();
    _restartTimer = null;

    // Wait for both old-process cleanup and a cancellable restartDelay Timer
    // before spawning the replacement Engine.
    var cleanupDone = false;
    var delayDone = false;
    void maybeStartReplacement() {
      if (!cleanupDone || !delayDone) return;
      if (_disposed || _intentionalStop || _sessionId != failureSession) return;
      final future = _startSession(isRestart: true);
      _activeStart = future;
      future.whenComplete(() {
        if (identical(_activeStart, future)) _activeStart = null;
      });
    }

    _restartTimer = Timer(restartDelay, () {
      _restartTimer = null;
      delayDone = true;
      maybeStartReplacement();
    });
    unawaited(cleanupFuture.whenComplete(() {
      cleanupDone = true;
      maybeStartReplacement();
    }));
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

  /// Registers [future] into the shared pending-cleanup barrier and returns a
  /// combined future that completes only once this teardown and all prior
  /// teardowns have finished.
  Future<void> _trackCleanup(Future<void> future) {
    final safe = future.catchError((Object _) {});
    final prev = _pendingCleanup;
    final combined = prev == null
        ? safe
        : Future.wait<void>([prev, safe]).then((_) {});
    _pendingCleanup = combined;
    combined.whenComplete(() {
      if (identical(_pendingCleanup, combined)) _pendingCleanup = null;
    });
    return combined;
  }

  Future<void> _runCleanup({required bool killProcess}) =>
      _trackCleanup(_cleanupConnection(killProcess: killProcess));

  Future<void> _awaitPendingCleanup() async {
    final pending = _pendingCleanup;
    if (pending != null) {
      await pending;
    }
  }

  /// Captures and clears all current-session fields synchronously before any
  /// await, then terminates any hung process (SIGTERM -> SIGKILL) before
  /// removing the temporary socket directory.
  Future<void> _cleanupConnection({required bool killProcess}) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    final sub = _socketSub;
    _socketSub = null;
    final sock = _socket;
    _socket = null;
    final proc = _process;
    _process = null;
    final stdoutSub = _stdoutSub;
    _stdoutSub = null;
    final stderrSub = _stderrSub;
    _stderrSub = null;
    final ownedDir = _ownedSocketDir;
    _ownedSocketDir = null;

    if (sock != null) {
      try {
        sock.destroy();
      } catch (_) {}
    }

    await _cancelSub(sub);

    if (proc != null && killProcess) {
      await _terminateProcess(proc, termTimeout: killTermTimeout);
    }

    await _cancelSub(stdoutSub);
    await _cancelSub(stderrSub);
    _deleteDirBestEffort(ownedDir);
  }

  static Future<void> _terminateProcess(
    Process proc, {
    required Duration termTimeout,
  }) async {
    try {
      proc.kill(ProcessSignal.sigterm);
    } catch (_) {}
    try {
      await proc.exitCode.timeout(termTimeout);
      return;
    } on TimeoutException {
      try {
        proc.kill(ProcessSignal.sigkill);
      } catch (_) {}
      try {
        await proc.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {}
    } catch (_) {}
  }

  static Future<void> _cancelSub(StreamSubscription<dynamic>? sub) async {
    if (sub == null) return;
    try {
      await sub.cancel();
    } catch (_) {}
  }

  static void _deleteDirBestEffort(Directory? dir) {
    if (dir != null && dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}

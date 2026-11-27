import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:deluge_engine_gui/backend/backend.dart';
import 'package:deluge_engine_gui/backend/engine_backend.dart';
import 'package:deluge_engine_gui/backend/fake_backend.dart';
import 'package:deluge_engine_gui/backend/framing.dart';
import 'package:deluge_engine_gui/backend/restart_policy.dart';
import 'package:deluge_engine_gui/proto/engine.pb.dart' as pb;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A real Unix domain socket server speaking the 4-byte LE protobuf framing,
/// used to test [EngineBackend] end-to-end without spawning the C++ binary.
class _FakeUnixEngineServer {
  _FakeUnixEngineServer(this.socketPath, this._onClient);

  final String socketPath;
  final Future<void> Function(Socket client, Stream<pb.ToEngine> incoming)
      _onClient;

  ServerSocket? _server;
  final List<Socket> _clients = [];
  int connectionCount = 0;

  Future<void> start() async {
    final f = File(socketPath);
    if (f.existsSync()) f.deleteSync();
    _server = await ServerSocket.bind(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
    _server!.listen((socket) {
      connectionCount++;
      _clients.add(socket);
      final decoder = FrameDecoder();
      final controller = StreamController<pb.ToEngine>();
      socket.listen(
        (chunk) {
          for (final payload in decoder.addChunk(chunk)) {
            controller.add(pb.ToEngine.fromBuffer(payload));
          }
        },
        onError: controller.addError,
        onDone: controller.close,
      );
      unawaited(_onClient(socket, controller.stream));
    });
  }

  static void send(Socket socket, pb.FromEngine msg) {
    socket.add(encodeFrame(msg));
  }

  Future<void> close() async {
    for (final c in _clients) {
      try {
        c.destroy();
      } catch (_) {}
    }
    _clients.clear();
    await _server?.close();
    final f = File(socketPath);
    if (f.existsSync()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
  }
}

void main() {
  group('FrameDecoder & encodeFrame', () {
    test('round-trips a ToEngine frame with 4-byte little-endian length', () {
      final msg = pb.ToEngine(
        setCard: pb.SetCard(folder: '/tmp/my-card'),
      );
      final encoded = encodeFrame(msg);
      final expectedPayload = msg.writeToBuffer();
      final bd = ByteData.sublistView(encoded, 0, 4);
      expect(bd.getUint32(0, Endian.little), expectedPayload.length);
      expect(encoded.sublist(4), expectedPayload);

      final decoder = FrameDecoder();
      final frames = decoder.addChunk(encoded);
      expect(frames, hasLength(1));
      final decoded = pb.ToEngine.fromBuffer(frames.single);
      expect(decoded.whichKind(), pb.ToEngine_Kind.setCard);
      expect(decoded.setCard.folder, '/tmp/my-card');
    });

    test('handles 1-byte chunks and multiple frames in a single chunk', () {
      final m1 = pb.FromEngine(
        hello: pb.Hello(
          protocolVersion: pb.ProtocolVersion.PROTOCOL_VERSION_CURRENT.value,
          engineVersion: '1.0.0',
        ),
      );
      final m2 = pb.FromEngine(
        heartbeat: pb.Heartbeat(voices: 7, cpuLoad: 0.25),
      );
      final combined = Uint8List.fromList([
        ...encodeFrame(m1),
        ...encodeFrame(m2),
      ]);

      // Feed byte by byte
      final byteDecoder = FrameDecoder();
      final byteOut = <Uint8List>[];
      for (final b in combined) {
        byteOut.addAll(byteDecoder.addChunk(Uint8List.fromList([b])));
      }
      expect(byteOut, hasLength(2));
      expect(pb.FromEngine.fromBuffer(byteOut[0]).hello.engineVersion, '1.0.0');
      expect(pb.FromEngine.fromBuffer(byteOut[1]).heartbeat.voices, 7);

      // Feed all at once
      final bulkDecoder = FrameDecoder();
      final bulkOut = bulkDecoder.addChunk(combined);
      expect(bulkOut, hasLength(2));
    });

    test('rejects frames larger than 16 MiB', () {
      final header = Uint8List(4);
      ByteData.sublistView(header)
          .setUint32(0, kMaxFrameBytes + 1, Endian.little);
      final decoder = FrameDecoder();
      expect(() => decoder.addChunk(header), throwsA(isA<FramingException>()));
    });
  });

  group('RestartPolicy', () {
    test('allows auto-restart on first two failures and stops on third in 60s',
        () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final policy = RestartPolicy(
        maxFailuresInWindow: 3,
        window: const Duration(minutes: 1),
        now: () => now,
      );

      expect(policy.recordFailureAndShouldRestart(), isTrue);
      expect(policy.recentFailureCount, 1);

      now = now.add(const Duration(seconds: 10));
      expect(policy.recordFailureAndShouldRestart(), isTrue);
      expect(policy.recentFailureCount, 2);

      now = now.add(const Duration(seconds: 10));
      expect(policy.recordFailureAndShouldRestart(), isFalse);
      expect(policy.recentFailureCount, 3);

      // After 61 seconds from the first failure, old entries expire.
      now = DateTime(2026, 1, 1, 12, 1, 15);
      expect(policy.recordFailureAndShouldRestart(), isTrue);

      // Manual reset clears the window.
      policy.reset();
      expect(policy.recentFailureCount, 0);
    });
  });

  group('EngineBackend over Unix domain socket', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory('/tmp').createTempSync('de_gui_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('createSocketPath always returns a Unix socket path under 100 bytes',
        () {
      final (sockPath, dir) = EngineBackend.createSocketPath();
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      expect(sockPath.length, lessThan(kMaxUnixSocketPathBytes));
    });

    test('handshakes Hello, exchanges framed messages, and shuts down cleanly',
        () async {
      final sockPath = p.join(tempDir.path, 'e.sock');
      final received = <pb.ToEngine>[];
      final gotShutdown = Completer<void>();

      final server = _FakeUnixEngineServer(sockPath, (client, incoming) async {
        _FakeUnixEngineServer.send(
          client,
          pb.FromEngine(
            hello: pb.Hello(
              protocolVersion:
                  pb.ProtocolVersion.PROTOCOL_VERSION_CURRENT.value,
              engineVersion: 'test-1.0',
              firmwareCommit: 'abc1234',
              capabilities: ['setups', 'pieces', 'render'],
            ),
          ),
        );
        _FakeUnixEngineServer.send(
          client,
          pb.FromEngine(heartbeat: pb.Heartbeat(voices: 4, cpuLoad: 0.12)),
        );
        await for (final msg in incoming) {
          received.add(msg);
          if (msg.whichKind() == pb.ToEngine_Kind.setCard) {
            _FakeUnixEngineServer.send(
              client,
              pb.FromEngine(
                cardStatus: pb.CardStatus(ready: pb.CardReady()),
              ),
            );
          } else if (msg.whichKind() == pb.ToEngine_Kind.shutdown) {
            if (!gotShutdown.isCompleted) gotShutdown.complete();
            await client.close();
          }
        }
      });
      await server.start();
      addTearDown(server.close);

      final backend = EngineBackend(
        socketPathOverride: sockPath,
        spawnProcess: false,
        heartbeatTimeout: const Duration(seconds: 5),
      );
      addTearDown(backend.dispose);

      final events = <pb.FromEngine>[];
      final sub = backend.events.listen(events.add);
      addTearDown(sub.cancel);

      await backend.start();
      expect(backend.status, BackendStatus.running);
      expect(backend.hello?.engineVersion, 'test-1.0');
      expect(backend.hasCapability('pieces'), isTrue);
      expect(backend.hasCapability('play_live'), isFalse);

      await backend.send(pb.ToEngine(setCard: pb.SetCard(folder: '/cards/a')));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        received.any(
          (m) =>
              m.whichKind() == pb.ToEngine_Kind.setCard &&
              m.setCard.folder == '/cards/a',
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.whichKind() == pb.FromEngine_Kind.cardStatus &&
              e.cardStatus.whichState() == pb.CardStatus_State.ready,
        ),
        isTrue,
      );

      await backend.shutdown();
      await gotShutdown.future.timeout(const Duration(seconds: 2));
      expect(backend.status, BackendStatus.stopped);
    });

    test('fails with versionMismatch and does not restart on wrong version',
        () async {
      final sockPath = p.join(tempDir.path, 'mismatch.sock');
      final server = _FakeUnixEngineServer(sockPath, (client, incoming) async {
        _FakeUnixEngineServer.send(
          client,
          pb.FromEngine(
            hello: pb.Hello(
              protocolVersion: 99,
              engineVersion: 'future-99',
            ),
          ),
        );
      });
      await server.start();
      addTearDown(server.close);

      final backend = EngineBackend(
        socketPathOverride: sockPath,
        spawnProcess: false,
        heartbeatTimeout: const Duration(seconds: 5),
      );
      addTearDown(backend.dispose);

      await backend.start();
      expect(backend.status, BackendStatus.versionMismatch);
      expect(backend.versionMismatchMessage, contains('99'));
      expect(server.connectionCount, 1);
    });

    test('restarts on Freeze and stops after 3 freezes within a minute',
        () async {
      final sockPath = p.join(tempDir.path, 'freeze.sock');
      final clients = <Socket>[];
      final server = _FakeUnixEngineServer(sockPath, (client, incoming) async {
        clients.add(client);
        _FakeUnixEngineServer.send(
          client,
          pb.FromEngine(
            hello: pb.Hello(
              protocolVersion:
                  pb.ProtocolVersion.PROTOCOL_VERSION_CURRENT.value,
              engineVersion: 'test-1.0',
            ),
          ),
        );
        // Keep connection open until server closes it or client disconnects.
        await incoming.drain<void>();
      });
      await server.start();
      addTearDown(server.close);

      final backend = EngineBackend(
        socketPathOverride: sockPath,
        spawnProcess: false,
        heartbeatTimeout: const Duration(seconds: 10),
        restartDelay: const Duration(milliseconds: 20),
      );
      addTearDown(backend.dispose);

      await backend.start();
      expect(backend.status, BackendStatus.running);
      expect(server.connectionCount, 1);

      // Freeze 1 -> auto-restarts -> connection 2
      _FakeUnixEngineServer.send(
        clients.last,
        pb.FromEngine(
          freeze_9: pb.Freeze(code: 'E380', message: 'boom 1', loaded: '000 Bass'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(backend.status, BackendStatus.running);
      expect(server.connectionCount, 2);
      expect(backend.lastFreeze?.code, 'E380');

      // Freeze 2 -> auto-restarts -> connection 3
      _FakeUnixEngineServer.send(
        clients.last,
        pb.FromEngine(
          freeze_9: pb.Freeze(code: 'E381', message: 'boom 2', loaded: '001 Sync'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(backend.status, BackendStatus.running);
      expect(server.connectionCount, 3);

      // Freeze 3 within 1 minute -> stops restarting (crashed)
      _FakeUnixEngineServer.send(
        clients.last,
        pb.FromEngine(
          freeze_9: pb.Freeze(code: 'S002', message: 'boom 3', loaded: '003 Kit'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(backend.status, BackendStatus.crashed);
      expect(backend.lastFreeze?.code, 'S002');
      expect(server.connectionCount, 3);

      // Manual restart clears the window and reconnects -> connection 4
      await backend.restart();
      expect(backend.status, BackendStatus.running);
      expect(server.connectionCount, 4);
    });

    test('treats missed Heartbeat as HANG and restarts', () async {
      final sockPath = p.join(tempDir.path, 'hang.sock');
      final server = _FakeUnixEngineServer(sockPath, (client, incoming) async {
        _FakeUnixEngineServer.send(
          client,
          pb.FromEngine(
            hello: pb.Hello(
              protocolVersion:
                  pb.ProtocolVersion.PROTOCOL_VERSION_CURRENT.value,
              engineVersion: 'test-1.0',
            ),
          ),
        );
        // Never sends a Heartbeat -> triggers HANG after heartbeatTimeout
        await incoming.drain<void>();
      });
      await server.start();
      addTearDown(server.close);

      final backend = EngineBackend(
        socketPathOverride: sockPath,
        spawnProcess: false,
        heartbeatTimeout: const Duration(milliseconds: 80),
        restartDelay: const Duration(milliseconds: 20),
      );
      addTearDown(backend.dispose);

      await backend.start();
      expect(backend.status, BackendStatus.running);
      await Future<void>.delayed(const Duration(milliseconds: 180));
      expect(backend.lastFreeze?.code, 'HANG');
      expect(server.connectionCount, greaterThanOrEqualTo(2));
    });

    test('fails promptly when spawned binary exits before accepting', () async {
      final backend = EngineBackend(
        executablePath: '/usr/bin/false',
        connectTimeout: const Duration(seconds: 5),
      );
      addTearDown(backend.dispose);

      final sw = Stopwatch()..start();
      await backend.start();
      sw.stop();

      expect(backend.status, BackendStatus.error);
      expect(backend.errorMessage, contains('exited early'));
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });

  group('FakeBackend', () {
    test('provides catalog, genres, renders with peaks/sections/notes, and freeze',
        () async {
      final backend = FakeBackend(
        stepDelay: Duration.zero,
        restartDelay: Duration.zero,
      );
      addTearDown(backend.dispose);

      final events = <pb.FromEngine>[];
      final sub = backend.events.listen(events.add);
      addTearDown(sub.cancel);

      await backend.start();
      expect(backend.status, BackendStatus.running);
      expect(backend.hello?.protocolVersion,
          pb.ProtocolVersion.PROTOCOL_VERSION_CURRENT.value);

      await backend.send(pb.ToEngine(setCard: pb.SetCard(folder: '/fake/card')));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        events.any((e) => e.whichKind() == pb.FromEngine_Kind.catalog),
        isTrue,
      );
      expect(
        events.any((e) => e.whichKind() == pb.FromEngine_Kind.genres),
        isTrue,
      );

      final genresMsg = events
          .firstWhere((e) => e.whichKind() == pb.FromEngine_Kind.genres)
          .genres;
      expect(genresMsg.genres, isNotEmpty);

      await backend.send(
        pb.ToEngine(
          renderPiece: pb.RenderPiece(
            id: 'r1',
            lengthS: 60.0,
            wavPath: '/tmp/fake_r1.wav',
            recipe: pb.Recipe(genre: genresMsg.genres.first.id, seed: 12345),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final done = events
          .firstWhere((e) => e.whichKind() == pb.FromEngine_Kind.renderDone)
          .renderDone;
      expect(done.id, 'r1');
      expect(done.peaks.length, greaterThan(100));
      expect(done.sections, isNotEmpty);
      expect(done.notes, isNotEmpty);
      expect(done.peakVoices, greaterThan(0));
    });
  });
}

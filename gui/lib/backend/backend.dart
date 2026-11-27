import 'package:deluge_engine_gui/proto/engine.pb.dart' as pb;

/// Lifecycle state of a [Backend] connection (spec §7.2, §7.7).
enum BackendStatus {
  /// Not started or cleanly shut down.
  stopped,

  /// Starting the Engine process and waiting for the initial `Hello`.
  starting,

  /// Connected, `Hello` verified, receiving heartbeats.
  running,

  /// Froze, hung, or exited unexpectedly; automatically restarting.
  restarting,

  /// Reached the restart limit (3 failures within 1 minute); waiting for manual Restart.
  crashed,

  /// `Hello.protocol_version` did not match `PROTOCOL_VERSION_CURRENT` (spec §7.2).
  versionMismatch,

  /// Unrecoverable startup error (for example, Engine binary missing).
  error,
}

/// Details of the most recent Engine freeze or hang (spec §7.7).
class FreezeInfo {
  const FreezeInfo({
    required this.code,
    required this.message,
    required this.loaded,
    required this.timestamp,
  });

  final String code;
  final String message;
  final String loaded;
  final DateTime timestamp;

  /// Compact summary suitable for the status bar (spec §7.7).
  String get summary => loaded.isEmpty ? code : '$code ($loaded)';

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        'loaded': loaded,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Emitted whenever a [Backend] changes lifecycle state.
class BackendLifecycleEvent {
  const BackendLifecycleEvent({
    required this.status,
    this.freeze,
    this.errorMessage,
    this.isRestart = false,
  });

  final BackendStatus status;
  final FreezeInfo? freeze;
  final String? errorMessage;
  final bool isRestart;
}

/// Protocol-level interface between the GUI and a Backend (`EngineBackend` or
/// `FakeBackend`, spec §8).
abstract class Backend {
  /// Stream of incoming `FromEngine` protobuf frames.
  Stream<pb.FromEngine> get events;

  /// Stream of lifecycle transitions (starting, running, restarting, crashed, etc.).
  Stream<BackendLifecycleEvent> get lifecycle;

  /// Current lifecycle state.
  BackendStatus get status;

  /// Latest verified `Hello` received from the Backend, or null before handshake.
  pb.Hello? get hello;

  /// Last recorded freeze/hang info, if any.
  FreezeInfo? get lastFreeze;

  /// Human-readable version mismatch error when [status] is [BackendStatus.versionMismatch].
  String? get versionMismatchMessage;

  /// Human-readable startup/transport error when [status] is [BackendStatus.error].
  String? get errorMessage;

  /// Capabilities advertised in `Hello.capabilities` (spec §7.2).
  Set<String> get capabilities => Set<String>.unmodifiable(
        hello?.capabilities ?? const <String>[],
      );

  /// Whether the connected Backend advertised [capability].
  bool hasCapability(String capability) =>
      hello?.capabilities.contains(capability) ?? false;

  /// Starts the Backend and waits for the `Hello` handshake to settle.
  Future<void> start();

  /// Sends one `ToEngine` frame to the Backend.
  Future<void> send(pb.ToEngine message);

  /// Clears any restart limit and starts a fresh Backend session.
  Future<void> restart();

  /// Requests a clean shutdown (`ToEngine.shutdown`) and closes transport.
  Future<void> shutdown();

  /// Releases all resources (sockets, timers, streams, child processes).
  Future<void> dispose();
}

/// Typed convenience methods built purely on top of [Backend.send].
extension BackendCommands on Backend {
  Future<void> setCard(String folder) =>
      send(pb.ToEngine(setCard: pb.SetCard(folder: folder)));

  Future<void> setSetup(Map<int, String> bindings) {
    final entries = bindings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return send(
      pb.ToEngine(
        setSetup: pb.SetSetup(
          bindings: [
            for (final e in entries)
              pb.SetupBinding(channel: e.key, path: e.value),
          ],
        ),
      ),
    );
  }

  Future<void> audition({
    required String path,
    int note = 60,
    int velocity = 100,
    int ms = 600,
  }) =>
      send(
        pb.ToEngine(
          audition: pb.Audition(
            path: path,
            note: note,
            velocity: velocity,
            ms: ms,
          ),
        ),
      );

  Future<void> sendNote({
    required int channel,
    required int note,
    int velocity = 100,
    required bool on,
  }) =>
      send(
        pb.ToEngine(
          note: pb.Note(
            channel: channel,
            note: note,
            velocity: velocity,
            on: on,
          ),
        ),
      );

  Future<void> setDevices({
    String audioOutput = '',
    List<String> midiInputs = const [],
  }) =>
      send(
        pb.ToEngine(
          setDevices: pb.SetDevices(
            audioOutput: audioOutput,
            midiInputs: midiInputs,
          ),
        ),
      );

  Future<void> renderPiece(pb.RenderPiece request) =>
      send(pb.ToEngine(renderPiece: request));

  Future<void> cancelRender(String id) =>
      send(pb.ToEngine(cancelRender: pb.CancelRender(id: id)));

  Future<void> play(String wavPath, double positionS) => send(
        pb.ToEngine(play: pb.Play(wavPath: wavPath, positionS: positionS)),
      );

  Future<void> seek(double positionS) =>
      send(pb.ToEngine(seek: pb.Seek(positionS: positionS)));

  Future<void> stopPlayback() => send(pb.ToEngine(stop: pb.Stop()));

  Future<void> playPiece(pb.Recipe recipe) =>
      send(pb.ToEngine(playPiece: pb.PlayPiece(recipe: recipe)));

  Future<void> stopPiece() => send(pb.ToEngine(stopPiece: pb.StopPiece()));
}

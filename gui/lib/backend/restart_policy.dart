/// Sliding-window restart policy (spec §7.7).
///
/// Auto-restarts the Engine on a freeze, unexpected exit, or heartbeat hang,
/// up to [maxFailuresInWindow] failures within [window]. Once the threshold
/// is reached within the window (default: 3 freezes in 1 minute), auto-restart
/// halts until the user clicks Restart (calling [reset]).
class RestartPolicy {
  RestartPolicy({
    this.maxFailuresInWindow = 3,
    this.window = const Duration(minutes: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int maxFailuresInWindow;
  final Duration window;
  final DateTime Function() _now;

  final List<DateTime> _failures = <DateTime>[];

  void _prune(DateTime current) {
    final cutoff = current.subtract(window);
    _failures.removeWhere((t) => t.isBefore(cutoff));
  }

  /// Number of recorded failures still inside the sliding [window].
  int get recentFailureCount {
    _prune(_now());
    return _failures.length;
  }

  /// Records a failure at the current time and returns `true` if the Backend
  /// should restart automatically, or `false` if it must stop and wait for
  /// manual user intervention.
  bool recordFailureAndShouldRestart() {
    final current = _now();
    _prune(current);
    _failures.add(current);
    return _failures.length < maxFailuresInWindow;
  }

  /// Clears the failure window (called on explicit manual restart).
  void reset() {
    _failures.clear();
  }
}

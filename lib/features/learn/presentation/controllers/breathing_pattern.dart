/// Guided breathing rhythm: inhale 4 s (circle grows), exhale 6 s (circle
/// shrinks).
enum BreathPhase { inhale, exhale }

abstract final class BreathingPattern {
  static const inhale = Duration(seconds: 4);
  static const exhale = Duration(seconds: 6);
  static const Duration cycle = Duration(seconds: 10);

  /// Session lengths offered to the user, in minutes.
  static const durations = [1, 3, 5];

  /// Phase and circle size (0 = smallest, 1 = largest) at [elapsed].
  static ({BreathPhase phase, double size}) at(Duration elapsed) {
    final ms = elapsed.inMilliseconds % cycle.inMilliseconds;
    if (ms < inhale.inMilliseconds) {
      return (phase: BreathPhase.inhale, size: ms / inhale.inMilliseconds);
    }
    final exhaleMs = ms - inhale.inMilliseconds;
    return (
      phase: BreathPhase.exhale,
      size: 1 - exhaleMs / exhale.inMilliseconds,
    );
  }

  /// `m:ss` for the remaining-time label.
  static String formatRemaining(Duration remaining) {
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    final seconds = (clamped.inMilliseconds / 1000).ceil();
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

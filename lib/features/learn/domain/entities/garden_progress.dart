/// Relaxation sessions completed. The garden only ever grows.
class GardenProgress {
  const new(this.completedSessions);

  static const sessionsPerStage = 3;
  static const maxStage = 4;

  final int completedSessions;

  /// 0 (seed) to 4 (in bloom): one stage per three sessions.
  int get stage {
    final raw = completedSessions ~/ sessionsPerStage;
    return raw > maxStage ? maxStage : raw;
  }

  /// Sessions still needed to reach the next stage, or 0 when fully grown.
  int get sessionsToNextStage => stage == maxStage
      ? 0
      : sessionsPerStage - completedSessions % sessionsPerStage;
}

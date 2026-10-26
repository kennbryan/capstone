import 'package:msu_wellbeing/features/checkin/domain/entities/check_in.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/article.dart';

/// Topics that fit today's mood best, most relevant first.
List<ArticleTopic> preferredTopics(int? mood) => switch (dailyFocusFor(mood)) {
  DailyFocus.heavy => const [
    ArticleTopic.stres,
    ArticleTopic.kecemasan,
    ArticleTopic.tidur,
  ],
  DailyFocus.middle => const [
    ArticleTopic.stres,
    ArticleTopic.tidur,
    ArticleTopic.kuliah,
  ],
  DailyFocus.good => const [
    ArticleTopic.hubungan,
    ArticleTopic.kuliah,
    ArticleTopic.tidur,
  ],
  DailyFocus.start => const [
    ArticleTopic.kuliah,
    ArticleTopic.tidur,
    ArticleTopic.stres,
  ],
};

/// Up to [count] articles, one per topic where possible, ordered by how
/// well their topic fits today's mood. Psychologist-reviewed articles come
/// first when there is a choice.
List<Article> pickRecommendations(
  List<Article> articles,
  int? mood, {
  int count = 3,
}) {
  final order = preferredTopics(mood);
  int rank(Article a) {
    final index = order.indexOf(a.topic);
    return index == -1 ? order.length : index;
  }

  final reviewed = [...articles]
    ..sort((a, b) {
      final byTopic = rank(a).compareTo(rank(b));
      if (byTopic != 0) return byTopic;
      return (b.reviewed ? 1 : 0).compareTo(a.reviewed ? 1 : 0);
    });
  final picked = <Article>[];
  final topics = <ArticleTopic>{};
  for (final article in reviewed) {
    if (topics.add(article.topic)) picked.add(article);
    if (picked.length == count) return picked;
  }
  for (final article in reviewed) {
    if (!picked.contains(article)) picked.add(article);
    if (picked.length == count) break;
  }
  return picked;
}

/// What Beranda gently suggests next, based on today's check-in.
enum DailyFocus {
  /// No check-in yet: invite a calm start.
  start,

  /// Mood 1–2: slow down and reach out.
  heavy,

  /// Mood 3: make some room for the mind.
  middle,

  /// Mood 4–5: keep the good feeling going.
  good,
}

DailyFocus dailyFocusFor(int? mood) => switch (mood) {
  null => DailyFocus.start,
  <= 2 => DailyFocus.heavy,
  3 => DailyFocus.middle,
  _ => DailyFocus.good,
};

/// How the latest check-in compares with the one before it. Descriptive
/// only: there are no scores or streaks.
enum MoodTrend { none, first, lighter, heavier, steady }

MoodTrend moodTrendOf(List<CheckInDay> days) {
  final logged = [
    for (final day in days)
      if (day.checkIn != null) day.checkIn!.mood,
  ];
  if (logged.isEmpty) return MoodTrend.none;
  if (logged.length == 1) return MoodTrend.first;
  final latest = logged.last;
  final previous = logged[logged.length - 2];
  if (latest > previous) return MoodTrend.lighter;
  if (latest < previous) return MoodTrend.heavier;
  return MoodTrend.steady;
}

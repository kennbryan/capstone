import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/features/checkin/domain/entities/check_in.dart';
import 'package:msu_wellbeing/features/home/presentation/controllers/home_insights.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/article.dart';

List<CheckInDay> _week(List<int?> moods) => [
  for (var i = 0; i < moods.length; i++)
    CheckInDay(
      date: DateTime(2026, 10, 16 + i),
      checkIn: moods[i] == null
          ? null
          : CheckIn(
              id: '$i',
              date: DateTime(2026, 10, 16 + i),
              mood: moods[i]!,
            ),
    ),
];

void main() {
  test("daily focus follows today's mood", () {
    expect(dailyFocusFor(null), DailyFocus.start);
    expect(dailyFocusFor(1), DailyFocus.heavy);
    expect(dailyFocusFor(2), DailyFocus.heavy);
    expect(dailyFocusFor(3), DailyFocus.middle);
    expect(dailyFocusFor(4), DailyFocus.good);
    expect(dailyFocusFor(5), DailyFocus.good);
  });

  group('pickRecommendations', () {
    Article article(String id, ArticleTopic topic, {bool reviewed = true}) =>
        Article(
          id: id,
          title: id,
          topic: topic,
          readingMinutes: 3,
          body: '',
          reviewed: reviewed,
        );

    final articles = [
      article('kuliah1', ArticleTopic.kuliah),
      article('kuliah2', ArticleTopic.kuliah),
      article('tidur', ArticleTopic.tidur),
      article('cemas', ArticleTopic.kecemasan),
      article('hubungan', ArticleTopic.hubungan),
      article('stres', ArticleTopic.stres),
      article('draft', ArticleTopic.stres, reviewed: false),
    ];

    test('a heavy day starts with stress, anxiety, and sleep', () {
      final picked = pickRecommendations(articles, 1);
      expect(picked.map((a) => a.id), ['stres', 'cemas', 'tidur']);
    });

    test('a good day leans toward relationships and studies', () {
      final picked = pickRecommendations(articles, 5);
      expect(picked.map((a) => a.id).take(2), ['hubungan', 'kuliah1']);
    });

    test('one per topic first, reviewed before unreviewed', () {
      final picked = pickRecommendations(articles, null, count: 6);
      expect(picked.map((a) => a.topic).take(5).toSet(), hasLength(5));
      expect(picked.map((a) => a.id), contains('stres'));
      expect(picked.map((a) => a.id), isNot(contains('draft')));
    });

    test('unreviewed articles still fill the list when needed', () {
      final picked = pickRecommendations(articles, null, count: 7);
      expect(picked.map((a) => a.id), contains('draft'));
    });
  });

  test('mood trend compares the last two check-ins, skipping gaps', () {
    expect(moodTrendOf(_week([null, null, null])), MoodTrend.none);
    expect(moodTrendOf(_week([null, 3, null])), MoodTrend.first);
    expect(moodTrendOf(_week([2, null, 4])), MoodTrend.lighter);
    expect(moodTrendOf(_week([4, 2, null])), MoodTrend.heavier);
    expect(moodTrendOf(_week([3, null, 3])), MoodTrend.steady);
  });
}

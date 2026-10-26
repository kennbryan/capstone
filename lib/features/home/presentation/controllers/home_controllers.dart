import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/features/checkin/presentation/controllers/checkin_controller.dart';
import 'package:msu_wellbeing/features/home/presentation/controllers/home_insights.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/article.dart';
import 'package:msu_wellbeing/features/learn/presentation/controllers/learn_controllers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_controllers.g.dart';

/// "Rekomendasi untukmu": articles matched to today's mood.
/// Exercises are left to the daily-focus card, so nothing repeats.
@riverpod
Future<List<Article>> homeRecommendations(Ref ref) async {
  final mood = ref.watch(
    checkInControllerProvider.select((s) => s.value?.today?.mood),
  );
  final articles = await ref.watch(articlesProvider().future);
  return pickRecommendations(articles, mood);
}

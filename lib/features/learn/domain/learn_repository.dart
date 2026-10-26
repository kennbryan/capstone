import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/article.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/garden_progress.dart';

abstract interface class LearnRepository {
  /// Published articles, optionally filtered by [topic].
  Future<Result<List<Article>>> getArticles({ArticleTopic? topic});

  Future<Result<Article>> getArticle(String id);
}

/// Local garden progress (non-sensitive, device only).
abstract interface class GardenRepository {
  GardenProgress load();

  /// Adds one completed session and returns the new progress.
  Future<GardenProgress> addSession();
}

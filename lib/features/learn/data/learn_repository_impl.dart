import 'package:msu_wellbeing/core/storage/preferences_service.dart';
import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/learn/data/models/article_dto.dart';
import 'package:msu_wellbeing/features/learn/data/sources/learn_sources.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/article.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/garden_progress.dart';
import 'package:msu_wellbeing/features/learn/domain/learn_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'learn_repository_impl.g.dart';

/// "Materi" articles, bundled with the app.
class LearnRepositoryImpl implements LearnRepository {
  const new([this._source = const LearnBundledSource()]);

  final LearnSource _source;

  @override
  Future<Result<List<Article>>> getArticles({ArticleTopic? topic}) {
    return Result.guard('articles.list', () async {
      final dtos = await _source.getArticles(topic: topic?.name);
      return [for (final dto in dtos) dto.toEntity()];
    });
  }

  @override
  Future<Result<Article>> getArticle(String id) {
    return Result.guard(
      'articles.detail',
      () async => (await _source.getArticle(id)).toEntity(),
    );
  }
}

class GardenRepositoryImpl implements GardenRepository {
  const new(this._prefs);

  final PreferencesService _prefs;

  @override
  GardenProgress load() => GardenProgress(_prefs.gardenSessions);

  @override
  Future<GardenProgress> addSession() async {
    final next = _prefs.gardenSessions + 1;
    await _prefs.setGardenSessions(next);
    return GardenProgress(next);
  }
}

@riverpod
LearnRepository learnRepository(Ref ref) {
  return const LearnRepositoryImpl();
}

@riverpod
GardenRepository gardenRepository(Ref ref) =>
    GardenRepositoryImpl(ref.watch(preferencesProvider));

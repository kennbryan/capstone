import 'package:msu_wellbeing/core/network/api_exception.dart';
import 'package:msu_wellbeing/features/learn/data/models/article_dto.dart';
import 'package:msu_wellbeing/features/learn/data/sources/bundled_articles.dart';

abstract interface class LearnSource {
  Future<List<ArticleDto>> getArticles({String? topic});

  Future<ArticleDto> getArticle(String id);
}

/// "Materi" articles. They are app content that ships with the app (see
/// `bundled_articles.dart`), so no backend endpoint is needed and they
/// work offline. Chatbot replies may link to these ids (`art_01`–`art_10`).
class LearnBundledSource implements LearnSource {
  const new();

  @override
  Future<List<ArticleDto>> getArticles({String? topic}) async => [
    for (final article in bundledArticles)
      if (topic == null || article.topic == topic) article,
  ];

  @override
  Future<ArticleDto> getArticle(String id) async => bundledArticles.firstWhere(
    (article) => article.id == id,
    orElse: () => throw const ApiException(ApiExceptionKind.notFound),
  );
}

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/article.dart';

part 'article_dto.freezed.dart';
part 'article_dto.g.dart';

@freezed
abstract class ArticleDto with _$ArticleDto {
  const factory({
    required String id,
    required String title,
    required String topic,
    required int readingMinutes,
    required String body,
    @Default(false) bool reviewed,
    String? reviewerName,
    String? sourceRef,
  }) = _ArticleDto;

  factory fromJson(Map<String, Object?> json) => _$ArticleDtoFromJson(json);
}

extension ArticleDtoMapper on ArticleDto {
  /// Unknown topics fall back to [ArticleTopic.stres].
  Article toEntity() => Article(
    id: id,
    title: title,
    topic: ArticleTopic.values.firstWhere(
      (value) => value.name == topic,
      orElse: () => ArticleTopic.stres,
    ),
    readingMinutes: readingMinutes,
    body: body,
    reviewed: reviewed,
    reviewerName: reviewerName,
    sourceRef: sourceRef,
  );
}

import 'package:freezed_annotation/freezed_annotation.dart';

part 'article.freezed.dart';

/// Topic filter for learning materials.
enum ArticleTopic { stres, tidur, kecemasan, hubungan, kuliah }

/// A short reviewed learning material. [body] is simple Markdown.
@freezed
abstract class Article with _$Article {
  const factory({
    required String id,
    required String title,
    required ArticleTopic topic,
    required int readingMinutes,
    required String body,
    required bool reviewed,
    String? reviewerName,
    String? sourceRef,
  }) = _Article;
}

import 'package:freezed_annotation/freezed_annotation.dart';

part 'learn_ref.freezed.dart';

/// Kinds of learning content the app can link to.
enum LearnKind { article, breathing, release, sounds }

/// A link to an article or exercise, e.g. from a chatbot suggestion.
@freezed
abstract class LearnRef with _$LearnRef {
  const factory({required LearnKind kind, required String title, String? id}) =
      _LearnRef;
}

import 'package:freezed_annotation/freezed_annotation.dart';

part 'summary_draft.freezed.dart';

/// Draft summary of a conversation for the psychologist. It is only a
/// draft: the app never sends it anywhere by itself.
@freezed
abstract class SummaryDraft with _$SummaryDraft {
  const factory({
    required String summary,
    @Default(<String>[]) List<String> topics,
    @Default(<String>[]) List<String> tried,
    @Default('') String hopes,
  }) = _SummaryDraft;
}

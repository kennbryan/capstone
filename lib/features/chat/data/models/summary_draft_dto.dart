import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/summary_draft.dart';

part 'summary_draft_dto.freezed.dart';
part 'summary_draft_dto.g.dart';

/// `POST /chatbot/conversations/{id}/summary-draft` response.
@freezed
abstract class SummaryDraftDto with _$SummaryDraftDto {
  const factory({
    required String summary,
    @Default(<String>[]) List<String> topics,
    @Default(<String>[]) List<String> tried,
    @Default('') String hopes,
  }) = _SummaryDraftDto;

  factory fromJson(Map<String, Object?> json) =>
      _$SummaryDraftDtoFromJson(json);
}

extension SummaryDraftDtoMapper on SummaryDraftDto {
  SummaryDraft toEntity() => SummaryDraft(
    summary: summary,
    topics: topics,
    tried: tried,
    hopes: hopes,
  );
}

import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_action.freezed.dart';

/// What a chatbot action button does. Unknown server values become
/// [unknown] and are not shown.
enum ChatActionType {
  openActivity,
  openPsychologistChat,
  prepareSummary,
  callPhone,
  openUrl,
  openReport,
  unknown,
}

/// A button the assistant attaches to a reply, e.g. "Telepon Healing119"
/// or "Siapkan ringkasan untuk psikolog".
@freezed
abstract class ChatAction with _$ChatAction {
  const factory({
    required ChatActionType type,
    required String label,

    /// Set for [ChatActionType.callPhone].
    String? phone,

    /// Set for [ChatActionType.openUrl].
    String? url,

    /// Set for [ChatActionType.openActivity].
    ActivityGuide? activity,
  }) = _ChatAction;
}

/// A short non-clinical activity from the chatbot catalog, shown as a
/// step-by-step sheet.
@freezed
abstract class ActivityGuide with _$ActivityGuide {
  const factory({
    required String id,
    required String title,
    required List<String> steps,
    @Default('') String description,
    int? durationMin,
    String? sourceName,
    String? sourceUrl,
  }) = _ActivityGuide;
}

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/chat_action.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/learn_ref.dart';

part 'chat_message.freezed.dart';

enum MessageRole { user, assistant, system }

/// `crisis` replies are always rendered as a crisis card, never a bubble.
enum MessageType { normal, crisis }

/// Material the assistant drew from. With a [url] the chip opens the
/// original source (WHO, Kemenkes); otherwise the in-app article.
@freezed
abstract class SourceRef with _$SourceRef {
  const factory({
    required String articleId,
    required String title,
    String? sourceName,
    String? url,
  }) = _SourceRef;
}

@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory({
    required String id,
    required MessageRole role,
    required String text,
    required DateTime createdAt,
    @Default(MessageType.normal) MessageType type,
    @Default(<SourceRef>[]) List<SourceRef> sources,
    @Default(<LearnRef>[]) List<LearnRef> suggestions,
    @Default(<ChatAction>[]) List<ChatAction> actions,

    /// Server conversation this reply belongs to, sent back with the next
    /// message so the assistant keeps the context.
    String? conversationId,
  }) = _ChatMessage;
}

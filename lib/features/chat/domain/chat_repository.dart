import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/chat_message.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/memory_item.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/summary_draft.dart';

abstract interface class ChatRepository {
  /// Sends [text] to the assistant and returns its reply. Pass the
  /// [conversationId] of the previous reply to continue that conversation.
  Future<Result<ChatMessage>> send(
    String text, {
    String? conversationId,
    String? displayName,
  });

  /// Deletes the conversation on the server.
  Future<Result<void>> deleteConversation(String conversationId);

  /// Drafts a summary of the conversation for the psychologist.
  Future<Result<SummaryDraft>> summaryDraft(String conversationId);

  /// What the assistant remembers about the signed-in user.
  Future<Result<List<MemoryItem>>> memory();

  Future<Result<void>> deleteMemory(String memoryId);

  Future<Result<void>> clearMemory();

  /// History kept on this device for [userId] (oldest first).
  Future<List<ChatMessage>> loadHistory(String userId);

  Future<void> saveHistory(String userId, List<ChatMessage> messages);

  Future<void> clearHistory(String userId);
}

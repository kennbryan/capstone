import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/chat_message.dart';

abstract interface class ChatRepository {
  /// Sends [text] to the assistant and returns its reply.
  Future<Result<ChatMessage>> send(String text);

  /// History kept on this device for [userId] (oldest first).
  Future<List<ChatMessage>> loadHistory(String userId);

  Future<void> saveHistory(String userId, List<ChatMessage> messages);

  Future<void> clearHistory(String userId);
}

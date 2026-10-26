import 'package:msu_wellbeing/core/logging/app_logger.dart';
import 'package:msu_wellbeing/core/network/dio_client.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';
import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/chat/data/models/chat_message_dto.dart';
import 'package:msu_wellbeing/features/chat/data/models/memory_item_dto.dart';
import 'package:msu_wellbeing/features/chat/data/models/summary_draft_dto.dart';
import 'package:msu_wellbeing/features/chat/data/sources/chat_sources.dart';
import 'package:msu_wellbeing/features/chat/domain/chat_repository.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/chat_message.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/memory_item.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/summary_draft.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_repository_impl.g.dart';

class ChatRepositoryImpl implements ChatRepository {
  const new(this._source, this._history);

  final ChatSource _source;
  final ChatHistoryStore _history;

  @override
  Future<Result<ChatMessage>> send(
    String text, {
    String? conversationId,
    String? displayName,
  }) {
    // The message text is never logged; only the event name.
    return Result.guard('chat.send', () async {
      final dto = await _source.send(
        text,
        conversationId: conversationId,
        displayName: displayName,
      );
      final reply = dto.toEntity();
      AppLogger.event('chat.reply', {
        'type': reply.type.name,
        'actions': reply.actions.length,
      });
      return reply;
    });
  }

  @override
  Future<Result<void>> deleteConversation(String conversationId) =>
      Result.guard(
        'chat.conversation.delete',
        () => _source.deleteConversation(conversationId),
      );

  @override
  Future<Result<SummaryDraft>> summaryDraft(String conversationId) =>
      Result.guard(
        'chat.summary',
        () async => (await _source.summaryDraft(conversationId)).toEntity(),
      );

  @override
  Future<Result<List<MemoryItem>>> memory() => Result.guard(
    'chat.memory.load',
    () async => [for (final dto in await _source.memory()) dto.toEntity()],
  );

  @override
  Future<Result<void>> deleteMemory(String memoryId) =>
      Result.guard('chat.memory.delete', () => _source.deleteMemory(memoryId));

  @override
  Future<Result<void>> clearMemory() =>
      Result.guard('chat.memory.clear', _source.clearMemory);

  @override
  Future<List<ChatMessage>> loadHistory(String userId) async {
    try {
      return [for (final dto in await _history.load(userId)) dto.toEntity()];
    } on Object catch (error, stackTrace) {
      AppLogger.error('chat.history.load', error, stackTrace);
      return const [];
    }
  }

  @override
  Future<void> saveHistory(String userId, List<ChatMessage> messages) =>
      _history.save(userId, [
        for (final message in messages) ChatMessageDto.fromEntity(message),
      ]);

  @override
  Future<void> clearHistory(String userId) => _history.clear(userId);
}

@riverpod
ChatRepository chatRepository(Ref ref) {
  return ChatRepositoryImpl(
    ChatRemoteSource(ref.watch(chatbotDioProvider)),
    ChatHistoryStore(ref.watch(secureStorageProvider)),
  );
}

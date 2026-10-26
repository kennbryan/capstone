import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';
import 'package:msu_wellbeing/features/chat/data/models/chat_message_dto.dart';
import 'package:msu_wellbeing/features/chat/data/models/memory_item_dto.dart';
import 'package:msu_wellbeing/features/chat/data/models/summary_draft_dto.dart';

abstract interface class ChatSource {
  Future<ChatMessageDto> send(
    String text, {
    String? conversationId,
    String? displayName,
  });

  Future<void> deleteConversation(String conversationId);

  Future<SummaryDraftDto> summaryDraft(String conversationId);

  Future<List<MemoryItemDto>> memory();

  Future<void> deleteMemory(String memoryId);

  Future<void> clearMemory();
}

/// The AI assistant (chatbot hibrida). Risk detection happens on the
/// backend; the app only renders what it receives.
///
/// Served by the chatbot service in `chatbot/` (`CHATBOT_BASE_URL`).
/// Auth: `Authorization: Bearer <accessToken>`; demo sessions send their
/// device token, which the service accepts in development.
///
/// `POST /chatbot/messages`
/// ```json
/// {
///   "text": "Aku lagi stres kuliah",
///   "conversationId": "c0ffee",
///   "displayName": "Rani"
/// }
/// ```
/// `conversationId` comes from the previous reply (omit it to start a new
/// conversation); every reply carries it.
/// → 200, one assistant message. Three shapes the app renders:
///
/// 1. Plain reply:
/// ```json
/// {
///   "id": "msg_123",
///   "role": "assistant",
///   "type": "normal",
///   "text": "Terima kasih sudah bercerita. Wajar merasa seperti itu.",
///   "createdAt": "2026-10-22T13:00:00Z"
/// }
/// ```
/// 2. With sources (chip "Sumber: {title}" opens `/learn/article/{articleId}`)
///    and/or suggestions (card opening an article or exercise):
/// ```json
/// {
///   "id": "msg_124",
///   "role": "assistant",
///   "type": "normal",
///   "text": "Wajar merasa tertekan saat tugas menumpuk.",
///   "sources": [
///     { "articleId": "art_01", "title": "Mengelola stres akademik" }
///   ],
///   "suggestions": [{ "kind": "breathing", "title": "Napas tenang 3 menit" }],
///   "createdAt": "2026-10-22T13:00:05Z"
/// }
/// ```
///    `suggestions[].kind` is one of `article` (then `id` = article id),
///    `breathing`, `release`, `sounds`.
/// 3. Crisis (shown as the red crisis card with help contacts, never as a
///    normal bubble):
/// ```json
/// {
///   "id": "msg_125",
///   "role": "assistant",
///   "type": "crisis",
///   "text": "Terima kasih sudah memberi tahu. Kamu tidak sendirian.",
///   "createdAt": "2026-10-22T13:00:09Z"
/// }
/// ```
/// 4. With actions (buttons under the reply):
/// ```json
/// "actions": [
///   { "type": "call_phone", "label": "Darurat 112",
///     "payload": { "phone": "112" } },
///   { "type": "open_url", "label": "Chat Healing119.id",
///     "payload": { "url": "https://www.healing119.id" } },
///   { "type": "open_psychologist_chat", "label": "Chat dengan psikolog" },
///   { "type": "prepare_summary",
///     "label": "Siapkan ringkasan untuk psikolog" },
///   { "type": "open_report", "label": "Buka menu Rapor" },
///   { "type": "open_activity", "label": "Grounding",
///     "payload": { "id": "grounding-dwm", "title": "Grounding",
///       "durationMin": 3, "description": "...", "steps": ["..."],
///       "sourceName": "WHO", "sourceUrl": "https://www.who.int/..." } }
/// ]
/// ```
/// `sources[]` may also carry `sourceName` and an `https` `url`; the chip
/// then opens the original source instead of an in-app article.
///
/// `sources`, `suggestions`, and `actions` may be omitted. Keys are
/// camelCase.
///
/// Other endpoints:
/// - `DELETE /chatbot/conversations/{conversationId}` → 204
/// - `POST /chatbot/conversations/{conversationId}/summary-draft` →
///   `{ "summary": "...", "topics": [], "tried": [], "hopes": "" }`
/// - `GET /chatbot/memory` →
///   `[{ "id", "category", "content", "updatedAt" }]`
/// - `DELETE /chatbot/memory/{memoryId}`, `DELETE /chatbot/memory` → 204
class ChatRemoteSource implements ChatSource {
  const new(this._dio);

  final Dio _dio;

  @override
  Future<ChatMessageDto> send(
    String text, {
    String? conversationId,
    String? displayName,
  }) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/chatbot/messages',
      data: {
        'text': text,
        'conversationId': ?conversationId,
        'displayName': ?displayName,
      },
    );
    return ChatMessageDto.fromJson(response.data!);
  }

  @override
  Future<void> deleteConversation(String conversationId) =>
      _dio.delete<void>('/chatbot/conversations/$conversationId');

  @override
  Future<SummaryDraftDto> summaryDraft(String conversationId) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/chatbot/conversations/$conversationId/summary-draft',
    );
    return SummaryDraftDto.fromJson(response.data!);
  }

  @override
  Future<List<MemoryItemDto>> memory() async {
    final response = await _dio.get<List<Object?>>('/chatbot/memory');
    return [
      for (final item in response.data!)
        MemoryItemDto.fromJson(item! as Map<String, Object?>),
    ];
  }

  @override
  Future<void> deleteMemory(String memoryId) =>
      _dio.delete<void>('/chatbot/memory/$memoryId');

  @override
  Future<void> clearMemory() => _dio.delete<void>('/chatbot/memory');
}

/// Chat history in secure storage, one entry per user.
class ChatHistoryStore {
  const new(this._storage);

  final SecureStorageService _storage;

  Future<List<ChatMessageDto>> load(String userId) async {
    final raw = await _storage.read(SecureKeys.chatHistory(userId));
    if (raw == null) return const [];
    return [
      for (final item in jsonDecode(raw) as List<Object?>)
        ChatMessageDto.fromJson(item! as Map<String, Object?>),
    ];
  }

  Future<void> save(String userId, List<ChatMessageDto> messages) =>
      _storage.write(
        SecureKeys.chatHistory(userId),
        jsonEncode([for (final message in messages) message.toJson()]),
      );

  Future<void> clear(String userId) =>
      _storage.delete(SecureKeys.chatHistory(userId));
}

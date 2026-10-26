import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';
import 'package:msu_wellbeing/features/chat/data/models/chat_message_dto.dart';

abstract interface class ChatSource {
  Future<ChatMessageDto> send(String text);
}

/// The AI assistant (chatbot hibrida). Risk detection happens on the
/// backend; the app only renders what it receives.
///
/// **For the backend team** (auth: `Authorization: Bearer <accessToken>`):
///
/// `POST /chatbot/messages`
/// ```json
/// { "text": "Aku lagi stres kuliah" }
/// ```
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
/// `sources` and `suggestions` may be omitted. Keys are camelCase.
class ChatRemoteSource implements ChatSource {
  const new(this._dio);

  final Dio _dio;

  // TODO(backend): accept and return `conversationId` to keep sessions.
  @override
  Future<ChatMessageDto> send(String text) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/chatbot/messages',
      data: {'text': text},
    );
    return ChatMessageDto.fromJson(response.data!);
  }
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

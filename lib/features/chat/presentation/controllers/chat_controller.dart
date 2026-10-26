import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:msu_wellbeing/core/network/api_exception.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/auth_controller.dart';
import 'package:msu_wellbeing/features/chat/data/chat_repository_impl.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/chat_message.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_controller.freezed.dart';
part 'chat_controller.g.dart';

@freezed
abstract class ChatState with _$ChatState {
  const factory({
    required List<ChatMessage> messages,
    @Default(false) bool sending,
  }) = _ChatState;
}

/// Limits for the chat input.
abstract final class ChatRules {
  static const maxLength = 1000;
}

/// Conversation with the AI assistant. Kept in memory and in secure
/// storage per user; reset automatically on logout.
@Riverpod(keepAlive: true)
class ChatController extends _$ChatController {
  @override
  Future<ChatState> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const ChatState(messages: []);
    final history = await ref.watch(chatRepositoryProvider).loadHistory(userId);
    return ChatState(messages: history);
  }

  /// Sends [text]. Returns the failure, or null on success.
  Future<ApiException?> send(String text) async {
    final trimmed = text.trim();
    final current = state.value;
    if (trimmed.isEmpty || current == null || current.sending) return null;

    final userMessage = ChatMessage(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      role: MessageRole.user,
      text: trimmed.length > ChatRules.maxLength
          ? trimmed.substring(0, ChatRules.maxLength)
          : trimmed,
      createdAt: DateTime.now(),
    );
    state = AsyncData(
      current.copyWith(
        messages: [...current.messages, userMessage],
        sending: true,
      ),
    );

    final result = await ref.read(chatRepositoryProvider).send(trimmed);
    final latest = state.value ?? current;
    return result.fold<ApiException?>(
      onSuccess: (reply) {
        final messages = [...latest.messages, reply];
        state = AsyncData(latest.copyWith(messages: messages, sending: false));
        _persist(messages);
        return null;
      },
      onFailure: (error) {
        state = AsyncData(latest.copyWith(sending: false));
        _persist(latest.messages);
        return error;
      },
    );
  }

  /// Deletes the conversation from memory and the device.
  Future<void> clearHistory() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      await ref.read(chatRepositoryProvider).clearHistory(userId);
    }
    state = const AsyncData(ChatState(messages: []));
  }

  void _persist(List<ChatMessage> messages) {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    ref.read(chatRepositoryProvider).saveHistory(userId, messages).ignore();
  }
}

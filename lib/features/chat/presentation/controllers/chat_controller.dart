import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:msu_wellbeing/core/network/api_exception.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/auth_controller.dart';
import 'package:msu_wellbeing/features/chat/data/chat_repository_impl.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/chat_message.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/summary_draft.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_controller.freezed.dart';
part 'chat_controller.g.dart';

@freezed
abstract class ChatState with _$ChatState {
  const factory({
    required List<ChatMessage> messages,
    @Default(false) bool sending,
  }) = _ChatState;
  const new _();

  /// Conversation of the newest assistant reply, continued by the next
  /// message.
  String? get conversationId => messages.reversed
      .map((message) => message.conversationId)
      .firstWhere((id) => id != null, orElse: () => null);
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

    final result = await ref
        .read(chatRepositoryProvider)
        .send(
          userMessage.text,
          conversationId: current.conversationId,
          displayName: ref.read(authControllerProvider).value?.displayName,
        );
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

  /// Deletes the conversation from memory, the device, and the chatbot
  /// server. The next message starts a new conversation.
  Future<void> clearHistory() async {
    final repository = ref.read(chatRepositoryProvider);
    final conversationId = state.value?.conversationId;
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) await repository.clearHistory(userId);
    state = const AsyncData(ChatState(messages: []));
    // Best effort: the local copy is already gone, and the server keeps
    // nothing new once the next message starts another conversation.
    if (conversationId != null) {
      await repository.deleteConversation(conversationId);
    }
  }

  void _persist(List<ChatMessage> messages) {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    ref.read(chatRepositoryProvider).saveHistory(userId, messages).ignore();
  }
}

/// Draft summary of [conversationId] for the psychologist. Generated on
/// request only, never sent automatically.
@riverpod
Future<SummaryDraft> summaryDraft(Ref ref, String conversationId) async {
  final result = await ref
      .watch(chatRepositoryProvider)
      .summaryDraft(conversationId);
  return result.unwrap();
}

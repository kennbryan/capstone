import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/brand_background.dart';
import 'package:msu_wellbeing/core/widgets/error_message.dart';
import 'package:msu_wellbeing/core/widgets/state_views.dart';
import 'package:msu_wellbeing/features/chat/presentation/controllers/chat_controller.dart';
import 'package:msu_wellbeing/features/chat/presentation/widgets/chat_parts.dart';
import 'package:msu_wellbeing/features/chat/presentation/widgets/message_bubble.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Conversation with the AI assistant.
class AssistantChatView extends ConsumerWidget {
  const new({super.key});

  Future<void> _send(BuildContext context, WidgetRef ref, String text) async {
    final failure = await ref.read(chatControllerProvider.notifier).send(text);
    if (failure != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.describeError(failure))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatControllerProvider);
    return switch (chat) {
      AsyncData(:final value) => Column(
        children: [
          Expanded(
            child: _MessageList(
              state: value,
              onSuggestion: _onChip(context, ref),
            ),
          ),
          const Divider(),
          ChatInputBar(
            sending: value.sending,
            onSend: (text) => _send(context, ref, text),
          ),
        ],
      ),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(chatControllerProvider),
      ),
      _ => const LoadingView(),
    };
  }

  ValueChanged<String> _onChip(BuildContext context, WidgetRef ref) =>
      (text) => _send(context, ref, text);
}

class _MessageList extends StatelessWidget {
  const new({required this.state, required this.onSuggestion});

  final ChatState state;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final messages = state.messages;
    // Reversed so the newest message sits above the input.
    final items = <Widget>[
      if (state.sending) const TypingIndicator(),
      // Only the newest message rises in, so scrolling back through older
      // ones never replays the animation.
      for (final message in messages.reversed)
        if (message == messages.last)
          FadeInUp(
            key: ValueKey(message.id),
            child: MessageBubble(message: message),
          )
        else
          MessageBubble(key: ValueKey(message.id), message: message),
      if (messages.isEmpty)
        _SuggestionChips(
          suggestions: [
            l10n.chatSuggestion1,
            l10n.chatSuggestion2,
            l10n.chatSuggestion3,
          ],
          onSelected: onSuggestion,
        ),
      const AssistantDisclaimer(),
      const AssistantHeader(),
    ];
    return ListView.separated(
      reverse: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screen,
        vertical: AppSpacing.lg,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => items[index],
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  const new({required this.suggestions, required this.onSelected});

  final List<String> suggestions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.chatEmptyHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final text in suggestions)
              ActionChip(label: Text(text), onPressed: () => onSelected(text)),
          ],
        ),
      ],
    );
  }
}

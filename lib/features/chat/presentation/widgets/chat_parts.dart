import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/features/chat/presentation/controllers/chat_controller.dart';
import 'package:msu_wellbeing/features/chat/presentation/widgets/assistant_avatar.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Assistant identity: avatar, "Asisten MSU", and an "AI" chip, so it is
/// never mistaken for the psychologist.
class AssistantHeader extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Row(
      children: [
        const AssistantAvatar(),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(l10n.assistantName, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(width: AppSpacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.assistant,
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs / 2,
            ),
            child: Text(
              l10n.assistantBadge,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onAssistant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The pinned "I am an AI, not a psychologist" message.
class AssistantDisclaimer extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.assistant,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: colors.onAssistant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                context.l10n.assistantDisclaimer,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onAssistant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three dots shown while the assistant replies. Static under reduce
/// motion.
class TypingIndicator extends StatefulWidget {
  const new({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      label: context.l10n.chatTyping,
      liveRegion: true,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.assistant,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs / 2,
                      ),
                      child: Opacity(
                        opacity: _opacity(i),
                        child: Container(
                          width: AppSizes.typingDot,
                          height: AppSizes.typingDot,
                          decoration: BoxDecoration(
                            color: colors.onAssistant,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _opacity(int index) {
    final phase = (_controller.value * 3 - index) % 3;
    return phase < 1 ? 1 : 0.35;
  }
}

/// Multiline input; send is disabled when empty or while sending.
class ChatInputBar extends StatefulWidget {
  const new({required this.sending, required this.onSend, super.key});

  final bool sending;
  final ValueChanged<String> onSend;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.sending) return;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              maxLength: ChatRules.maxLength,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: l10n.chatInputHint,
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton.filled(
            tooltip: l10n.chatSend,
            onPressed: _controller.text.trim().isEmpty || widget.sending
                ? null
                : _send,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

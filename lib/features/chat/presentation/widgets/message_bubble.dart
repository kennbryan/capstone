import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:msu_wellbeing/core/router/app_routes.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/chat_message.dart';
import 'package:msu_wellbeing/features/chat/presentation/widgets/crisis_inline_card.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/learn_ref.dart';
import 'package:msu_wellbeing/features/learn/presentation/widgets/learn_ref_display.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Renders one message. User messages use the primary color; assistant
/// messages use the cool `assistant` token; crisis replies become a
/// [CrisisInlineCard].
class MessageBubble extends StatelessWidget {
  const new({required this.message, super.key});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.crisis) {
      return CrisisInlineCard(message: message);
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isUser = message.role == MessageRole.user;
    final gradients = context.gradients;
    final background = isUser ? null : colors.assistant;
    final foreground = isUser ? gradients.onBrand : colors.onAssistant;
    final maxWidth =
        MediaQuery.sizeOf(context).width * AppSizes.bubbleMaxWidthFactor;

    return Semantics(
      label: isUser ? l10n.chatYou : l10n.assistantName,
      child: Align(
        alignment: isUser
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  gradient: isUser ? gradients.brand : null,
                  borderRadius: BorderRadiusDirectional.only(
                    topStart: const Radius.circular(AppRadius.card),
                    topEnd: const Radius.circular(AppRadius.card),
                    bottomStart: Radius.circular(
                      isUser ? AppRadius.card : AppSpacing.xs,
                    ),
                    bottomEnd: Radius.circular(
                      isUser ? AppSpacing.xs : AppRadius.card,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Text(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ),
              if (message.sources.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final source in message.sources)
                      ActionChip(
                        avatar: const Icon(
                          Icons.menu_book_outlined,
                          size: AppSizes.iconSm,
                        ),
                        label: Text(l10n.chatSource(source.title)),
                        onPressed: () =>
                            context.push(AppRoutes.article(source.articleId)),
                      ),
                  ],
                ),
              ],
              for (final suggestion in message.suggestions) ...[
                const SizedBox(height: AppSpacing.sm),
                _SuggestionCard(suggestion: suggestion),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const new({required this.suggestion});

  final LearnRef suggestion;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final route = suggestion.route;
    final title = suggestion.title.isEmpty
        ? suggestion.displayTitle(l10n)
        : suggestion.title;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          suggestion.icon,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: route == null ? null : () => context.push(route),
      ),
    );
  }
}

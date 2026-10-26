import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:msu_wellbeing/core/router/app_routes.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/chat_message.dart';
import 'package:msu_wellbeing/features/crisis/presentation/widgets/crisis_contacts.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Shown instead of a bubble for `type == crisis` replies.
class CrisisInlineCard extends StatelessWidget {
  const new({required this.message, super.key});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.crisisContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: colors.crisis),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite_outline, color: colors.crisis),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.crisisCardTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.onCrisisContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onCrisisContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const CrisisContacts(),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.crisis,
                  foregroundColor: colors.onCrisis,
                ),
                onPressed: () => context.push(AppRoutes.crisis),
                child: Text(l10n.crisisCardOpen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

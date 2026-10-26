import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/app_card.dart';
import 'package:msu_wellbeing/core/widgets/hero_card.dart';
import 'package:msu_wellbeing/features/chat/presentation/widgets/whatsapp_flow.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Information about the human psychologist service, reached via WhatsApp.
/// Styled with the primary palette so it never looks like the AI chat.
class PsychologistView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const GradientIconBadge(
                    icon: Icons.support_agent_outlined,
                    size: AppSizes.avatar,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.psychologistTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.psychologistBody, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.psychologistPrivacy, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xl),
              const WhatsAppButton(),
            ],
          ),
        ),
      ],
    );
  }
}

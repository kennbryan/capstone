import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:msu_wellbeing/core/router/app_routes.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/features/chat/presentation/widgets/whatsapp_flow.dart';
import 'package:msu_wellbeing/features/crisis/presentation/widgets/crisis_contacts.dart';
import 'package:msu_wellbeing/features/remote_config/presentation/controllers/remote_config_controller.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Full-screen crisis help, reachable from every main tab and from crisis
/// chat replies. The only screen allowed to use the crisis tokens.
class CrisisScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final config = ref.watch(remoteConfigProvider).value;
    final number = config?.whatsappNumber;
    final hasContacts = config?.crisisContacts.isNotEmpty ?? true;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.close,
          icon: const Icon(Icons.close),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.crisisContainer, theme.colorScheme.surface],
                ),
                borderRadius: BorderRadius.circular(AppRadius.hero),
                border: Border.all(
                  color: colors.crisis.withValues(alpha: 0.25),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.crisis.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite_outline,
                        color: colors.crisis,
                        size: AppSizes.iconLg,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.crisisHeading,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: colors.onCrisisContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.crisisBody,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onCrisisContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(l10n.crisisContactsTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hasContacts ? l10n.crisisContactsHint : l10n.crisisNoContacts,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            const CrisisContacts(),
            const SizedBox(height: AppSpacing.lg),
            if (number == null || number.isEmpty)
              Text(
                l10n.psychologistUnavailable,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              )
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.crisis,
                  foregroundColor: colors.onCrisis,
                ),
                onPressed: () => openPsychologistWhatsApp(context, ref, number),
                icon: const Icon(Icons.chat_outlined),
                label: Text(l10n.crisisPsychologist),
              ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.breathing),
              icon: const Icon(Icons.air),
              label: Text(l10n.crisisBreathing),
            ),
          ],
        ),
      ),
    );
  }
}

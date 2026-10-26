import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:msu_wellbeing/core/router/app_routes.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/app_card.dart';
import 'package:msu_wellbeing/core/widgets/hero_card.dart';
import 'package:msu_wellbeing/features/checkin/presentation/controllers/checkin_controller.dart';
import 'package:msu_wellbeing/features/home/presentation/controllers/home_insights.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// "Untukmu hari ini": a gentle next step that adapts to today's check-in,
/// so the app responds as soon as the user tells it how they feel.
class DailyFocusCard extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(checkInControllerProvider);
    if (!week.hasValue) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final focus = dailyFocusFor(week.value?.today?.mood);

    final (icon, title, body, actions) = switch (focus) {
      DailyFocus.start => (
        Icons.wb_twilight_outlined,
        l10n.focusStartTitle,
        l10n.focusStartBody,
        [_Action.breathing],
      ),
      DailyFocus.heavy => (
        Icons.favorite_outline,
        l10n.focusHeavyTitle,
        l10n.focusHeavyBody,
        [_Action.breathing, _Action.psychologist],
      ),
      DailyFocus.middle => (
        Icons.cloud_outlined,
        l10n.focusMiddleTitle,
        l10n.focusMiddleBody,
        [_Action.release, _Action.breathing],
      ),
      DailyFocus.good => (
        Icons.wb_sunny_outlined,
        l10n.focusGoodTitle,
        l10n.focusGoodBody,
        [_Action.learn, _Action.breathing],
      ),
    };

    return AnimatedSwitcher(
      duration: AppDurations.long,
      switchInCurve: AppDurations.curve,
      child: AppCard(
        key: ValueKey(focus),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.focusTitle, style: theme.textTheme.labelMedium),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GradientIconBadge(icon: icon),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(body, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: _ActionButton(action: actions.first, primary: true),
            ),
            if (actions.length > 1) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  for (final (index, action) in actions.skip(1).indexed) ...[
                    if (index > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ActionButton(action: action, primary: false),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _Action { breathing, assistant, psychologist, release, learn }

class _ActionButton extends StatelessWidget {
  const new({required this.action, required this.primary});

  final _Action action;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (icon, label, VoidCallback onTap) = switch (action) {
      _Action.breathing => (
        Icons.air,
        l10n.focusActionBreathing,
        () => context.push(AppRoutes.breathing),
      ),
      _Action.assistant => (
        Icons.smart_toy_outlined,
        l10n.focusActionAssistant,
        () => context.go(AppRoutes.chatAssistant),
      ),
      _Action.psychologist => (
        Icons.support_agent_outlined,
        l10n.focusActionPsychologist,
        () => context.go(AppRoutes.chatPsychologist),
      ),
      _Action.release => (
        Icons.cloud_outlined,
        l10n.focusActionRelease,
        () => context.push(AppRoutes.release),
      ),
      _Action.learn => (
        Icons.menu_book_outlined,
        l10n.focusActionLearn,
        () => context.go(AppRoutes.learn),
      ),
    };
    final iconWidget = Icon(icon, size: AppSizes.iconSm);
    return primary
        ? FilledButton.icon(
            onPressed: onTap,
            icon: iconWidget,
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: iconWidget,
            label: Text(label),
          );
  }
}

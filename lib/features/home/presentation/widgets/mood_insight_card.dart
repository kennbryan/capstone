import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/app_card.dart';
import 'package:msu_wellbeing/core/widgets/state_views.dart';
import 'package:msu_wellbeing/features/checkin/presentation/controllers/checkin_controller.dart';
import 'package:msu_wellbeing/features/checkin/presentation/widgets/mood_trend_chart.dart';
import 'package:msu_wellbeing/features/home/presentation/controllers/home_insights.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Seven-day mood chart with a gentle, plain-language insight.
class MoodInsightCard extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(checkInControllerProvider);
    return AppCard(
      child: switch (week) {
        AsyncData(:final value) => _content(context, value),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(checkInControllerProvider),
        ),
        _ => const LoadingView(compact: true),
      },
    );
  }

  Widget _content(BuildContext context, CheckInWeek week) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final trend = moodTrendOf(week.days);
    final (icon, insight) = switch (trend) {
      MoodTrend.none => (Icons.spa_outlined, l10n.homeMoodEmpty),
      MoodTrend.first => (Icons.spa_outlined, l10n.insightFirst),
      MoodTrend.lighter => (Icons.trending_up, l10n.insightLighter),
      MoodTrend.heavier => (Icons.trending_down, l10n.insightHeavier),
      MoodTrend.steady => (Icons.trending_flat, l10n.insightSteady),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartHeader(logged: week.days.where((d) => d.checkIn != null).length),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Icon(icon, size: AppSizes.iconSm, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(insight, style: theme.textTheme.bodySmall)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        MoodTrendChart(days: week.days),
      ],
    );
  }
}

/// "Suasana hatimu · 7 hari terakhir" with a logged-days chip.
class _ChartHeader extends StatelessWidget {
  const new({required this.logged});

  final int logged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.homeMoodTitle, style: theme.textTheme.titleSmall),
                  Text(l10n.weekTitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: context.gradients.soft,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  l10n.homeDaysLogged(logged),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

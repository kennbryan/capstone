import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/garden_progress.dart';
import 'package:msu_wellbeing/features/learn/presentation/controllers/learn_controllers.dart';
import 'package:msu_wellbeing/features/learn/presentation/widgets/garden_guide.dart';
import 'package:msu_wellbeing/features/learn/presentation/widgets/garden_painter.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// "Taman tenang": a plant on a soft sky that grows with relaxation
/// sessions. It explains itself (stage name, sessions to the next stage,
/// and a "how it works" guide); there are no scores or targets, and it
/// never shrinks or wilts.
class GardenHeader extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final gradients = context.gradients;
    final garden = ref.watch(gardenControllerProvider);
    final stage = garden.stage;
    const total = GardenProgress.maxStage + 1;
    final next = garden.sessionsToNextStage;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradients.sky,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.hero),
        child: Stack(
          children: [
            Positioned(
              top: AppSpacing.xl,
              left: AppSpacing.xxl * 1.5,
              child: Container(
                width: AppSizes.iconLg,
                height: AppSizes.iconLg,
                decoration: BoxDecoration(
                  color: gradients.sun,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Semantics(
                        label: l10n.learnGardenLabel(stage + 1, total),
                        child: SizedBox.square(
                          dimension: AppSizes.gardenHeight * 0.85,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: stage.toDouble()),
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : AppDurations.chart,
                            curve: AppDurations.curve,
                            builder: (context, value, _) => CustomPaint(
                              painter: GardenPainter(
                                growth: value,
                                plant: theme.colorScheme.primary,
                                soil: theme.colorScheme.onSurfaceVariant,
                                bloom: gradients.sun,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.learnGardenTitle,
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${l10n.learnGardenStage(stage + 1, total)}'
                              ' · ${gardenStageName(l10n, stage)}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _StageDots(stage: stage, total: total),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              next == 0
                                  ? l10n.learnGardenFull
                                  : l10n.learnGardenNext(next),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.learnGardenCaption,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      icon: const Icon(Icons.help_outline),
                      label: Text(l10n.learnGardenHow),
                      onPressed: () => showGardenGuide(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageDots extends StatelessWidget {
  const new({required this.stage, required this.total});

  final int stage;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: AppDurations.medium,
              margin: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
              width: i == stage ? AppSizes.pageDotActive : AppSizes.pageDot,
              height: AppSizes.pageDot,
              decoration: BoxDecoration(
                color: i <= stage ? scheme.primary : scheme.outline,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
            ),
        ],
      ),
    );
  }
}

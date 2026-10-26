import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/hero_card.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/learn_ref.dart';
import 'package:msu_wellbeing/features/learn/presentation/widgets/learn_art.dart';
import 'package:msu_wellbeing/features/learn/presentation/widgets/learn_ref_display.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Horizontal carousel of solid-color tiles, each with its own small
/// drawing, for the three relaxation exercises.
class ExerciseCarousel extends StatelessWidget {
  const new({super.key});

  static const _exercises = [
    LearnRef(kind: LearnKind.breathing, title: ''),
    LearnRef(kind: LearnKind.release, title: ''),
    LearnRef(kind: LearnKind.sounds, title: ''),
  ];

  @override
  Widget build(BuildContext context) {
    final gradients = context.gradients;
    Gradient gradientFor(LearnKind kind) => switch (kind) {
      LearnKind.breathing => gradients.brand,
      LearnKind.release => gradients.ai,
      _ => LinearGradient(colors: [gradients.accent, gradients.accent]),
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final exercise in _exercises) ...[
              _ExerciseTile(
                exercise: exercise,
                gradient: gradientFor(exercise.kind),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const new({required this.exercise, required this.gradient});

  final LearnRef exercise;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final onBrand = context.gradients.onBrand;
    return SizedBox(
      width: AppSizes.carouselCard * 0.8,
      child: Semantics(
        button: true,
        child: HeroCard(
          gradient: gradient,
          radius: AppRadius.tile,
          padding: const EdgeInsets.all(AppSpacing.lg),
          onTap: () => context.push(exercise.route!),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExerciseArt(kind: exercise.kind),
              const SizedBox(height: AppSpacing.lg),
              Text(
                exercise.displayTitle(l10n),
                style: theme.textTheme.titleSmall?.copyWith(color: onBrand),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                exercise.subtitle(l10n)!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: onBrand.withValues(alpha: 0.88),
                ),
              ),
              const Spacer(),
              const SizedBox(height: AppSpacing.md),
              Icon(Icons.arrow_forward, color: onBrand, size: AppSizes.iconSm),
            ],
          ),
        ),
      ),
    );
  }
}

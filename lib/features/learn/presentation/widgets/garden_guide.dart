import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:msu_wellbeing/core/router/app_routes.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/primary_button.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/garden_progress.dart';
import 'package:msu_wellbeing/features/learn/presentation/widgets/garden_painter.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Friendly name of a garden stage (0 = seed … 4 = in bloom).
String gardenStageName(AppLocalizations l10n, int stage) => switch (stage) {
  0 => l10n.gardenStage1,
  1 => l10n.gardenStage2,
  2 => l10n.gardenStage3,
  3 => l10n.gardenStage4,
  _ => l10n.gardenStage5,
};

/// Explains how "Taman tenang" works: which exercises count, how growth
/// works, and that the plant never wilts. Ends with a shortcut to start.
Future<void> showGardenGuide(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _GardenGuide(),
  );
}

class _GardenGuide extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final steps = [
      (Icons.spa_outlined, l10n.gardenGuideStep1Title, l10n.gardenGuideStep1),
      (
        Icons.check_circle_outline,
        l10n.gardenGuideStep2Title,
        l10n.gardenGuideStep2,
      ),
      (
        Icons.local_florist_outlined,
        l10n.gardenGuideStep3Title,
        l10n.gardenGuideStep3,
      ),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.gardenGuideTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            for (final (index, (icon, title, body)) in steps.indexed) ...[
              _Step(number: index + 1, icon: icon, title: title, body: body),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.gardenGuideStages, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            const _StageStrip(),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: l10n.gardenGuideStart,
              icon: Icons.air,
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(context.push(AppRoutes.breathing));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const new({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
  });

  final int number;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Icon(icon),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$number. $title', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs / 2),
              Text(body, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

/// The five stages side by side, so people see what they are growing.
class _StageStrip extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Row(
      children: [
        for (var stage = 0; stage <= GardenProgress.maxStage; stage++)
          Expanded(
            child: Column(
              children: [
                ExcludeSemantics(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CustomPaint(
                      painter: GardenPainter(
                        growth: stage.toDouble(),
                        plant: theme.colorScheme.primary,
                        soil: theme.colorScheme.onSurfaceVariant,
                        bloom: context.gradients.sun,
                      ),
                    ),
                  ),
                ),
                Text(
                  gardenStageName(l10n, stage),
                  style: theme.textTheme.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

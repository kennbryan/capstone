import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/primary_button.dart';
import 'package:msu_wellbeing/features/learn/presentation/controllers/breathing_pattern.dart';
import 'package:msu_wellbeing/features/learn/presentation/controllers/learn_controllers.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Duration picker plus the hold-mode and haptics toggles.
class BreathingSetup extends ConsumerWidget {
  const new({
    required this.minutes,
    required this.holdMode,
    required this.onMinutes,
    required this.onHoldMode,
    required this.onStart,
    super.key,
  });

  final int minutes;
  final bool holdMode;
  final ValueChanged<int> onMinutes;
  final ValueChanged<bool> onHoldMode;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final haptics = ref.watch(hapticsControllerProvider);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        Text(l10n.breathingIntro, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.breathingDuration, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            for (final value in BreathingPattern.durations)
              ButtonSegment(value: value, label: Text(l10n.minutes(value))),
          ],
          selected: {minutes},
          onSelectionChanged: (selection) => onMinutes(selection.first),
        ),
        const SizedBox(height: AppSpacing.lg),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: holdMode,
          onChanged: onHoldMode,
          title: Text(l10n.breathingHoldMode),
          subtitle: Text(l10n.breathingHoldModeHint),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: haptics,
          onChanged: (enabled) => ref
              .read(hapticsControllerProvider.notifier)
              .toggle(enabled: enabled),
          title: Text(l10n.breathingHaptics),
          subtitle: Text(l10n.breathingHapticsHint),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(label: l10n.breathingStart, onPressed: onStart),
      ],
    );
  }
}

/// Glowing gradient orb that grows and shrinks with the breath, inside a
/// ring showing how much of the session has passed. Under reduce motion the
/// orb keeps a fixed size and only its glow and opacity change.
class BreathingCircle extends StatelessWidget {
  const new({
    required this.size,
    required this.label,
    this.sessionProgress = 0,
    super.key,
  });

  /// 0 (smallest) to 1 (largest).
  final double size;
  final String label;

  /// 0 to 1, for the outer ring.
  final double sessionProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradients = context.gradients;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final diameter = reduceMotion
        ? AppSizes.breathingMax * 0.85
        : AppSizes.breathingMin +
              (AppSizes.breathingMax - AppSizes.breathingMin) * size;
    final brand = gradients.brand.colors;

    return SizedBox.square(
      dimension: AppSizes.progressRing,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(AppSizes.progressRing),
            painter: _RingPainter(
              progress: sessionProgress,
              track: theme.colorScheme.outline,
              gradient: gradients.brand,
            ),
          ),
          Opacity(
            opacity: reduceMotion ? 0.55 + 0.45 * size : 1,
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [brand.last, brand.first],
                  stops: const [0.2, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: brand.first.withValues(alpha: 0.25 + 0.25 * size),
                    blurRadius: AppSpacing.xl + AppSpacing.xxl * size,
                    spreadRadius: AppSpacing.xs + AppSpacing.md * size,
                  ),
                ],
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: gradients.onBrand,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const new({
    required this.progress,
    required this.track,
    required this.gradient,
  });

  final double progress;
  final Color track;
  final Gradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = AppSizes.chartStroke * 2;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke);
    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.track != track;
}

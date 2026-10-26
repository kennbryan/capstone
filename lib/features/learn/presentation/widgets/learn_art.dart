import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/sketch.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/learn_ref.dart';

/// Small white drawing for an exercise tile on its solid color: calm rings
/// for breathing, a drifting leaf for release, waves for sounds.
class ExerciseArt extends StatelessWidget {
  const new({required this.kind, this.size = AppSizes.thumbnail, super.key});

  /// Which exercise.
  final LearnKind kind;

  /// Width and height.
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ExercisePainter(kind, context.gradients.onBrand),
      ),
    ),
  );
}

class _ExercisePainter extends CustomPainter {
  const new(this.kind, this.white);

  final LearnKind kind;
  final Color white;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    switch (kind) {
      case LearnKind.breathing:
        for (var i = 3; i >= 1; i--) {
          canvas.drawCircle(
            c,
            s * 0.15 * i,
            Paint()..color = white.withValues(alpha: 0.12 + 0.12 * (3 - i)),
          );
        }
        canvas.drawCircle(c, s * 0.12, Paint()..color = white);
      case LearnKind.release:
        final dots = Paint()..color = white.withValues(alpha: 0.5);
        for (var i = 0; i < 4; i++) {
          canvas.drawCircle(
            Offset(s * (0.2 + 0.1 * i), s * (0.85 - 0.12 * i)),
            s * 0.03,
            dots,
          );
        }
        canvas.leaf(
          Offset(s * 0.5, s * 0.5),
          s * 0.42,
          -math.pi / 4,
          white,
          vein: white.withValues(alpha: 0.4),
        );
      case LearnKind.sounds:
      case LearnKind.article:
        for (var i = 0; i < 3; i++) {
          _wave(
            canvas,
            s,
            s * (0.32 + 0.18 * i),
            white.withValues(alpha: 1 - 0.28 * i),
          );
        }
    }
  }

  void _wave(Canvas canvas, double s, double y, Color color) {
    final path = Path()..moveTo(s * 0.1, y);
    for (var x = 0; x < 4; x++) {
      final x0 = s * (0.1 + 0.2 * x);
      path
        ..quadraticBezierTo(x0 + s * 0.05, y - s * 0.07, x0 + s * 0.1, y)
        ..quadraticBezierTo(x0 + s * 0.15, y + s * 0.07, x0 + s * 0.2, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.06
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ExercisePainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.white != white;
}

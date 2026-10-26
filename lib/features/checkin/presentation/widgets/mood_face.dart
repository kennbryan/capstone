import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';

/// Hand-drawn face features (eyes, mouth, cheeks) for a mood from 1 to 5.
/// Soft and friendly at every level: even "very heavy" is tired, not
/// distressed. The round face itself is drawn by the parent.
class MoodFace extends StatelessWidget {
  const new({
    required this.mood,
    required this.color,
    this.size = AppSizes.moodFace,
    super.key,
  });

  /// Mood from 1 (very heavy) to 5 (very good).
  final int mood;

  /// Color of the features.
  final Color color;

  /// Width and height.
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _MoodFacePainter(mood, color)),
  );
}

class _MoodFacePainter extends CustomPainter {
  const new(this.mood, this.color);

  final int mood;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, s * 0.075)
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color;
    final left = Offset(s * 0.33, s * 0.4);
    final right = Offset(s * 0.67, s * 0.4);

    // Eyes.
    switch (mood) {
      case 1:
        // Tired, lowered lids.
        for (final eye in [left, right]) {
          canvas.drawArc(
            Rect.fromCenter(center: eye, width: s * 0.17, height: s * 0.12),
            0,
            math.pi,
            false,
            line,
          );
        }
      case 5:
        // Smiling, closed eyes.
        for (final eye in [left, right]) {
          canvas.drawArc(
            Rect.fromCenter(
              center: eye + Offset(0, s * 0.03),
              width: s * 0.17,
              height: s * 0.14,
            ),
            math.pi,
            math.pi,
            false,
            line,
          );
        }
      default:
        for (final eye in [left, right]) {
          canvas.drawCircle(eye, s * 0.055, fill);
        }
    }

    // Mouth: curvature from gentle frown (1) to wide smile (5).
    final curve = switch (mood) {
      1 => -0.08,
      2 => -0.05,
      3 => 0.0,
      4 => 0.09,
      _ => 0.14,
    };
    final width = mood == 5 ? 0.38 : 0.3;
    final y = s * (mood <= 2 ? 0.7 : 0.64);
    final mouth = Path()
      ..moveTo(s * (0.5 - width / 2), y)
      ..quadraticBezierTo(s * 0.5, y + s * curve * 2, s * (0.5 + width / 2), y);
    canvas.drawPath(mouth, line);

    // Soft cheeks on the happiest face.
    if (mood == 5) {
      final cheek = Paint()..color = color.withValues(alpha: 0.3);
      canvas
        ..drawCircle(Offset(s * 0.2, s * 0.58), s * 0.07, cheek)
        ..drawCircle(Offset(s * 0.8, s * 0.58), s * 0.07, cheek);
    }
  }

  @override
  bool shouldRepaint(_MoodFacePainter oldDelegate) =>
      oldDelegate.mood != mood || oldDelegate.color != color;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/sketch.dart';

/// Part of the day, used to pick the greeting card's small sky drawing.
enum DayPart {
  /// 04:00–10:59, rising sun.
  pagi,

  /// 11:00–14:59, high sun.
  siang,

  /// 15:00–17:59, low warm sun.
  sore,

  /// 18:00–03:59, moon and stars.
  malam;

  /// Part of the day for [time].
  static DayPart of(DateTime time) => switch (time.hour) {
    >= 4 && < 11 => pagi,
    >= 11 && < 15 => siang,
    >= 15 && < 18 => sore,
    _ => malam,
  };
}

/// Small decorative sky for the greeting card on the brand color: a sun
/// with a cloud during the day, a moon with stars at night.
class DaySky extends StatelessWidget {
  const new({required this.part, this.size = AppSizes.daySky, super.key});

  /// Which sky to draw.
  final DayPart part;

  /// Width and height.
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SkyPainter(
          part: part,
          sun: context.gradients.sun,
          white: context.gradients.onBrand,
        ),
      ),
    ),
  );
}

class _SkyPainter extends CustomPainter {
  const new({required this.part, required this.sun, required this.white});

  final DayPart part;
  final Color sun;
  final Color white;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawCircle(
      Offset(s * 0.5, s * 0.5),
      s * 0.5,
      Paint()..color = white.withValues(alpha: 0.12),
    );
    switch (part) {
      case DayPart.malam:
        _moon(canvas, s);
      case DayPart.pagi:
        _sun(canvas, Offset(s * 0.42, s * 0.56), s * 0.17);
        _cloud(canvas, Offset(s * 0.62, s * 0.66), s);
      case DayPart.siang:
        _sun(canvas, Offset(s * 0.5, s * 0.4), s * 0.19);
        _cloud(canvas, Offset(s * 0.38, s * 0.7), s);
      case DayPart.sore:
        _sun(canvas, Offset(s * 0.5, s * 0.66), s * 0.2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(s * 0.18, s * 0.74, s * 0.64, s * 0.07),
            Radius.circular(s * 0.04),
          ),
          Paint()..color = white.withValues(alpha: 0.5),
        );
    }
  }

  void _sun(Canvas canvas, Offset c, double r) {
    final rays = Paint()
      ..color = sun.withValues(alpha: 0.8)
      ..strokeWidth = r * 0.18
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * r * 1.35, c + dir * r * 1.7, rays);
    }
    canvas.drawCircle(c, r, Paint()..color = sun);
  }

  void _cloud(Canvas canvas, Offset c, double s) {
    final paint = Paint()..color = white.withValues(alpha: 0.92);
    canvas
      ..drawCircle(c + Offset(-s * 0.09, 0), s * 0.08, paint)
      ..drawCircle(c + Offset(s * 0.02, -s * 0.04), s * 0.1, paint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(c.dx - s * 0.17, c.dy - s * 0.01, s * 0.34, s * 0.09),
          Radius.circular(s * 0.045),
        ),
        paint,
      );
  }

  void _moon(Canvas canvas, double s) {
    final c = Offset(s * 0.48, s * 0.5);
    final r = s * 0.2;
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Path()..addOval(
        Rect.fromCircle(center: c + Offset(r * 0.55, -r * 0.35), radius: r),
      ),
    );
    canvas
      ..drawPath(moon, Paint()..color = sun)
      ..sparkle(Offset(s * 0.74, s * 0.32), s * 0.06, white)
      ..sparkle(
        Offset(s * 0.7, s * 0.7),
        s * 0.04,
        white.withValues(alpha: 0.8),
      )
      ..sparkle(Offset(s * 0.26, s * 0.24), s * 0.035, white);
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) =>
      oldDelegate.part != part || oldDelegate.sun != sun;
}

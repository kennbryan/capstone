import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/sketch.dart';

/// Draws the plant for a [growth] value from 0 to 4:
/// seed → sprout → small plant → leafy plant with a bud → in flower.
/// It only ever grows; there is no wilted state.
class GardenPainter extends CustomPainter {
  const new({
    required this.growth,
    required this.plant,
    required this.soil,
    required this.bloom,
  });

  final double growth;
  final Color plant;
  final Color soil;
  final Color bloom;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ground = h * 0.84;
    final light = Color.lerp(plant, bloom, 0.25)!.withValues(alpha: 0.75);
    final vein = soil.withValues(alpha: 0.25);

    // Soil mound with two grass tufts.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, ground + h * 0.02),
        width: w * 0.72,
        height: h * 0.16,
      ),
      Paint()..color = soil.withValues(alpha: 0.3),
    );
    for (final x in [0.24, 0.76]) {
      final base = Offset(w * x, ground + h * 0.01);
      canvas
        ..leaf(base, h * 0.07, -math.pi * 0.62, light)
        ..leaf(base, h * 0.06, -math.pi * 0.38, light);
    }

    final stem = Paint()
      ..color = plant
      ..strokeWidth = math.max(2, w * 0.024)
      ..strokeCap = StrokeCap.round;

    // Stage 1: a seed with a tiny curl.
    final seedRise = growth.clamp(0.0, 1.0);
    if (growth < 1) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w / 2, ground - h * 0.02),
          width: w * 0.12,
          height: h * 0.08,
        ),
        Paint()..color = Color.lerp(soil, bloom, 0.4)!,
      );
      final curl = Path()
        ..moveTo(w / 2, ground - h * 0.06)
        ..quadraticBezierTo(
          w / 2 - w * 0.04,
          ground - h * (0.12 + 0.06 * seedRise),
          w / 2 + w * 0.02,
          ground - h * (0.14 + 0.08 * seedRise),
        );
      canvas.drawPath(curl, stem..style = PaintingStyle.stroke);
      return;
    }

    // From the sprout on: the stem rises with each stage.
    final g = math.min<double>(growth, 4);
    final stemHeight = h * (0.18 + 0.13 * (g - 1));
    final top = Offset(w / 2, ground - stemHeight);
    final path = Path()
      ..moveTo(w / 2, ground)
      ..quadraticBezierTo(
        w / 2 + w * 0.03,
        ground - stemHeight * 0.5,
        top.dx,
        top.dy,
      );
    canvas.drawPath(path, stem..style = PaintingStyle.stroke);

    // Leaf pairs: one at the sprout, then one more per stage.
    final pairs = g.floor().clamp(1, 3);
    for (var i = 0; i < pairs; i++) {
      final y = ground - stemHeight * (0.28 + 0.24 * i);
      final length = h * (0.17 - 0.025 * i) * (i == pairs - 1 ? 0.9 : 1);
      canvas
        ..leaf(
          Offset(w / 2, y),
          length,
          -math.pi * 0.86,
          i.isEven ? plant : light,
          vein: vein,
        )
        ..leaf(
          Offset(w / 2, y - h * 0.035),
          length,
          -math.pi * 0.14,
          i.isEven ? light : plant,
          vein: vein,
        );
    }

    if (g < 3) {
      // Young tip.
      canvas.leaf(top, h * 0.08, -math.pi * 0.5, light);
      return;
    }

    // Stage 4: a closed bud. Stage 5: the bud opens into a warm flower.
    final open = (g - 3).clamp(0.0, 1.0);
    final petal = h * (0.04 + 0.03 * open);
    final petalPaint = Paint()..color = Color.lerp(light, bloom, open)!;
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 - math.pi / 2;
      canvas.drawCircle(
        top + Offset(math.cos(angle), math.sin(angle)) * petal * 1.15 * open,
        petal,
        petalPaint,
      );
    }
    canvas.drawCircle(
      top,
      petal * (0.6 + 0.2 * open),
      Paint()..color = open > 0 ? plant : light,
    );
  }

  @override
  bool shouldRepaint(GardenPainter oldDelegate) =>
      oldDelegate.growth != growth ||
      oldDelegate.plant != plant ||
      oldDelegate.soil != soil ||
      oldDelegate.bloom != bloom;
}

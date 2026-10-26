import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/illustration_palette.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/sketch.dart';

/// Base class: paints a scene with an [IllustrationPalette].
abstract class ScenePainter extends CustomPainter {
  const new(this.p);

  /// Colors for this scene.
  final IllustrationPalette p;

  @override
  bool shouldRepaint(ScenePainter oldDelegate) => oldDelegate.p != p;
}

/// Onboarding 1: a person resting beside a growing plant, under a warm sun.
class CompanionScene extends ScenePainter {
  const new(super.p);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final u = math.min(w, h);
    canvas
      ..blob(Offset(w * 0.5, h * 0.52), u * 0.44, p.backdrop)
      ..drawCircle(Offset(w * 0.74, h * 0.2), u * 0.08, Paint()..color = p.warm)
      ..drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.86),
          width: u * 0.8,
          height: u * 0.08,
        ),
        Paint()..color = p.leafSoft.withValues(alpha: 0.35),
      )
      ..person(Offset(w * 0.38, h * 0.86), u * 0.46, p.leaf, p.warm);

    // Plant in a pot on the right.
    final pot = Rect.fromCenter(
      center: Offset(w * 0.66, h * 0.79),
      width: u * 0.18,
      height: u * 0.15,
    );
    final stemBase = Offset(pot.center.dx, pot.top);
    canvas
      ..stroke([stemBase, stemBase - Offset(0, u * 0.3)], p.leaf, u * 0.018)
      ..leaf(
        stemBase - Offset(0, u * 0.08),
        u * 0.14,
        -math.pi * 0.9,
        p.leafSoft,
      )
      ..leaf(stemBase - Offset(0, u * 0.15), u * 0.15, -math.pi * 0.12, p.leaf)
      ..leaf(stemBase - Offset(0, u * 0.23), u * 0.12, -math.pi * 0.85, p.leaf)
      ..leaf(
        stemBase - Offset(0, u * 0.3),
        u * 0.1,
        -math.pi * 0.35,
        p.leafSoft,
      )
      ..soft(pot, u * 0.04, p.paper)
      ..heart(Offset(w * 0.4, h * 0.3), u * 0.045, p.warm)
      ..sparkle(Offset(w * 0.2, h * 0.36), u * 0.035, p.leafSoft)
      ..sparkle(Offset(w * 0.86, h * 0.48), u * 0.03, p.leafSoft);
  }
}

/// Onboarding 2: the AI assistant (cool, rounded screen face) and a person
/// (green), each with their own speech bubble.
class AiAndHumanScene extends ScenePainter {
  const new(super.p);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final u = math.min(w, h);
    canvas
      ..blob(Offset(w * 0.5, h * 0.55), u * 0.44, p.backdrop, phase: 1.2)
      ..drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.88),
          width: u * 0.86,
          height: u * 0.07,
        ),
        Paint()..color = p.leafSoft.withValues(alpha: 0.3),
      );

    // Assistant: rounded body with a screen face and a leaf antenna.
    final botX = w * 0.3;
    final body = Rect.fromCenter(
      center: Offset(botX, h * 0.77),
      width: u * 0.22,
      height: u * 0.2,
    );
    final head = Rect.fromCenter(
      center: Offset(botX, h * 0.56),
      width: u * 0.26,
      height: u * 0.21,
    );
    canvas
      ..soft(body, u * 0.07, p.cool)
      ..stroke(
        [head.topCenter, head.topCenter - Offset(0, u * 0.06)],
        p.coolStrong,
        u * 0.014,
      )
      ..leaf(
        head.topCenter - Offset(0, u * 0.06),
        u * 0.07,
        -math.pi * 0.3,
        p.leafSoft,
      )
      ..soft(head, u * 0.07, p.coolStrong)
      ..soft(head.deflate(u * 0.035), u * 0.045, p.paper);
    for (final dx in [-0.045, 0.045]) {
      canvas.drawCircle(
        head.center + Offset(u * dx, -u * 0.005),
        u * 0.016,
        Paint()..color = p.coolStrong,
      );
    }

    canvas
      ..person(Offset(w * 0.7, h * 0.88), u * 0.44, p.leaf, p.warm)
      ..bubble(Rect.fromLTWH(w * 0.1, h * 0.12, u * 0.3, u * 0.17), p.cool)
      ..textLines(
        Rect.fromLTWH(
          w * 0.1 + u * 0.05,
          h * 0.12 + u * 0.045,
          u * 0.2,
          u * 0.08,
        ),
        2,
        p.coolStrong.withValues(alpha: 0.6),
      )
      ..bubble(
        Rect.fromLTWH(w * 0.58, h * 0.1, u * 0.28, u * 0.16),
        p.paper,
        tailRight: true,
      )
      ..heart(
        Offset(w * 0.58 + u * 0.14, h * 0.1 + u * 0.085),
        u * 0.04,
        p.warm,
      );
  }
}

/// Onboarding 3: a phone showing a heart with calm "call" waves around it.
class HelpScene extends ScenePainter {
  const new(super.p);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final u = math.min(w, h);
    final c = Offset(w * 0.5, h * 0.52);
    canvas.blob(c, u * 0.44, p.backdrop, phase: 2.4);

    final waves = Paint()
      ..color = p.leaf.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.02
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i <= 2; i++) {
      final r = u * (0.2 + 0.08 * i);
      for (final start in [-math.pi * 0.28, math.pi - math.pi * 0.22]) {
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          start,
          math.pi * 0.5,
          false,
          waves,
        );
      }
    }

    final phone = Rect.fromCenter(center: c, width: u * 0.28, height: u * 0.46);
    canvas
      ..soft(phone, u * 0.05, p.leaf)
      ..soft(phone.deflate(u * 0.022), u * 0.035, p.paper)
      ..heart(c - Offset(0, u * 0.03), u * 0.07, p.warm)
      ..soft(
        Rect.fromCenter(
          center: c + Offset(0, u * 0.13),
          width: u * 0.14,
          height: u * 0.04,
        ),
        u * 0.02,
        p.leafSoft,
      )
      ..sparkle(Offset(w * 0.2, h * 0.22), u * 0.035, p.warm)
      ..sparkle(Offset(w * 0.82, h * 0.78), u * 0.03, p.leafSoft);
  }
}

/// A plant in a pot under the sun, for headers (login, splash).
class GrowthScene extends ScenePainter {
  const new(super.p);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final u = math.min(w, h);
    final pot = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.82),
      width: u * 0.34,
      height: u * 0.26,
    );
    final base = Offset(pot.center.dx, pot.top);
    canvas
      ..blob(Offset(w * 0.5, h * 0.5), u * 0.46, p.backdrop)
      ..drawCircle(Offset(w * 0.76, h * 0.22), u * 0.1, Paint()..color = p.warm)
      ..stroke([base, base - Offset(0, u * 0.42)], p.leaf, u * 0.03)
      ..leaf(base - Offset(0, u * 0.1), u * 0.24, -math.pi * 0.88, p.leafSoft)
      ..leaf(base - Offset(0, u * 0.2), u * 0.25, -math.pi * 0.1, p.leaf)
      ..leaf(base - Offset(0, u * 0.32), u * 0.2, -math.pi * 0.86, p.leaf)
      ..leaf(base - Offset(0, u * 0.42), u * 0.16, -math.pi * 0.35, p.leafSoft)
      ..soft(pot, u * 0.06, p.paper)
      ..sparkle(Offset(w * 0.2, h * 0.3), u * 0.05, p.paper);
  }
}

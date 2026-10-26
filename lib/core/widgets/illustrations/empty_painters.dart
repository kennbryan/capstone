import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/scene_painters.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/sketch.dart';

/// No assessment yet: a blank clipboard with a sprout beside it.
class NoReportScene extends ScenePainter {
  const new(super.p);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final u = math.min(w, h);
    final board = Rect.fromCenter(
      center: Offset(w * 0.47, h * 0.55),
      width: u * 0.5,
      height: u * 0.66,
    );
    canvas
      ..blob(Offset(w * 0.5, h * 0.52), u * 0.48, p.backdrop)
      ..soft(board, u * 0.06, p.paper)
      ..soft(
        Rect.fromCenter(
          center: board.topCenter + Offset(0, u * 0.02),
          width: u * 0.2,
          height: u * 0.08,
        ),
        u * 0.03,
        p.leaf,
      )
      ..textLines(
        Rect.fromLTWH(
          board.left + u * 0.08,
          board.top + u * 0.14,
          board.width - u * 0.16,
          u * 0.3,
        ),
        4,
        p.line.withValues(alpha: 0.35),
      )
      ..sprout(Offset(w * 0.8, h * 0.9), u * 0.24, p.leaf, p.leaf)
      ..sparkle(Offset(w * 0.18, h * 0.24), u * 0.04, p.warm);
  }
}

/// No check-ins yet: a week card with seven empty, friendly dots.
class NoCheckinsScene extends ScenePainter {
  const new(super.p);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final u = math.min(w, h);
    final card = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.56),
      width: u * 0.84,
      height: u * 0.5,
    );
    canvas
      ..blob(Offset(w * 0.5, h * 0.5), u * 0.48, p.backdrop, phase: 0.7)
      ..soft(card, u * 0.07, p.paper)
      ..soft(
        Rect.fromLTWH(card.left, card.top, card.width, u * 0.12),
        u * 0.07,
        p.leafSoft,
      );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.016
      ..color = p.line.withValues(alpha: 0.45);
    for (var i = 0; i < 7; i++) {
      final x = card.left + card.width * (i + 0.5) / 7;
      canvas.drawCircle(Offset(x, card.center.dy + u * 0.07), u * 0.035, ring);
    }
    canvas.sprout(Offset(w * 0.86, h * 0.95), u * 0.22, p.leaf, p.leaf);
  }
}

/// New conversation: an assistant bubble with dots and a reply bubble.
class EmptyChatScene extends ScenePainter {
  const new(super.p);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final u = math.min(w, h);
    final left = Rect.fromLTWH(w * 0.14, h * 0.18, u * 0.6, u * 0.3);
    canvas
      ..blob(Offset(w * 0.5, h * 0.52), u * 0.48, p.backdrop, phase: 1.9)
      ..bubble(left, p.cool);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        left.center + Offset(u * (i - 1) * 0.11, 0),
        u * 0.035,
        Paint()..color = p.coolStrong,
      );
    }
    final right = Rect.fromLTWH(w * 0.86 - u * 0.5, h * 0.6, u * 0.5, u * 0.24);
    canvas
      ..bubble(right, p.paper, tailRight: true)
      ..textLines(right.deflate(u * 0.06), 2, p.line.withValues(alpha: 0.35))
      ..sparkle(Offset(w * 0.86, h * 0.2), u * 0.04, p.warm);
  }
}

/// Psychologist not available yet: a warm cup of tea and a clock.
class AwayScene extends ScenePainter {
  const new(super.p);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final u = math.min(w, h);
    final clock = Offset(w * 0.68, h * 0.34);
    canvas
      ..blob(Offset(w * 0.5, h * 0.54), u * 0.48, p.backdrop, phase: 3.1)
      ..drawCircle(clock, u * 0.17, Paint()..color = p.paper)
      ..stroke([clock, clock - Offset(0, u * 0.1)], p.leaf, u * 0.025)
      ..stroke([clock, clock + Offset(u * 0.07, u * 0.03)], p.leaf, u * 0.025);

    final cup = Rect.fromLTWH(w * 0.2, h * 0.58, u * 0.34, u * 0.28);
    final handle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.03
      ..color = p.paper;
    canvas
      ..drawArc(
        Rect.fromCircle(center: cup.centerRight, radius: u * 0.07),
        -math.pi / 2,
        math.pi,
        false,
        handle,
      )
      ..soft(cup, u * 0.08, p.paper)
      ..soft(
        Rect.fromLTWH(
          cup.left + u * 0.04,
          cup.top + u * 0.04,
          cup.width - u * 0.08,
          u * 0.06,
        ),
        u * 0.03,
        p.warm,
      );
    for (var i = 0; i < 2; i++) {
      final x = cup.left + cup.width * (0.35 + 0.3 * i);
      canvas.stroke(
        [
          Offset(x, cup.top - u * 0.04),
          Offset(x + u * 0.03, cup.top - u * 0.1),
          Offset(x, cup.top - u * 0.16),
        ],
        p.line.withValues(alpha: 0.4),
        u * 0.02,
      );
    }
  }
}

/// Something went wrong / offline: a soft cloud with gentle drops.
class OfflineScene extends ScenePainter {
  const new(super.p);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final u = math.min(w, h);
    final c = Offset(w * 0.5, h * 0.44);
    canvas
      ..blob(Offset(w * 0.5, h * 0.52), u * 0.48, p.backdrop, phase: 0.4)
      ..drawCircle(
        c + Offset(-u * 0.16, u * 0.04),
        u * 0.13,
        Paint()..color = p.paper,
      )
      ..drawCircle(
        c + Offset(u * 0.02, -u * 0.04),
        u * 0.18,
        Paint()..color = p.paper,
      )
      ..drawCircle(
        c + Offset(u * 0.2, u * 0.05),
        u * 0.12,
        Paint()..color = p.paper,
      )
      ..soft(
        Rect.fromLTWH(c.dx - u * 0.28, c.dy + u * 0.02, u * 0.6, u * 0.15),
        u * 0.075,
        p.paper,
      );
    for (var i = 0; i < 3; i++) {
      canvas.stroke(
        [
          c + Offset(u * (i - 1) * 0.14, u * 0.26),
          c + Offset(u * (i - 1) * 0.14 - u * 0.02, u * 0.33),
        ],
        p.leafSoft,
        u * 0.03,
      );
    }
    canvas.sprout(Offset(w * 0.18, h * 0.95), u * 0.2, p.leaf, p.leaf);
  }
}

/// Default calm empty state: a sprout and a couple of twinkles.
class CalmScene extends ScenePainter {
  const new(super.p);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final u = math.min(w, h);
    canvas
      ..blob(Offset(w * 0.5, h * 0.52), u * 0.44, p.backdrop, phase: 2)
      ..drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.8),
          width: u * 0.5,
          height: u * 0.1,
        ),
        Paint()..color = p.leafSoft.withValues(alpha: 0.5),
      )
      ..sprout(Offset(w * 0.5, h * 0.8), u * 0.42, p.leaf, p.leaf)
      ..sparkle(Offset(w * 0.25, h * 0.3), u * 0.05, p.warm)
      ..sparkle(Offset(w * 0.76, h * 0.42), u * 0.035, p.leafSoft);
  }
}

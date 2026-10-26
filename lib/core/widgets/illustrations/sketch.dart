import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Small drawing helpers shared by the illustration painters. Every shape
/// is soft and rounded; sizes are given relative to the scene size `s`.
extension Sketch on Canvas {
  /// Organic blob around [center]: a circle whose radius wobbles gently.
  void blob(
    Offset center,
    double radius,
    Color color, {
    double wobble = 0.08,
    double phase = 0,
  }) {
    const points = 48;
    final path = Path();
    for (var i = 0; i <= points; i++) {
      final a = i / points * math.pi * 2;
      final r =
          radius *
          (1 +
              wobble * math.sin(a * 3 + phase) +
              wobble * 0.5 * math.cos(a * 2 - phase));
      final p = center + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    drawPath(path..close(), Paint()..color = color);
  }

  /// Pointed leaf from [base] towards [angle] (radians, 0 = right).
  void leaf(
    Offset base,
    double length,
    double angle,
    Color color, {
    Color? vein,
  }) {
    save();
    translate(base.dx, base.dy);
    rotate(angle);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(length * 0.45, -length * 0.42, length, 0)
      ..quadraticBezierTo(length * 0.45, length * 0.42, 0, 0)
      ..close();
    drawPath(path, Paint()..color = color);
    if (vein != null) {
      drawLine(
        Offset(length * 0.12, 0),
        Offset(length * 0.8, 0),
        Paint()
          ..color = vein
          ..strokeWidth = math.max(1, length * 0.05)
          ..strokeCap = StrokeCap.round,
      );
    }
    restore();
  }

  /// Rounded rectangle filled with [color].
  void soft(Rect rect, double radius, Color color) => drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(radius)),
    Paint()..color = color,
  );

  /// Speech bubble with a small tail at the bottom-left or bottom-right.
  void bubble(Rect rect, Color color, {bool tailRight = false}) {
    soft(rect, rect.height * 0.35, color);
    final x = tailRight
        ? rect.right - rect.width * 0.22
        : rect.left + rect.width * 0.22;
    final dir = tailRight ? 1.0 : -1.0;
    final tail = Path()
      ..moveTo(x - rect.height * 0.12, rect.bottom - 1)
      ..lineTo(x + dir * rect.height * 0.18, rect.bottom + rect.height * 0.28)
      ..lineTo(x + rect.height * 0.12, rect.bottom - 1)
      ..close();
    drawPath(tail, Paint()..color = color);
  }

  /// Short rounded strokes standing in for lines of text.
  void textLines(Rect area, int count, Color color, {double gap = 1.9}) {
    final h = area.height / (count * gap);
    final paint = Paint()
      ..color = color
      ..strokeWidth = h
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final y = area.top + h / 2 + i * h * gap;
      final end = area.right - (i.isOdd ? area.width * 0.3 : 0);
      drawLine(Offset(area.left + h / 2, y), Offset(end - h / 2, y), paint);
    }
  }

  /// Abstract seated person: round head and a soft rounded body.
  void person(Offset feet, double height, Color body, Color head) {
    final w = height * 0.62;
    final bodyRect = Rect.fromLTWH(
      feet.dx - w / 2,
      feet.dy - height * 0.62,
      w,
      height * 0.62,
    );
    drawRRect(
      RRect.fromRectAndCorners(
        bodyRect,
        topLeft: Radius.circular(w * 0.5),
        topRight: Radius.circular(w * 0.5),
        bottomLeft: Radius.circular(w * 0.12),
        bottomRight: Radius.circular(w * 0.12),
      ),
      Paint()..color = body,
    );
    drawCircle(
      Offset(feet.dx, feet.dy - height * 0.8),
      height * 0.2,
      Paint()..color = head,
    );
  }

  /// Four-point twinkle.
  void sparkle(Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    drawPath(path, Paint()..color = color);
  }

  /// Simple heart centered at [c].
  void heart(Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r * 0.9)
      ..cubicTo(
        c.dx - r * 1.6,
        c.dy - r * 0.2,
        c.dx - r * 0.6,
        c.dy - r * 1.3,
        c.dx,
        c.dy - r * 0.4,
      )
      ..cubicTo(
        c.dx + r * 0.6,
        c.dy - r * 1.3,
        c.dx + r * 1.6,
        c.dy - r * 0.2,
        c.dx,
        c.dy + r * 0.9,
      )
      ..close();
    drawPath(path, Paint()..color = color);
  }

  /// Small sprout (two leaves on a short stem) growing up from [base].
  void sprout(Offset base, double height, Color leafColor, Color stem) {
    drawLine(
      base,
      base - Offset(0, height),
      Paint()
        ..color = stem
        ..strokeWidth = math.max(1.5, height * 0.08)
        ..strokeCap = StrokeCap.round,
    );
    final top = base - Offset(0, height);
    leaf(top, height * 0.7, -math.pi * 0.85, leafColor);
    leaf(top, height * 0.75, -math.pi * 0.15, leafColor);
  }

  /// Rounded stroke helper.
  void stroke(List<Offset> points, Color color, double width) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }
}

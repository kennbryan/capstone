import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/theme/app_typography.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// MSU logo.
///
/// Uses `assets/images/msu_logo.png` when it is bundled. Until DKMSU
/// provides the official file, a simple placeholder mark is drawn instead
/// (a dome on a brand-gradient badge with "MSU").
// TODO(DKMSU): add the official logo as assets/images/msu_logo.png.
class MsuLogo extends StatelessWidget {
  const new({this.size = AppSizes.logo, this.onBrand = false, super.key});

  static const asset = 'assets/images/msu_logo.png';

  final double size;

  /// Draws the placeholder for use on a brand-gradient background.
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: context.l10n.logoLabel,
      child: SizedBox.square(
        dimension: size,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (context, _, _) =>
              _PlaceholderMark(size: size, onBrand: onBrand),
        ),
      ),
    );
  }
}

class _PlaceholderMark extends StatelessWidget {
  const new({required this.size, required this.onBrand});

  final double size;
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final gradients = context.gradients;
    final radius = BorderRadius.circular(size * 0.3);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: onBrand ? null : gradients.brand,
        color: onBrand ? gradients.onBrand.withValues(alpha: 0.16) : null,
        border: onBrand
            ? Border.all(color: gradients.onBrand.withValues(alpha: 0.35))
            : null,
      ),
      child: CustomPaint(
        painter: _DomePainter(
          color: gradients.onBrand,
          showText: size >= AppSizes.avatarLg,
        ),
      ),
    );
  }
}

/// The bare placeholder mark (no badge) in [color]. Used to generate the
/// launcher icon and launch splash (`tool/generate_icons.dart`).
class MsuLogoMark extends StatelessWidget {
  const new({required this.color, this.showText = true, super.key});

  final Color color;
  final bool showText;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DomePainter(color: color, showText: showText),
    child: const SizedBox.expand(),
  );
}

/// A dome with a spire and two minarets, plus "MSU" for larger sizes.
class _DomePainter extends CustomPainter {
  const new({required this.color, required this.showText});

  final Color color;
  final bool showText;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = color;
    final top = showText ? 0.16 : 0.2;
    final ground = showText ? 0.6 : 0.74;
    final scaleY = ground - top;

    double y(double t) => h * (top + scaleY * t);

    // Own layer so the door cut-out only clears the mark, not the badge.
    canvas.saveLayer(Offset.zero & size, Paint());

    // Minarets.
    for (final x in [0.2, 0.8]) {
      canvas
        ..drawRRect(
          RRect.fromLTRBR(
            w * (x - 0.035),
            y(0.25),
            w * (x + 0.035),
            y(1),
            Radius.circular(w * 0.02),
          ),
          paint,
        )
        ..drawCircle(Offset(w * x, y(0.2)), w * 0.035, paint);
    }

    // Dome body and cupola.
    final body = Rect.fromLTRB(w * 0.32, y(0.55), w * 0.68, y(1));
    canvas
      ..drawRect(body, paint)
      ..drawArc(
        Rect.fromCenter(
          center: Offset(w * 0.5, y(0.56)),
          width: w * 0.36,
          height: h * scaleY * 0.7,
        ),
        math.pi,
        math.pi,
        true,
        paint,
      )
      ..drawLine(
        Offset(w * 0.5, y(0.2)),
        Offset(w * 0.5, y(0.05)),
        paint
          ..strokeWidth = w * 0.025
          ..strokeCap = StrokeCap.round,
      )
      ..drawCircle(Offset(w * 0.5, y(0.02)), w * 0.022, paint);

    // Door, cut out of the body.
    final door = Path()
      ..addRRect(
        RRect.fromLTRBAndCorners(
          w * 0.45,
          y(0.75),
          w * 0.55,
          y(1),
          topLeft: Radius.circular(w * 0.05),
          topRight: Radius.circular(w * 0.05),
        ),
      );
    canvas
      ..drawPath(door, Paint()..blendMode = BlendMode.clear)
      // Ground line.
      ..drawRRect(
        RRect.fromLTRBR(
          w * 0.12,
          y(1),
          w * 0.88,
          y(1) + h * 0.035,
          Radius.circular(h * 0.02),
        ),
        paint,
      )
      ..restore();

    if (showText) {
      final text = TextPainter(
        text: TextSpan(
          text: 'MSU',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: h * 0.17,
            letterSpacing: h * 0.02,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset((w - text.width) / 2, h * 0.68));
    }
  }

  @override
  bool shouldRepaint(_DomePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.showText != showText;
}

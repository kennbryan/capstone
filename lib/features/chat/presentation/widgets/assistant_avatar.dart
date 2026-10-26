import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';

/// Avatar for "Asisten MSU": a rounded screen face with a small leaf
/// antenna, in the cool AI color. Clearly an assistant, never a person, so
/// it cannot be confused with the psychologist channel.
class AssistantAvatar extends StatelessWidget {
  const new({this.size = AppSizes.avatar, super.key});

  /// Width and height.
  final double size;

  @override
  Widget build(BuildContext context) {
    final gradients = context.gradients;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _AvatarPainter(
            body: gradients.ai.colors.first,
            face: gradients.onBrand,
            leaf: context.appColors.assistant,
          ),
        ),
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  const new({required this.body, required this.face, required this.leaf});

  final Color body;
  final Color face;
  final Color leaf;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Offset.zero & size;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(s * 0.32)),
        Paint()..color = body,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.2, s * 0.3, s * 0.6, s * 0.46),
          Radius.circular(s * 0.16),
        ),
        Paint()..color = face,
      );

    // Leaf antenna.
    final stem = Paint()
      ..color = face
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s * 0.5, s * 0.3), Offset(s * 0.5, s * 0.16), stem);
    final leafPath = Path()
      ..moveTo(s * 0.5, s * 0.17)
      ..quadraticBezierTo(s * 0.58, s * 0.04, s * 0.72, s * 0.08)
      ..quadraticBezierTo(s * 0.66, s * 0.2, s * 0.5, s * 0.17)
      ..close();
    canvas.drawPath(leafPath, Paint()..color = leaf);

    // Eyes and a small smile.
    final features = Paint()..color = body;
    canvas
      ..drawCircle(Offset(s * 0.39, s * 0.5), s * 0.055, features)
      ..drawCircle(Offset(s * 0.61, s * 0.5), s * 0.055, features)
      ..drawArc(
        Rect.fromCenter(
          center: Offset(s * 0.5, s * 0.58),
          width: s * 0.2,
          height: s * 0.12,
        ),
        0.3,
        2.5,
        false,
        Paint()
          ..color = body
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.045
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_AvatarPainter oldDelegate) =>
      oldDelegate.body != body || oldDelegate.face != face;
}

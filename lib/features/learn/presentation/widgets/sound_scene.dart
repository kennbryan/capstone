import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/features/learn/presentation/controllers/sounds_controller.dart';

/// Little scene for a calm sound: rain from a cloud, a small forest, or
/// waves. Moves gently while [playing], unless reduce motion is on.
class SoundScene extends StatefulWidget {
  const new({required this.track, required this.playing, super.key});

  /// Which sound.
  final SoundTrack track;

  /// Animate while the sound plays.
  final bool playing;

  @override
  State<SoundScene> createState() => _SoundSceneState();
}

class _SoundSceneState extends State<SoundScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  void _sync() {
    final animate = widget.playing && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!animate) {
      _controller.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SoundScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final background = switch (widget.track) {
      SoundTrack.hujan => colors.assistant,
      SoundTrack.hutan => scheme.primaryContainer,
      SoundTrack.ombak => Color.lerp(
        colors.assistant,
        scheme.primaryContainer,
        0.5,
      )!,
    };
    final ink = switch (widget.track) {
      SoundTrack.hujan => context.gradients.ai.colors.first,
      _ => scheme.primary,
    };
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: SizedBox.square(
          dimension: AppSizes.soundScene,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _SoundPainter(
                track: widget.track,
                t: _controller.value,
                background: background,
                ink: ink,
                paper: colors.surfaceCard,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SoundPainter extends CustomPainter {
  const new({
    required this.track,
    required this.t,
    required this.background,
    required this.ink,
    required this.paper,
  });

  final SoundTrack track;
  final double t;
  final Color background;
  final Color ink;
  final Color paper;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    switch (track) {
      case SoundTrack.hujan:
        final drop = Paint()
          ..color = ink.withValues(alpha: 0.7)
          ..strokeWidth = s * 0.04
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 4; i++) {
          final y = s * (0.55 + ((t + i * 0.27) % 1) * 0.35);
          final x = s * (0.28 + 0.15 * i);
          canvas.drawLine(
            Offset(x, y),
            Offset(x - s * 0.03, y + s * 0.08),
            drop,
          );
        }
        final c = Offset(s * 0.5, s * 0.36);
        final cloud = Paint()..color = paper;
        canvas
          ..drawCircle(c + Offset(-s * 0.12, s * 0.03), s * 0.12, cloud)
          ..drawCircle(c + Offset(s * 0.04, -s * 0.03), s * 0.15, cloud)
          ..drawCircle(c + Offset(s * 0.17, s * 0.04), s * 0.1, cloud);
      case SoundTrack.hutan:
        final sway = math.sin(t * math.pi * 2) * 0.04;
        for (final (x, h) in [(0.3, 0.42), (0.55, 0.55), (0.78, 0.38)]) {
          final base = Offset(s * x, s * 0.86);
          canvas
            ..drawLine(
              base,
              base - Offset(0, s * h * 0.4),
              Paint()
                ..color = ink
                ..strokeWidth = s * 0.04
                ..strokeCap = StrokeCap.round,
            )
            ..drawPath(
              Path()
                ..moveTo(base.dx - s * 0.13, base.dy - s * h * 0.3)
                ..lineTo(base.dx + s * sway, base.dy - s * h - s * 0.1)
                ..lineTo(base.dx + s * 0.13, base.dy - s * h * 0.3)
                ..close(),
              Paint()..color = ink.withValues(alpha: x == 0.55 ? 1 : 0.7),
            );
        }
      case SoundTrack.ombak:
        for (var i = 0; i < 3; i++) {
          final y = s * (0.4 + 0.18 * i);
          final shift = (t + i * 0.2) * s * 0.4;
          final path = Path()..moveTo(-s * 0.4 + shift % (s * 0.4), y);
          for (var k = 0; k < 6; k++) {
            final x0 = -s * 0.4 + shift % (s * 0.4) + k * s * 0.2;
            path
              ..quadraticBezierTo(x0 + s * 0.05, y - s * 0.07, x0 + s * 0.1, y)
              ..quadraticBezierTo(x0 + s * 0.15, y + s * 0.07, x0 + s * 0.2, y);
          }
          canvas.drawPath(
            path,
            Paint()
              ..color = ink.withValues(alpha: 1 - 0.25 * i)
              ..style = PaintingStyle.stroke
              ..strokeWidth = s * 0.05
              ..strokeCap = StrokeCap.round,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_SoundPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.track != track ||
      oldDelegate.background != background;
}

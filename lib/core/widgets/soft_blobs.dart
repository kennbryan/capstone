import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/sketch.dart';

/// Calm background of three organic shapes for the exercise screens. They
/// drift slowly once when the screen opens, then rest (no endless loop, to
/// save battery). Still under reduce motion.
class SoftBlobs extends StatefulWidget {
  const new({super.key});

  @override
  State<SoftBlobs> createState() => _SoftBlobsState();
}

class _SoftBlobsState extends State<SoftBlobs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.ambient,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (_controller.isDismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = [
      scheme.primaryContainer.withValues(alpha: 0.7),
      context.appColors.assistant.withValues(alpha: 0.7),
      context.gradients.sun.withValues(alpha: 0.18),
    ];
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _BlobsPainter(
                Curves.easeInOutSine.transform(_controller.value) * 0.35,
                colors,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class _BlobsPainter extends CustomPainter {
  const new(this.t, this.colors);

  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const tau = 6.283185307179586;
    final phase = t * tau;
    canvas
      ..blob(
        Offset(w * 0.1, h * 0.12),
        w * 0.5,
        colors[0],
        wobble: 0.1,
        phase: phase,
      )
      ..blob(
        Offset(w * 0.95, h * 0.55),
        w * 0.42,
        colors[1],
        wobble: 0.12,
        phase: -phase + 1,
      )
      ..blob(
        Offset(w * 0.25, h * 1.02),
        w * 0.45,
        colors[2],
        wobble: 0.1,
        phase: phase + 2,
      );
  }

  @override
  bool shouldRepaint(_BlobsPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.colors != colors;
}

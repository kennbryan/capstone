import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';

/// Full-screen brand gradient with soft decorative circles and light
/// status-bar icons. Used by splash and lock screens.
class BrandBackground extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gradients = context.gradients;
    final circle = gradients.onBrand.withValues(alpha: 0.08);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradients.brand),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -AppSizes.heroBubble,
              left: -AppSizes.heroBubble / 2,
              child: _Circle(size: AppSizes.heroBubble * 2.2, color: circle),
            ),
            Positioned(
              bottom: -AppSizes.heroBubble,
              right: -AppSizes.heroBubble / 1.5,
              child: _Circle(size: AppSizes.heroBubble * 2, color: circle),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const new({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

/// Fades and gently scales [child] in once. Static under reduce motion.
class FadeInUp extends StatelessWidget {
  const new({required this.child, this.delay = Duration.zero, super.key});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppDurations.long + delay,
      curve: Interval(
        delay.inMilliseconds / (AppDurations.long + delay).inMilliseconds,
        1,
        curve: AppDurations.curve,
      ),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, AppSpacing.lg * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

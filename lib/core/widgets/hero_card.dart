import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';

/// Solid brand card with soft decorative circles, for hero content. Flat:
/// no shadow, per the design system.
class HeroCard extends StatelessWidget {
  const new({
    required this.child,
    this.gradient,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.radius = AppRadius.hero,
    this.onTap,
    super.key,
  });

  final Widget child;

  /// Defaults to the brand gradient.
  final Gradient? gradient;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gradients = context.gradients;
    final fill = gradient ?? gradients.brand;
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: fill, borderRadius: borderRadius),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned(
                  top: -AppSizes.heroBubble / 2,
                  right: -AppSizes.heroBubble / 3,
                  child: _Bubble(
                    size: AppSizes.heroBubble,
                    color: gradients.onBrand.withValues(alpha: 0.10),
                  ),
                ),
                Positioned(
                  bottom: -AppSizes.heroBubble / 2.5,
                  right: AppSizes.heroBubble / 2,
                  child: _Bubble(
                    size: AppSizes.heroBubble / 1.6,
                    color: gradients.onBrand.withValues(alpha: 0.07),
                  ),
                ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
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

/// Rounded square with a solid brand fill and a white icon.
class GradientIconBadge extends StatelessWidget {
  const new({
    required this.icon,
    this.gradient,
    this.size = AppSizes.tileIcon,
    super.key,
  });

  final IconData icon;
  final Gradient? gradient;
  final double size;

  @override
  Widget build(BuildContext context) {
    final gradients = context.gradients;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient ?? gradients.brand,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: gradients.onBrand, size: size * 0.55),
    );
  }
}

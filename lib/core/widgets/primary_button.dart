import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';

/// Full-width filled button with an optional icon and busy state.
class PrimaryButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Shows a progress indicator and disables the button.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final child = busy
        ? SizedBox.square(
            dimension: AppSizes.iconSm,
            child: CircularProgressIndicator(
              strokeWidth: AppSizes.borderStrong,
              color: onPrimary,
            ),
          )
        : Text(label);
    return SizedBox(
      width: double.infinity,
      child: icon == null || busy
          ? FilledButton(onPressed: busy ? null : onPressed, child: child)
          : FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: child,
            ),
    );
  }
}

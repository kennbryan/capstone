import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:msu_wellbeing/core/router/app_routes.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Global entry point to the crisis screen, shown in every main tab's
/// app bar. Calm styling: it uses the primary color, not crisis red.
class HelpButton extends StatelessWidget {
  const new({this.onBrand = false, super.key});

  /// White styling for use on a brand-gradient header.
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Tooltip(
      message: l10n.helpButtonTooltip,
      child: TextButton.icon(
        style: onBrand
            ? TextButton.styleFrom(foregroundColor: context.gradients.onBrand)
            : null,
        onPressed: () => context.push(AppRoutes.crisis),
        icon: const Icon(Icons.support_outlined),
        label: Text(l10n.helpButton),
      ),
    );
  }
}

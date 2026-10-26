import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/brand_background.dart';
import 'package:msu_wellbeing/core/widgets/msu_logo.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Shown while startup state resolves (at most 1.5 s, see the router).
class SplashScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final onBrand = context.gradients.onBrand;
    return Scaffold(
      body: BrandBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: FadeInUp(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MsuLogo(onBrand: true),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    l10n.appTitle,
                    style: textTheme.headlineMedium?.copyWith(color: onBrand),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.splashTagline,
                    style: textTheme.bodyMedium?.copyWith(
                      color: onBrand.withValues(alpha: 0.85),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

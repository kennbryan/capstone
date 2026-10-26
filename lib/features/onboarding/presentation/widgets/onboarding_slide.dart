import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/brand_background.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/illustration.dart';

/// One intro slide: illustration, title, and body text.
class OnboardingSlide extends StatelessWidget {
  const new({
    required this.illustration,
    required this.title,
    required this.body,
    super.key,
  });

  final IllustrationKind illustration;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screen,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        children: [
          FadeInUp(child: Illustration(illustration)),
          const SizedBox(height: AppSpacing.xl),
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            body,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Page position dots.
class PageDots extends StatelessWidget {
  const new({
    required this.count,
    required this.index,
    required this.semanticLabel,
    super.key,
  });

  final int count;
  final int index;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: reduceMotion ? Duration.zero : AppDurations.short,
                curve: AppDurations.curve,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                width: i == index ? AppSizes.pageDotActive : AppSizes.pageDot,
                height: AppSizes.pageDot,
                decoration: BoxDecoration(
                  color: i == index ? scheme.primary : scheme.outline,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

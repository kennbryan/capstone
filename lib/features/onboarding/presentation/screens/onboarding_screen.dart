import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/illustration.dart';
import 'package:msu_wellbeing/core/widgets/primary_button.dart';
import 'package:msu_wellbeing/features/onboarding/presentation/controllers/onboarding_controllers.dart';
import 'package:msu_wellbeing/features/onboarding/presentation/widgets/onboarding_slide.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Three intro slides shown on first run. Completing them lets the router
/// move on to the consent screen.
class OnboardingScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _count = 3;
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() => ref.read(onboardingControllerProvider.notifier).complete();

  void _next() {
    if (_index == _count - 1) {
      _finish();
      return;
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _controller.jumpToPage(_index + 1);
    } else {
      _controller.nextPage(
        duration: AppDurations.medium,
        curve: AppDurations.curve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final slides = [
      OnboardingSlide(
        illustration: IllustrationKind.companion,
        title: l10n.onboarding1Title,
        body: l10n.onboarding1Body,
      ),
      OnboardingSlide(
        illustration: IllustrationKind.aiAndHuman,
        title: l10n.onboarding2Title,
        body: l10n.onboarding2Body,
      ),
      OnboardingSlide(
        illustration: IllustrationKind.help,
        title: l10n.onboarding3Title,
        body: l10n.onboarding3Body,
      ),
    ];
    final isLast = _index == _count - 1;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (!isLast)
            TextButton(onPressed: _finish, child: Text(l10n.onboardingSkip)),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) => setState(() => _index = index),
                children: slides,
              ),
            ),
            PageDots(
              count: _count,
              index: _index,
              semanticLabel: l10n.onboardingPage(_index + 1, _count),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: PrimaryButton(
                label: isLast ? l10n.onboardingStart : l10n.onboardingNext,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

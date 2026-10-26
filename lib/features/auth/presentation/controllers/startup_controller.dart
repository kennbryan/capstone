import 'dart:async';

import 'package:msu_wellbeing/core/router/route_guard.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/auth_controller.dart';
import 'package:msu_wellbeing/features/onboarding/presentation/controllers/onboarding_controllers.dart';
import 'package:msu_wellbeing/features/profile/presentation/controllers/settings_controllers.dart';
import 'package:msu_wellbeing/features/remote_config/presentation/controllers/remote_config_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'startup_controller.g.dart';

/// Flips to true once the splash screen has been visible for its maximum
/// time, so a slow config request never holds the user on the splash.
@Riverpod(keepAlive: true)
class SplashTimeout extends _$SplashTimeout {
  @override
  bool build() {
    final timer = Timer(AppDurations.splashMax, () => state = true);
    ref.onDispose(timer.cancel);
    return false;
  }
}

/// Combines session, onboarding, consent, and lock state for the router.
@Riverpod(keepAlive: true)
GateState gateState(Ref ref) {
  final auth = ref.watch(authControllerProvider);
  final consent = ref.watch(consentControllerProvider);
  final config = ref.watch(remoteConfigProvider);
  final lock = ref.watch(appLockControllerProvider);
  final timedOut = ref.watch(splashTimeoutProvider);

  bool settled(AsyncValue<Object?> value) => value.hasValue || value.hasError;

  final current = ref.watch(currentConsentProvider);
  final requiredVersion = config.value?.consentVersion ?? current?.version ?? 1;

  return GateState(
    ready:
        settled(auth) &&
        settled(consent) &&
        settled(lock) &&
        (settled(config) || timedOut),
    locked: lock.value?.locked ?? false,
    onboardingSeen: ref.watch(onboardingControllerProvider),
    consentValid: current?.isValidFor(requiredVersion) ?? false,
    authenticated: auth.value != null,
  );
}

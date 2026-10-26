import 'package:msu_wellbeing/core/router/app_routes.dart';

/// Snapshot of everything the startup redirect depends on.
class GateState {
  const new({
    required this.ready,
    required this.locked,
    required this.onboardingSeen,
    required this.consentValid,
    required this.authenticated,
  });

  /// Startup data has resolved (or the splash time limit passed).
  final bool ready;
  final bool locked;
  final bool onboardingSeen;
  final bool consentValid;
  final bool authenticated;
}

/// Redirect order: app lock → onboarding seen → consent given →
/// authenticated → requested route. Returns null to stay on [location].
///
/// The crisis screen is reachable from every state once startup is ready.
String? guardRedirect(GateState state, String location) {
  String? goTo(String target) => location == target ? null : target;

  if (!state.ready) return goTo(AppRoutes.splash);
  if (location == AppRoutes.crisis) return null;
  if (state.locked) return goTo(AppRoutes.lock);
  if (!state.onboardingSeen) return goTo(AppRoutes.onboarding);
  if (!state.consentValid) return goTo(AppRoutes.consent);
  if (!state.authenticated) return goTo(AppRoutes.login);
  if (AppRoutes.gates.contains(location)) return AppRoutes.home;
  return null;
}

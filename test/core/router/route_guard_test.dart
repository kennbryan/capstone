import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/router/app_routes.dart';
import 'package:msu_wellbeing/core/router/route_guard.dart';

GateState _state({
  bool ready = true,
  bool locked = false,
  bool onboardingSeen = true,
  bool consentValid = true,
  bool authenticated = true,
}) => GateState(
  ready: ready,
  locked: locked,
  onboardingSeen: onboardingSeen,
  consentValid: consentValid,
  authenticated: authenticated,
);

void main() {
  group('guardRedirect', () {
    test('holds on splash until ready', () {
      expect(guardRedirect(_state(ready: false), '/home'), AppRoutes.splash);
      expect(guardRedirect(_state(ready: false), AppRoutes.splash), isNull);
    });

    test('follows lock → onboarding → consent → login order', () {
      final everythingMissing = _state(
        locked: true,
        onboardingSeen: false,
        consentValid: false,
        authenticated: false,
      );
      expect(guardRedirect(everythingMissing, '/home'), AppRoutes.lock);
      expect(
        guardRedirect(
          _state(onboardingSeen: false, consentValid: false),
          '/home',
        ),
        AppRoutes.onboarding,
      );
      expect(
        guardRedirect(_state(consentValid: false, authenticated: false), '/'),
        AppRoutes.consent,
      );
      expect(guardRedirect(_state(authenticated: false), '/home'), '/login');
    });

    test('leaves gate screens once everything is satisfied', () {
      expect(guardRedirect(_state(), AppRoutes.login), AppRoutes.home);
      expect(guardRedirect(_state(), AppRoutes.splash), AppRoutes.home);
      expect(guardRedirect(_state(), '/learn/breathing'), isNull);
    });

    test('crisis screen is reachable before sign-in', () {
      final signedOut = _state(authenticated: false, consentValid: false);
      expect(guardRedirect(signedOut, AppRoutes.crisis), isNull);
    });
  });
}

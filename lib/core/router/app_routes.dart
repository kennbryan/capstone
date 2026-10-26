/// Route paths. Never put personal data in a path or query.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const consent = '/consent';
  static const login = '/login';
  static const lock = '/lock';
  static const crisis = '/crisis';

  static const home = '/home';
  static const reports = '/home/reports';
  static String report(String id) => '/home/reports/$id';

  static const chat = '/chat';
  static const chatAssistant = '/chat?tab=ai';
  static const chatPsychologist = '/chat?tab=psikolog';

  static const learn = '/learn';
  static String article(String id) => '/learn/article/$id';
  static const breathing = '/learn/breathing';
  static const release = '/learn/release';
  static const sounds = '/learn/sounds';

  static const profile = '/profile';
  static const privacy = '/profile/privacy';
  static const consentHistory = '/profile/consent-history';

  /// Startup gates handled by the router redirect.
  static const Set<String> gates = {splash, onboarding, consent, login, lock};
}

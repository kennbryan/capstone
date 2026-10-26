import 'package:msu_wellbeing/core/config/environment.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_config.g.dart';

/// Build-time configuration read from `--dart-define` values.
///
/// Never put real URLs, keys, or phone numbers in the defaults.
class AppConfig {
  const new({
    required this.apiBaseUrl,
    required this.environment,
    this.demoLogin = demoLoginEnabled,
    this._chatbotBaseUrl,
  });

  /// Reads `API_BASE_URL`, `CHATBOT_BASE_URL`, `APP_ENV`, and `DEMO_LOGIN`.
  factory fromEnvironment() => AppConfig(
    apiBaseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.example.invalid',
    ),
    chatbotBaseUrl: const String.fromEnvironment('CHATBOT_BASE_URL'),
    environment: Environment.parse(
      const String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
    ),
  );

  /// Compile-time `DEMO_LOGIN` (default on). With `DEMO_LOGIN=false` the
  /// demo accounts are off and the compiler strips them from the binary.
  static const demoLoginEnabled = bool.fromEnvironment(
    'DEMO_LOGIN',
    defaultValue: true,
  );

  final String apiBaseUrl;
  final Environment environment;
  final String? _chatbotBaseUrl;

  /// Base URL of the chatbot service (`/chatbot/*`). Falls back to
  /// [apiBaseUrl] when the backend serves the chatbot itself.
  String get chatbotBaseUrl {
    final url = _chatbotBaseUrl;
    return url == null || url.isEmpty ? apiBaseUrl : url;
  }

  /// Whether the demo accounts are on for this build.
  final bool demoLogin;

  /// Throws a [StateError] when the configuration is unsafe:
  /// - a plain `http://` base URL outside `dev`;
  /// - a `prod` build that still has the demo accounts on, or the
  ///   placeholder API address.
  void validate() {
    final uri = _checkUrl('API_BASE_URL', apiBaseUrl);
    _checkUrl('CHATBOT_BASE_URL', chatbotBaseUrl);
    if (environment.isProd) {
      if (demoLogin) {
        throw StateError('prod builds must use DEMO_LOGIN=false.');
      }
      if (uri.host.endsWith('.invalid')) {
        throw StateError('prod builds need a real API_BASE_URL.');
      }
    }
  }

  Uri _checkUrl(String name, String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('$name is not a valid absolute URL.');
    }
    if (uri.scheme != 'https' && !environment.isDev) {
      throw StateError('$name must use HTTPS outside dev.');
    }
    return uri;
  }
}

/// App-wide configuration. Override in tests.
@Riverpod(keepAlive: true)
AppConfig appConfig(Ref ref) => AppConfig.fromEnvironment();

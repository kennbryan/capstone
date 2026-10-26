import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/config/app_config.dart';
import 'package:msu_wellbeing/core/config/environment.dart';

AppConfig _config(String url, {required bool demo, required Environment env}) =>
    AppConfig(apiBaseUrl: url, environment: env, demoLogin: demo);

void main() {
  test('dev with demo accounts and the placeholder URL is allowed', () {
    expect(
      () => _config(
        'https://api.example.invalid',
        demo: true,
        env: Environment.dev,
      ).validate(),
      returnsNormally,
    );
  });

  test('http is rejected outside dev', () {
    expect(
      () => _config(
        'http://api.msu.example',
        demo: false,
        env: Environment.staging,
      ).validate(),
      throwsStateError,
    );
  });

  test('prod refuses the demo accounts', () {
    expect(
      () => _config(
        'https://api.msu.example',
        demo: true,
        env: Environment.prod,
      ).validate(),
      throwsStateError,
    );
  });

  test('prod refuses the placeholder API address', () {
    expect(
      () => _config(
        'https://api.example.invalid',
        demo: false,
        env: Environment.prod,
      ).validate(),
      throwsStateError,
    );
  });

  test('a real HTTPS prod config is accepted', () {
    expect(
      () => _config(
        'https://api.msu.example',
        demo: false,
        env: Environment.prod,
      ).validate(),
      returnsNormally,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/config/app_config.dart';
import 'package:msu_wellbeing/core/config/environment.dart';

AppConfig _config(
  String url, {
  required bool demo,
  required Environment env,
  String? supabaseUrl = 'https://auth.msu.example',
  String? supabaseKey = 'sb_publishable_test',
}) => AppConfig(
  apiBaseUrl: url,
  environment: env,
  demoLogin: demo,
  supabaseUrl: supabaseUrl,
  supabasePublishableKey: supabaseKey,
);

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

  test('prod needs a Supabase project', () {
    expect(
      () => _config(
        'https://api.msu.example',
        demo: false,
        env: Environment.prod,
        supabaseUrl: null,
        supabaseKey: null,
      ).validate(),
      throwsStateError,
    );
  });

  test('Supabase must use HTTPS, even in dev', () {
    expect(
      () => _config(
        'http://127.0.0.1:8002',
        demo: false,
        env: Environment.dev,
        supabaseUrl: 'http://auth.msu.example',
      ).validate(),
      throwsStateError,
    );
  });

  test('only a publishable key is accepted, never a secret key', () {
    for (final key in ['sb_secret_test', 'eyJhbGciOiJIUzI1NiJ9.e30.x', '']) {
      expect(
        () => _config(
          'https://api.msu.example',
          demo: false,
          env: Environment.staging,
          supabaseKey: key,
        ).validate(),
        throwsStateError,
      );
    }
  });
}

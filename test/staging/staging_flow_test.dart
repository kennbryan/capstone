// End-to-end check against Supabase staging and a running backend.
// Skipped unless the values below are passed; never put them in a file.
//
//   flutter test test/staging/staging_flow_test.dart
//     --dart-define=API_BASE_URL=http://127.0.0.1:8002
//     --dart-define=SUPABASE_URL=https://<ref>.supabase.co
//     --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
//     --dart-define=TESTER_A_EMAIL=... --dart-define=TESTER_B_EMAIL=...
//     --dart-define=TESTER_PASSWORD=...
@Tags(['staging'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/config/app_config.dart';
import 'package:msu_wellbeing/core/config/environment.dart';
import 'package:msu_wellbeing/core/network/api_exception.dart';
import 'package:msu_wellbeing/core/network/dio_client.dart';
import 'package:msu_wellbeing/core/network/session_source.dart';
import 'package:msu_wellbeing/core/utils/date_formatter.dart';
import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/auth/data/auth_repository_impl.dart';
import 'package:msu_wellbeing/features/auth/data/sources/auth_source.dart';
import 'package:msu_wellbeing/features/checkin/data/checkin_repository_impl.dart';
import 'package:msu_wellbeing/features/checkin/data/sources/checkin_sources.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/in_memory_secure_storage.dart';

const _api = String.fromEnvironment('API_BASE_URL');
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _emailA = String.fromEnvironment('TESTER_A_EMAIL');
const _emailB = String.fromEnvironment('TESTER_B_EMAIL');
const _password = String.fromEnvironment('TESTER_PASSWORD');

/// The app's own stack (session, interceptor, repositories) on one
/// Supabase client, like `main.dart` wires it.
class _App {
  new() {
    session = SupabaseSessionSource(auth);
    final dio = createDio(
      config: const AppConfig(
        apiBaseUrl: _api,
        environment: Environment.dev,
        demoLogin: false,
      ),
      authInterceptor: (dio) => AuthInterceptor(
        readToken: session.current,
        refresh: session.refresh,
        retry: dio.fetch,
        onUnauthorized: () => expired++,
      ),
    );
    authRepo = AuthRepositoryImpl(AuthRemoteSource(dio, session), storage);
    checkIns = CheckInRepositoryImpl(CheckInRemoteSource(dio));
  }

  final auth = GoTrueClient(
    url: '$_supabaseUrl/auth/v1',
    headers: {'apikey': _key},
    autoRefreshToken: false,
  );
  final storage = InMemorySecureStorage();
  late final SupabaseSessionSource session;
  late final AuthRepositoryImpl authRepo;
  late final CheckInRepositoryImpl checkIns;
  int expired = 0;
}

void main() {
  final configured = [
    _api,
    _supabaseUrl,
    _key,
    _emailA,
    _emailB,
    _password,
  ].every((v) => v.isNotEmpty);
  final today = DateFormatter.dateOnly(DateTime.now());

  test(
    'login, check-in, refresh, restore, and account switch on staging',
    () async {
      final app = _App();

      // 1. Wrong password: a clear "wrong password", nothing stored.
      final wrong = await app.authRepo.login(
        email: _emailA,
        password: 'salah-$_password',
      );
      expect((wrong as Failure).error.kind, ApiExceptionKind.unauthorized);
      expect(await app.session.current(), isNull);

      // 2. Login A: Supabase, then /me with the new token.
      final userA = (await app.authRepo.login(
        email: _emailA,
        password: _password,
      )).unwrap();
      expect(userA.email, _emailA);
      final tokenA = (await app.session.current())!;
      expect(tokenA.userId, userA.id);

      // 3. Save, read back, replace the same day, clear the note.
      final first = (await app.checkIns.save(
        date: today,
        mood: 4,
        note: 'uji staging 🌿',
      )).unwrap();
      expect(first.note, 'uji staging 🌿');
      final replaced = (await app.checkIns.save(date: today, mood: 2)).unwrap();
      expect(replaced.id, first.id);
      expect(replaced.mood, 2);
      expect(replaced.note, isNull);
      final readBack = (await app.checkIns.getCheckIns(
        from: today,
        to: today,
      )).unwrap();
      expect(readBack.single.id, first.id);
      expect(readBack.single.mood, 2);

      // 4. Refresh: a new access token for the same user still works.
      final refreshed = (await app.session.refresh())!;
      expect(refreshed.accessToken, isNot(tokenA.accessToken));
      expect(refreshed.userId, userA.id);
      expect(
        (await app.checkIns.getCheckIns(from: today, to: today)).isSuccess,
        isTrue,
      );

      // 5. A rejected token is refreshed once and the request retried.
      final beforeRetry = (await app.session.current())!.accessToken;
      final corrupt = Session.fromJson({
        ...app.auth.currentSession!.toJson(),
        'access_token': '${beforeRetry}x',
      })!;
      await app.auth.recoverSession(jsonEncode(corrupt.toJson()));
      final afterRetry = await app.checkIns.getCheckIns(from: today, to: today);
      expect(afterRetry.isSuccess, isTrue);
      expect(app.expired, 0);

      // 6. Reopening the app restores the session from storage.
      final persisted = jsonEncode(app.auth.currentSession!.toJson());
      final reopened = _App();
      await reopened.auth.setInitialSession(persisted);
      await reopened.storage.write(
        'auth.user',
        await app.storage.read('auth.user') ?? '',
      );
      final restored = (await reopened.authRepo.restoreSession()).unwrap();
      expect(restored?.id, userA.id);

      // 7. Logout A, login B: no session or data of A remains.
      await app.authRepo.logout();
      expect(await app.session.current(), isNull);
      expect(app.storage.values, isEmpty);
      final userB = (await app.authRepo.login(
        email: _emailB,
        password: _password,
      )).unwrap();
      expect(userB.id, isNot(userA.id));
      final weekOfB = (await app.checkIns.getCheckIns(
        from: today.subtract(const Duration(days: 6)),
        to: today,
      )).unwrap();
      expect(weekOfB.map((c) => c.id), isNot(contains(first.id)));
      expect(app.expired, 0);
      await app.authRepo.logout();
    },
    skip: configured ? false : 'Pass the staging --dart-define values.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

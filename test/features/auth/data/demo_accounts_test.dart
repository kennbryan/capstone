import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/network/api_exception.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';
import 'package:msu_wellbeing/features/auth/data/auth_repository_impl.dart';
import 'package:msu_wellbeing/features/auth/data/sources/demo_accounts.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/in_memory_secure_storage.dart';

void main() {
  test('there are five demo accounts with unique ids and emails', () {
    expect(demoAccounts, hasLength(5));
    expect(demoAccounts.map((a) => a.id).toSet(), hasLength(5));
    expect(demoAccounts.map((a) => a.email).toSet(), hasLength(5));
  });

  test('every demo account signs in on the device', () async {
    final storage = InMemorySecureStorage();
    final repo = AuthRepositoryImpl(
      const FakeAuthSource(),
      storage,
      demoLogin: true,
    );
    for (final account in demoAccounts) {
      final user = (await repo.login(
        email: account.email.toUpperCase(),
        password: demoPassword,
      )).unwrap();
      expect(user.id, account.id);
      expect(user.isDemo, isTrue);
      expect(isDemoToken(storage.values[SecureKeys.accessToken]!), isTrue);
    }
  });

  test('a demo session is restored without calling the backend', () async {
    final storage = InMemorySecureStorage();
    final repo = AuthRepositoryImpl(
      const FakeAuthSource(),
      storage,
      demoLogin: true,
    );
    await repo.login(email: 'rani@msu.demo', password: demoPassword);
    final restored = (await repo.restoreSession()).unwrap();
    expect(restored?.displayName, 'Rani');
  });

  test('wrong passwords and other accounts go to the backend (401)', () async {
    final repo = AuthRepositoryImpl(
      const FakeAuthSource(),
      InMemorySecureStorage(),
      demoLogin: true,
    );
    for (final (email, password) in [
      ('rani@msu.demo', 'salah'),
      ('orang@lain.com', demoPassword),
    ]) {
      final result = await repo.login(email: email, password: password);
      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.kind),
        ApiExceptionKind.unauthorized,
      );
    }
  });

  test('with demo login off, demo accounts are not accepted', () async {
    final repo = AuthRepositoryImpl(
      const FakeAuthSource(),
      InMemorySecureStorage(),
    );
    final result = await repo.login(
      email: 'rani@msu.demo',
      password: demoPassword,
    );
    expect(
      result.fold(onSuccess: (_) => null, onFailure: (e) => e.kind),
      ApiExceptionKind.unauthorized,
    );
  });
}

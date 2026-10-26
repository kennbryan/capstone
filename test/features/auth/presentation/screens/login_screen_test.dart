import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';
import 'package:msu_wellbeing/features/auth/data/sources/demo_accounts.dart';

import '../../../../helpers/pump_app.dart';

/// Onboarding seen and consent given, but not signed in.
Future<TestDeps> _signedOut() async {
  final deps = await TestDeps.create(prefs: {'onboarding.seen': true});
  deps.secureStorage.values[SecureKeys.consentHistory] =
      '[{"version":1,"grantedScopes":["processData"],'
      '"grantedAt":"2026-01-01T00:00:00.000Z"}]';
  return deps;
}

void main() {
  testWidgets('shows the login form with the website link', (tester) async {
    await pumpApp(tester, await _signedOut());

    expect(
      find.text('Gunakan akun yang sama dengan website asesmen MSU.'),
      findsOneWidget,
    );
    expect(
      find.text('Belum punya akun? Daftar di website asesmen'),
      findsOneWidget,
    );
    expect(find.text('Bantuan'), findsOneWidget);
  });

  testWidgets('empty fields show validation messages', (tester) async {
    await pumpApp(tester, await _signedOut());

    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Email wajib diisi.'), findsOneWidget);
    expect(find.text('Kata sandi wajib diisi.'), findsOneWidget);
  });

  testWidgets('a wrong password is rejected with a calm message', (
    tester,
  ) async {
    final deps = await _signedOut();
    await pumpApp(tester, deps);

    await tester.enterText(find.byType(TextFormField).at(0), 'rani@msu.demo');
    await tester.enterText(find.byType(TextFormField).at(1), 'salah');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Email atau kata sandi belum sesuai.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(deps.secureStorage.values[SecureKeys.accessToken], isNull);
  });

  testWidgets('a demo account signs in and stores the token', (tester) async {
    final deps = await _signedOut();
    await pumpApp(tester, deps);

    await tester.enterText(find.byType(TextFormField).at(0), 'rani@msu.demo');
    await tester.enterText(find.byType(TextFormField).at(1), demoPassword);
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Halo, Rani'), findsOneWidget);
    expect(deps.secureStorage.values[SecureKeys.accessToken], isNotNull);
    expect(deps.prefs.themeMode, isNull, reason: 'token not in prefs');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/features/auth/data/sources/demo_accounts.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('first run: onboarding → consent → login → home', (tester) async {
    final deps = await TestDeps.create();
    await pumpApp(tester, deps);

    expect(find.text('Pendamping kesejahteraan dirimu'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Bantuan selalu ada'), findsOneWidget);
    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();

    expect(find.text('Persetujuan data'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Setuju dan lanjutkan'), 200);
    await tester.tap(
      find.text('Proses data saya agar aplikasi bisa digunakan'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setuju dan lanjutkan'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'rani@msu.demo');
    await tester.enterText(find.byType(TextFormField).at(1), demoPassword);
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(deps.prefs.onboardingSeen, isTrue);
  });

  testWidgets('returning user lands on the shell with four tabs', (
    tester,
  ) async {
    await pumpApp(tester, await TestDeps.signedIn());

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['Beranda', 'Chat', 'Belajar', 'Profil']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Bantuan'), findsOneWidget);
  });

  testWidgets('tabs keep their state when switching', (tester) async {
    await pumpApp(tester, await TestDeps.signedIn());

    await tester.tap(find.text('Chat').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Psikolog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beranda').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat').last);
    await tester.pumpAndSettle();

    expect(find.text('Layanan psikolog MSU'), findsOneWidget);
  });
}

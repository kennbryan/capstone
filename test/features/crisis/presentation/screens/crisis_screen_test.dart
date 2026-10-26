import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:msu_wellbeing/core/utils/link_launcher.dart';
import 'package:msu_wellbeing/features/crisis/presentation/screens/crisis_screen.dart';

import '../../../../helpers/fakes.dart';
import '../../../../helpers/pump_app.dart';

class _MockLauncher extends Mock implements LinkLauncher;

void main() {
  testWidgets('crisis screen shows heading, contacts, and actions', (
    tester,
  ) async {
    final launcher = _MockLauncher();
    when(() => launcher.dial(any())).thenAnswer((_) async => true);
    final deps = await TestDeps.signedIn(
      mockSettings: const MockSettings(instant: true, whatsappDummy: true),
    );
    await pumpScreen(
      tester,
      const CrisisScreen(),
      deps,
      overrides: [linkLauncherProvider.overrideWithValue(launcher)],
    );

    expect(find.text('Kamu tidak sendirian.'), findsOneWidget);
    expect(find.text('Healing119 (Kemenkes)'), findsOneWidget);
    expect(find.text('Darurat umum'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Latihan napas sekarang'), 200);
    expect(find.text('Hubungi psikolog MSU'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Darurat umum'), -200);
    await tester.tap(find.text('Darurat umum'));
    await tester.pumpAndSettle();
    verify(() => launcher.dial('112')).called(1);
  });

  testWidgets('psychologist button is hidden without a WhatsApp number', (
    tester,
  ) async {
    await pumpScreen(tester, const CrisisScreen(), await TestDeps.signedIn());

    await tester.scrollUntilVisible(find.textContaining('belum tersedia'), 200);
    expect(find.text('Hubungi psikolog MSU'), findsNothing);
  });

  testWidgets('"Bantuan" opens the crisis screen from every main tab', (
    tester,
  ) async {
    await pumpApp(tester, await TestDeps.signedIn());

    for (final tab in ['Beranda', 'Chat', 'Belajar', 'Profil']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bantuan'));
      await tester.pumpAndSettle();
      expect(find.text('Kamu tidak sendirian.'), findsOneWidget, reason: tab);

      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget, reason: tab);
    }
  });
}

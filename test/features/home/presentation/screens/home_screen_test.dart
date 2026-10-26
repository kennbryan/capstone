import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fakes.dart';
import '../../../../helpers/pump_app.dart';

/// The Beranda page list (the note field is scrollable too).
final Finder _page = find.byType(Scrollable).first;

/// Scrolls [finder] toward the middle of the page so taps are not covered
/// by the navigation bar.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 120, scrollable: _page);
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

void main() {
  setUp(CheckInMockSource.reset);

  testWidgets('shows greeting, check-in, latest report, and actions', (
    tester,
  ) async {
    await pumpApp(tester, await TestDeps.signedIn());

    expect(find.text('Halo, Rani'), findsOneWidget);
    expect(find.text('Bagaimana perasaanmu hari ini?'), findsOneWidget);
    expect(find.text('Langkah kecil hari ini'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('7 hari terakhir'),
      120,
      scrollable: _page,
    );

    await tester.scrollUntilVisible(
      find.text('Rapor Kesejahteraan Diri — Oktober'),
      200,
      scrollable: _page,
    );
    expect(find.text('Lihat detail'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Cerita ke Asisten'),
      200,
      scrollable: _page,
    );
    expect(find.text('Hubungi Psikolog'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Mungkin bermanfaat'),
      200,
      scrollable: _page,
    );
  });

  testWidgets('empty report state invites the user to the website', (
    tester,
  ) async {
    final deps = await TestDeps.signedIn(
      mockSettings: const MockSettings(
        instant: true,
        reports: MockScenario.empty,
      ),
    );
    await pumpApp(tester, deps);

    await tester.scrollUntilVisible(
      find.text('Kamu belum mengikuti asesmen'),
      200,
      scrollable: _page,
    );
    expect(find.text('Mulai asesmen di website'), findsOneWidget);
  });

  testWidgets('error state offers a retry', (tester) async {
    final deps = await TestDeps.signedIn(
      mockSettings: const MockSettings(
        instant: true,
        reports: MockScenario.error,
      ),
    );
    await pumpApp(tester, deps);

    await tester.scrollUntilVisible(
      find.text('Ada kendala'),
      200,
      scrollable: _page,
    );
    expect(find.text('Coba lagi'), findsWidgets);
  });

  testWidgets('one tap saves the check-in and adapts the suggestion', (
    tester,
  ) async {
    await pumpApp(tester, await TestDeps.signedIn());

    expect(find.text('Mulai harimu dengan tenang'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Kurang baik'));
    await tester.pumpAndSettle();

    expect(find.text('Hari ini: Kurang baik'), findsOneWidget);
    expect(find.text('Terima kasih sudah check-in hari ini'), findsOneWidget);
    expect(find.text('Hari ini terasa berat'), findsOneWidget);
    expect(find.text('Hubungi psikolog'), findsOneWidget);

    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Sangat baik'));
    await tester.pumpAndSettle();
    expect(find.text('Senang mendengarnya'), findsOneWidget);
  });

  testWidgets('a note can be added after checking in', (tester) async {
    await pumpApp(tester, await TestDeps.signedIn());

    await tester.tap(find.bySemanticsLabel('Baik'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah catatan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'tidur cukup');
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Ubah catatan'), findsOneWidget);
  });

  testWidgets('report detail shows sections and the non-diagnosis footer', (
    tester,
  ) async {
    await pumpApp(tester, await TestDeps.signedIn());

    await _reveal(tester, find.text('Lihat detail'));
    await tester.tap(find.text('Lihat detail'));
    await tester.pumpAndSettle();

    expect(find.text('Tuntutan akademik'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Hasil ini bukan diagnosis'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('lays out at 1.3× text in ${brightness.name} mode', (
      tester,
    ) async {
      tester.platformDispatcher
        ..textScaleFactorTestValue = 1.3
        ..platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await pumpApp(tester, await TestDeps.signedIn());
      for (final tab in ['Chat', 'Belajar', 'Profil', 'Beranda']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}

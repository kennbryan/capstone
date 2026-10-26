// Captures documentation screenshots of the main screens on mock data.
//
// Run:
//   flutter test --update-goldens tool/screenshots/capture_screens_test.dart
//
// PNGs are written to docs/screenshots/. Not part of the CI test suite.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';

import '../../test/helpers/fakes.dart';
import '../../test/helpers/pump_app.dart';

const _out = '../../docs/screenshots';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Loads real fonts so text renders instead of test boxes.
Future<void> _loadFonts() async {
  final material =
      '${Platform.environment['FLUTTER_ROOT']}'
      '/bin/cache/artifacts/material_fonts';
  await _loadFont('PlusJakartaSans', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/PlusJakartaSans-$w.ttf',
  ]);
  await _loadFont('MaterialIcons', ['$material/materialicons-regular.otf']);
  await _loadFont('Roboto', [
    for (final w in ['regular', 'medium', 'bold']) '$material/roboto-$w.ttf',
  ]);
}

void _phone(WidgetTester tester, {Brightness brightness = Brightness.light}) {
  tester.view
    ..physicalSize = const Size(1080, 2340)
    ..devicePixelRatio = 3;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

Future<void> _shot(String name) async {
  await expectLater(
    find.byType(MaterialApp).first,
    matchesGoldenFile('$_out/$name.png'),
  );
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(
  WidgetTester tester,
  Finder finder, {
  double at = 0,
}) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: at);
  await tester.pumpAndSettle();
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.byTooltip('Kirim'));
  await tester.pumpAndSettle();
}

/// A signed-in user whose garden has grown a few stages.
Future<TestDeps> _user({
  MockSettings mock = const MockSettings(instant: true),
}) async {
  final deps = await TestDeps.create(
    prefs: {'onboarding.seen': true, 'learn.garden_sessions': 7},
    mockSettings: mock,
  );
  deps.secureStorage.values.addAll({
    SecureKeys.accessToken: 'mock-access-token',
    SecureKeys.user:
        '{"id":"usr_demo","displayName":"Rani","email":"rani@example.com"}',
    SecureKeys.consentHistory:
        '[{"version":1,"grantedScopes":["processData"],'
        '"grantedAt":"2026-10-01T08:00:00.000Z"},'
        '{"version":1,"grantedScopes":["processData","personalizeWithReport"],'
        '"grantedAt":"2026-10-12T19:30:00.000Z"}]',
  });
  return deps;
}

void main() {
  setUpAll(_loadFonts);
  setUp(() {
    ChatMockSource.reset();
    CheckInMockSource.reset();
  });

  testWidgets('01 auth & onboarding', (tester) async {
    _phone(tester);
    await pumpApp(tester, await TestDeps.create());
    await _shot('02_onboarding_1');
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await _shot('03_onboarding_2');
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await _shot('04_onboarding_3');
    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();
    await _shot('05_consent');
    await tester.tap(
      find.text('Proses data saya agar aplikasi bisa digunakan'),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Setuju dan lanjutkan'), at: 0.7);
    await _shot('06_consent_bottom');
    await tester.tap(find.text('Setuju dan lanjutkan'));
    await tester.pumpAndSettle();
    await _shot('07_login');
  });

  testWidgets('01b lock', (tester) async {
    _phone(tester);
    final deps = await _user();
    deps.secureStorage.values[SecureKeys.appLockEnabled] = 'true';
    deps.appLock.authenticateResult = false;
    await pumpApp(tester, deps);
    await _shot('08_lock');
  });

  testWidgets('02 beranda', (tester) async {
    _phone(tester);
    await pumpApp(tester, await _user());
    await _shot('10_home_top');
    await tester.tap(find.bySemanticsLabel('Baik'));
    await tester.pumpAndSettle();
    await _shot('11_home_checked_in');
    await _scrollTo(tester, find.text('7 hari terakhir'), at: 0.1);
    await _shot('12_home_report');
    await _scrollTo(tester, find.text('Mungkin bermanfaat'), at: 0.3);
    await _shot('13_home_actions');
    await _scrollTo(tester, find.text('Lihat detail'), at: 0.5);
    await tester.tap(find.text('Lihat detail'));
    await tester.pumpAndSettle();
    await _shot('14_report_detail');
  });

  testWidgets('03 beranda empty', (tester) async {
    _phone(tester);
    await pumpApp(
      tester,
      await _user(
        mock: const MockSettings(instant: true, reports: MockScenario.empty),
      ),
    );
    await _scrollTo(tester, find.text('Kamu belum mengikuti asesmen'), at: 0.4);
    await _shot('15_home_empty_report');
  });

  testWidgets('04 chat', (tester) async {
    _phone(tester);
    await pumpApp(
      tester,
      await _user(mock: const MockSettings(instant: true, whatsappDummy: true)),
    );
    await _tab(tester, 'Chat');
    await _shot('20_chat_empty');
    await _send(tester, 'Aku lagi stres kuliah');
    await _send(tester, 'Tugasku numpuk banget minggu ini');
    await _send(tester, 'Susah tidur akhir-akhir ini');
    await _shot('21_chat_conversation');
    await _send(tester, '#tes-krisis');
    await _shot('22_chat_crisis');
    await tester.tap(find.text('Psikolog'));
    await tester.pumpAndSettle();
    await _shot('23_chat_psychologist');
    await tester.tap(find.text('Chat via WhatsApp'));
    await tester.pumpAndSettle();
    await _shot('24_whatsapp_sheet');
  });

  testWidgets('05 belajar', (tester) async {
    _phone(tester);
    await pumpApp(tester, await _user());
    await _tab(tester, 'Belajar');
    await _shot('30_learn_top');
    await _scrollTo(tester, find.text('Kuliah'), at: 0.1);
    await _shot('31_learn_articles');
    await tester.tap(find.text('Mengelola stres akademik').first);
    await tester.pumpAndSettle();
    await _shot('32_article');
  });

  testWidgets('05b breathing', (tester) async {
    _phone(tester);
    await pumpApp(tester, await _user());
    await _tab(tester, 'Belajar');
    await tester.tap(find.text('Napas tenang'));
    await tester.pumpAndSettle();
    await _shot('33_breathing_setup');
    await tester.tap(find.text('1 menit'));
    await tester.pump();
    await tester.tap(find.text('Mulai'));
    await tester.pump(const Duration(milliseconds: 3800));
    await _shot('34_breathing_inhale');
    await tester.pump(const Duration(seconds: 58));
    await tester.pumpAndSettle();
    await _shot('35_breathing_done');
  });

  testWidgets('05c release', (tester) async {
    _phone(tester);
    await pumpApp(tester, await _user());
    await _tab(tester, 'Belajar');
    await tester.tap(find.text('Lepaskan pikiran'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Deadline laporan besok');
    await tester.pump();
    await _shot('36_release_input');
    await tester.tap(find.text('Lepaskan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    await _shot('37_release_floating');
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    await _shot('38_release_done');
  });

  testWidgets('05d sounds', (tester) async {
    _phone(tester);
    await pumpApp(tester, await _user());
    await _tab(tester, 'Belajar');
    await Scrollable.ensureVisible(tester.element(find.text('Suara tenang')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suara tenang'));
    await tester.pumpAndSettle();
    await _shot('39_sounds');
  });

  testWidgets('06 crisis', (tester) async {
    _phone(tester);
    await pumpApp(
      tester,
      await _user(mock: const MockSettings(instant: true, whatsappDummy: true)),
    );
    await tester.tap(find.text('Bantuan'));
    await tester.pumpAndSettle();
    await _shot('40_crisis');
  });

  testWidgets('07 profil', (tester) async {
    _phone(tester);
    await pumpApp(tester, await _user());
    await _tab(tester, 'Profil');
    await _shot('50_profile');
    await tester.tap(find.text('Privasi & izin'));
    await tester.pumpAndSettle();
    await _shot('51_privacy');
    await tester.tap(find.textContaining('Riwayat persetujuan').first);
    await tester.pumpAndSettle();
    await _shot('52_consent_history');
  });

  testWidgets('08 dark mode', (tester) async {
    _phone(tester, brightness: Brightness.dark);
    await pumpApp(tester, await _user());
    await _shot('60_dark_home');
    await _tab(tester, 'Chat');
    await _send(tester, 'Aku lagi stres kuliah');
    await _shot('61_dark_chat');
    await _tab(tester, 'Belajar');
    await _shot('62_dark_learn');
  });
}

// UI check of the handover's acceptance criteria on a device, against
// Supabase staging and a running backend. Nothing secret lives here:
//
//   flutter test integration_test/staging_ui_test.dart -d <device>
//     --dart-define=APP_ENV=dev --dart-define=DEMO_LOGIN=false
//     --dart-define=API_BASE_URL=http://127.0.0.1:8002
//     --dart-define=SUPABASE_URL=https://<ref>.supabase.co
//     --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
//     --dart-define=TESTER_A_EMAIL=... --dart-define=TESTER_B_EMAIL=...
//     --dart-define=TESTER_PASSWORD=...
//
// On Android, run `adb reverse tcp:8002 tcp:8002` first.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:msu_wellbeing/core/utils/date_formatter.dart';
import 'package:msu_wellbeing/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _api = String.fromEnvironment('API_BASE_URL');
const _emailA = String.fromEnvironment('TESTER_A_EMAIL');
const _emailB = String.fromEnvironment('TESTER_B_EMAIL');
const _password = String.fromEnvironment('TESTER_PASSWORD');

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  // The app draws its own frames (fullyLive), so just poll the tree.
  while (DateTime.now().isBefore(end)) {
    if (finder.evaluate().isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await tester.tap(finder);
  await Future<void>.delayed(const Duration(milliseconds: 300));
}

Future<void> _login(WidgetTester tester, String email, String password) async {
  final emailField = find.widgetWithText(TextField, 'Email');
  final passwordField = find.widgetWithText(TextField, 'Kata sandi');
  await _waitFor(tester, passwordField);
  await tester.enterText(emailField, email);
  await tester.enterText(passwordField, password);
  await _tap(tester, find.text('Masuk').last);
}

/// Today's check-ins of the signed-in user, read over HTTP.
Future<List<Object?>> _todayOnServer() async {
  final token = Supabase.instance.client.auth.currentSession!.accessToken;
  final day = DateFormatter.isoDate(DateTime.now());
  final response = await Dio().get<List<Object?>>(
    '$_api/checkins',
    queryParameters: {'from': day, 'to': day},
    options: Options(headers: {'Authorization': 'Bearer $token'}),
  );
  return response.data!;
}

Future<void> _logout(WidgetTester tester) async {
  await _tap(tester, find.text('Profil').last);
  await tester.scrollUntilVisible(
    find.text('Keluar'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await _tap(tester, find.text('Keluar'));
  await _tap(tester, find.text('Keluar').last);
  // Logout also withdraws consent, so the next user gives it again.
  await _giveConsent(tester);
}

Future<void> _giveConsent(WidgetTester tester) async {
  await _tap(
    tester,
    find.text('Proses data saya agar aplikasi bisa digunakan'),
  );
  await _tap(tester, find.text('Setuju dan lanjutkan'));
  await _waitFor(
    tester,
    find.text('Gunakan akun yang sama dengan website asesmen MSU.'),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('login, check-in, and account switch through the UI', (
    tester,
  ) async {
    // Start like a fresh install.
    await const FlutterSecureStorage().deleteAll();
    await (await SharedPreferences.getInstance()).clear();
    final onError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = onError);
    // The mood faces are found by their spoken labels.
    final semantics = tester.ensureSemantics();

    await app.main();
    // Let the test framework, not the app's handler, report errors.
    FlutterError.onError = onError;
    await _tap(tester, find.text('Lewati'));
    await _giveConsent(tester);

    // 1. Wrong password: a calm message, still on the login screen.
    await _login(tester, _emailA, 'salah-$_password');
    await _waitFor(tester, find.text('Email atau kata sandi belum sesuai.'));
    expect(Supabase.instance.client.auth.currentSession, isNull);

    // 1. Account A signs in; the greeting comes from /me.
    await _login(tester, _emailA, _password);
    await _waitFor(tester, find.textContaining('Halo, Admin'));

    // 2. Save today's mood from the UI and read it back over HTTP.
    await _waitFor(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data == 'Ketuk satu wajah, langsung tersimpan.' ||
                (w.data ?? '').startsWith('Hari ini: ')),
      ),
    );
    if (find.text('Ubah').evaluate().isNotEmpty) {
      await _tap(tester, find.text('Ubah'));
    }
    await _tap(tester, find.bySemanticsLabel('Baik'));
    await _waitFor(tester, find.text('Hari ini: Baik'));
    final saved = (await _todayOnServer()).single! as Map<String, Object?>;
    expect(saved['mood'], 4);

    // 3. Add a note with an emoji, then change only the mood: one row,
    //    same id, note kept.
    await _tap(
      tester,
      find.text('Tambah catatan').evaluate().isNotEmpty
          ? find.text('Tambah catatan')
          : find.text('Ubah catatan'),
    );
    await tester.enterText(find.byType(TextField).last, 'catatan UI 🌿');
    await _tap(tester, find.widgetWithText(FilledButton, 'Simpan'));
    await _waitFor(tester, find.text('Ubah catatan'));
    await _tap(tester, find.text('Ubah'));
    await _tap(tester, find.bySemanticsLabel('Sangat baik'));
    await _waitFor(tester, find.text('Hari ini: Sangat baik'));
    final changed = (await _todayOnServer()).single! as Map<String, Object?>;
    expect(changed['id'], saved['id']);
    expect(changed['mood'], 5);
    expect(changed['note'], 'catatan UI 🌿');

    // 3. Clearing the note removes it on the server.
    await _tap(tester, find.text('Ubah catatan'));
    await tester.enterText(find.byType(TextField).last, '');
    await _tap(tester, find.widgetWithText(FilledButton, 'Simpan'));
    await _waitFor(tester, find.text('Tambah catatan'));
    final cleared = (await _todayOnServer()).single! as Map<String, Object?>;
    expect(cleared['id'], saved['id']);
    expect(cleared['note'], isNull);

    // 6. Logout A, login B: nothing of A remains on screen.
    await _logout(tester);
    expect(Supabase.instance.client.auth.currentSession, isNull);
    await _login(tester, _emailB, _password);
    await _waitFor(tester, find.textContaining('Halo, Tester'));
    await _waitFor(tester, find.text('Ketuk satu wajah, langsung tersimpan.'));
    expect(find.text('Hari ini: Sangat baik'), findsNothing);
    expect(await _todayOnServer(), isEmpty);

    await _logout(tester);
    semantics.dispose();
  }, timeout: const Timeout(Duration(minutes: 5)));
}

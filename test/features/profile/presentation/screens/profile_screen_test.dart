import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';
import 'package:msu_wellbeing/features/profile/presentation/controllers/settings_controllers.dart';

import '../../../../helpers/pump_app.dart';

Future<void> _openProfile(WidgetTester tester, TestDeps deps) async {
  await pumpApp(tester, deps);
  await tester.tap(find.text('Profil').last);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => AppLockController.now = DateTime.now);

  testWidgets('app lock gates launch until the user unlocks', (tester) async {
    final deps = await TestDeps.signedIn();
    deps.secureStorage.values[SecureKeys.appLockEnabled] = 'true';
    deps.appLock.authenticateResult = false;

    await pumpApp(tester, deps);
    expect(find.text('Aplikasi terkunci'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    deps.appLock.authenticateResult = true;
    await tester.tap(find.text('Buka kunci'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('app relocks after more than 30 s in the background', (
    tester,
  ) async {
    final deps = await TestDeps.signedIn();
    deps.secureStorage.values[SecureKeys.appLockEnabled] = 'true';
    var clock = DateTime(2026, 10, 22, 10);
    AppLockController.now = () => clock;

    await pumpApp(tester, deps);
    expect(find.byType(NavigationBar), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    clock = clock.add(const Duration(seconds: 31));
    deps.appLock.authenticateResult = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Aplikasi terkunci'), findsOneWidget);
  });

  testWidgets('logout clears tokens, chat history, and consent', (
    tester,
  ) async {
    final deps = await TestDeps.signedIn();
    deps.secureStorage.values[SecureKeys.chatHistory('usr_test')] = '[]';
    await _openProfile(tester, deps);

    await tester.scrollUntilVisible(find.text('Keluar'), 200);
    await tester.ensureVisible(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Keluar'));
    await tester.pumpAndSettle();

    expect(deps.secureStorage.values, isEmpty);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Persetujuan data'), findsOneWidget);
  });

  testWidgets('withdrawing the optional scope adds a consent record', (
    tester,
  ) async {
    final deps = await TestDeps.signedIn();
    await _openProfile(tester, deps);
    await tester.tap(find.text('Privasi & izin'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Izin diperbarui.'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Tarik izin ini?'), findsOneWidget);
    await tester.tap(find.text('Tarik izin'));
    await tester.pumpAndSettle();

    final history = deps.secureStorage.values[SecureKeys.consentHistory]!;
    expect(RegExp('grantedAt').allMatches(history).length, 3);
  });

  testWidgets('theme can be switched to dark', (tester) async {
    final deps = await TestDeps.signedIn();
    await _openProfile(tester, deps);

    await tester.scrollUntilVisible(
      find.text('Gelap'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(deps.prefs.themeMode, 'dark');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/pump_app.dart';

Future<void> _openLearn(WidgetTester tester, TestDeps deps) async {
  await pumpApp(tester, deps);
  await tester.tap(find.text('Belajar').last);
  await tester.pumpAndSettle();
}

Future<void> _openExercise(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows garden, exercises, topics, and articles', (tester) async {
    await _openLearn(tester, await TestDeps.signedIn());

    expect(find.textContaining('Tamanmu tumbuh'), findsOneWidget);
    expect(find.text('Napas tenang'), findsOneWidget);
    expect(find.text('Lepaskan pikiran'), findsOneWidget);
    expect(find.text('Suara tenang'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Tidur'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Kuliah'), findsOneWidget);
    await tester.tap(find.text('Tidur'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Rutinitas tidur yang menenangkan'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Rutinitas tidur yang menenangkan'), findsOneWidget);
    expect(find.text('Mengelola stres akademik'), findsNothing);
  });

  testWidgets('a breathing session completes and grows the garden', (
    tester,
  ) async {
    final deps = await TestDeps.signedIn();
    await _openLearn(tester, deps);
    await _openExercise(tester, 'Napas tenang');

    await tester.tap(find.text('1 menit'));
    await tester.pump();
    await tester.tap(find.text('Mulai'));
    await tester.pump();
    expect(find.text('Tarik napas'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Hembuskan perlahan'), findsOneWidget);

    await tester.pump(const Duration(seconds: 56));
    await tester.pumpAndSettle();
    expect(find.text('Sesi selesai'), findsOneWidget);
    expect(find.text('Ulangi'), findsOneWidget);
    expect(deps.prefs.gardenSessions, 1);
  });

  testWidgets('released text is never stored', (tester) async {
    final deps = await TestDeps.signedIn();
    await _openLearn(tester, deps);
    await _openExercise(tester, 'Lepaskan pikiran');

    const secret = 'pikiran-rahasia-123';
    await tester.enterText(find.byType(TextField), secret);
    await tester.pump();
    await tester.tap(find.text('Lepaskan'));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.textContaining('sudah kamu lepaskan'), findsOneWidget);
    expect(find.text(secret), findsNothing);
    expect(
      deps.secureStorage.values.values.any((v) => v.contains(secret)),
      isFalse,
    );
    expect(deps.prefs.remoteConfigCache?.contains(secret) ?? false, isFalse);
    expect(deps.prefs.gardenSessions, 1);
  });

  testWidgets('the three bundled sounds are ready to play', (tester) async {
    await _openLearn(tester, await TestDeps.signedIn());
    await _openExercise(tester, 'Suara tenang');

    expect(find.text('Hujan'), findsOneWidget);
    expect(find.text('Hutan'), findsOneWidget);
    expect(find.text('Ombak'), findsOneWidget);
    expect(find.text('Segera hadir'), findsNothing);
    expect(find.byTooltip('Putar Hujan'), findsOneWidget);
  });
}

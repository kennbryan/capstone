import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fakes.dart';
import '../../../../helpers/pump_app.dart';

Future<void> _openChat(WidgetTester tester, TestDeps deps) async {
  await pumpApp(tester, deps);
  await tester.tap(find.text('Chat').last);
  await tester.pumpAndSettle();
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.byTooltip('Kirim'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(ChatMockSource.reset);

  testWidgets('shows the AI disclaimer and suggestion chips', (tester) async {
    await _openChat(tester, await TestDeps.signedIn());

    expect(find.text('Asisten MSU'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.textContaining('bukan psikolog'), findsOneWidget);
    expect(find.text('Aku lagi stres kuliah'), findsOneWidget);
  });

  testWidgets('a normal message gets an assistant reply bubble', (
    tester,
  ) async {
    await _openChat(tester, await TestDeps.signedIn());
    await _send(tester, 'Halo');

    expect(find.text('Halo'), findsOneWidget);
    expect(find.textContaining('Terima kasih sudah bercerita'), findsOneWidget);
  });

  testWidgets('#tes-krisis renders the crisis card, not a bubble', (
    tester,
  ) async {
    await _openChat(tester, await TestDeps.signedIn());
    await _send(tester, '#tes-krisis');

    expect(find.text('Kamu tidak sendirian'), findsOneWidget);
    expect(find.text('Darurat umum'), findsOneWidget);
    expect(find.text('Lihat bantuan darurat'), findsOneWidget);
  });

  testWidgets('psychologist segment hides WhatsApp when no number', (
    tester,
  ) async {
    await _openChat(tester, await TestDeps.signedIn());
    await tester.tap(find.text('Psikolog'));
    await tester.pumpAndSettle();

    expect(find.text('Chat via WhatsApp'), findsNothing);
    expect(find.textContaining('belum tersedia'), findsOneWidget);
  });

  testWidgets('psychologist segment shows WhatsApp with a dummy number', (
    tester,
  ) async {
    final deps = await TestDeps.signedIn(
      mockSettings: const MockSettings(instant: true, whatsappDummy: true),
    );
    await _openChat(tester, deps);
    await tester.tap(find.text('Psikolog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chat via WhatsApp'));
    await tester.pumpAndSettle();
    expect(find.textContaining('diarahkan ke WhatsApp'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
  });
}

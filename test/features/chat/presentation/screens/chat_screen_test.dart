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

  testWidgets('assistant actions render as cards; unknown ones are hidden', (
    tester,
  ) async {
    await _openChat(tester, await TestDeps.signedIn());
    await _send(tester, '#tes-aksi');

    expect(find.text('Grounding saat emosi terasa kuat'), findsOneWidget);
    expect(find.text('3 menit'), findsOneWidget);
    expect(find.text('Chat dengan psikolog'), findsOneWidget);
    expect(find.text('Siapkan ringkasan untuk psikolog'), findsOneWidget);
    expect(find.text('Disembunyikan'), findsNothing);
  });

  testWidgets('an activity action opens its steps', (tester) async {
    await _openChat(tester, await TestDeps.signedIn());
    await _send(tester, '#tes-aksi');

    await tester.tap(find.text('Grounding saat emosi terasa kuat'));
    await tester.pumpAndSettle();
    expect(find.text('Langkah-langkah'), findsOneWidget);
    expect(find.text('Tekan telapak kaki ke lantai.'), findsOneWidget);
    expect(find.text('Sumber: WHO'), findsOneWidget);
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(find.text('Langkah-langkah'), findsNothing);
  });

  testWidgets('summary action shows an editable draft that is not sent', (
    tester,
  ) async {
    await _openChat(tester, await TestDeps.signedIn());
    await _send(tester, '#tes-aksi');

    await tester.tap(find.text('Siapkan ringkasan untuk psikolog'));
    await tester.pumpAndSettle();
    expect(find.text('Ringkasan untuk psikolog'), findsOneWidget);
    expect(find.textContaining('tugas kuliah menumpuk'), findsOneWidget);
    expect(find.textContaining('belum dikirim'), findsOneWidget);
    expect(find.text('Salin ringkasan'), findsOneWidget);
  });

  testWidgets('psychologist action switches to the Psikolog segment', (
    tester,
  ) async {
    await _openChat(tester, await TestDeps.signedIn());
    await _send(tester, '#tes-aksi');

    await tester.tap(find.text('Chat dengan psikolog'));
    await tester.pumpAndSettle();
    expect(find.text('Layanan psikolog MSU'), findsOneWidget);

    // Back to the assistant and again: the action still switches.
    await tester.tap(find.text('Asisten AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat dengan psikolog'));
    await tester.pumpAndSettle();
    expect(find.text('Layanan psikolog MSU'), findsOneWidget);
  });
}

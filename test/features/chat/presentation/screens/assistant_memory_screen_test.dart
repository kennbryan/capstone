import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fakes.dart';
import '../../../../helpers/pump_app.dart';

Future<void> _openMemory(WidgetTester tester) async {
  await pumpApp(tester, await TestDeps.signedIn());
  await tester.tap(find.text('Profil').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Memori Asisten AI'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(ChatMockSource.reset);

  testWidgets('lists what the assistant remembers and deletes an item', (
    tester,
  ) async {
    await _openMemory(tester);

    expect(
      find.text('Jalan sore membantu menenangkan pikiran'),
      findsOneWidget,
    );
    expect(find.text('Yang membantu'), findsOneWidget);

    await tester.tap(find.byTooltip('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada yang diingat'), findsOneWidget);
    expect(ChatMockSource.memoryItems, isEmpty);
  });

  testWidgets('clear all asks first', (tester) async {
    await _openMemory(tester);

    await tester.tap(find.text('Hapus semua memori'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus semua memori?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada yang diingat'), findsOneWidget);
  });
}

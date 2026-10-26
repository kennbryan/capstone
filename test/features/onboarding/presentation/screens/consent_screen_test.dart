import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  testWidgets('requires the mandatory toggle and records consent', (
    tester,
  ) async {
    final deps = await TestDeps.create(prefs: {'onboarding.seen': true});
    await pumpApp(tester, deps);

    expect(find.text('Persetujuan data'), findsOneWidget);
    expect(find.text('Tidak dipakai untuk melatih model'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Setuju dan lanjutkan'), 200);
    final agree = find.widgetWithText(FilledButton, 'Setuju dan lanjutkan');
    expect(tester.widget<FilledButton>(agree).onPressed, isNull);

    await tester.tap(
      find.text('Proses data saya agar aplikasi bisa digunakan'),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(agree).onPressed, isNotNull);

    await tester.tap(agree);
    await tester.pumpAndSettle();

    expect(
      find.text('Gunakan akun yang sama dengan website asesmen MSU.'),
      findsOneWidget,
    );
    final stored = deps.secureStorage.values[SecureKeys.consentHistory]!;
    expect(stored, contains('processData'));
    expect(stored, isNot(contains('personalizeWithReport')));
  });

  testWidgets('a newer consent version asks again', (tester) async {
    final deps = await TestDeps.signedIn();
    deps.secureStorage.values[SecureKeys.consentHistory] =
        '[{"version":0,"grantedScopes":["processData"],'
        '"grantedAt":"2025-01-01T00:00:00.000Z"}]';
    await pumpApp(tester, deps);

    expect(find.text('Persetujuan data'), findsOneWidget);
    expect(find.textContaining('Ketentuan data diperbarui'), findsOneWidget);
  });
}

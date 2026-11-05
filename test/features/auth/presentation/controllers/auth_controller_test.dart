import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/network/session_source.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/auth_controller.dart';

import '../../../../helpers/pump_app.dart';

/// A signed-in session that the test can end from "Supabase".
class _EndableSession extends NoSessionSource {
  final ended = StreamController<void>.broadcast();

  @override
  Stream<void> get sessionEnded => ended.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a session ended by Supabase signs the user out', () async {
    final session = _EndableSession();
    final deps = await TestDeps.signedIn();
    final container = deps.container([
      sessionSourceProvider.overrideWithValue(session),
    ]);
    expect(await container.read(authControllerProvider.future), isNotNull);

    session.ended.add(null);
    await pumpEventQueue();

    expect(container.read(authControllerProvider).value, isNull);
    expect(deps.secureStorage.values, isEmpty);
  });

  test('stream errors (e.g. offline refresh) keep the user', () async {
    final session = _EndableSession();
    final deps = await TestDeps.signedIn();
    final container = deps.container([
      sessionSourceProvider.overrideWithValue(session),
    ]);
    await container.read(authControllerProvider.future);

    session.ended.addError(Exception('offline'));
    await pumpEventQueue();

    expect(container.read(authControllerProvider).value, isNotNull);
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/auth/data/sources/demo_accounts.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/auth_controller.dart';
import 'package:msu_wellbeing/features/checkin/domain/checkin_repository.dart';
import 'package:msu_wellbeing/features/checkin/domain/entities/check_in.dart';
import 'package:msu_wellbeing/features/checkin/presentation/controllers/checkin_controller.dart';

import '../../../../helpers/fakes.dart';
import '../../../../helpers/pump_app.dart';

/// Empty history; [save] waits until [finishSave] completes.
class _SlowSaveRepository implements CheckInRepository {
  final finishSave = Completer<void>();

  @override
  Future<Result<List<CheckIn>>> getCheckIns({
    required DateTime from,
    required DateTime to,
  }) async => const Success([]);

  @override
  Future<Result<CheckIn>> save({
    required DateTime date,
    required int mood,
    String? note,
  }) async {
    await finishSave.future;
    return Success(CheckIn(id: 'chk_a', date: date, mood: mood, note: note));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(CheckInMockSource.reset);
  tearDown(() => CheckInController.now = DateTime.now);

  test('builds seven days ending today, oldest first', () async {
    final deps = await TestDeps.signedIn();
    final container = deps.container();
    await container.read(authControllerProvider.future);

    final week = await container.read(checkInControllerProvider.future);
    expect(week.days, hasLength(7));
    expect(week.days.last.date.day, DateTime.now().day);
    expect(week.today, isNull);
    // Seeded mock data leaves some days empty on purpose.
    expect(week.days.where((d) => d.checkIn == null), isNotEmpty);
  });

  test('saving updates today without touching other days', () async {
    final deps = await TestDeps.signedIn();
    final container = deps.container();
    await container.read(authControllerProvider.future);
    final before = await container.read(checkInControllerProvider.future);

    final failure = await container
        .read(checkInControllerProvider.notifier)
        .save(mood: 4, note: '  catatan  ');

    expect(failure, isNull);
    final after = container.read(checkInControllerProvider).requireValue;
    expect(after.today?.mood, 4);
    expect(after.today?.note, 'catatan');
    expect(
      after.days.take(6).map((d) => d.checkIn),
      before.days.take(6).map((d) => d.checkIn),
    );
  });

  test('the empty scenario shows a week with no check-ins', () async {
    final deps = await TestDeps.signedIn(
      mockSettings: const MockSettings(
        instant: true,
        checkins: MockScenario.empty,
      ),
    );
    final container = deps.container();
    await container.read(authControllerProvider.future);

    final week = await container.read(checkInControllerProvider.future);
    expect(week.days.every((d) => d.checkIn == null), isTrue);
  });

  test("a save finishing after an account switch stays off B's week", () async {
    final repository = _SlowSaveRepository();
    final deps = await TestDeps.signedIn()
      ..checkInRepository = repository;
    final container = deps.container();
    final auth = container.read(authControllerProvider.notifier);
    await container.read(authControllerProvider.future);
    await container.read(checkInControllerProvider.future);

    // Account A saves; before the server answers, A signs out and B in.
    final saving = container
        .read(checkInControllerProvider.notifier)
        .save(mood: 5, note: 'catatan A');
    await auth.logout();
    await auth.login(email: demoAccounts.last.email, password: demoPassword);
    final weekOfB = await container.read(checkInControllerProvider.future);

    repository.finishSave.complete();
    expect(await saving, isNull);

    final after = container.read(checkInControllerProvider).requireValue;
    expect(after, weekOfB);
    expect(after.today, isNull);
  });
}

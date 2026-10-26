import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/auth_controller.dart';
import 'package:msu_wellbeing/features/checkin/presentation/controllers/checkin_controller.dart';

import '../../../../helpers/fakes.dart';
import '../../../../helpers/pump_app.dart';

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
}

import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/garden_progress.dart';

void main() {
  group('GardenProgress', () {
    test('grows one stage per three sessions', () {
      expect(const GardenProgress(0).stage, 0);
      expect(const GardenProgress(2).stage, 0);
      expect(const GardenProgress(3).stage, 1);
      expect(const GardenProgress(6).stage, 2);
      expect(const GardenProgress(11).stage, 3);
      expect(const GardenProgress(12).stage, 4);
    });

    test('stops at the last stage and never goes back', () {
      expect(const GardenProgress(100).stage, GardenProgress.maxStage);
      var previous = 0;
      for (var sessions = 0; sessions < 30; sessions++) {
        final stage = GardenProgress(sessions).stage;
        expect(stage, greaterThanOrEqualTo(previous));
        previous = stage;
      }
    });

    test('reports sessions left until the next stage', () {
      expect(const GardenProgress(0).sessionsToNextStage, 3);
      expect(const GardenProgress(4).sessionsToNextStage, 2);
      expect(const GardenProgress(12).sessionsToNextStage, 0);
    });
  });
}

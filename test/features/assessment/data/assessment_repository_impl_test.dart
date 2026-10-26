import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/network/api_exception.dart';
import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/assessment/data/assessment_repository_impl.dart';

import '../../../helpers/fakes.dart';

AssessmentRepositoryImpl _repo(MockScenario scenario) =>
    AssessmentRepositoryImpl(
      AssessmentMockSource(MockSettings(instant: true, reports: scenario)),
    );

void main() {
  group('AssessmentRepositoryImpl (mock source)', () {
    test('returns reports newest first', () async {
      final reports = (await _repo(MockScenario.data).getReports()).unwrap();
      expect(reports, hasLength(2));
      expect(reports.first.takenAt.isAfter(reports.last.takenAt), isTrue);
      expect(reports.first.sections, isNotEmpty);
    });

    test('returns an empty list for the empty scenario', () async {
      final reports = (await _repo(MockScenario.empty).getReports()).unwrap();
      expect(reports, isEmpty);
    });

    test('returns a network failure for the error scenario', () async {
      final result = await _repo(MockScenario.error).getReports();
      expect((result as Failure).error.kind, ApiExceptionKind.network);
    });

    test('returns notFound for an unknown report id', () async {
      final result = await _repo(MockScenario.data).getReport('missing');
      expect((result as Failure).error.kind, ApiExceptionKind.notFound);
    });
  });
}

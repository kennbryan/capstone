import 'package:msu_wellbeing/core/network/dio_client.dart';
import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/assessment/data/models/assessment_report_dto.dart';
import 'package:msu_wellbeing/features/assessment/data/sources/assessment_sources.dart';
import 'package:msu_wellbeing/features/assessment/domain/assessment_repository.dart';
import 'package:msu_wellbeing/features/assessment/domain/entities/assessment_report.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'assessment_repository_impl.g.dart';

class AssessmentRepositoryImpl implements AssessmentRepository {
  const new(this._source);

  final AssessmentSource _source;

  @override
  Future<Result<List<AssessmentReport>>> getReports() {
    return Result.guard('reports.list', () async {
      final reports = [
        for (final dto in await _source.getReports()) dto.toEntity(),
      ]..sort((a, b) => b.takenAt.compareTo(a.takenAt));
      return reports;
    });
  }

  @override
  Future<Result<AssessmentReport>> getReport(String id) {
    return Result.guard(
      'reports.detail',
      () async => (await _source.getReport(id)).toEntity(),
    );
  }
}

@riverpod
AssessmentRepository assessmentRepository(Ref ref) {
  return AssessmentRepositoryImpl(
    AssessmentRemoteSource(ref.watch(dioProvider)),
  );
}

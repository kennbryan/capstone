import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/assessment/domain/entities/assessment_report.dart';

abstract interface class AssessmentRepository {
  /// Reports, newest first.
  Future<Result<List<AssessmentReport>>> getReports();

  Future<Result<AssessmentReport>> getReport(String id);
}

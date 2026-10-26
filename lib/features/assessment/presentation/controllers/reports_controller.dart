import 'package:msu_wellbeing/features/assessment/data/assessment_repository_impl.dart';
import 'package:msu_wellbeing/features/assessment/domain/entities/assessment_report.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/auth_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reports_controller.g.dart';

/// The signed-in user's reports, newest first.
@riverpod
Future<List<AssessmentReport>> reports(Ref ref) async {
  ref.watch(currentUserIdProvider);
  final result = await ref.watch(assessmentRepositoryProvider).getReports();
  return result.unwrap();
}

@riverpod
Future<AssessmentReport> reportDetail(Ref ref, String id) async {
  ref.watch(currentUserIdProvider);
  final result = await ref.watch(assessmentRepositoryProvider).getReport(id);
  return result.unwrap();
}

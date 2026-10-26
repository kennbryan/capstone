import 'package:dio/dio.dart';
import 'package:msu_wellbeing/features/assessment/data/models/assessment_report_dto.dart';

abstract interface class AssessmentSource {
  Future<List<AssessmentReportDto>> getReports();

  Future<AssessmentReportDto> getReport(String id);
}

/// Assessment reports, read-only (they come from the MSU assessment site).
///
/// **For the backend team** (auth: `Authorization: Bearer <accessToken>`):
///
/// `GET /reports` → 200, the signed-in user's reports (any order; the app
/// sorts newest first). An empty list `[]` shows "Kamu belum mengikuti
/// asesmen".
/// ```json
/// [
///   {
///     "id": "rpt_002",
///     "title": "Rapor Kesejahteraan Diri — Oktober",
///     "takenAt": "2026-10-14T03:00:00Z",
///     "summary": "Kamu sedang membawa cukup banyak tuntutan kuliah.",
///     "sections": [
///       {
///         "heading": "Tuntutan akademik",
///         "body": "Beban tugas terasa cukup padat. Jeda singkat membantu.",
///         "level": "Perlu perhatian lebih"
///       },
///       {
///         "heading": "Dukungan sosial",
///         "body": "Kamu memiliki teman dan keluarga yang bisa diajak bicara.",
///         "level": "Baik"
///       }
///     ]
///   }
/// ]
/// ```
///
/// `GET /reports/{id}` → 200 with one report object (same shape). Return
/// 404 when it does not exist **or belongs to another user** (ownership is
/// checked server-side).
///
/// Wording rules: plain language, never a diagnosis. `level` is optional
/// display text shown as-is (the app does not interpret it).
class AssessmentRemoteSource implements AssessmentSource {
  const new(this._dio);

  final Dio _dio;

  @override
  Future<List<AssessmentReportDto>> getReports() async {
    final response = await _dio.get<List<Object?>>('/reports');
    return [
      for (final item in response.data!)
        AssessmentReportDto.fromJson(item! as Map<String, Object?>),
    ];
  }

  @override
  Future<AssessmentReportDto> getReport(String id) async {
    final response = await _dio.get<Map<String, Object?>>(
      '/reports/${Uri.encodeComponent(id)}',
    );
    return AssessmentReportDto.fromJson(response.data!);
  }
}

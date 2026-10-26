import 'package:freezed_annotation/freezed_annotation.dart';

part 'assessment_report.freezed.dart';

/// A read-only report from the MSU assessment website.
@freezed
abstract class AssessmentReport with _$AssessmentReport {
  const factory({
    required String id,
    required String title,
    required DateTime takenAt,
    required String summary,
    required List<ReportSection> sections,
  }) = _AssessmentReport;
}

/// One report section, shown exactly as provided by the API.
@freezed
abstract class ReportSection with _$ReportSection {
  const factory({
    required String heading,
    required String body,

    /// Display-only text from the API; the app never interprets it.
    String? level,
  }) = _ReportSection;
}

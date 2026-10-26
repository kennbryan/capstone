import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:msu_wellbeing/features/assessment/domain/entities/assessment_report.dart';

part 'assessment_report_dto.freezed.dart';
part 'assessment_report_dto.g.dart';

@freezed
abstract class AssessmentReportDto with _$AssessmentReportDto {
  const factory({
    required String id,
    required String title,
    required DateTime takenAt,
    required String summary,
    @Default(<ReportSectionDto>[]) List<ReportSectionDto> sections,
  }) = _AssessmentReportDto;

  factory fromJson(Map<String, Object?> json) =>
      _$AssessmentReportDtoFromJson(json);
}

@freezed
abstract class ReportSectionDto with _$ReportSectionDto {
  const factory({
    required String heading,
    required String body,
    String? level,
  }) = _ReportSectionDto;

  factory fromJson(Map<String, Object?> json) =>
      _$ReportSectionDtoFromJson(json);
}

extension AssessmentReportDtoMapper on AssessmentReportDto {
  AssessmentReport toEntity() => AssessmentReport(
    id: id,
    title: title,
    takenAt: takenAt.toLocal(),
    summary: summary,
    sections: [
      for (final section in sections)
        ReportSection(
          heading: section.heading,
          body: section.body,
          level: section.level,
        ),
    ],
  );
}

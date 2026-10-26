import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:msu_wellbeing/features/onboarding/domain/entities/consent_record.dart';

part 'consent_record_dto.freezed.dart';
part 'consent_record_dto.g.dart';

@freezed
abstract class ConsentRecordDto with _$ConsentRecordDto {
  const factory({
    required int version,
    required List<String> grantedScopes,
    required DateTime grantedAt,
  }) = _ConsentRecordDto;

  factory fromJson(Map<String, Object?> json) =>
      _$ConsentRecordDtoFromJson(json);

  factory fromEntity(ConsentRecord record) => ConsentRecordDto(
    version: record.version,
    grantedScopes: [for (final scope in record.grantedScopes) scope.name],
    grantedAt: record.grantedAt.toUtc(),
  );
}

extension ConsentRecordDtoMapper on ConsentRecordDto {
  /// Unknown scope names (from newer app versions) are ignored.
  ConsentRecord toEntity() => ConsentRecord(
    version: version,
    grantedScopes: {
      for (final name in grantedScopes)
        ...ConsentScope.values.where((scope) => scope.name == name),
    },
    grantedAt: grantedAt.toLocal(),
  );
}

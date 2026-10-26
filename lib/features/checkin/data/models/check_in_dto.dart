import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:msu_wellbeing/core/utils/date_formatter.dart';
import 'package:msu_wellbeing/features/checkin/domain/entities/check_in.dart';

part 'check_in_dto.freezed.dart';
part 'check_in_dto.g.dart';

/// `date` is a `yyyy-MM-dd` string.
@freezed
abstract class CheckInDto with _$CheckInDto {
  const factory({
    required String id,
    required String date,
    required int mood,
    String? note,
  }) = _CheckInDto;

  factory fromJson(Map<String, Object?> json) => _$CheckInDtoFromJson(json);
}

extension CheckInDtoMapper on CheckInDto {
  CheckIn toEntity() => CheckIn(
    id: id,
    date: DateFormatter.dateOnly(DateTime.parse(date)),
    mood: mood,
    note: note,
  );
}

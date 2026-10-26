import 'package:freezed_annotation/freezed_annotation.dart';

part 'check_in.freezed.dart';

/// A daily mood check-in. [mood] is 1 (very heavy) to 5 (very good).
@freezed
abstract class CheckIn with _$CheckIn {
  const factory({
    required String id,
    required DateTime date,
    required int mood,
    String? note,
  }) = _CheckIn;
}

/// One calendar day in the weekly strip; [checkIn] is null when skipped.
@freezed
abstract class CheckInDay with _$CheckInDay {
  const factory({required DateTime date, CheckIn? checkIn}) = _CheckInDay;
}

/// Limits shared by the UI and the repository.
abstract final class CheckInRules {
  static const minMood = 1;
  static const maxMood = 5;
  static const noteMaxLength = 200;
  static const weekDays = 7;
}

import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/checkin/domain/entities/check_in.dart';

abstract interface class CheckInRepository {
  /// Check-ins between [from] and [to] (inclusive, date only).
  Future<Result<List<CheckIn>>> getCheckIns({
    required DateTime from,
    required DateTime to,
  });

  /// Creates or replaces the check-in for [date].
  Future<Result<CheckIn>> save({
    required DateTime date,
    required int mood,
    String? note,
  });
}

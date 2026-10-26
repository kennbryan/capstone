import 'package:msu_wellbeing/core/network/dio_client.dart';
import 'package:msu_wellbeing/core/utils/date_formatter.dart';
import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/checkin/data/models/check_in_dto.dart';
import 'package:msu_wellbeing/features/checkin/data/sources/checkin_sources.dart';
import 'package:msu_wellbeing/features/checkin/domain/checkin_repository.dart';
import 'package:msu_wellbeing/features/checkin/domain/entities/check_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checkin_repository_impl.g.dart';

class CheckInRepositoryImpl implements CheckInRepository {
  const new(this._source);

  final CheckInSource _source;

  @override
  Future<Result<List<CheckIn>>> getCheckIns({
    required DateTime from,
    required DateTime to,
  }) {
    return Result.guard('checkins.list', () async {
      final dtos = await _source.getCheckIns(
        from: DateFormatter.isoDate(from),
        to: DateFormatter.isoDate(to),
      );
      return [for (final dto in dtos) dto.toEntity()];
    });
  }

  @override
  Future<Result<CheckIn>> save({
    required DateTime date,
    required int mood,
    String? note,
  }) {
    return Result.guard('checkins.save', () async {
      final trimmed = note?.trim();
      final dto = await _source.save(
        date: DateFormatter.isoDate(date),
        mood: mood.clamp(CheckInRules.minMood, CheckInRules.maxMood),
        note: trimmed == null || trimmed.isEmpty ? null : trimmed,
      );
      return dto.toEntity();
    });
  }
}

@riverpod
CheckInRepository checkInRepository(Ref ref) {
  return CheckInRepositoryImpl(CheckInRemoteSource(ref.watch(dioProvider)));
}

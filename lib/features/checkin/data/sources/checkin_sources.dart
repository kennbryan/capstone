import 'package:dio/dio.dart';
import 'package:msu_wellbeing/features/checkin/data/models/check_in_dto.dart';

abstract interface class CheckInSource {
  Future<List<CheckInDto>> getCheckIns({
    required String from,
    required String to,
  });

  Future<CheckInDto> save({
    required String date,
    required int mood,
    String? note,
  });
}

/// Daily mood check-ins.
///
/// **For the backend team** (auth: `Authorization: Bearer <accessToken>`):
///
/// `GET /checkins?from=2026-10-20&to=2026-10-26` (dates `YYYY-MM-DD`,
/// inclusive) → 200, the user's check-ins in that range. Days without a
/// check-in are simply absent (the app shows them as empty, never as a
/// failure).
/// ```json
/// [
///   { "id": "chk_2026-10-25", "date": "2026-10-25", "mood": 4 },
///   {
///     "id": "chk_2026-10-24",
///     "date": "2026-10-24",
///     "mood": 3,
///     "note": "tidur cukup"
///   }
/// ]
/// ```
///
/// `POST /checkins` → 200/201 with the saved check-in (same shape).
/// One check-in per user per day: posting again for the same `date`
/// **replaces** it (the user can change today's mood or add a note).
/// ```json
/// { "date": "2026-10-26", "mood": 4, "note": "opsional, maks. 200 karakter" }
/// ```
/// `mood` is 1 (sangat berat) to 5 (sangat baik). `note` may be omitted.
/// Notes are private: never log them.
class CheckInRemoteSource implements CheckInSource {
  const new(this._dio);

  final Dio _dio;

  @override
  Future<List<CheckInDto>> getCheckIns({
    required String from,
    required String to,
  }) async {
    final response = await _dio.get<List<Object?>>(
      '/checkins',
      queryParameters: {'from': from, 'to': to},
    );
    return [
      for (final item in response.data!)
        CheckInDto.fromJson(item! as Map<String, Object?>),
    ];
  }

  @override
  Future<CheckInDto> save({
    required String date,
    required int mood,
    String? note,
  }) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/checkins',
      data: {'date': date, 'mood': mood, 'note': ?note},
    );
    return CheckInDto.fromJson(response.data!);
  }
}

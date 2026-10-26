import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';
import 'package:msu_wellbeing/features/onboarding/data/models/consent_record_dto.dart';

/// Consent history kept in secure storage on the device.
class ConsentLocalSource {
  const new(this._storage);

  final SecureStorageService _storage;

  Future<List<ConsentRecordDto>> load() async {
    final raw = await _storage.read(SecureKeys.consentHistory);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<Object?>;
    return [
      for (final item in list)
        ConsentRecordDto.fromJson(item! as Map<String, Object?>),
    ];
  }

  Future<void> save(List<ConsentRecordDto> history) => _storage.write(
    SecureKeys.consentHistory,
    jsonEncode([for (final record in history) record.toJson()]),
  );
}

/// Consent records on the server.
///
/// **For the backend team** (auth: `Authorization: Bearer <accessToken>`):
///
/// `PUT /consents` → 200/204, appends one record to the user's history:
/// ```json
/// {
///   "version": 1,
///   "grantedScopes": ["processData", "personalizeWithReport"],
///   "grantedAt": "2026-10-26T08:00:00.000Z"
/// }
/// ```
/// `processData` is required to use the app; `personalizeWithReport`
/// (the assistant may read the latest report summary) is optional and can
/// be withdrawn later, which sends a new record without it.
///
/// `GET /consents` (planned): current consent plus history, same shape.
/// The first consent is given before login, so it may arrive later.
class ConsentRemoteSource {
  const new(this._dio);

  final Dio _dio;

  Future<void> put(ConsentRecordDto record) =>
      _dio.put<void>('/consents', data: record.toJson());
}

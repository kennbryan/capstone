import 'package:msu_wellbeing/core/logging/app_logger.dart';
import 'package:msu_wellbeing/core/network/dio_client.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';
import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/onboarding/data/models/consent_record_dto.dart';
import 'package:msu_wellbeing/features/onboarding/data/sources/consent_sources.dart';
import 'package:msu_wellbeing/features/onboarding/domain/consent_repository.dart';
import 'package:msu_wellbeing/features/onboarding/domain/entities/consent_record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'consent_repository_impl.g.dart';

/// Consent is stored on the device first (it is given before login), then
/// sent to the server when possible. A failed upload never blocks the user.
class ConsentRepositoryImpl implements ConsentRepository {
  const new(this._local, [this._remote]);

  final ConsentLocalSource _local;

  /// Null in tests: consent then stays on the device only.
  final ConsentRemoteSource? _remote;

  @override
  Future<Result<List<ConsentRecord>>> loadHistory() {
    return Result.guard('consent.load', () async {
      final history = await _local.load();
      return [for (final dto in history) dto.toEntity()];
    });
  }

  @override
  Future<Result<ConsentRecord>> record(ConsentRecord record) {
    return Result.guard('consent.record', () async {
      final dto = ConsentRecordDto.fromEntity(record);
      await _local.save([...await _local.load(), dto]);
      try {
        await _remote?.put(dto);
      } on Object catch (error, stackTrace) {
        // Offline or not signed in yet: the device record stays valid.
        // TODO(backend): resend pending consent records after login.
        AppLogger.error('consent.sync', error, stackTrace);
      }
      return record;
    });
  }
}

@Riverpod(keepAlive: true)
ConsentRepository consentRepository(Ref ref) {
  return ConsentRepositoryImpl(
    ConsentLocalSource(ref.watch(secureStorageProvider)),
    ConsentRemoteSource(ref.watch(dioProvider)),
  );
}

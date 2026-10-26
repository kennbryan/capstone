import 'dart:convert';

import 'package:msu_wellbeing/core/logging/app_logger.dart';
import 'package:msu_wellbeing/core/network/api_exception.dart';
import 'package:msu_wellbeing/core/network/dio_client.dart';
import 'package:msu_wellbeing/core/storage/preferences_service.dart';
import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/remote_config/data/models/remote_config_dto.dart';
import 'package:msu_wellbeing/features/remote_config/data/sources/remote_config_source.dart';
import 'package:msu_wellbeing/features/remote_config/domain/entities/remote_config.dart';
import 'package:msu_wellbeing/features/remote_config/domain/remote_config_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'remote_config_repository_impl.g.dart';

class RemoteConfigRepositoryImpl implements RemoteConfigRepository {
  const new(this._source, this._prefs);

  final RemoteConfigSource _source;
  final PreferencesService _prefs;

  @override
  Future<Result<RemoteConfig>> fetch() async {
    try {
      final dto = await _source.fetch();
      await _prefs.setRemoteConfigCache(jsonEncode(dto.toJson()));
      return Success(dto.toEntity());
    } on Object catch (error, stackTrace) {
      AppLogger.error('remote_config.fetch', error, stackTrace);
      final cached = _readCache();
      if (cached != null) return Success(cached);
      return Failure(ApiException.from(error));
    }
  }

  RemoteConfig? _readCache() {
    final raw = _prefs.remoteConfigCache;
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      return RemoteConfigDto.fromJson(json).toEntity();
    } on Object catch (error, stackTrace) {
      AppLogger.error('remote_config.cache', error, stackTrace);
      return null;
    }
  }
}

@Riverpod(keepAlive: true)
RemoteConfigRepository remoteConfigRepository(Ref ref) {
  return RemoteConfigRepositoryImpl(
    RemoteConfigRemoteSource(ref.watch(dioProvider)),
    ref.watch(preferencesProvider),
  );
}

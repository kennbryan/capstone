import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/remote_config/domain/entities/remote_config.dart';

/// Loads [RemoteConfig], falling back to the last cached value.
abstract interface class RemoteConfigRepository {
  Future<Result<RemoteConfig>> fetch();
}

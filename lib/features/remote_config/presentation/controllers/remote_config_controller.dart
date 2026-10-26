import 'package:msu_wellbeing/features/remote_config/data/remote_config_repository_impl.dart';
import 'package:msu_wellbeing/features/remote_config/domain/entities/remote_config.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'remote_config_controller.g.dart';

/// Current remote config. Refresh with `ref.invalidate(remoteConfigProvider)`.
@Riverpod(keepAlive: true)
Future<RemoteConfig> remoteConfig(Ref ref) async {
  final result = await ref.watch(remoteConfigRepositoryProvider).fetch();
  return result.unwrap();
}

import 'package:msu_wellbeing/core/logging/app_logger.dart';
import 'package:msu_wellbeing/core/storage/preferences_service.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/auth_controller.dart';
import 'package:msu_wellbeing/features/learn/data/learn_repository_impl.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/article.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/garden_progress.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/learn_ref.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'learn_controllers.g.dart';

/// Articles for [topic], or all topics when null.
@riverpod
Future<List<Article>> articles(Ref ref, {ArticleTopic? topic}) async {
  final result = await ref
      .watch(learnRepositoryProvider)
      .getArticles(topic: topic);
  return result.unwrap();
}

@riverpod
Future<Article> articleDetail(Ref ref, String id) async {
  final result = await ref.watch(learnRepositoryProvider).getArticle(id);
  return result.unwrap();
}

/// Light haptics during breathing (default off).
@Riverpod(keepAlive: true)
class HapticsController extends _$HapticsController {
  @override
  bool build() => ref.watch(preferencesProvider).hapticsEnabled;

  Future<void> toggle({required bool enabled}) async {
    await ref.read(preferencesProvider).setHapticsEnabled(enabled: enabled);
    state = enabled;
  }
}

/// Garden progress. Only grows; never shrinks or wilts.
@Riverpod(keepAlive: true)
class GardenController extends _$GardenController {
  @override
  GardenProgress build() {
    ref.watch(currentUserIdProvider);
    return ref.watch(gardenRepositoryProvider).load();
  }

  /// Records a completed relaxation session.
  Future<void> recordSession(LearnKind kind) async {
    state = await ref.read(gardenRepositoryProvider).addSession();
    AppLogger.event('garden.session', {'kind': kind.name});
  }
}

import 'package:msu_wellbeing/core/network/api_exception.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/auth_controller.dart';
import 'package:msu_wellbeing/features/chat/data/chat_repository_impl.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/memory_item.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'assistant_memory_controller.g.dart';

/// What the assistant remembers about the signed-in user. The user can
/// delete single items or everything.
@riverpod
class AssistantMemoryController extends _$AssistantMemoryController {
  @override
  Future<List<MemoryItem>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return const [];
    final result = await ref.watch(chatRepositoryProvider).memory();
    return result.unwrap();
  }

  /// Returns the failure, or null on success.
  Future<ApiException?> delete(String memoryId) async {
    final result = await ref
        .read(chatRepositoryProvider)
        .deleteMemory(memoryId);
    return result.fold<ApiException?>(
      onSuccess: (_) {
        final items = state.value ?? const <MemoryItem>[];
        state = AsyncData([
          for (final item in items)
            if (item.id != memoryId) item,
        ]);
        return null;
      },
      onFailure: (error) => error,
    );
  }

  /// Returns the failure, or null on success.
  Future<ApiException?> clear() async {
    final result = await ref.read(chatRepositoryProvider).clearMemory();
    return result.fold<ApiException?>(
      onSuccess: (_) {
        state = const AsyncData([]);
        return null;
      },
      onFailure: (error) => error,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/app_card.dart';
import 'package:msu_wellbeing/core/widgets/error_message.dart';
import 'package:msu_wellbeing/core/widgets/state_views.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/memory_item.dart';
import 'package:msu_wellbeing/features/chat/presentation/controllers/assistant_memory_controller.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// "Memori Asisten AI": what the assistant remembers to personalize
/// replies. Every item can be deleted, or all at once.
class AssistantMemoryScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MemoryItem item,
  ) async {
    final failure = await ref
        .read(assistantMemoryControllerProvider.notifier)
        .delete(item.id);
    if (!context.mounted) return;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure == null ? l10n.memoryDeleted : l10n.describeError(failure),
        ),
      ),
    );
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.memoryClearTitle),
        content: Text(l10n.memoryClearBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.memoryDelete),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    final failure = await ref
        .read(assistantMemoryControllerProvider.notifier)
        .clear();
    if (failure != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.describeError(failure))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final memory = ref.watch(assistantMemoryControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.memoryTitle)),
      body: switch (memory) {
        AsyncData(:final value) when value.isEmpty => EmptyView(
          title: l10n.memoryEmptyTitle,
          message: l10n.memoryEmptyBody,
        ),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text(
              l10n.memoryIntro,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final item in value)
                    ListTile(
                      title: Text(item.content),
                      subtitle: Text(_categoryLabel(l10n, item.category)),
                      trailing: IconButton(
                        tooltip: l10n.memoryDelete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, ref, item),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton.icon(
              onPressed: () => _clear(context, ref),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(l10n.memoryClearAll),
            ),
          ],
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(assistantMemoryControllerProvider),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

String _categoryLabel(AppLocalizations l10n, String category) =>
    switch (category) {
      'identitas' => l10n.memoryCategoryIdentity,
      'preferensi' => l10n.memoryCategoryPreference,
      'tujuan' => l10n.memoryCategoryGoal,
      'pemicu' => l10n.memoryCategoryStressor,
      'yang_membantu' => l10n.memoryCategoryCoping,
      _ => l10n.memoryCategoryOther,
    };

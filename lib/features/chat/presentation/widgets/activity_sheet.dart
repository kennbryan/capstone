import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/utils/link_launcher.dart';
import 'package:msu_wellbeing/features/chat/domain/entities/chat_action.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Shows the steps of an activity the assistant suggested.
Future<void> showActivitySheet(BuildContext context, ActivityGuide activity) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Above the bottom navigation bar, not under it.
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => ActivitySheet(activity: activity),
    );

class ActivitySheet extends ConsumerWidget {
  const new({required this.activity, super.key});

  final ActivityGuide activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final duration = activity.durationMin;
    final sourceName = activity.sourceName;
    final sourceUrl = Uri.tryParse(activity.sourceUrl ?? '');
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(activity.title, style: theme.textTheme.titleLarge),
            if (duration != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.activityMinutes(duration),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (activity.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(activity.description, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.activityStepsTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final (index, step) in activity.steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: AppSizes.iconMd / 2,
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(step, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            if (sourceName != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: sourceUrl == null || !sourceUrl.hasScheme
                      ? null
                      : () => ref.read(linkLauncherProvider).open(sourceUrl),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(l10n.activitySource(sourceName)),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.activityDone),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/error_message.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/illustration.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Centered progress indicator.
class LoadingView extends StatelessWidget {
  const new({this.compact = false, super.key});

  /// Uses less vertical space, for loading inside a card or list section.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
      child: Center(
        child: Semantics(
          label: context.l10n.loading,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

/// Friendly empty state with an illustration and an optional action.
class EmptyView extends StatelessWidget {
  const new({
    required this.title,
    this.message,
    this.illustration = IllustrationKind.calm,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? message;

  /// Drawing shown above the title.
  final IllustrationKind illustration;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _MessageView(
      illustration: illustration,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

/// Error state that explains the problem in plain words and offers a retry.
class ErrorView extends StatelessWidget {
  const new({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _MessageView(
      illustration: IllustrationKind.offline,
      title: l10n.errorTitle,
      message: l10n.describeError(error),
      actionLabel: onRetry == null ? null : l10n.retry,
      onAction: onRetry,
    );
  }
}

class _MessageView extends StatelessWidget {
  const new({
    required this.illustration,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IllustrationKind illustration;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Illustration(illustration, height: AppSizes.illustrationSm),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

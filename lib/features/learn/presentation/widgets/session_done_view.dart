import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:msu_wellbeing/core/router/app_routes.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// End of an exercise: a calm message with "Ulangi" and "Kembali". No
/// scores or streaks.
class SessionDoneView extends StatelessWidget {
  const new({required this.onRepeat, this.title, this.repeatLabel, super.key});

  final VoidCallback onRepeat;
  final String? title;
  final String? repeatLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.spa_outlined,
              size: AppSizes.iconXl,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              liveRegion: true,
              child: Text(
                title ?? l10n.sessionDone,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.sessionDoneBody,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: onRepeat,
              child: Text(repeatLabel ?? l10n.sessionRepeat),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.learn),
              child: Text(l10n.back),
            ),
          ],
        ),
      ),
    );
  }
}

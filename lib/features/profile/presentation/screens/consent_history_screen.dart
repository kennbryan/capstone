import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/utils/date_formatter.dart';
import 'package:msu_wellbeing/core/widgets/app_card.dart';
import 'package:msu_wellbeing/core/widgets/state_views.dart';
import 'package:msu_wellbeing/features/onboarding/domain/entities/consent_record.dart';
import 'package:msu_wellbeing/features/onboarding/presentation/controllers/onboarding_controllers.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Every consent decision, newest first.
class ConsentHistoryScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final history = ref.watch(consentControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileConsentHistory)),
      body: switch (history) {
        AsyncData(:final value) when value.isEmpty => EmptyView(
          title: l10n.consentHistoryEmpty,
        ),
        AsyncData(:final value) => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.screen),
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) =>
              _RecordCard(record: value[value.length - 1 - index]),
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(consentControllerProvider),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class _RecordCard extends StatelessWidget {
  const new({required this.record});

  final ConsentRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormatter.dateTime(record.grantedAt),
            style: theme.textTheme.titleSmall,
          ),
          Text(
            l10n.consentHistoryVersion(record.version),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final scope in ConsentScope.values)
                if (record.grantedScopes.contains(scope))
                  Chip(
                    avatar: const Icon(Icons.check, size: AppSizes.iconSm),
                    label: Text(
                      scope.isRequired
                          ? l10n.consentScopeRequired
                          : l10n.consentScopeOptional,
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

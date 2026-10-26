import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:msu_wellbeing/core/router/app_routes.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/utils/date_formatter.dart';
import 'package:msu_wellbeing/core/utils/link_launcher.dart';
import 'package:msu_wellbeing/core/widgets/app_card.dart';
import 'package:msu_wellbeing/core/widgets/hero_card.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/illustration.dart';
import 'package:msu_wellbeing/core/widgets/section_header.dart';
import 'package:msu_wellbeing/core/widgets/state_views.dart';
import 'package:msu_wellbeing/features/assessment/domain/entities/assessment_report.dart';
import 'package:msu_wellbeing/features/assessment/presentation/controllers/reports_controller.dart';
import 'package:msu_wellbeing/features/remote_config/presentation/controllers/remote_config_controller.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Beranda section with the newest report, or an invitation to take the
/// assessment on the website.
class LatestReportSection extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final reports = ref.watch(reportsProvider);
    final hasReports = reports.value?.isNotEmpty ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.reportLatestTitle,
          actionLabel: hasReports ? l10n.reportSeeAll : null,
          onAction: () => context.push(AppRoutes.reports),
        ),
        switch (reports) {
          AsyncData(:final value) when value.isEmpty => const _NoReportCard(),
          AsyncData(:final value) => ReportSummaryCard(report: value.first),
          AsyncError(:final error) => AppCard(
            child: ErrorView(
              error: error,
              onRetry: () => ref.invalidate(reportsProvider),
            ),
          ),
          _ => const AppCard(child: LoadingView(compact: true)),
        },
      ],
    );
  }
}

/// Title, date, plain-language summary, and "Lihat detail".
class ReportSummaryCard extends StatelessWidget {
  const new({required this.report, super.key});

  final AssessmentReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    void open() => context.push(AppRoutes.report(report.id));
    return AppCard(
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GradientIconBadge(icon: Icons.insights_outlined),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.title, style: theme.textTheme.titleMedium),
                    Text(
                      l10n.reportTakenAt(
                        DateFormatter.fullDate(report.takenAt),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(report.summary, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                l10n.reportSeeDetail,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.arrow_forward,
                size: AppSizes.iconSm,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoReportCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final url = ref.watch(
      remoteConfigProvider.select((c) => c.value?.assessmentWebsiteUrl),
    );
    Future<void> openWebsite() async {
      final opened = await ref.read(linkLauncherProvider).open(Uri.parse(url!));
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.linkOpenFailed)));
      }
    }

    return AppCard(
      child: EmptyView(
        illustration: IllustrationKind.noReport,
        title: l10n.reportEmptyTitle,
        actionLabel: url == null || url.isEmpty ? null : l10n.reportEmptyAction,
        onAction: url == null || url.isEmpty ? null : openWebsite,
      ),
    );
  }
}

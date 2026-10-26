import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:msu_wellbeing/core/router/app_routes.dart';
import 'package:msu_wellbeing/core/security/secure_screen.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/utils/date_formatter.dart';
import 'package:msu_wellbeing/core/widgets/app_card.dart';
import 'package:msu_wellbeing/core/widgets/hero_card.dart';
import 'package:msu_wellbeing/core/widgets/state_views.dart';
import 'package:msu_wellbeing/features/assessment/domain/entities/assessment_report.dart';
import 'package:msu_wellbeing/features/assessment/presentation/controllers/reports_controller.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Read-only report. Sections are shown exactly as the API provides them.
/// Screenshots are blocked while visible.
class ReportDetailScreen extends ConsumerWidget {
  const new({required this.reportId, super.key});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reportDetailProvider(reportId));
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.reportListTitle)),
        body: switch (report) {
          AsyncData(:final value) => _ReportBody(report: value),
          AsyncError(:final error) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(reportDetailProvider(reportId)),
          ),
          _ => const LoadingView(),
        },
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const new({required this.report});

  final AssessmentReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final onBrand = context.gradients.onBrand;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        HeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.insights_outlined, color: onBrand),
              const SizedBox(height: AppSpacing.md),
              Text(
                report.title,
                style: theme.textTheme.headlineSmall?.copyWith(color: onBrand),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.reportTakenAt(DateFormatter.fullDate(report.takenAt)),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: onBrand.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                report.summary,
                style: theme.textTheme.bodyLarge?.copyWith(color: onBrand),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final section in report.sections) ...[
          _SectionCard(section: section),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.md),
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.reportDisclaimer,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => context.go(AppRoutes.chatPsychologist),
                  icon: const Icon(Icons.person_outline),
                  label: Text(l10n.reportContactPsychologist),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const new({required this.section});

  final ReportSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = section.level;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.heading, style: theme.textTheme.titleMedium),
          if (level != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Chip(label: Text(level)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(section.body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

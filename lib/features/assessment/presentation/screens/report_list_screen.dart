import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/illustration.dart';
import 'package:msu_wellbeing/core/widgets/state_views.dart';
import 'package:msu_wellbeing/features/assessment/presentation/controllers/reports_controller.dart';
import 'package:msu_wellbeing/features/assessment/presentation/widgets/report_widgets.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// All reports, newest first.
class ReportListScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final reports = ref.watch(reportsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportListTitle)),
      body: switch (reports) {
        AsyncData(:final value) when value.isEmpty => EmptyView(
          illustration: IllustrationKind.noReport,
          title: l10n.reportEmptyTitle,
        ),
        AsyncData(:final value) => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.screen),
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) =>
              ReportSummaryCard(report: value[index]),
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(reportsProvider),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

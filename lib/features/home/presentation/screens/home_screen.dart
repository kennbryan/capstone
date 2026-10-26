import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/msu_logo.dart';
import 'package:msu_wellbeing/core/widgets/tab_scaffold.dart';
import 'package:msu_wellbeing/features/assessment/presentation/controllers/reports_controller.dart';
import 'package:msu_wellbeing/features/assessment/presentation/widgets/report_widgets.dart';
import 'package:msu_wellbeing/features/checkin/presentation/controllers/checkin_controller.dart';
import 'package:msu_wellbeing/features/home/presentation/controllers/home_controllers.dart';
import 'package:msu_wellbeing/features/home/presentation/widgets/daily_focus_card.dart';
import 'package:msu_wellbeing/features/home/presentation/widgets/home_sections.dart';
import 'package:msu_wellbeing/features/home/presentation/widgets/mood_insight_card.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Beranda: greeting, check-in, weekly strip, latest report, quick
/// actions, and recommendations, in that order.
class HomeScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() async {
      ref
        ..invalidate(checkInControllerProvider)
        ..invalidate(reportsProvider)
        ..invalidate(homeRecommendationsProvider);
      try {
        await ref.read(reportsProvider.future);
      } on Object {
        // The report section shows its own error state.
      }
    }

    return TabScaffold(
      title: context.l10n.navHome,
      titleWidget: Row(
        children: [
          const MsuLogo(size: AppSizes.logoXs),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: Text(context.l10n.appTitle)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.sm,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          children: const [
            HomeHero(),
            SizedBox(height: AppSpacing.lg),
            DailyFocusCard(),
            SizedBox(height: AppSpacing.xl),
            MoodInsightCard(),
            SizedBox(height: AppSpacing.xl),
            LatestReportSection(),
            SizedBox(height: AppSpacing.xl),
            QuickActions(),
            SizedBox(height: AppSpacing.xl),
            RecommendationsSection(),
          ],
        ),
      ),
    );
  }
}

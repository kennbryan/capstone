import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/section_header.dart';
import 'package:msu_wellbeing/core/widgets/state_views.dart';
import 'package:msu_wellbeing/core/widgets/tab_scaffold.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/article.dart';
import 'package:msu_wellbeing/features/learn/presentation/controllers/learn_controllers.dart';
import 'package:msu_wellbeing/features/learn/presentation/widgets/article_widgets.dart';
import 'package:msu_wellbeing/features/learn/presentation/widgets/exercise_tiles.dart';
import 'package:msu_wellbeing/features/learn/presentation/widgets/garden_header.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Belajar: garden, relaxation exercises, and topic-filtered articles.
/// Light and relaxing: no scores, quizzes, or win/lose states.
class LearnScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  ArticleTopic? _topic;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final articles = ref.watch(articlesProvider(topic: _topic));

    return TabScaffold(
      title: l10n.navLearn,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.sm,
          AppSpacing.screen,
          AppSpacing.xxl,
        ),
        children: [
          const GardenHeader(),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: l10n.learnExercisesTitle),
          const ExerciseCarousel(),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: l10n.learnMaterialsTitle),
          TopicChips(
            selected: _topic,
            onChanged: (topic) => setState(() => _topic = topic),
          ),
          const SizedBox(height: AppSpacing.md),
          switch (articles) {
            AsyncData(:final value) when value.isEmpty => EmptyView(
              title: l10n.learnArticlesEmpty,
            ),
            AsyncData(:final value) => Column(
              children: [
                for (final article in value) ...[
                  ArticleCard(article: article),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
            AsyncError(:final error) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(articlesProvider(topic: _topic)),
            ),
            _ => const LoadingView(compact: true),
          },
        ],
      ),
    );
  }
}

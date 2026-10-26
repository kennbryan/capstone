import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:msu_wellbeing/core/router/app_routes.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/app_card.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/article.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Display name of a topic.
String topicLabel(AppLocalizations l10n, ArticleTopic topic) => switch (topic) {
  ArticleTopic.stres => l10n.topicStres,
  ArticleTopic.tidur => l10n.topicTidur,
  ArticleTopic.kecemasan => l10n.topicKecemasan,
  ArticleTopic.hubungan => l10n.topicHubungan,
  ArticleTopic.kuliah => l10n.topicKuliah,
};

/// Icon for a topic.
IconData topicIcon(ArticleTopic topic) => switch (topic) {
  ArticleTopic.stres => Icons.self_improvement,
  ArticleTopic.tidur => Icons.bedtime_outlined,
  ArticleTopic.kecemasan => Icons.spa_outlined,
  ArticleTopic.hubungan => Icons.people_outline,
  ArticleTopic.kuliah => Icons.school_outlined,
};

/// Soft sky-gradient square with the topic icon.
class TopicThumbnail extends StatelessWidget {
  const new({required this.topic, super.key});

  final ArticleTopic topic;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.thumbnail,
      height: AppSizes.thumbnail,
      decoration: BoxDecoration(
        gradient: context.gradients.sky,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Icon(
        topicIcon(topic),
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Single-select topic filter. Tapping the active chip shows all topics.
class TopicChips extends StatelessWidget {
  const new({required this.selected, required this.onChanged, super.key});

  final ArticleTopic? selected;
  final ValueChanged<ArticleTopic?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final topic in ArticleTopic.values)
          ChoiceChip(
            avatar: Icon(topicIcon(topic), size: AppSizes.iconSm),
            label: Text(topicLabel(l10n, topic)),
            selected: topic == selected,
            onSelected: (isSelected) => onChanged(isSelected ? topic : null),
          ),
      ],
    );
  }
}

/// Title, reading time, and the reviewed badge.
class ArticleCard extends StatelessWidget {
  const new({required this.article, super.key});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.push(AppRoutes.article(article.id)),
      child: Row(
        children: [
          TopicThumbnail(topic: article.topic),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(article.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${topicLabel(l10n, article.topic)} · '
                      '${l10n.readingTime(article.readingMinutes)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (article.reviewed) const ReviewedBadge(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Ditinjau oleh psikolog".
class ReviewedBadge extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs / 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_outlined,
              size: AppSizes.iconSm,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              context.l10n.learnReviewedBadge,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/state_views.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/article.dart';
import 'package:msu_wellbeing/features/learn/presentation/controllers/learn_controllers.dart';
import 'package:msu_wellbeing/features/learn/presentation/widgets/article_widgets.dart';
import 'package:msu_wellbeing/features/learn/presentation/widgets/markdown_text.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// Title, topic, reading time, reviewer, body, and source reference.
class ArticleScreen extends ConsumerWidget {
  const new({required this.articleId, super.key});

  final String articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final article = ref.watch(articleDetailProvider(articleId));
    return Scaffold(
      appBar: AppBar(),
      body: switch (article) {
        AsyncData(:final value) => _ArticleBody(article: value),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(articleDetailProvider(articleId)),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class _ArticleBody extends StatelessWidget {
  const new({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final reviewer = article.reviewerName;
    final source = article.sourceRef;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        AppSpacing.xxl,
      ),
      children: [
        Text(article.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${topicLabel(l10n, article.topic)} · '
          '${l10n.readingTime(article.readingMinutes)}',
          style: theme.textTheme.bodySmall,
        ),
        if (article.reviewed) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: reviewer == null
                ? const ReviewedBadge()
                : Text(
                    l10n.articleReviewer(reviewer),
                    style: theme.textTheme.bodySmall,
                  ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        MarkdownText(article.body),
        if (source != null) ...[
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.articleSource(source), style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

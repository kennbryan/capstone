import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:msu_wellbeing/core/router/app_routes.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/utils/date_formatter.dart';
import 'package:msu_wellbeing/core/widgets/app_card.dart';
import 'package:msu_wellbeing/core/widgets/hero_card.dart';
import 'package:msu_wellbeing/core/widgets/section_header.dart';
import 'package:msu_wellbeing/core/widgets/state_views.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/auth_controller.dart';
import 'package:msu_wellbeing/features/chat/presentation/widgets/assistant_avatar.dart';
import 'package:msu_wellbeing/features/home/presentation/controllers/home_controllers.dart';
import 'package:msu_wellbeing/features/home/presentation/widgets/day_sky.dart';
import 'package:msu_wellbeing/features/home/presentation/widgets/hero_check_in.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/article.dart';
import 'package:msu_wellbeing/features/learn/presentation/widgets/article_widgets.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// The one solid brand card on Beranda: date, "Halo, {displayName}", a
/// small sky for the time of day, a calm line, and the one-tap check-in.
class HomeHero extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final onBrand = context.gradients.onBrand;
    final name = ref.watch(
      authControllerProvider.select((s) => s.value?.displayName ?? ''),
    );

    final now = DateTime.now();
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormatter.heroDate(now),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onBrand.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.homeGreeting(name),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: onBrand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              DaySky(part: DayPart.of(now)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.homeGreetingLine,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onBrand.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const HeroCheckIn(),
        ],
      ),
    );
  }
}

/// Two entry points: the AI assistant (its own blue avatar) and the
/// psychologist (green person badge), so they are never confused. Light
/// cards, so the hero stays the only solid brand block.
class QuickActions extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gradients = context.gradients;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _QuickAction(
              badge: const AssistantAvatar(size: AppSizes.tileIcon),
              label: l10n.quickActionAssistant,
              hint: l10n.quickActionAssistantHint,
              onTap: () => context.go(AppRoutes.chatAssistant),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _QuickAction(
              badge: GradientIconBadge(
                icon: Icons.support_agent_outlined,
                gradient: gradients.brand,
              ),
              label: l10n.quickActionPsychologist,
              hint: l10n.quickActionPsychologistHint,
              onTap: () => context.go(AppRoutes.chatPsychologist),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const new({
    required this.badge,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final Widget badge;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            badge,
            const SizedBox(height: AppSpacing.md),
            Text(label, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(hint, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// "Rekomendasi untukmu": articles matched to today's mood.
class RecommendationsSection extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final items = ref.watch(homeRecommendationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.recommendationsTitle),
        Text(l10n.recommendationsCaption, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        switch (items) {
          AsyncData(:final value) when value.isEmpty => const SizedBox.shrink(),
          AsyncData(:final value) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final article in value) ...[
                    _RecommendationCard(article: article),
                    const SizedBox(width: AppSpacing.md),
                  ],
                ],
              ),
            ),
          ),
          AsyncError() => const SizedBox.shrink(),
          _ => const LoadingView(compact: true),
        },
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const new({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SizedBox(
      width: AppSizes.carouselCard,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () => context.push(AppRoutes.article(article.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TopicThumbnail(topic: article.topic),
            const SizedBox(height: AppSpacing.md),
            Text(
              topicLabel(l10n, article.topic),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              article.title,
              style: theme.textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.readingTime(article.readingMinutes),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

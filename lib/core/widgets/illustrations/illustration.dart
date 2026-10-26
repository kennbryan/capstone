import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/empty_painters.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/illustration_palette.dart';
import 'package:msu_wellbeing/core/widgets/illustrations/scene_painters.dart';

/// The app's illustrations. All are drawn in code with soft, rounded flat
/// shapes in the theme palette, so they follow dark mode automatically.
enum IllustrationKind {
  /// Onboarding 1: a well-being companion.
  companion,

  /// Onboarding 2: AI assistant vs psychologist.
  aiAndHuman,

  /// Onboarding 3: help is always near.
  help,

  /// Headers: a plant growing under the sun.
  growth,

  /// No assessment report yet.
  noReport,

  /// No check-ins yet.
  noCheckins,

  /// New, empty conversation.
  emptyChat,

  /// Psychologist service not available yet.
  away,

  /// Error or no connection.
  offline,

  /// Generic calm empty state.
  calm,
}

/// Paints one [IllustrationKind]. Purely decorative: hidden from screen
/// readers, so the surrounding text carries the meaning.
class Illustration extends StatelessWidget {
  const new(
    this.kind, {
    this.height = AppSizes.illustration,
    this.onBrand = false,
    super.key,
  });

  /// Which scene to draw.
  final IllustrationKind kind;

  /// Height of the drawing; width follows a 5:4 ratio.
  final double height;

  /// Use white tints, for drawings placed on the solid brand color.
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final palette = onBrand
        ? IllustrationPalette.onBrand(context)
        : IllustrationPalette.of(context);
    final painter = switch (kind) {
      IllustrationKind.companion => CompanionScene(palette),
      IllustrationKind.aiAndHuman => AiAndHumanScene(palette),
      IllustrationKind.help => HelpScene(palette),
      IllustrationKind.growth => GrowthScene(palette),
      IllustrationKind.noReport => NoReportScene(palette),
      IllustrationKind.noCheckins => NoCheckinsScene(palette),
      IllustrationKind.emptyChat => EmptyChatScene(palette),
      IllustrationKind.away => AwayScene(palette),
      IllustrationKind.offline => OfflineScene(palette),
      IllustrationKind.calm => CalmScene(palette),
    };
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: height * 1.25,
        child: CustomPaint(painter: painter),
      ),
    );
  }
}

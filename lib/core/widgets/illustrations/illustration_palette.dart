import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';

/// Colors an illustration is painted with, taken from the active theme so
/// every drawing follows light and dark mode.
@immutable
class IllustrationPalette {
  const new({
    required this.leaf,
    required this.leafSoft,
    required this.backdrop,
    required this.paper,
    required this.warm,
    required this.cool,
    required this.coolStrong,
    required this.line,
  });

  /// Palette for drawings on normal surfaces.
  factory of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final gradients = context.gradients;
    return IllustrationPalette(
      leaf: scheme.primary,
      leafSoft: Color.lerp(scheme.primary, colors.surfaceCard, 0.55)!,
      backdrop: scheme.primaryContainer,
      paper: colors.surfaceCard,
      warm: gradients.sun,
      cool: colors.assistant,
      coolStrong: gradients.ai.colors.first,
      line: colors.onSurfaceMuted,
    );
  }

  /// Palette for drawings on the solid brand color (white tints only).
  factory onBrand(BuildContext context) {
    final white = context.gradients.onBrand;
    final sun = context.gradients.sun;
    return IllustrationPalette(
      leaf: white,
      leafSoft: white.withValues(alpha: 0.55),
      backdrop: white.withValues(alpha: 0.12),
      paper: white.withValues(alpha: 0.9),
      warm: sun,
      cool: white.withValues(alpha: 0.3),
      coolStrong: white.withValues(alpha: 0.7),
      line: white.withValues(alpha: 0.6),
    );
  }

  /// Main green for leaves and figures.
  final Color leaf;

  /// Lighter green for secondary leaves.
  final Color leafSoft;

  /// Soft round backdrop behind each scene.
  final Color backdrop;

  /// Paper, bubbles and cards inside a scene.
  final Color paper;

  /// Warm accent: sun, flowers, hearts.
  final Color warm;

  /// Cool accent used for anything that belongs to the AI assistant.
  final Color cool;

  /// Stronger cool tone for the assistant figure itself.
  final Color coolStrong;

  /// Thin details: lines of text, eyes, outlines.
  final Color line;

  @override
  bool operator ==(Object other) =>
      other is IllustrationPalette &&
      other.leaf == leaf &&
      other.backdrop == backdrop &&
      other.paper == paper &&
      other.warm == warm &&
      other.cool == cool &&
      other.line == line;

  @override
  int get hashCode => Object.hash(leaf, backdrop, paper, warm, cool, line);
}

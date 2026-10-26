import 'package:flutter/material.dart';

/// Raw color tokens for one brightness. Widgets must not read these
/// directly; use `Theme.of(context).colorScheme`, [AppColorsExtension], or
/// [AppGradients].
@immutable
class AppPalette {
  const new({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.surface,
    required this.surfaceCard,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.outline,
    required this.assistant,
    required this.onAssistant,
    required this.crisis,
    required this.onCrisis,
    required this.crisisContainer,
    required this.onCrisisContainer,
    required this.scrim,
    required this.brandStart,
    required this.brandEnd,
    required this.aiStart,
    required this.aiEnd,
    required this.skyTop,
    required this.skyBottom,
    required this.sun,
    required this.moods,
  });

  // TODO(DKMSU): replace with the official MSU primary hex once confirmed.
  static const light = AppPalette(
    primary: Color(0xFF1F7A4D),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE3F2E9),
    onPrimaryContainer: Color(0xFF0F3D26),
    surface: Color(0xFFF6F8F6),
    surfaceCard: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1C2420),
    onSurfaceMuted: Color(0xFF5E6A63),
    outline: Color(0xFFDDE3DF),
    assistant: Color(0xFFE8EEF8),
    onAssistant: Color(0xFF1F2D44),
    crisis: Color(0xFFB3261E),
    onCrisis: Color(0xFFFFFFFF),
    crisisContainer: Color(0xFFFCEEEE),
    onCrisisContainer: Color(0xFF5C1A16),
    scrim: Color(0xFF000000),
    brandStart: Color(0xFF1F7A4D),
    brandEnd: Color(0xFF177E6E),
    aiStart: Color(0xFF2F4C7E),
    aiEnd: Color(0xFF4A6AA6),
    skyTop: Color(0xFFD7EFE2),
    skyBottom: Color(0xFFF4FAF6),
    sun: Color(0xFFF2D38B),
    moods: [
      Color(0xFF8C97AD),
      Color(0xFF8FAABD),
      Color(0xFFC8B57D),
      Color(0xFF5DB487),
      Color(0xFF1F7A4D),
    ],
  );

  static const dark = AppPalette(
    primary: Color(0xFF7CC9A0),
    onPrimary: Color(0xFF0B2E1D),
    primaryContainer: Color(0xFF1E3A2B),
    onPrimaryContainer: Color(0xFFCDEBD9),
    surface: Color(0xFF111412),
    surfaceCard: Color(0xFF1B1F1C),
    onSurface: Color(0xFFE3E7E4),
    onSurfaceMuted: Color(0xFFA3ADA7),
    outline: Color(0xFF2E3531),
    assistant: Color(0xFF1E2633),
    onAssistant: Color(0xFFD3DDEE),
    crisis: Color(0xFFF2B8B5),
    onCrisis: Color(0xFF601410),
    crisisContainer: Color(0xFF3B1F1E),
    onCrisisContainer: Color(0xFFF9DEDC),
    scrim: Color(0xFF000000),
    brandStart: Color(0xFF17573A),
    brandEnd: Color(0xFF145E55),
    aiStart: Color(0xFF26385A),
    aiEnd: Color(0xFF34507F),
    skyTop: Color(0xFF1B2D24),
    skyBottom: Color(0xFF151A17),
    sun: Color(0xFFB89A55),
    moods: [
      Color(0xFF7D879B),
      Color(0xFF7F9AAD),
      Color(0xFFB5A26C),
      Color(0xFF5DB487),
      Color(0xFF7CC9A0),
    ],
  );

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color surface;
  final Color surfaceCard;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color outline;
  final Color assistant;
  final Color onAssistant;

  /// Crisis tokens: only the crisis screen and crisis cards may use them.
  final Color crisis;
  final Color onCrisis;
  final Color crisisContainer;
  final Color onCrisisContainer;
  final Color scrim;

  /// Brand fill (white text on it keeps ≥ 4.5:1 contrast). [brandEnd] is
  /// the calm teal accent.
  final Color brandStart;
  final Color brandEnd;

  /// AI assistant fill (cool blue, never green, so it is never mistaken for
  /// the psychologist channel).
  final Color aiStart;
  final Color aiEnd;

  /// Garden sky and sun.
  final Color skyTop;
  final Color skyBottom;
  final Color sun;

  /// Calm mood scale from 1 (very heavy) to 5 (very good). No red.
  final List<Color> moods;
}

/// Custom tokens not covered by [ColorScheme].
@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const new({
    required this.surfaceCard,
    required this.onSurfaceMuted,
    required this.assistant,
    required this.onAssistant,
    required this.crisis,
    required this.onCrisis,
    required this.crisisContainer,
    required this.onCrisisContainer,
  });

  factory fromPalette(AppPalette palette) => AppColorsExtension(
    surfaceCard: palette.surfaceCard,
    onSurfaceMuted: palette.onSurfaceMuted,
    assistant: palette.assistant,
    onAssistant: palette.onAssistant,
    crisis: palette.crisis,
    onCrisis: palette.onCrisis,
    crisisContainer: palette.crisisContainer,
    onCrisisContainer: palette.onCrisisContainer,
  );

  final Color surfaceCard;
  final Color onSurfaceMuted;
  final Color assistant;
  final Color onAssistant;
  final Color crisis;
  final Color onCrisis;
  final Color crisisContainer;
  final Color onCrisisContainer;

  @override
  AppColorsExtension copyWith({
    Color? surfaceCard,
    Color? onSurfaceMuted,
    Color? assistant,
    Color? onAssistant,
    Color? crisis,
    Color? onCrisis,
    Color? crisisContainer,
    Color? onCrisisContainer,
  }) {
    return AppColorsExtension(
      surfaceCard: surfaceCard ?? this.surfaceCard,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      assistant: assistant ?? this.assistant,
      onAssistant: onAssistant ?? this.onAssistant,
      crisis: crisis ?? this.crisis,
      onCrisis: onCrisis ?? this.onCrisis,
      crisisContainer: crisisContainer ?? this.crisisContainer,
      onCrisisContainer: onCrisisContainer ?? this.onCrisisContainer,
    );
  }

  @override
  AppColorsExtension lerp(AppColorsExtension? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColorsExtension(
      surfaceCard: mix(surfaceCard, other.surfaceCard),
      onSurfaceMuted: mix(onSurfaceMuted, other.onSurfaceMuted),
      assistant: mix(assistant, other.assistant),
      onAssistant: mix(onAssistant, other.onAssistant),
      crisis: mix(crisis, other.crisis),
      onCrisis: mix(onCrisis, other.onCrisis),
      crisisContainer: mix(crisisContainer, other.crisisContainer),
      onCrisisContainer: mix(onCrisisContainer, other.onCrisisContainer),
    );
  }
}

/// Brand surfaces (flat fills) and data-visualization colors.
@immutable
class AppGradients extends ThemeExtension<AppGradients> {
  const new({
    required this.brand,
    required this.ai,
    required this.soft,
    required this.sky,
    required this.sun,
    required this.moods,
    required this.onBrand,
    required this.accent,
  });

  /// Every fill is a flat tonal color (both stops equal): the design uses
  /// calm solid surfaces, not color gradients.
  factory fromPalette(AppPalette p) => AppGradients(
    brand: _flat(p.brandStart),
    ai: _flat(p.aiStart),
    soft: _flat(p.primaryContainer),
    sky: _flat(p.skyTop),
    sun: p.sun,
    moods: p.moods,
    onBrand: const Color(0xFFFFFFFF),
    accent: p.brandEnd,
  );

  static LinearGradient _flat(Color color) =>
      LinearGradient(colors: [color, color]);

  /// Hero headers, primary highlights.
  final LinearGradient brand;

  /// AI assistant accents.
  final LinearGradient ai;

  /// Subtle tinted cards.
  final LinearGradient soft;

  /// Garden and exercise backgrounds.
  final LinearGradient sky;
  final Color sun;

  /// Mood 1–5 colors; use [mood].
  final List<Color> moods;

  /// Text and icons on [brand] and [ai].
  final Color onBrand;

  /// Calm teal for a third solid surface (the sounds exercise tile).
  final Color accent;

  /// Color for a mood value from 1 to 5.
  Color mood(int value) => moods[(value - 1).clamp(0, moods.length - 1)];

  @override
  AppGradients copyWith({
    LinearGradient? brand,
    LinearGradient? ai,
    LinearGradient? soft,
    LinearGradient? sky,
    Color? sun,
    List<Color>? moods,
    Color? onBrand,
    Color? accent,
  }) {
    return AppGradients(
      brand: brand ?? this.brand,
      ai: ai ?? this.ai,
      soft: soft ?? this.soft,
      sky: sky ?? this.sky,
      sun: sun ?? this.sun,
      moods: moods ?? this.moods,
      onBrand: onBrand ?? this.onBrand,
      accent: accent ?? this.accent,
    );
  }

  @override
  AppGradients lerp(AppGradients? other, double t) {
    if (other == null) return this;
    return AppGradients(
      brand: LinearGradient.lerp(brand, other.brand, t)!,
      ai: LinearGradient.lerp(ai, other.ai, t)!,
      soft: LinearGradient.lerp(soft, other.soft, t)!,
      sky: LinearGradient.lerp(sky, other.sky, t)!,
      sun: Color.lerp(sun, other.sun, t)!,
      moods: [
        for (var i = 0; i < moods.length; i++)
          Color.lerp(moods[i], other.moods[i], t)!,
      ],
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

/// Shorthand for the custom color tokens.
extension AppColorsContext on BuildContext {
  AppColorsExtension get appColors =>
      Theme.of(this).extension<AppColorsExtension>()!;

  AppGradients get gradients => Theme.of(this).extension<AppGradients>()!;
}

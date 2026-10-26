import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';
import 'package:msu_wellbeing/core/theme/app_typography.dart';

/// Builds the light and dark [ThemeData] from the color tokens.
///
/// Surfaces are flat (elevation 0), separated by outline borders or tonal
/// fills. No gradients, no patterns.
abstract final class AppTheme {
  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.primaryContainer,
      onPrimaryContainer: p.onPrimaryContainer,
      secondary: p.primary,
      onSecondary: p.onPrimary,
      secondaryContainer: p.primaryContainer,
      onSecondaryContainer: p.onPrimaryContainer,
      tertiary: p.primary,
      onTertiary: p.onPrimary,
      tertiaryContainer: p.primaryContainer,
      onTertiaryContainer: p.onPrimaryContainer,
      // Red is reserved for crisis UI, so validation feedback stays calm.
      error: p.onSurfaceMuted,
      onError: p.surfaceCard,
      errorContainer: p.primaryContainer,
      onErrorContainer: p.onPrimaryContainer,
      surface: p.surface,
      onSurface: p.onSurface,
      onSurfaceVariant: p.onSurfaceMuted,
      surfaceDim: p.surface,
      surfaceBright: p.surfaceCard,
      surfaceContainerLowest: p.surfaceCard,
      surfaceContainerLow: p.surfaceCard,
      surfaceContainer: p.surfaceCard,
      surfaceContainerHigh: p.surfaceCard,
      surfaceContainerHighest: p.surface,
      outline: p.outline,
      outlineVariant: p.outline,
      shadow: p.scrim,
      scrim: p.scrim,
      inverseSurface: p.onSurface,
      onInverseSurface: p.surface,
      inversePrimary: p.primaryContainer,
      surfaceTint: Colors.transparent,
    );
    final text = AppTypography.textTheme(
      text: p.onSurface,
      muted: p.onSurfaceMuted,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
    );
    const buttonSize = Size(AppSizes.minTapTarget, AppSizes.minTapTarget);
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: AppSpacing.md,
    );
    final outlineSide = BorderSide(color: p.outline);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
      borderSide: outlineSide,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: p.surface,
      canvasColor: p.surface,
      extensions: [
        AppColorsExtension.fromPalette(p),
        AppGradients.fromPalette(p),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: p.surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: outlineSide,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
          foregroundColor: p.primary,
          side: outlineSide,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: text.labelLarge,
          foregroundColor: p.primary,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: buttonSize),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: p.surfaceCard,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: p.onSurfaceMuted),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: p.onSurfaceMuted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceCard,
        selectedColor: p.primaryContainer,
        labelStyle: text.labelMedium,
        side: outlineSide,
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surfaceCard,
        indicatorColor: p.primaryContainer,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: buttonSize,
          selectedBackgroundColor: p.primaryContainer,
          selectedForegroundColor: p.onPrimaryContainer,
          side: outlineSide,
          textStyle: text.labelLarge,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.outline,
        thickness: AppSizes.border,
        space: AppSizes.border,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.onSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.surface),
        shape: buttonShape,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceCard,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.card),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.onSurfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screen,
        ),
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.outline,
      ),
    );
  }
}

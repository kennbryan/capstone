import 'package:flutter/material.dart';

/// Type scale using the bundled Plus Jakarta Sans font.
///
/// | Role     | Size/weight | TextTheme slots                         |
/// |----------|-------------|-----------------------------------------|
/// | display  | 28/600      | displaySmall, headlineMedium            |
/// | title    | 20/600      | headlineSmall, titleLarge               |
/// | subtitle | 16/600      | titleMedium, titleSmall                 |
/// | body     | 15/400, 1.5 | bodyLarge, bodyMedium                   |
/// | caption  | 13/400      | bodySmall, labelSmall                   |
/// | label    | 15/600      | labelLarge (buttons), labelMedium 13/600|
abstract final class AppTypography {
  static const fontFamily = 'PlusJakartaSans';

  static TextTheme textTheme({required Color text, required Color muted}) {
    TextStyle style(
      double size,
      FontWeight weight, {
      double height = 1.4,
      Color? color,
    }) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color ?? text,
      );
    }

    final display = style(28, FontWeight.w600, height: 1.25);
    final title = style(20, FontWeight.w600, height: 1.3);
    final subtitle = style(16, FontWeight.w600);
    final body = style(15, FontWeight.w400, height: 1.5);
    final caption = style(13, FontWeight.w400, color: muted);

    return TextTheme(
      displayLarge: display,
      displayMedium: display,
      displaySmall: display,
      headlineLarge: display,
      headlineMedium: display,
      headlineSmall: title,
      titleLarge: title,
      titleMedium: subtitle,
      titleSmall: subtitle,
      bodyLarge: body,
      bodyMedium: body,
      bodySmall: caption,
      labelLarge: style(15, FontWeight.w600),
      labelMedium: style(13, FontWeight.w600),
      labelSmall: style(13, FontWeight.w500),
    );
  }
}

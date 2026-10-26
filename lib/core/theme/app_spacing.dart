import 'package:flutter/animation.dart';

/// Spacing scale (4, 8, 12, 16, 24, 32) and screen padding.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal padding for every screen.
  static const double screen = 20;
}

/// Corner radii.
abstract final class AppRadius {
  static const double card = 16;
  static const double tile = 20;
  static const double hero = 28;
  static const double button = 12;
  static const double chip = 999;
}

/// Fixed component sizes. Text never sits in fixed-height boxes.
abstract final class AppSizes {
  static const double minTapTarget = 48;
  static const double border = 1;
  static const double borderStrong = 2;
  static const double iconSm = 18;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double iconXl = 48;
  static const double avatar = 40;
  static const double avatarLg = 64;
  static const double moodFace = 36;
  static const double chartHeight = 128;
  static const double chartDot = 5;
  static const double chartStroke = 3;
  static const double gardenHeight = 150;
  static const double breathingMin = 120;
  static const double breathingMax = 240;
  static const double progressRing = 280;
  static const double logo = 96;
  static const double logoSm = 44;
  static const double logoXs = 32;
  static const double heroBubble = 160;
  static const double tileIcon = 44;
  static const double carouselCard = 220;
  static const double thumbnail = 56;
  static const double soundScene = 64;
  static const double illustration = 168;
  static const double illustrationSm = 112;
  static const double illustrationHeader = 88;
  static const double daySky = 64;
  static const double typingDot = 8;
  static const double pageDot = 8;
  static const double pageDotActive = 28;
  static const double bubbleMaxWidthFactor = 0.8;
  static const double maxContentWidth = 640;
}

/// Motion: 200–400 ms with an ease-out-cubic curve; charts draw in a bit
/// slower.
abstract final class AppDurations {
  static const short = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 300);
  static const long = Duration(milliseconds: 400);
  static const chart = Duration(milliseconds: 900);

  /// One slow drift of the exercise background shapes.
  static const ambient = Duration(seconds: 6);
  static const Curve curve = Curves.easeOutCubic;

  /// Longest time the splash screen may stay visible.
  static const splashMax = Duration(milliseconds: 1500);
}

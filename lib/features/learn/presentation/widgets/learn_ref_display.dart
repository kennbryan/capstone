import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/router/app_routes.dart';
import 'package:msu_wellbeing/features/learn/domain/entities/learn_ref.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';

/// How a [LearnRef] looks and where it leads.
extension LearnRefDisplay on LearnRef {
  IconData get icon => switch (kind) {
    LearnKind.article => Icons.menu_book_outlined,
    LearnKind.breathing => Icons.air,
    LearnKind.release => Icons.cloud_outlined,
    LearnKind.sounds => Icons.music_note_outlined,
  };

  /// Exercise titles come from l10n; article titles from the API.
  String displayTitle(AppLocalizations l10n) => switch (kind) {
    LearnKind.article => title,
    LearnKind.breathing => l10n.exerciseBreathingTitle,
    LearnKind.release => l10n.exerciseReleaseTitle,
    LearnKind.sounds => l10n.exerciseSoundsTitle,
  };

  String? subtitle(AppLocalizations l10n) => switch (kind) {
    LearnKind.article => null,
    LearnKind.breathing => l10n.exerciseBreathingSubtitle,
    LearnKind.release => l10n.exerciseReleaseSubtitle,
    LearnKind.sounds => l10n.exerciseSoundsSubtitle,
  };

  /// Route for this item, or null for an article without an id.
  String? get route => switch (kind) {
    LearnKind.article => id == null ? null : AppRoutes.article(id!),
    LearnKind.breathing => AppRoutes.breathing,
    LearnKind.release => AppRoutes.release,
    LearnKind.sounds => AppRoutes.sounds,
  };
}

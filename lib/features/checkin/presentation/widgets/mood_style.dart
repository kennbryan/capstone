import 'package:msu_wellbeing/l10n/l10n.dart';

/// Gentle, non-judgemental label for a mood from 1 to 5.
String moodLabel(AppLocalizations l10n, int mood) => switch (mood) {
  1 => l10n.mood1,
  2 => l10n.mood2,
  3 => l10n.mood3,
  4 => l10n.mood4,
  _ => l10n.mood5,
};

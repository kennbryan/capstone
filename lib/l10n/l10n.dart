import 'package:flutter/widgets.dart';
import 'package:msu_wellbeing/l10n/generated/app_localizations.dart';

export 'package:msu_wellbeing/l10n/generated/app_localizations.dart';

/// Shorthand for the generated localizations.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

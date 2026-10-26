import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'preferences_service.g.dart';

/// Non-sensitive UI preferences. Never store tokens, chat, notes, or
/// report content here.
class PreferencesService {
  new(this._prefs);

  final SharedPreferences _prefs;

  static const _onboardingSeen = 'onboarding.seen';
  static const _themeMode = 'ui.theme_mode';
  static const _haptics = 'learn.haptics';
  static const _gardenSessions = 'learn.garden_sessions';
  static const _remoteConfig = 'config.remote_cache';

  bool get onboardingSeen => _prefs.getBool(_onboardingSeen) ?? false;

  Future<void> setOnboardingSeen() => _prefs.setBool(_onboardingSeen, true);

  /// Stored as `system`, `light`, or `dark`.
  String? get themeMode => _prefs.getString(_themeMode);

  Future<void> setThemeMode(String value) =>
      _prefs.setString(_themeMode, value);

  bool get hapticsEnabled => _prefs.getBool(_haptics) ?? false;

  Future<void> setHapticsEnabled({required bool enabled}) =>
      _prefs.setBool(_haptics, enabled);

  int get gardenSessions => _prefs.getInt(_gardenSessions) ?? 0;

  Future<void> setGardenSessions(int value) =>
      _prefs.setInt(_gardenSessions, value);

  /// Last remote config JSON, used as a fallback when offline.
  String? get remoteConfigCache => _prefs.getString(_remoteConfig);

  Future<void> setRemoteConfigCache(String json) =>
      _prefs.setString(_remoteConfig, json);

  /// Clears per-user progress on logout. Device-level UI choices
  /// (theme, onboarding seen, cached config) are kept.
  Future<void> clearUserData() async {
    await _prefs.remove(_gardenSessions);
    await _prefs.remove(_haptics);
  }
}

/// Must be overridden in `main` with a loaded [SharedPreferences].
@Riverpod(keepAlive: true)
PreferencesService preferences(Ref ref) =>
    throw UnimplementedError('preferencesProvider must be overridden.');

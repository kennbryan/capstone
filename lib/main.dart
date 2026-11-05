import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:msu_wellbeing/app.dart';
import 'package:msu_wellbeing/core/config/app_config.dart';
import 'package:msu_wellbeing/core/logging/app_logger.dart';
import 'package:msu_wellbeing/core/network/session_source.dart';
import 'package:msu_wellbeing/core/storage/preferences_service.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fails fast on an unsafe build (e.g. prod with mock data or http).
  final config = AppConfig.fromEnvironment()..validate();
  AppLogger.verbose = !config.environment.isProd;
  _catchUncaughtErrors();
  await initializeDateFormatting('id');
  final prefs = await SharedPreferences.getInstance();
  final session = await _startSession(config);

  runApp(
    ProviderScope(
      // Show errors immediately with a "Coba lagi" button instead of
      // Riverpod's silent automatic retries.
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        preferencesProvider.overrideWithValue(PreferencesService(prefs)),
        sessionSourceProvider.overrideWithValue(session),
      ],
      child: const MsuWellbeingApp(),
    ),
  );
}

/// Connects Supabase Auth, restoring the saved session from secure
/// storage and refreshing it in the background.
Future<SessionSource> _startSession(AppConfig config) async {
  if (!config.hasSupabase) return const NoSessionSource();
  final supabase = await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(
      localStorage: SecureSessionStorage(FlutterSecureStorageService()),
      detectSessionInUri: false,
    ),
    // The SDK's debug log can include auth details.
    debug: false,
  );
  return SupabaseSessionSource(supabase.client.auth);
}

/// Records uncaught framework and async errors by type only (never their
/// message, which could quote user content) instead of letting them crash
/// the app silently. Debug builds still show Flutter's red error screen.
void _catchUncaughtErrors() {
  FlutterError.onError = (details) {
    AppLogger.error('flutter.uncaught', details.exception, details.stack);
    if (kDebugMode) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppLogger.error('platform.uncaught', error, stackTrace);
    return true;
  };
}

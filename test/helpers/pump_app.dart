import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:msu_wellbeing/app.dart';
import 'package:msu_wellbeing/core/security/app_lock_service.dart';
import 'package:msu_wellbeing/core/storage/preferences_service.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';
import 'package:msu_wellbeing/core/theme/app_theme.dart';
import 'package:msu_wellbeing/features/assessment/data/assessment_repository_impl.dart';
import 'package:msu_wellbeing/features/auth/data/auth_repository_impl.dart';
import 'package:msu_wellbeing/features/chat/data/chat_repository_impl.dart';
import 'package:msu_wellbeing/features/chat/data/sources/chat_sources.dart';
import 'package:msu_wellbeing/features/checkin/data/checkin_repository_impl.dart';
import 'package:msu_wellbeing/features/checkin/domain/checkin_repository.dart';
import 'package:msu_wellbeing/features/onboarding/data/consent_repository_impl.dart';
import 'package:msu_wellbeing/features/onboarding/data/sources/consent_sources.dart';
import 'package:msu_wellbeing/features/remote_config/data/remote_config_repository_impl.dart';
import 'package:msu_wellbeing/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_app_lock_service.dart';
import 'fakes.dart';
import 'in_memory_secure_storage.dart';

/// Shared test dependencies: fake backend sources, in-memory storage,
/// and mock SharedPreferences.
class TestDeps {
  new _(this.prefs, this.secureStorage, this.mockSettings);

  static Future<TestDeps> create({
    Map<String, Object> prefs = const {},
    MockSettings mockSettings = const MockSettings(instant: true),
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    await initializeDateFormatting('id');
    return TestDeps._(
      PreferencesService(await SharedPreferences.getInstance()),
      InMemorySecureStorage(),
      mockSettings,
    );
  }

  /// A returning user: onboarding seen, consent given, session stored.
  static Future<TestDeps> signedIn({
    MockSettings mockSettings = const MockSettings(instant: true),
  }) async {
    final deps = await create(
      prefs: {'onboarding.seen': true},
      mockSettings: mockSettings,
    );
    deps.secureStorage.values.addAll({
      SecureKeys.accessToken: 'mock-access-token',
      SecureKeys.user:
          '{"id":"usr_test","displayName":"Rani","email":"rani@example.com"}',
      SecureKeys.consentHistory:
          '[{"version":1,"grantedScopes":["processData"],'
          '"grantedAt":"2026-01-01T00:00:00.000Z"}]',
    });
    return deps;
  }

  final PreferencesService prefs;
  final InMemorySecureStorage secureStorage;
  final MockSettings mockSettings;
  final FakeAppLockService appLock = FakeAppLockService();

  /// Replaces the mock check-in backend when set.
  CheckInRepository? checkInRepository;

  List<Override> get overrides => [
    preferencesProvider.overrideWithValue(prefs),
    secureStorageProvider.overrideWithValue(secureStorage),
    appLockServiceProvider.overrideWithValue(appLock),
    // The backend, replaced by fakes (see fakes.dart).
    authRepositoryProvider.overrideWithValue(
      AuthRepositoryImpl(
        const FakeAuthSource(),
        secureStorage,
        demoLogin: true,
      ),
    ),
    assessmentRepositoryProvider.overrideWithValue(
      AssessmentRepositoryImpl(AssessmentMockSource(mockSettings)),
    ),
    checkInRepositoryProvider.overrideWithValue(
      checkInRepository ??
          CheckInRepositoryImpl(CheckInMockSource(mockSettings)),
    ),
    chatRepositoryProvider.overrideWithValue(
      ChatRepositoryImpl(
        ChatMockSource(mockSettings),
        ChatHistoryStore(secureStorage),
      ),
    ),
    remoteConfigRepositoryProvider.overrideWithValue(
      RemoteConfigRepositoryImpl(RemoteConfigMockSource(mockSettings), prefs),
    ),
    consentRepositoryProvider.overrideWithValue(
      ConsentRepositoryImpl(ConsentLocalSource(secureStorage)),
    ),
  ];

  ProviderContainer container([List<Override> extra = const []]) {
    final container = ProviderContainer(
      overrides: [...overrides, ...extra],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    return container;
  }
}

/// Pumps the full app.
Future<void> pumpApp(
  WidgetTester tester,
  TestDeps deps, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [...deps.overrides, ...overrides],
      child: const MsuWellbeingApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps a single widget inside a themed, localized [MaterialApp].
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child,
  TestDeps deps, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [...deps.overrides, ...overrides],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('id'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

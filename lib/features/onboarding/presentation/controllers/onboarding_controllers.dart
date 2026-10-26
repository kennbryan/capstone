import 'package:msu_wellbeing/core/network/api_exception.dart';
import 'package:msu_wellbeing/core/storage/preferences_service.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/auth_controller.dart';
import 'package:msu_wellbeing/features/onboarding/data/consent_repository_impl.dart';
import 'package:msu_wellbeing/features/onboarding/domain/entities/consent_record.dart';
import 'package:msu_wellbeing/features/remote_config/presentation/controllers/remote_config_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_controllers.g.dart';

/// Whether the intro slides were seen on this device.
@Riverpod(keepAlive: true)
class OnboardingController extends _$OnboardingController {
  @override
  bool build() => ref.watch(preferencesProvider).onboardingSeen;

  Future<void> complete() async {
    await ref.read(preferencesProvider).setOnboardingSeen();
    state = true;
  }
}

/// Consent history (oldest first). Reloads when the user changes, so a
/// logout (which wipes secure storage) resets it.
@Riverpod(keepAlive: true)
class ConsentController extends _$ConsentController {
  @override
  Future<List<ConsentRecord>> build() async {
    ref.watch(currentUserIdProvider);
    final result = await ref.watch(consentRepositoryProvider).loadHistory();
    return result.unwrap();
  }

  /// Records a new decision granting exactly [scopes] at the current
  /// consent version. Returns the failure, or null on success.
  Future<ApiException?> grant(Set<ConsentScope> scopes) async {
    final record = ConsentRecord(
      version: await _currentVersion(),
      grantedScopes: scopes,
      grantedAt: DateTime.now(),
    );
    final result = await ref.read(consentRepositoryProvider).record(record);
    return result.fold<ApiException?>(
      onSuccess: (saved) {
        state = AsyncData([...?state.value, saved]);
        return null;
      },
      onFailure: (error) => error,
    );
  }

  Future<int> _currentVersion() async {
    try {
      return (await ref.read(remoteConfigProvider.future)).consentVersion;
    } on Object {
      return state.value?.lastOrNull?.version ?? 1;
    }
  }
}

/// The latest consent decision, or null.
@Riverpod(keepAlive: true)
ConsentRecord? currentConsent(Ref ref) =>
    ref.watch(consentControllerProvider).value?.lastOrNull;

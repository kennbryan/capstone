import 'package:local_auth/local_auth.dart';
import 'package:msu_wellbeing/core/logging/app_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_lock_service.g.dart';

/// Biometric / device-credential authentication for the app lock.
class AppLockService {
  new([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Whether the device has biometrics or a screen lock to fall back to.
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on Exception catch (error, stackTrace) {
      AppLogger.error('app_lock.supported', error, stackTrace);
      return false;
    }
  }

  /// Prompts for biometrics, falling back to the device PIN/pattern.
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
    } on Exception catch (error, stackTrace) {
      AppLogger.error('app_lock.authenticate', error, stackTrace);
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
AppLockService appLockService(Ref ref) => AppLockService();

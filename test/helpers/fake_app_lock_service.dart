import 'package:msu_wellbeing/core/security/app_lock_service.dart';

/// [AppLockService] with scripted results instead of device biometrics.
class FakeAppLockService implements AppLockService {
  bool supported = true;
  bool authenticateResult = true;
  int prompts = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> authenticate({required String reason}) async {
    prompts++;
    return authenticateResult;
  }
}

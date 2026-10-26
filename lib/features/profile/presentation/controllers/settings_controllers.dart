import 'dart:async';

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:msu_wellbeing/core/security/app_lock_service.dart';
import 'package:msu_wellbeing/core/storage/preferences_service.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/auth_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_controllers.freezed.dart';
part 'settings_controllers.g.dart';

/// System / light / dark. Follows the system by default.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() {
    final stored = ref.watch(preferencesProvider).themeMode;
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> select(ThemeMode mode) async {
    await ref.read(preferencesProvider).setThemeMode(mode.name);
    state = mode;
  }
}

@freezed
abstract class AppLockState with _$AppLockState {
  const factory({required bool enabled, required bool locked}) = _AppLockState;
}

/// Outcome of changing the app-lock setting.
enum AppLockChange { changed, unsupported, failed }

/// App lock: when enabled, requires biometrics or the device credential on
/// launch and after more than 30 s in the background.
@Riverpod(keepAlive: true)
class AppLockController extends _$AppLockController {
  static const relockAfter = Duration(seconds: 30);

  /// Clock; tests can replace it.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  DateTime? _hiddenAt;

  @override
  Future<AppLockState> build() async {
    ref.watch(currentUserIdProvider);
    final listener = AppLifecycleListener(
      onHide: () => _hiddenAt = now(),
      onShow: _onShow,
    );
    ref.onDispose(listener.dispose);
    final stored = await ref
        .watch(secureStorageProvider)
        .read(SecureKeys.appLockEnabled);
    final enabled = stored == 'true';
    return AppLockState(enabled: enabled, locked: enabled);
  }

  void _onShow() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    final current = state.value;
    if (current == null || !current.enabled || hiddenAt == null) return;
    if (now().difference(hiddenAt) > relockAfter) {
      state = AsyncData(current.copyWith(locked: true));
    }
  }

  /// Prompts for biometrics / device credential. Returns true on success.
  Future<bool> unlock({required String reason}) async {
    final ok = await ref
        .read(appLockServiceProvider)
        .authenticate(reason: reason);
    final current = state.value;
    if (ok && current != null) {
      state = AsyncData(current.copyWith(locked: false));
    }
    return ok;
  }

  /// Turns the lock on or off after verifying the user.
  Future<AppLockChange> setEnabled({
    required bool enabled,
    required String reason,
  }) async {
    final service = ref.read(appLockServiceProvider);
    if (!await service.isSupported()) return AppLockChange.unsupported;
    if (!await service.authenticate(reason: reason)) {
      return AppLockChange.failed;
    }
    await ref
        .read(secureStorageProvider)
        .write(SecureKeys.appLockEnabled, enabled.toString());
    state = AsyncData(AppLockState(enabled: enabled, locked: false));
    return AppLockChange.changed;
  }
}

/// Whether the device can use the app lock.
@riverpod
Future<bool> appLockSupported(Ref ref) =>
    ref.watch(appLockServiceProvider).isSupported();

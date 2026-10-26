import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msu_wellbeing/core/network/api_exception.dart';
import 'package:msu_wellbeing/core/network/dio_client.dart';
import 'package:msu_wellbeing/core/storage/preferences_service.dart';
import 'package:msu_wellbeing/features/auth/data/auth_repository_impl.dart';
import 'package:msu_wellbeing/features/auth/domain/entities/user.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_controller.g.dart';

/// Current session. `null` means signed out.
///
/// User-scoped controllers watch [currentUserIdProvider], so they reset
/// automatically on logout.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  Future<User?> build() async {
    ref.listen(sessionExpiryProvider, (_, _) {
      // Demo sessions have no backend account, so the backend rejecting
      // their requests must not sign them out.
      if (!(state.value?.isDemo ?? false)) unawaited(logout());
    });
    final result = await ref.watch(authRepositoryProvider).restoreSession();
    return result.fold<User?>(
      onSuccess: (user) => user,
      onFailure: (_) => null,
    );
  }

  /// Signs in. Returns the failure, or null on success.
  Future<ApiException?> login({
    required String email,
    required String password,
  }) async {
    final result = await ref
        .read(authRepositoryProvider)
        .login(email: email.trim(), password: password);
    return result.fold<ApiException?>(
      onSuccess: (user) {
        state = AsyncData(user);
        return null;
      },
      onFailure: (error) => error,
    );
  }

  /// Returns the failure, or null on success.
  Future<ApiException?> updateDisplayName(String displayName) async {
    final result = await ref
        .read(authRepositoryProvider)
        .updateDisplayName(displayName);
    return result.fold<ApiException?>(
      onSuccess: (user) {
        state = AsyncData(user);
        return null;
      },
      onFailure: (error) => error,
    );
  }

  /// Clears tokens, chat history, consent, and cached user data.
  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    await ref.read(preferencesProvider).clearUserData();
    state = const AsyncData(null);
  }
}

/// Id of the signed-in user, or null.
@Riverpod(keepAlive: true)
String? currentUserId(Ref ref) =>
    ref.watch(authControllerProvider.select((state) => state.value?.id));

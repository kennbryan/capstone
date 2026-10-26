import 'dart:convert';

import 'package:msu_wellbeing/core/config/app_config.dart';
import 'package:msu_wellbeing/core/logging/app_logger.dart';
import 'package:msu_wellbeing/core/network/api_exception.dart';
import 'package:msu_wellbeing/core/network/dio_client.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';
import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/auth/data/models/user_dto.dart';
import 'package:msu_wellbeing/features/auth/data/sources/auth_source.dart';
import 'package:msu_wellbeing/features/auth/data/sources/demo_accounts.dart';
import 'package:msu_wellbeing/features/auth/domain/auth_repository.dart';
import 'package:msu_wellbeing/features/auth/domain/entities/user.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository_impl.g.dart';

/// Real sign-in goes to the backend. When [demoLogin] is on, the five
/// demo accounts sign in on the device without the backend; their data
/// screens still call the backend like any other user.
class AuthRepositoryImpl implements AuthRepository {
  const new(this._source, this._storage, {this.demoLogin = false});

  final AuthSource _source;
  final SecureStorageService _storage;

  /// Whether the demo accounts are accepted (never in `prod`).
  final bool demoLogin;

  @override
  Future<Result<User>> login({
    required String email,
    required String password,
  }) {
    return Result.guard('auth.login', () async {
      DemoAccount? demo;
      // Plain `if` on the compile-time constant: builds with
      // DEMO_LOGIN=false strip the demo accounts entirely.
      if (AppConfig.demoLoginEnabled) {
        if (demoLogin) demo = findDemoAccount(email, password);
      }
      final response = demo != null
          ? demoLoginResponse(demo)
          : await _source.login(email: email, password: password);
      await _storage.write(SecureKeys.accessToken, response.accessToken);
      await _storage.write(SecureKeys.refreshToken, response.refreshToken);
      await _saveUser(response.user);
      AppLogger.event('auth.login');
      return response.user.toEntity();
    });
  }

  @override
  Future<Result<User?>> restoreSession() {
    return Result.guard('auth.restore', () async {
      final token = await _storage.read(SecureKeys.accessToken);
      if (token == null) return null;
      var user = await _readUser();
      // Demo sessions have no account on the backend to refresh from.
      if (isDemoToken(token)) return user?.toEntity();
      try {
        final fresh = await _source.me();
        if (fresh != null) {
          user = fresh;
          await _saveUser(fresh);
        }
      } on Object catch (error) {
        if (ApiException.from(error).kind == ApiExceptionKind.unauthorized) {
          await logout();
          return null;
        }
        // Offline or server issue: keep the cached profile.
      }
      return user?.toEntity();
    });
  }

  @override
  Future<Result<User>> updateDisplayName(String displayName) {
    return Result.guard('auth.display_name', () async {
      final user = await _readUser();
      if (user == null) {
        throw const ApiException(ApiExceptionKind.unauthorized);
      }
      // TODO(backend): sync the nickname once the API exposes an endpoint.
      final updated = user.copyWith(displayName: displayName.trim());
      await _saveUser(updated);
      return updated.toEntity();
    });
  }

  @override
  Future<void> logout() async {
    await _storage.deleteAll();
    AppLogger.event('auth.logout');
  }

  Future<void> _saveUser(UserDto user) =>
      _storage.write(SecureKeys.user, jsonEncode(user.toJson()));

  Future<UserDto?> _readUser() async {
    final raw = await _storage.read(SecureKeys.user);
    if (raw == null) return null;
    return UserDto.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(
    AuthRemoteSource(ref.watch(dioProvider)),
    ref.watch(secureStorageProvider),
    demoLogin: AppConfig.demoLoginEnabled,
  );
}

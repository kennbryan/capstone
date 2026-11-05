import 'dart:async';

import 'package:msu_wellbeing/core/network/api_exception.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'session_source.g.dart';

/// The access token of a session and the account it belongs to.
class AuthToken {
  const new({required this.accessToken, required this.userId});

  final String accessToken;
  final String userId;
}

/// The single owner of the signed-in session: sign-in, the current
/// access token, refresh, and sign-out. The refresh token stays here and
/// is never sent to our backend.
abstract interface class SessionSource {
  /// The current session's token, or null when signed out.
  Future<AuthToken?> current();

  /// Throws an [ApiException]: `unauthorized` for a wrong email or
  /// password, `network` when offline.
  Future<void> signIn({required String email, required String password});

  /// Refreshes the session. Returns the new token, or null when the
  /// server rejected the session (it is then gone). Throws when the
  /// refresh could not run (offline), which keeps the session.
  Future<AuthToken?> refresh();

  /// Ends the session on this device. Never throws.
  Future<void> signOut();

  /// Fires when the session ends outside the app's own logout, e.g. the
  /// refresh token was revoked during a background refresh.
  Stream<void> get sessionEnded;
}

/// [SessionSource] backed by Supabase Auth (`SUPABASE_URL`).
class SupabaseSessionSource implements SessionSource {
  const new(this._auth);

  final GoTrueClient _auth;

  @override
  Future<AuthToken?> current() async => _token(_auth.currentSession);

  @override
  Stream<void> get sessionEnded => _auth.onAuthStateChange
      // Refresh failures arrive as stream errors; they are not a sign-out
      // (offline keeps the session), so they are dropped here.
      .handleError((Object _) {})
      .where((state) => state.event == AuthChangeEvent.signedOut)
      .map((_) {});

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
    } on Object catch (error) {
      throw _toApiException(error);
    }
  }

  @override
  Future<AuthToken?> refresh() async {
    if (_auth.currentSession == null) return null;
    try {
      await _auth.refreshSession();
    } on AuthRetryableFetchException {
      rethrow;
    } on AuthException {
      // Refresh token revoked or expired: the session is over.
      return null;
    }
    // Read the session again: a sign-out or another sign-in during the
    // refresh wins over the refreshed result.
    return _token(_auth.currentSession);
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on Object {
      // Offline: the local session is removed anyway.
    }
  }

  static AuthToken? _token(Session? session) => session == null
      ? null
      : AuthToken(accessToken: session.accessToken, userId: session.user.id);

  static ApiException _toApiException(Object error) {
    if (error is! AuthException) {
      return const ApiException(ApiExceptionKind.network);
    }
    if (error is AuthRetryableFetchException) {
      return error.statusCode == null
          ? const ApiException(ApiExceptionKind.network)
          : const ApiException(ApiExceptionKind.server);
    }
    final status = int.tryParse(error.statusCode ?? '');
    return switch (error.code) {
      'invalid_credentials' => const ApiException(
        ApiExceptionKind.unauthorized,
        statusCode: 401,
      ),
      'email_not_confirmed' || 'user_banned' => ApiException(
        ApiExceptionKind.forbidden,
        statusCode: status,
      ),
      _ when status == 400 => const ApiException(
        ApiExceptionKind.unauthorized,
        statusCode: 401,
      ),
      _ => ApiException(ApiExceptionKind.server, statusCode: status),
    };
  }
}

/// Used when the build has no `SUPABASE_URL`: nobody can sign in except
/// the demo accounts.
class NoSessionSource implements SessionSource {
  const new();

  @override
  Future<AuthToken?> current() async => null;

  @override
  Future<void> signIn({required String email, required String password}) =>
      Future.error(const ApiException(ApiExceptionKind.server));

  @override
  Future<AuthToken?> refresh() async => null;

  @override
  Future<void> signOut() async {}

  @override
  Stream<void> get sessionEnded => const Stream.empty();
}

/// Keeps the Supabase session (with its refresh token) in secure storage
/// instead of the SDK's default SharedPreferences.
class SecureSessionStorage extends LocalStorage {
  const new(this._storage);

  final SecureStorageService _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      await _storage.read(SecureKeys.authSession) != null;

  @override
  Future<String?> accessToken() => _storage.read(SecureKeys.authSession);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(SecureKeys.authSession, persistSessionString);

  @override
  Future<void> removePersistedSession() =>
      _storage.delete(SecureKeys.authSession);
}

/// Overridden in `main.dart` once Supabase is initialized.
@Riverpod(keepAlive: true)
SessionSource sessionSource(Ref ref) => const NoSessionSource();

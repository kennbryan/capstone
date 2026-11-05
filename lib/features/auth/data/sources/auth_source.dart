import 'package:dio/dio.dart';
import 'package:msu_wellbeing/core/network/session_source.dart';
import 'package:msu_wellbeing/features/auth/data/models/user_dto.dart';

/// Source of authentication data.
abstract interface class AuthSource {
  /// Signs in and returns the profile. Throws an `ApiException`;
  /// `unauthorized` means a wrong email or password.
  Future<UserDto> login({required String email, required String password});

  /// Whether a session survives from a previous run.
  Future<bool> hasSession();

  /// Fresh profile from the server, or null when the source has none,
  /// in which case the cached user is used.
  Future<UserDto?> me();

  /// Ends the session. Never throws.
  Future<void> logout();
}

/// Sign-in with the MSU assessment website account.
///
/// The app signs in to Supabase Auth directly (`SUPABASE_URL`,
/// `SUPABASE_PUBLISHABLE_KEY`), then calls the backend with the Supabase
/// access token:
///
/// `GET /me` (auth: `Authorization: Bearer <accessToken>`) returns 200:
/// ```json
/// { "id": "usr_123", "displayName": "Rani", "email": "rani@..." }
/// ```
/// 401: the token is not valid (the app refreshes once, then signs out);
/// 403: the account has no access to the app.
class AuthRemoteSource implements AuthSource {
  const new(this._dio, this._session);

  final Dio _dio;
  final SessionSource _session;

  @override
  Future<UserDto> login({
    required String email,
    required String password,
  }) async {
    await _session.signIn(email: email, password: password);
    try {
      return (await me())!;
    } on Object {
      // No half sign-in: without a profile, drop the new session.
      await _session.signOut();
      rethrow;
    }
  }

  @override
  Future<bool> hasSession() async => await _session.current() != null;

  @override
  Future<UserDto?> me() async {
    final response = await _dio.get<Map<String, Object?>>('/me');
    return UserDto.fromJson(response.data!);
  }

  @override
  Future<void> logout() => _session.signOut();
}

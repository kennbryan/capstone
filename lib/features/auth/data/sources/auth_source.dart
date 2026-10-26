import 'package:dio/dio.dart';
import 'package:msu_wellbeing/features/auth/data/models/user_dto.dart';

/// Source of authentication data.
abstract interface class AuthSource {
  Future<LoginResponseDto> login({
    required String email,
    required String password,
  });

  /// Fresh profile from the server, or null when the source has none
  /// (mock), in which case the cached user is used.
  Future<UserDto?> me();
}

/// Sign-in with the MSU assessment website account.
///
/// **For the backend team:**
///
/// `POST /auth/login` (no auth)
/// ```json
/// { "email": "rani@student.telkomuniversity.ac.id", "password": "..." }
/// ```
/// returns 200:
/// ```json
/// {
///   "accessToken": "eyJ...",
///   "refreshToken": "eyJ...",
///   "user": { "id": "usr_123", "displayName": "Rani", "email": "rani@..." }
/// }
/// ```
/// Wrong email or password: **401** (the app shows "Email atau kata sandi
/// belum sesuai"). Any other API call answering 401 signs the user out.
///
/// `GET /me` (auth: `Authorization: Bearer <accessToken>`) returns 200 with
/// the `user` object above; used to refresh the profile at app start.
class AuthRemoteSource implements AuthSource {
  const new(this._dio);

  final Dio _dio;

  @override
  Future<LoginResponseDto> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return LoginResponseDto.fromJson(response.data!);
  }

  @override
  Future<UserDto?> me() async {
    final response = await _dio.get<Map<String, Object?>>('/me');
    return UserDto.fromJson(response.data!);
  }
}

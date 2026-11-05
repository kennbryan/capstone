import 'package:dio/dio.dart';

/// Broad failure categories the UI can explain without exposing details.
enum ApiExceptionKind {
  network,
  timeout,
  unauthorized,

  /// Signed in, but the account may not use this (403).
  forbidden,

  /// The request was rejected as invalid (400/413/415/422).
  invalidInput,
  notFound,
  server,
  unknown,
}

/// A failure returned by repositories inside a `Failure` result.
///
/// Carries no response body, so it is safe to log.
class ApiException implements Exception {
  const new(this.kind, {this.statusCode});

  /// Maps any thrown object to an [ApiException].
  factory from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) return ApiException.fromDio(error);
    return const ApiException(ApiExceptionKind.unknown);
  }

  /// Maps a [DioException] to an [ApiException].
  factory fromDio(DioException error) {
    final status = error.response?.statusCode;
    final kind = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => ApiExceptionKind.timeout,
      DioExceptionType.connectionError => ApiExceptionKind.network,
      DioExceptionType.badResponse => switch (status) {
        401 => ApiExceptionKind.unauthorized,
        403 => ApiExceptionKind.forbidden,
        404 => ApiExceptionKind.notFound,
        408 => ApiExceptionKind.timeout,
        400 || 413 || 415 || 422 => ApiExceptionKind.invalidInput,
        _ => ApiExceptionKind.server,
      },
      _ => ApiExceptionKind.unknown,
    };
    return ApiException(kind, statusCode: status);
  }

  final ApiExceptionKind kind;
  final int? statusCode;

  @override
  String toString() => 'ApiException(${kind.name}, status: $statusCode)';
}

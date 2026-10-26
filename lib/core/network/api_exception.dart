import 'package:dio/dio.dart';

/// Broad failure categories the UI can explain without exposing details.
enum ApiExceptionKind {
  network,
  timeout,
  unauthorized,
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
        401 || 403 => ApiExceptionKind.unauthorized,
        404 => ApiExceptionKind.notFound,
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

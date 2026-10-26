import 'package:msu_wellbeing/core/logging/app_logger.dart';
import 'package:msu_wellbeing/core/network/api_exception.dart';

/// Outcome of a repository call: either [Success] or [Failure].
sealed class Result<T> {
  const new();

  /// Runs [body] and wraps its value, converting any error to a [Failure].
  ///
  /// [context] names the operation for logs; it must not contain user data.
  static Future<Result<T>> guard<T>(
    String context,
    Future<T> Function() body,
  ) async {
    try {
      return Success(await body());
    } on Object catch (error, stackTrace) {
      AppLogger.error(context, error, stackTrace);
      return Failure(ApiException.from(error));
    }
  }

  bool get isSuccess => this is Success<T>;

  /// Returns the value, or throws the [ApiException] so that `AsyncValue`
  /// in a controller captures it as an error state.
  T unwrap() => switch (this) {
    Success(:final value) => value,
    Failure(:final error) => throw error,
  };

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(ApiException error) onFailure,
  }) => switch (this) {
    Success(:final value) => onSuccess(value),
    Failure(:final error) => onFailure(error),
  };
}

/// A successful [Result] holding [value].
final class Success<T> extends Result<T> {
  const new(this.value);

  final T value;
}

/// A failed [Result] holding [error].
final class Failure<T> extends Result<T> {
  const new(this.error);

  final ApiException error;
}

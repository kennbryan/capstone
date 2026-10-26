import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/network/api_exception.dart';
import 'package:msu_wellbeing/core/utils/result.dart';

void main() {
  group('Result.guard', () {
    test('wraps a value in Success', () async {
      final result = await Result.guard('test', () async => 42);
      expect(result, isA<Success<int>>());
      expect(result.unwrap(), 42);
      expect(result.isSuccess, isTrue);
    });

    test('keeps an ApiException kind', () async {
      final result = await Result.guard<int>(
        'test',
        () async => throw const ApiException(ApiExceptionKind.notFound),
      );
      expect(result, isA<Failure<int>>());
      expect((result as Failure<int>).error.kind, ApiExceptionKind.notFound);
    });

    test('maps Dio errors to friendly kinds', () async {
      final options = RequestOptions(path: '/reports');
      Future<Result<int>> guardDio(DioException error) =>
          Result.guard<int>('test', () async => throw error);

      final offline = await guardDio(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      final unauthorized = await guardDio(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 401),
        ),
      );
      final timeout = await guardDio(
        DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
      );

      expect((offline as Failure).error.kind, ApiExceptionKind.network);
      expect(
        (unauthorized as Failure).error.kind,
        ApiExceptionKind.unauthorized,
      );
      expect((timeout as Failure).error.kind, ApiExceptionKind.timeout);
    });

    test('maps unknown errors to unknown', () async {
      final result = await Result.guard<int>(
        'test',
        () async => throw StateError('boom'),
      );
      expect((result as Failure).error.kind, ApiExceptionKind.unknown);
    });
  });

  test('unwrap throws the failure and fold picks the right branch', () {
    const failure = Failure<int>(ApiException(ApiExceptionKind.server));
    expect(failure.unwrap, throwsA(isA<ApiException>()));
    expect(
      failure.fold(onSuccess: (_) => 'ok', onFailure: (e) => e.kind.name),
      'server',
    );
    expect(
      const Success(1).fold(onSuccess: (v) => 'ok $v', onFailure: (_) => ''),
      'ok 1',
    );
  });
}

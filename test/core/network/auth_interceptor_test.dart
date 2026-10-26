import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/network/dio_client.dart';

class _Capture extends RequestInterceptorHandler {
  RequestOptions? options;

  @override
  void next(RequestOptions requestOptions) => options = requestOptions;
}

class _ErrorCapture extends ErrorInterceptorHandler {
  @override
  void next(DioException error) {}
}

void main() {
  var expired = 0;
  final interceptor = AuthInterceptor(
    readToken: () async => 'secret-token',
    onUnauthorized: () => expired++,
  );

  Future<RequestOptions> send(String path) async {
    final handler = _Capture();
    await interceptor.onRequest(
      RequestOptions(baseUrl: 'https://api.msu.example', path: path),
      handler,
    );
    return handler.options!;
  }

  test('the token is sent to our own API', () async {
    final options = await send('/reports');
    expect(options.headers['Authorization'], 'Bearer secret-token');
  });

  test('the token is never sent to another host', () async {
    final options = await send('https://other.example/collect');
    expect(options.headers.containsKey('Authorization'), isFalse);
  });

  test('a 401 on login is a wrong password, not an expired session', () {
    DioException unauthorized(String path) {
      final request = RequestOptions(
        baseUrl: 'https://api.msu.example',
        path: path,
      );
      return DioException(
        requestOptions: request,
        response: Response<void>(requestOptions: request, statusCode: 401),
      );
    }

    expired = 0;
    interceptor
      ..onError(unauthorized('/auth/login'), _ErrorCapture())
      ..onError(unauthorized('/reports'), _ErrorCapture());
    expect(expired, 1);
  });
}

import 'package:dio/dio.dart';
import 'package:msu_wellbeing/core/config/app_config.dart';
import 'package:msu_wellbeing/core/logging/app_logger.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dio_client.g.dart';

/// Attaches the bearer token (only to our own API host, never to another
/// server) and reports rejected sessions (401).
class AuthInterceptor extends Interceptor {
  new({required this.readToken, required this.onUnauthorized});

  final Future<String?> Function() readToken;
  final void Function() onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final sameHost = options.uri.host == Uri.parse(options.baseUrl).host;
    final token = sameHost ? await readToken() : null;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // A 401 from the login endpoint means wrong credentials, not an expired
    // session, so it must not trigger a sign-out.
    final isLogin = err.requestOptions.path.endsWith('/auth/login');
    if (err.response?.statusCode == 401 && !isLogin) onUnauthorized();
    handler.next(err);
  }
}

/// Logs method, path, and status only. Never bodies, queries, or headers.
class _EventLogInterceptor extends Interceptor {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final request = response.requestOptions;
    AppLogger.event('http', {
      'method': request.method,
      'path': request.uri.path,
      'status': response.statusCode ?? 0,
    });
    handler.next(response);
  }
}

/// Builds the configured [Dio]. Rejects `http://` base URLs outside dev.
Dio createDio({
  required AppConfig config,
  required AuthInterceptor authInterceptor,
}) {
  config.validate();
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
    ),
  );
  dio.interceptors.add(authInterceptor);
  if (!config.environment.isProd) dio.interceptors.add(_EventLogInterceptor());
  return dio;
}

/// Bumped whenever the API rejects the session; the auth controller
/// listens and signs the user out.
@Riverpod(keepAlive: true)
class SessionExpiry extends _$SessionExpiry {
  @override
  int build() => 0;

  void signal() => state++;
}

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final storage = ref.watch(secureStorageProvider);
  return createDio(
    config: ref.watch(appConfigProvider),
    authInterceptor: AuthInterceptor(
      readToken: () => storage.read(SecureKeys.accessToken),
      onUnauthorized: () => ref.read(sessionExpiryProvider.notifier).signal(),
    ),
  );
}

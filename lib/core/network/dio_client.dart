import 'dart:async';

import 'package:dio/dio.dart';
import 'package:msu_wellbeing/core/config/app_config.dart';
import 'package:msu_wellbeing/core/logging/app_logger.dart';
import 'package:msu_wellbeing/core/network/session_source.dart';
import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dio_client.g.dart';

/// Attaches the current access token (only to the client's own origin,
/// never to another server) and handles rejected tokens (401):
///
/// - the session that sent the request is still current: refresh once
///   (shared by concurrent requests) and retry once with the new token;
/// - the server rejects the refresh: [onUnauthorized] (sign out);
/// - the refresh cannot run (offline): pass the error on, stay signed in;
/// - the request was sent by a session that has since ended or switched
///   accounts: pass the error on, never sign the new account out;
/// - the request was sent without a session: [onUnauthorized], which the
///   auth controller ignores when nobody is signed in.
class AuthInterceptor extends Interceptor {
  new({
    required this.readToken,
    required this.refresh,
    required this.retry,
    required this.onUnauthorized,
  });

  final Future<AuthToken?> Function() readToken;

  /// See [SessionSource.refresh].
  final Future<AuthToken?> Function() refresh;

  /// Sends a request again through the same client.
  final Future<Response<dynamic>> Function(RequestOptions options) retry;
  final void Function() onUnauthorized;

  static const _sentAs = 'auth.sentAs';
  static const _retryFor = 'auth.retryFor';

  Future<AuthToken?>? _refreshing;

  /// Same scheme, host, and port as the client's base URL.
  static bool _ownOrigin(RequestOptions options) {
    final target = options.uri;
    final base = Uri.parse(options.baseUrl);
    return target.scheme == base.scheme &&
        target.host == base.host &&
        target.port == base.port;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_ownOrigin(options)) {
      options.headers.remove('Authorization');
      return handler.next(options);
    }
    final token = await readToken();
    final retryFor = options.extra[_retryFor];
    if (retryFor != null && token?.userId != retryFor) {
      // The account changed before the retry went out.
      return handler.reject(
        DioException(requestOptions: options, type: DioExceptionType.cancel),
      );
    }
    options.extra[_sentAs] = token;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer ${token.accessToken}';
    } else {
      options.headers.remove('Authorization');
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final sentAs = options.extra[_sentAs];
    if (err.response?.statusCode != 401 || !_ownOrigin(options)) {
      return handler.next(err);
    }
    if (sentAs is! AuthToken) {
      // Sent without a session: if the app still shows someone signed
      // in, their session is gone.
      onUnauthorized();
      return handler.next(err);
    }
    final current = await readToken();
    if (current?.userId != sentAs.userId) return handler.next(err);
    if (options.extra[_retryFor] != null) {
      // Even the refreshed token was rejected.
      onUnauthorized();
      return handler.next(err);
    }
    final AuthToken? fresh;
    if (current!.accessToken != sentAs.accessToken) {
      fresh = current; // Another request already refreshed it.
    } else {
      try {
        fresh = await (_refreshing ??= refresh().whenComplete(
          () => _refreshing = null,
        ));
      } on Object {
        return handler.next(err); // Offline: keep the session.
      }
    }
    if (fresh == null) {
      onUnauthorized();
      return handler.next(err);
    }
    if (fresh.userId != sentAs.userId) return handler.next(err);
    try {
      options.extra[_retryFor] = sentAs.userId;
      handler.resolve(await retry(options));
    } on DioException catch (error) {
      handler.next(error);
    }
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
///
/// [baseUrl] defaults to the main API. [authInterceptor] receives the
/// client so it can retry requests through it.
Dio createDio({
  required AppConfig config,
  required AuthInterceptor Function(Dio dio) authInterceptor,
  String? baseUrl,
  Duration receiveTimeout = const Duration(seconds: 20),
}) {
  config.validate();
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: receiveTimeout,
      contentType: Headers.jsonContentType,
    ),
  );
  dio.interceptors.add(authInterceptor(dio));
  if (!config.environment.isProd) dio.interceptors.add(_EventLogInterceptor());
  return dio;
}

/// Bumped whenever the session is rejected for good; the auth controller
/// listens and signs the user out.
@Riverpod(keepAlive: true)
class SessionExpiry extends _$SessionExpiry {
  @override
  int build() => 0;

  void signal() => state++;
}

AuthInterceptor Function(Dio) _authInterceptor(Ref ref) {
  final session = ref.watch(sessionSourceProvider);
  final storage = ref.watch(secureStorageProvider);
  return (dio) => AuthInterceptor(
    readToken: () async {
      final real = await session.current();
      if (real != null) return real;
      // Demo accounts keep a device token; the backend rejects it.
      final demo = await storage.read(SecureKeys.accessToken);
      return demo == null ? null : AuthToken(accessToken: demo, userId: demo);
    },
    refresh: session.refresh,
    retry: dio.fetch,
    onUnauthorized: () => ref.read(sessionExpiryProvider.notifier).signal(),
  );
}

@Riverpod(keepAlive: true)
Dio dio(Ref ref) => createDio(
  config: ref.watch(appConfigProvider),
  authInterceptor: _authInterceptor(ref),
);

/// Client for the chatbot service (`CHATBOT_BASE_URL`). AI replies can
/// take longer than a normal API call, so it waits up to 45 seconds.
@Riverpod(keepAlive: true)
Dio chatbotDio(Ref ref) {
  final config = ref.watch(appConfigProvider);
  return createDio(
    config: config,
    authInterceptor: _authInterceptor(ref),
    baseUrl: config.chatbotBaseUrl,
    receiveTimeout: const Duration(seconds: 45),
  );
}

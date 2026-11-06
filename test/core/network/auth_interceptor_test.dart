import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/config/app_config.dart';
import 'package:msu_wellbeing/core/config/environment.dart';
import 'package:msu_wellbeing/core/network/dio_client.dart';
import 'package:msu_wellbeing/core/network/session_source.dart';

/// Answers 200 to the tokens in [valid] and 401 to anything else.
class _Server implements HttpClientAdapter {
  final valid = <String>{};
  final seen = <String?>[];

  /// Runs before each answer, e.g. to switch accounts mid-request.
  FutureOr<void> Function()? beforeAnswer;

  /// Thrown instead of answering.
  Exception? failWith;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'] as String?;
    seen.add(auth);
    await beforeAnswer?.call();
    if (failWith != null) throw failWith!;
    final ok = auth != null && valid.contains(auth.substring(7));
    return ResponseBody.fromString(ok ? '{}' : '{"error":"x"}', ok ? 200 : 401);
  }

  @override
  void close({bool force = false}) {}
}

class _Session {
  AuthToken? token;
  AuthToken? Function()? onRefresh;
  Future<AuthToken?> Function()? refreshOverride;
  Exception? refreshError;
  int refreshes = 0;

  Future<AuthToken?> refresh() async {
    refreshes++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (refreshError != null) throw refreshError!;
    final override = refreshOverride;
    if (override != null) return await override();
    return token = onRefresh?.call();
  }
}

AuthToken _token(String user, int n) =>
    AuthToken(accessToken: '$user-$n', userId: user);

void main() {
  late _Server server;
  late _Session session;
  late int expired;
  late Dio dio;

  setUp(() {
    server = _Server();
    session = _Session();
    expired = 0;
    dio = createDio(
      config: const AppConfig(
        apiBaseUrl: 'https://api.msu.example',
        environment: Environment.dev,
      ),
      authInterceptor: (dio) => AuthInterceptor(
        readToken: () async => session.token,
        refresh: session.refresh,
        retry: dio.fetch,
        onUnauthorized: () => expired++,
      ),
    )..httpClientAdapter = server;
  });

  group('the token', () {
    Future<String?> sentTo(String url) async {
      session.token = _token('a', 1);
      server.valid.add('a-1');
      try {
        await dio.get<void>(url);
      } on DioException {
        // Only the header matters here.
      }
      return server.seen.single;
    }

    test('is sent to our own API', () async {
      expect(await sentTo('/me'), 'Bearer a-1');
    });

    test('is never sent to another origin', () async {
      expect(await sentTo('https://other.example/collect'), isNull);
      server.seen.clear();
      expect(await sentTo('http://api.msu.example/me'), isNull);
      server.seen.clear();
      expect(await sentTo('https://api.msu.example:8443/me'), isNull);
    });
  });

  test('an expired token is refreshed once and the request retried', () async {
    session
      ..token = _token('a', 1)
      ..onRefresh = () => _token('a', 2);
    server.valid.add('a-2');

    final response = await dio.get<void>('/me');

    expect(response.statusCode, 200);
    expect(server.seen, ['Bearer a-1', 'Bearer a-2']);
    expect(session.refreshes, 1);
    expect(expired, 0);
  });

  test('concurrent requests share one refresh', () async {
    session
      ..token = _token('a', 1)
      ..onRefresh = () => _token('a', 2);
    server.valid.add('a-2');

    final responses = await Future.wait([
      for (var i = 0; i < 3; i++) dio.get<void>('/checkins'),
    ]);

    expect(responses.map((r) => r.statusCode), [200, 200, 200]);
    expect(session.refreshes, 1);
    expect(expired, 0);
  });

  test('a refresh that cannot run (offline) keeps the session', () async {
    session
      ..token = _token('a', 1)
      ..refreshError = const SocketException('offline');

    await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));

    expect(expired, 0);
    expect(session.token?.accessToken, 'a-1');
  });

  test('a rejected refresh signs out', () async {
    session
      ..token = _token('a', 1)
      ..onRefresh = () => null;

    await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));

    expect(expired, 1);
  });

  test('a refreshed token that is still rejected signs out, no loop', () async {
    session
      ..token = _token('a', 1)
      ..onRefresh = () => _token('a', 2);

    await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));

    expect(server.seen, ['Bearer a-1', 'Bearer a-2']);
    expect(session.refreshes, 1);
    expect(expired, 1);
  });

  test('a late 401 for account A never signs out account B', () async {
    session.token = _token('a', 1);
    server.beforeAnswer = () {
      // A signs out and B signs in while A's request is in flight.
      session.token = _token('b', 1);
      server.beforeAnswer = null;
    };

    await expectLater(
      dio.post<void>('/checkins', data: {'mood': 3}),
      throwsA(isA<DioException>()),
    );

    expect(expired, 0);
    expect(session.refreshes, 0);
    // A's request is never re-sent with B's token.
    expect(server.seen, ['Bearer a-1']);
  });

  test('a retry is dropped when the account changes during refresh', () async {
    session
      ..token = _token('a', 1)
      ..onRefresh = () => _token('b', 1);
    server.valid.add('b-1');

    await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));

    expect(server.seen, ['Bearer a-1']);
    expect(expired, 0);
  });

  test('a 401 for a request sent without a session is reported', () async {
    await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));

    expect(server.seen, [null]);
    expect(expired, 1);
  });

  test('a late anonymous 401 keeps the new session', () async {
    server.beforeAnswer = () {
      session.token = _token('b', 1);
      server.valid.add('b-1');
      server.beforeAnswer = null;
    };

    await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));
    expect(server.seen, [null]);
    expect(session.refreshes, 0);
    expect(expired, 0);
    expect((await dio.get<void>('/me')).statusCode, 200);
    expect(server.seen, [null, 'Bearer b-1']);
  });

  test('a rejected refresh for account A keeps account B signed in', () async {
    session
      ..token = _token('a', 1)
      ..refreshOverride = () async {
        session.token = _token('b', 1);
        return null;
      };

    await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));
    expect(server.seen, ['Bearer a-1']);
    expect(session.refreshes, 1);
    expect(expired, 0);
  });

  test(
    'account B refreshes separately while account A is refreshing',
    () async {
      final startedA = Completer<void>();
      final rejectedA = Completer<AuthToken?>();
      session
        ..token = _token('a', 1)
        ..refreshOverride = () async {
          if (session.token?.userId == 'a') {
            startedA.complete();
            return await rejectedA.future;
          }
          return session.token = _token('b', 2);
        };
      server.valid.add('b-2');

      final responseA = expectLater(
        dio.get<void>('/me'),
        throwsA(isA<DioException>()),
      );
      await startedA.future;
      session.token = _token('b', 1);
      try {
        final responseB = await dio
            .get<void>('/me')
            .timeout(const Duration(seconds: 5));
        expect(responseB.statusCode, 200);
      } finally {
        rejectedA.complete(null);
        await responseA;
      }

      expect(server.seen, ['Bearer a-1', 'Bearer b-1', 'Bearer b-2']);
      expect(session.refreshes, 2);
      expect(expired, 0);
    },
  );

  test('a late retry 401 keeps a newer token for the same account', () async {
    session
      ..token = _token('a', 1)
      ..onRefresh = () => _token('a', 2);
    server.beforeAnswer = () {
      if (server.seen.length == 2) session.token = _token('a', 3);
    };

    await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));
    expect(server.seen, ['Bearer a-1', 'Bearer a-2']);
    expect(session.refreshes, 1);
    expect(expired, 0);
  });

  test('a timed-out POST is not retried', () async {
    session.token = _token('a', 1);
    server.failWith = DioException.receiveTimeout(
      timeout: const Duration(seconds: 20),
      requestOptions: RequestOptions(),
    );

    await expectLater(
      dio.post<void>('/checkins', data: {'mood': 3}),
      throwsA(isA<DioException>()),
    );

    expect(server.seen, hasLength(1));
    expect(session.refreshes, 0);
  });
}

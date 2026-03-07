import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/exceptions.dart';
import 'package:youtogether/core/network/auth_interceptor.dart';
import 'package:youtogether/features/auth/data/datasources/i_auth_local_data_source.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class MockLocalDataSource extends Mock implements IAuthLocalDataSource {}

class FakeRequestInterceptorHandler extends Fake
    implements RequestInterceptorHandler {
  RequestOptions? passedOptions;
  bool nextCalled = false;

  @override
  void next(RequestOptions options) {
    passedOptions = options;
    nextCalled = true;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockLocalDataSource localDataSource;
  late AuthInterceptor interceptor;

  setUp(() {
    localDataSource = MockLocalDataSource();
    interceptor = AuthInterceptor(localDataSource: localDataSource);
  });

  group('AuthInterceptor.onRequest()', () {
    test(
      'attaches Authorization: Bearer header when a token is stored',
          () async {
        const token = 'valid.access.token';
        when(() => localDataSource.getAccessToken())
            .thenAnswer((_) async => token);

        final options = RequestOptions(path: '/auth/logout');
        final handler = FakeRequestInterceptorHandler();

        await interceptor.onRequest(options, handler);

        expect(handler.nextCalled, isTrue);
        expect(
          handler.passedOptions?.headers['Authorization'],
          equals('Bearer $token'),
        );
      },
    );

    test(
      'proceeds without Authorization header when no token is stored',
          () async {
        when(() => localDataSource.getAccessToken())
            .thenThrow(const CacheException(message: 'CacheException'));

        final options = RequestOptions(path: '/auth/register');
        final handler = FakeRequestInterceptorHandler();

        await interceptor.onRequest(options, handler);

        expect(handler.nextCalled, isTrue);
        expect(
          handler.passedOptions?.headers.containsKey('Authorization'),
          isFalse,
        );
      },
    );

    test(
      'always calls handler.next() regardless of token availability',
          () async {
        when(() => localDataSource.getAccessToken())
            .thenThrow(const CacheException(message: 'CacheException'));

        final options = RequestOptions(path: '/any/path');
        final handler = FakeRequestInterceptorHandler();

        await interceptor.onRequest(options, handler);

        expect(handler.nextCalled, isTrue);
      },
    );
  });
}
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/exceptions.dart';
import 'package:youtogether/features/auth/data/datasources/auth_remote_data_source_impl.dart';
import 'package:youtogether/features/auth/data/models/user_model.dart';
import 'package:youtogether/features/auth/data/models/token_model.dart';

import '../../../../common/fixtures/fixture_reader.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MockDio extends Mock implements Dio {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Response<Map<String, dynamic>> _okResponse(Map<String, dynamic> data) {
  return Response(
    requestOptions: RequestOptions(path: ''),
    statusCode: 200,
    data: data,
  );
}

DioException _errorResponse(
    int statusCode,
    Map<String, dynamic> body, {
      String path = '',
    }) {
  return DioException(
    requestOptions: RequestOptions(path: path),
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: RequestOptions(path: path),
      statusCode: statusCode,
      data: body,
    ),
  );
}

DioException _connectionError() {
  return DioException(
    requestOptions: RequestOptions(path: ''),
    type: DioExceptionType.connectionError,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockDio mockDio;
  late AuthRemoteDataSourceImpl dataSource;

  setUp(() {
    mockDio = MockDio();
    dataSource = AuthRemoteDataSourceImpl(dio: mockDio);
  });

  // ── register ──────────────────────────────────────────────────────────────

  group('register()', () {
    const email = 'alice@example.com';
    const password = 's3cur3P@ssword!';
    const username = 'Alice';

    test('returns UserModel on HTTP 201', () async {
      when(
            () => mockDio.post<Map<String, dynamic>>(
          '/auth/register',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
            (_) async => _okResponse(
          FixtureDirectory.auth.read('auth_session_success.json'),
        ),
      );

      final result = await dataSource.register(
        email: email,
        password: password,
        username: username,
      );

      expect(result, isA<UserModel>());
      expect(result.email, equals(email));
      expect(result.accessToken, isNotNull);
      expect(result.refreshToken, isNotNull);
    });

    test('throws ServerException(statusCode: 409) on duplicate email', () {
      when(
            () => mockDio.post<Map<String, dynamic>>(
          '/auth/register',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        _errorResponse(
          409,
          FixtureDirectory.auth.read('error_conflict_409.json'),
        ),
      );

      expect(
            () => dataSource.register(
          email: email,
          password: password,
          username: username,
        ),
        throwsA(
          isA<ServerException>().having(
                (e) => e.statusCode,
            'statusCode',
            409,
          ),
        ),
      );
    });

    test('throws ServerException with field messages on HTTP 422', () {
      when(
            () => mockDio.post<Map<String, dynamic>>(
          '/auth/register',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        _errorResponse(
          422,
          FixtureDirectory.auth.read('error_validation_422.json'),
        ),
      );

      expect(
            () => dataSource.register(
          email: email,
          password: password,
          username: username,
        ),
        throwsA(
          isA<ServerException>().having(
                (e) => e.statusCode,
            'statusCode',
            422,
          ),
        ),
      );
    });

    test('throws NetworkException on connectivity error', () {
      when(
            () => mockDio.post<Map<String, dynamic>>(
          '/auth/register',
          data: any(named: 'data'),
        ),
      ).thenThrow(_connectionError());

      expect(
            () => dataSource.register(
          email: email,
          password: password,
          username: username,
        ),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ── login ─────────────────────────────────────────────────────────────────

  group('login()', () {
    const email = 'alice@example.com';
    const password = 's3cur3P@ssword!';

    test('returns UserModel with tokens on HTTP 200', () async {
      when(
            () => mockDio.post<Map<String, dynamic>>(
          '/auth/login',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
            (_) async => _okResponse(
          FixtureDirectory.auth.read('auth_session_success.json'),
        ),
      );

      final result = await dataSource.login(email: email, password: password);

      expect(result, isA<UserModel>());
      expect(result.accessToken, isNotNull);
    });

    test('throws AuthException on HTTP 401', () {
      when(
            () => mockDio.post<Map<String, dynamic>>(
          '/auth/login',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        _errorResponse(
          401,
          FixtureDirectory.auth.read('error_unauthorized_401.json'),
        ),
      );

      expect(
            () => dataSource.login(email: email, password: password),
        throwsA(isA<AuthException>()),
      );
    });

    test('throws NetworkException on connection error', () {
      when(
            () => mockDio.post<Map<String, dynamic>>(
          '/auth/login',
          data: any(named: 'data'),
        ),
      ).thenThrow(_connectionError());

      expect(
            () => dataSource.login(email: email, password: password),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ── logout ────────────────────────────────────────────────────────────────

  group('logout()', () {
    test('completes without error on HTTP 204', () async {
      when(() => mockDio.post<void>('/auth/logout')).thenAnswer(
            (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 204,
          data: null,
        ),
      );

      await expectLater(dataSource.logout(), completes);
    });

    test('throws AuthException on HTTP 401', () {
      when(() => mockDio.post<void>('/auth/logout')).thenThrow(
        _errorResponse(
          401,
          FixtureDirectory.auth.read('error_unauthorized_401.json'),
        ),
      );

      expect(() => dataSource.logout(), throwsA(isA<AuthException>()));
    });
  });

  // ── refreshToken ──────────────────────────────────────────────────────────

  group('refreshToken()', () {
    const rawRefreshToken = 'some.refresh.token';

    test('returns TokenModel with new token pair on HTTP 200', () async {
      when(
            () => mockDio.post<Map<String, dynamic>>(
          '/auth/refresh',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
            (_) async => _okResponse(
          FixtureDirectory.auth.read('auth_session_success.json'),
        ),
      );

      final result = await dataSource.refreshToken(rawRefreshToken);

      expect(result, isA<TokenModel>());
      expect(result.accessToken, isNotNull);
      expect(result.refreshToken, isNotNull);
    });

    test('throws AuthException on HTTP 403 (token reuse)', () {
      when(
            () => mockDio.post<Map<String, dynamic>>(
          '/auth/refresh',
          options: any(named: 'options'),
        ),
      ).thenThrow(
        _errorResponse(
          403,
          FixtureDirectory.auth.read('error_forbidden_403.json'),
        ),
      );

      expect(
            () => dataSource.refreshToken(rawRefreshToken),
        throwsA(isA<AuthException>()),
      );
    });
  });

  // ── getCurrentUser ────────────────────────────────────────────────────────

  group('getCurrentUser()', () {
    test('returns UserModel without tokens on HTTP 200', () async {
      when(
            () => mockDio.get<Map<String, dynamic>>('/auth/me'),
      ).thenAnswer(
            (_) async => _okResponse(
          FixtureDirectory.auth.read('auth_me_success.json'),
        ),
      );

      final result = await dataSource.getCurrentUser();

      expect(result, isA<UserModel>());
      expect(result.accessToken, isNull);
      expect(result.refreshToken, isNull);
    });

    test('throws AuthException on HTTP 401', () {
      when(
            () => mockDio.get<Map<String, dynamic>>('/auth/me'),
      ).thenThrow(
        _errorResponse(
          401,
          FixtureDirectory.auth.read('error_unauthorized_401.json'),
        ),
      );

      expect(
            () => dataSource.getCurrentUser(),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
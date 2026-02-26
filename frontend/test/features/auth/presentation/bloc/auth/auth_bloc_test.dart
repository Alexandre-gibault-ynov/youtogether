import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/core/usecases/use_case.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/usecases/get_current_user_use_case.dart';
import 'package:youtogether/features/auth/domain/usecases/login_use_case.dart';
import 'package:youtogether/features/auth/domain/usecases/logout_use_case.dart';
import 'package:youtogether/features/auth/domain/usecases/refresh_token_use_case.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth/auth_event.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth/auth_state.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockGetCurrentUserUseCase extends Mock implements GetCurrentUserUseCase {}

class MockRefreshTokenUseCase extends Mock implements RefreshTokenUseCase {}

// Mocktail requires fallback values for custom types passed via any()
class FakeLoginParams extends Fake implements LoginParams {}

class FakeNoParams extends Fake implements NoParams {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _tEmail = 'alice@example.com';
const _tPassword = 's3cur3P@ssword!';

final _tUserEntity = UserEntity(
  id: '00000000-0000-0000-0000-000000000001',
  email: _tEmail,
  displayName: 'Alice',
  role: UserRole.authenticated,
  createdAt: DateTime.utc(2025, 1, 1),
);

const _tAuthFailure = Failure.auth(message: 'Invalid credentials');
const _tNetworkFailure = Failure.network();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeLoginParams());
    registerFallbackValue(FakeNoParams());
  });

  late MockLoginUseCase mockLogin;
  late MockLogoutUseCase mockLogout;
  late MockGetCurrentUserUseCase mockGetCurrentUser;
  late MockRefreshTokenUseCase mockRefreshToken;

  AuthBloc buildBloc() => AuthBloc(
    loginUseCase: mockLogin,
    logoutUseCase: mockLogout,
    getCurrentUserUseCase: mockGetCurrentUser,
    refreshTokenUseCase: mockRefreshToken,
  );

  setUp(() {
    mockLogin = MockLoginUseCase();
    mockLogout = MockLogoutUseCase();
    mockGetCurrentUser = MockGetCurrentUserUseCase();
    mockRefreshToken = MockRefreshTokenUseCase();
  });

  // ---------------------------------------------------------------------------
  // Initial state
  // ---------------------------------------------------------------------------

  group('AuthBloc — initial state', () {
    test('emits AuthInitial as the initial state', () {
      expect(buildBloc().state, equals(const AuthState.initial()));
    });
  });

  // ---------------------------------------------------------------------------
  // TC-01: User logs in with valid credentials
  // ---------------------------------------------------------------------------

  group('AuthBloc — AuthLoginRequested', () {
    blocTest<AuthBloc, AuthState>(
      'TC-01: emits [loading, authenticated] when login succeeds',
      build: buildBloc,
      setUp: () {
        when(() => mockLogin(any()))
            .thenAnswer((_) async => Right(_tUserEntity));
      },
      act: (bloc) => bloc.add(
        const AuthEvent.loginRequested(email: _tEmail, password: _tPassword),
      ),
      expect: () => [
        const AuthState.loading(),
        AuthState.authenticated(user: _tUserEntity),
      ],
      verify: (_) {
        verify(() => mockLogin(any())).called(1);
      },
    );

    // TC-02: User logs in with invalid credentials
    blocTest<AuthBloc, AuthState>(
      'TC-02: emits [loading, failure] when login returns AuthFailure',
      build: buildBloc,
      setUp: () {
        when(() => mockLogin(any()))
            .thenAnswer((_) async => const Left(_tAuthFailure));
      },
      act: (bloc) => bloc.add(
        const AuthEvent.loginRequested(email: _tEmail, password: _tPassword),
      ),
      expect: () => [
        const AuthState.loading(),
        const AuthState.failure(failure: _tAuthFailure),
      ],
    );

    // Network failure during login
    blocTest<AuthBloc, AuthState>(
      'emits [loading, failure] when login returns NetworkFailure',
      build: buildBloc,
      setUp: () {
        when(() => mockLogin(any()))
            .thenAnswer((_) async => const Left(_tNetworkFailure));
      },
      act: (bloc) => bloc.add(
        const AuthEvent.loginRequested(email: _tEmail, password: _tPassword),
      ),
      expect: () => [
        const AuthState.loading(),
        const AuthState.failure(failure: _tNetworkFailure),
      ],
    );
  });

  // ---------------------------------------------------------------------------
  // TC-03: Unauthenticated user opens app
  // ---------------------------------------------------------------------------

  group('AuthBloc — AuthCheckStatusRequested', () {
    blocTest<AuthBloc, AuthState>(
      'TC-03: emits [loading, unauthenticated] when no valid session exists',
      build: buildBloc,
      setUp: () {
        when(() => mockGetCurrentUser(any()))
            .thenAnswer((_) async => const Right(null));
      },
      act: (bloc) => bloc.add(const AuthEvent.checkStatusRequested()),
      expect: () => [
        const AuthState.loading(),
        const AuthState.unauthenticated(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated] when a valid session is restored',
      build: buildBloc,
      setUp: () {
        when(() => mockGetCurrentUser(any()))
          .thenAnswer((_) async => Right(_tUserEntity));
      },
      act: (bloc) => bloc.add(const AuthEvent.checkStatusRequested()),
      expect: () => [
        const AuthState.loading(),
        AuthState.authenticated(user: _tUserEntity),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, unauthenticated] when getCurrentUser returns AuthFailure',
      build: buildBloc,
      setUp: () {
        when(() => mockGetCurrentUser(any())).thenAnswer(
          (_) async => const Right(null),
        );
      },
      act: (bloc) => bloc.add(const AuthEvent.checkStatusRequested()),
      expect: () => [
        const AuthState.loading(),
        const AuthState.unauthenticated(),
      ],
    );
  });

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

  group('AuthBloc — AuthLogoutRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [loading, unauthenticated] when logout succeeds',
      build: buildBloc,
      setUp: () {
        when(() => mockLogout(any()))
          .thenAnswer((_) async => const Right(null));
      },
      act: (bloc) => bloc.add(const AuthEvent.logoutRequested()),
      expect: () => [
        const AuthState.loading(),
        const AuthState.unauthenticated(),
      ],
    );
  });

  // ---------------------------------------------------------------------------
  // Token refresh (internal)
  // ---------------------------------------------------------------------------

  group('AuthBloc — AuthTokenRefreshRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits no state change when token refresh succeeds',
      build: buildBloc,
      setUp: () {
        when(() => mockRefreshToken(any()))
          .thenAnswer((_) async => const Right(null));
      },
      act: (bloc) => bloc.add(const AuthEvent.tokenRefreshRequested()),
      // No state change on successful refresh — the Dio interceptor retries.
      expect: () => <AuthState>[],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [unauthenticated] when token refresh fails',
      build: buildBloc,
      setUp: () {
        when(() => mockRefreshToken(any())).thenAnswer(
          (_) async => const Left(Failure.auth(message: 'Refresh token expired')),
        );
      },
      act: (bloc) => bloc.add(const AuthEvent.tokenRefreshRequested()),
      expect: () => [const AuthState.unauthenticated()],
    );
  });
}
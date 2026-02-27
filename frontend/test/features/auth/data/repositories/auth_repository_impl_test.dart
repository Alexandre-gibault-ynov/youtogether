import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/exceptions.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/auth/data/datasources/i_auth_local_datasource.dart';
import 'package:youtogether/features/auth/data/datasources/i_auth_remote_datasource.dart';
import 'package:youtogether/features/auth/data/model/token_model.dart';
import 'package:youtogether/features/auth/data/model/user_model.dart';
import 'package:youtogether/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MockAuthRemoteDataSource extends Mock implements IAuthRemoteDatasource {}

class MockAuthLocalDataSource extends Mock implements IAuthLocalDatasource {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _tEmail = 'alice@example.com';
const _tPassword = 's3cur3P@ssword!';
const _tAccessToken = 'access.jwt.token';
const _tRefreshToken = 'refresh.opaque.token';

final _tUserModel = UserModel(
  id: '00000000-0000-0000-0000-000000000001',
  email: _tEmail,
  displayName: 'Alice',
  role: 'registered',
  accessToken: _tAccessToken,
  refreshToken: _tRefreshToken,
  createdAt: DateTime.utc(2025, 1, 1),
);

final _tUserEntity = _tUserModel.toDomain();

const _tTokenModel = TokenModel(
  accessToken: 'new.access.jwt',
  refreshToken: 'new.refresh.opaque',
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthRemoteDataSource mockRemote;
  late MockAuthLocalDataSource mockLocal;
  late AuthRepositoryImpl sut;

  setUp(() {
    mockRemote = MockAuthRemoteDataSource();
    mockLocal = MockAuthLocalDataSource();
    sut = AuthRepositoryImpl(
      remoteDataSource: mockRemote,
      localDataSource: mockLocal,
    );
  });

  // Helper — stubs a successful token persistence.
  void arrangeTokenPersistenceSuccess() {
    when(
      () => mockLocal.saveTokens(
        accessToken: _tAccessToken,
        refreshToken: _tRefreshToken,
      ),
    ).thenAnswer((_) async {});
  }

  // ---------------------------------------------------------------------------
  // login()
  // ---------------------------------------------------------------------------
  group('AuthRepositoryImpl.login', () {
    test(
      'returns Right(UserEntity) and persists tokens on successful API response',
      () async {
        // Arrange
        when(
          () => mockRemote.login(email: _tEmail, password: _tPassword),
        ).thenAnswer((_) async => _tUserModel);
        arrangeTokenPersistenceSuccess();

        // Act
        final result = await sut.login(email: _tEmail, password: _tPassword);

        // Assert
        expect(result.isRight, isTrue);
        expect(result.right, equals(_tUserEntity));
        verify(
          () => mockLocal.saveTokens(
            accessToken: _tAccessToken,
            refreshToken: _tRefreshToken,
          ),
        ).called(1);
      },
    );

    test(
      'returns Left(AuthFailure) when the remote source throws AuthException',
      () async {
        // Arrange
        when(
          () => mockRemote.login(email: _tEmail, password: _tPassword),
        ).thenThrow(const AuthException(message: 'Invalid credentials'));

        // Act
        final result = await sut.login(email: _tEmail, password: _tPassword);

        // Assert
        expect(result.isLeft, isTrue);
        expect(result.left, isA<AuthFailure>());
        verifyNever(
          () => mockLocal.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ),
        );
      },
    );

    test(
      'returns Left(NetworkFailure) when the remote source throws NetworkException',
      () async {
        // Arrange
        when(
          () => mockRemote.login(email: _tEmail, password: _tPassword),
        ).thenThrow(const NetworkException());

        // Act
        final result = await sut.login(email: _tEmail, password: _tPassword);

        // Assert
        expect(result.isLeft, isTrue);
        expect(result.left, isA<NetworkFailure>());
      },
    );

    test(
      'returns Left(ServerFailure) when the remote source throws ServerException',
      () async {
        // Arrange
        when(
          () => mockRemote.login(email: _tEmail, password: _tPassword),
        ).thenThrow(
          const ServerException(
            statusCode: 500,
            message: 'Internal server error',
          ),
        );

        // Act
        final result = await sut.login(email: _tEmail, password: _tPassword);

        // Assert
        expect(result.isLeft, isTrue);
        final failure = result.left as ServerFailure;
        expect(failure.statusCode, equals(500));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // registerGroup()
  // ---------------------------------------------------------------------------

  registerGroup();

  // ---------------------------------------------------------------------------
  // logout()
  // ---------------------------------------------------------------------------

  group('AuthRepositoryImpl.logout', () {
    test('calls remote logout and clears local tokens on success', () async {
      // Arrange
      when(() => mockRemote.logout()).thenAnswer((_) async {});
      when(() => mockLocal.clearTokens()).thenAnswer((_) async {});

      // Act
      final result = await sut.logout();

      // Assert
      expect(result.isRight, isTrue);
      verify(() => mockRemote.logout()).called(1);
      verify(() => mockLocal.clearTokens()).called(1);
    });

    test(
      'still clears local tokens when the network is unavailable (offline logout)',
      () async {
        // Arrange — network unavailable, remote call throws
        when(() => mockRemote.logout()).thenThrow(const NetworkException());
        when(() => mockLocal.clearTokens()).thenAnswer((_) async {});

        // Act
        final result = await sut.logout();

        // Assert — offline logout is treated as success
        expect(result.isRight, isTrue);
        verify(() => mockLocal.clearTokens()).called(1);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // refreshToken()
  // ---------------------------------------------------------------------------

  group('AuthRepositoryImpl.refreshToken', () {
    test('stores the new token pair when the refresh succeeds', () async {
      // Arrange
      when(
        () => mockLocal.getRefreshToken(),
      ).thenAnswer((_) async => _tRefreshToken);
      when(
        () => mockRemote.refreshToken(_tRefreshToken),
      ).thenAnswer((_) async => _tTokenModel);
      when(
        () => mockLocal.saveTokens(
          accessToken: _tTokenModel.accessToken,
          refreshToken: _tTokenModel.refreshToken,
        ),
      ).thenAnswer((_) async {});

      // Act
      final result = await sut.refreshToken();

      // Assert
      expect(result.isRight, isTrue);
      verify(
        () => mockLocal.saveTokens(
          accessToken: _tTokenModel.accessToken,
          refreshToken: _tTokenModel.refreshToken,
        ),
      ).called(1);
    });

    test(
      'returns Left(CacheFailure) when no refresh token is stored locally',
      () async {
        // Arrange
        when(
          () => mockLocal.getRefreshToken(),
        ).thenThrow(const CacheException(message: 'No refresh token stored'));

        // Act
        final result = await sut.refreshToken();

        // Assert
        expect(result.isLeft, isTrue);
        expect(result.left, isA<CacheFailure>());
        verifyNever(() => mockRemote.refreshToken(any()));
      },
    );

    test(
      'returns Left(AuthFailure) when the refresh token is expired',
      () async {
        // Arrange
        when(
          () => mockLocal.getRefreshToken(),
        ).thenAnswer((_) async => _tRefreshToken);
        when(
          () => mockRemote.refreshToken(_tRefreshToken),
        ).thenThrow(const AuthException(message: 'Refresh token expired'));

        // Act
        final result = await sut.refreshToken();

        // Assert
        expect(result.isLeft, isTrue);
        expect(result.left, isA<AuthFailure>());
      },
    );
  });

  // ---------------------------------------------------------------------------
  // getCurrentUser()
  // ---------------------------------------------------------------------------

  group('AuthRepositoryImpl.getCurrentUser', () {
    test('returns Right(null) when no valid token is stored locally', () async {
      // Arrange
      when(() => mockLocal.hasValidToken()).thenAnswer((_) async => false);

      // Act
      final result = await sut.getCurrentUser();

      // Assert
      expect(result.isRight, isTrue);
      expect(result.right, isNull);
      verifyNever(() => mockRemote.getCurrentUser());
    });

    test(
      'returns Right(UserEntity) when a valid token exists and the API succeeds',
      () async {
        // Arrange — model without embedded tokens (GET /auth/me pattern)
        final meModel = UserModel(
          id: _tUserModel.id,
          email: _tUserModel.email,
          displayName: _tUserModel.displayName,
          role: _tUserModel.role,
          createdAt: _tUserModel.createdAt,
        );
        when(() => mockLocal.hasValidToken()).thenAnswer((_) async => true);
        when(
          () => mockRemote.getCurrentUser(),
        ).thenAnswer((_) async => meModel);

        // Act
        final result = await sut.getCurrentUser();

        // Assert
        expect(result.isRight, isTrue);
        expect(result.right, isA<UserEntity>());
      },
    );
  });
}

// ---------------------------------------------------------------------------
// register() — appended group
// ---------------------------------------------------------------------------

void registerGroup() {
  // Shared setup — mirrors the outer test file setUp().
  late MockAuthRemoteDataSource mockRemote;
  late MockAuthLocalDataSource mockLocal;
  late AuthRepositoryImpl sut;

  setUp(() {
    mockRemote = MockAuthRemoteDataSource();
    mockLocal = MockAuthLocalDataSource();
    sut = AuthRepositoryImpl(
      remoteDataSource: mockRemote,
      localDataSource: mockLocal,
    );
  });

  const tUsername = 'Alice';

  final tRegisterModel = UserModel(
    id: '00000000-0000-0000-0000-000000000002',
    email: _tEmail,
    displayName: tUsername,
    role: 'registered',
    accessToken: _tAccessToken,
    refreshToken: _tRefreshToken,
    createdAt: DateTime.utc(2025, 1, 1),
  );

  group('AuthRepositoryImpl.register', () {
    test(
      'returns Right(UserEntity) and persists tokens on successful API response',
      () async {
        // Arrange
        when(
          () => mockRemote.register(
            email: _tEmail,
            password: _tPassword,
            username: tUsername,
          ),
        ).thenAnswer((_) async => tRegisterModel);
        when(
          () => mockLocal.saveTokens(
            accessToken: _tAccessToken,
            refreshToken: _tRefreshToken,
          ),
        ).thenAnswer((_) async {});

        // Act
        final result = await sut.register(
          email: _tEmail,
          password: _tPassword,
          username: tUsername,
        );

        // Assert
        expect(result.isRight, isTrue);
        expect(result.right, isA<UserEntity>());
        verify(
          () => mockLocal.saveTokens(
            accessToken: _tAccessToken,
            refreshToken: _tRefreshToken,
          ),
        ).called(1);
      },
    );

    test(
      'returns Left(ValidationFailure) with email key on HTTP 409',
      () async {
        // Arrange
        when(
          () => mockRemote.register(
            email: _tEmail,
            password: _tPassword,
            username: tUsername,
          ),
        ).thenThrow(
          const ServerException(
            statusCode: 409,
            message: 'Email already in use',
          ),
        );

        // Act
        final result = await sut.register(
          email: _tEmail,
          password: _tPassword,
          username: tUsername,
        );

        // Assert
        expect(result.isLeft, isTrue);
        final failure = result.left as ValidationFailure;
        expect(failure.errors, containsPair('email', isNotEmpty));
        verifyNever(
          () => mockLocal.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ),
        );
      },
    );

    test('returns Left(ValidationFailure) with form key on HTTP 422', () async {
      // Arrange
      when(
        () => mockRemote.register(
          email: _tEmail,
          password: _tPassword,
          username: tUsername,
        ),
      ).thenThrow(
        const ServerException(
          statusCode: 422,
          message: 'Username must be at least 3 characters.',
        ),
      );

      // Act
      final result = await sut.register(
        email: _tEmail,
        password: _tPassword,
        username: tUsername,
      );

      // Assert
      expect(result.isLeft, isTrue);
      final failure = result.left as ValidationFailure;
      expect(failure.errors, containsPair('form', isNotEmpty));
    });

    test(
      'returns Left(NetworkFailure) when the remote source throws NetworkException',
      () async {
        // Arrange
        when(
          () => mockRemote.register(
            email: _tEmail,
            password: _tPassword,
            username: tUsername,
          ),
        ).thenThrow(const NetworkException());

        // Act
        final result = await sut.register(
          email: _tEmail,
          password: _tPassword,
          username: tUsername,
        );

        // Assert
        expect(result.isLeft, isTrue);
        expect(result.left, isA<NetworkFailure>());
      },
    );

    test('returns Left(ServerFailure) on unexpected HTTP 5xx error', () async {
      // Arrange
      when(
        () => mockRemote.register(
          email: _tEmail,
          password: _tPassword,
          username: tUsername,
        ),
      ).thenThrow(
        const ServerException(
          statusCode: 500,
          message: 'Internal server error',
        ),
      );

      // Act
      final result = await sut.register(
        email: _tEmail,
        password: _tPassword,
        username: tUsername,
      );

      // Assert
      expect(result.isLeft, isTrue);
      final failure = result.left as ServerFailure;
      expect(failure.statusCode, equals(500));
    });
  });
}

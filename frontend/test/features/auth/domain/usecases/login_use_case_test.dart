import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:youtogether/features/auth/domain/usecases/login_use_case.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MockAuthRepository extends Mock implements IAuthRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _tEmail = 'john@example.com';
const _tPassword = 's3cur3P@ssword!';

final _tUserEntity = UserEntity(
  id: '00000000-0000-0000-0000-000000000001',
  email: _tEmail,
  displayName: 'Alice',
  role: UserRole.authenticated,
  createdAt: DateTime.utc(2025, 1, 1),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthRepository mockRepository;
  late LoginUseCase sut;

  setUp(() {
    mockRepository = MockAuthRepository();
    sut = LoginUseCase(mockRepository);
  });

  // Arrange helper — returns a successful login result.
  void arrangeLoginSuccess() {
    when(
      () => mockRepository.login(email: _tEmail, password: _tPassword),
    ).thenAnswer((_) async => Right(_tUserEntity));
  }

  group('LoginUseCase', () {
    group('call', () {
      // TC-01: happy path
      test('returns Right(UserEntity) when repository login succeeds', () {
        () async {
          //Arrange
          arrangeLoginSuccess();
          final params = LoginParams(email: _tEmail, password: _tPassword);

          // Act
          final result = await sut(params);

          // Asserts
          expect(result.isRight, isTrue);
          expect(result.right, equals(_tUserEntity));
          verify(
            () => mockRepository.login(email: _tEmail, password: _tPassword),
          ).called(1);
          verifyNoMoreInteractions(mockRepository);
        };
      });

      // TC-02: invalid credentials
      test(
        'returns Left(AuthFailure) when the repository returns AuthFailure',
        () async {
          // Arrange
          when(
            () => mockRepository.login(email: _tEmail, password: _tPassword),
          ).thenAnswer(
            (_) async =>
                const Left(Failure.auth(message: 'invalid credentials')),
          );
          final params = LoginParams(email: _tEmail, password: _tPassword);

          // Act
          final result = await sut(params);

          // Assert
          expect(result.isLeft, isTrue);
          expect(result.left, isA<AuthFailure>());
        },
      );

      // Network failure propagation
      test(
        'returns Left(NeworkFailure) when the repository returns NetworkFailure',
        () async {
          // Arrange
          when(
            () => mockRepository.login(email: _tEmail, password: _tPassword),
          ).thenAnswer((_) async => const Left(Failure.network()));
          final params = LoginParams(email: _tEmail, password: _tPassword);

          // Act
          final result = await sut(params);

          // Assert
          expect(result.isLeft, isTrue);
          expect(result.left, isA<NetworkFailure>());
        },
      );
    });
  });

  // Delegation — use case does not add logic beyond delegation
  test(
    'delegates to IAuthRepository.login exactly once with the correct params',
    () async {
      // Arrange
      arrangeLoginSuccess();
      final params = LoginParams(email: _tEmail, password: _tPassword);

      // Act
      await sut(params);

      // Assert
      verify(
        () => mockRepository.login(email: _tEmail, password: _tPassword),
      ).called(1);
    },
  );
}

import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:youtogether/features/auth/domain/usecases/register_use_case.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MockAuthRepository extends Mock implements IAuthRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _tEmail = 'alice@example.com';
const _tPassword = 's3cur3P@ssword!';
const _tUsername = 'Alice';

final _tUserEntity = UserEntity(
  id: '00000000-0000-0000-0000-000000000002',
  email: _tEmail,
  displayName: _tUsername,
  role: UserRole.authenticated,
  createdAt: DateTime.utc(2025, 1, 1),
);

const _tParams = RegisterParams(
  email: _tEmail,
  password: _tPassword,
  username: _tUsername,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthRepository mockRepository;
  late RegisterUseCase sut;

  setUp(() {
    mockRepository = MockAuthRepository();
    sut = RegisterUseCase(mockRepository);
  });

  // Arrange helper — stubs a successful registration.
  void arrangeRegisterSuccess() {
    when(
      () => mockRepository.register(
        email: _tEmail,
        password: _tPassword,
        username: _tUsername,
      ),
    ).thenAnswer((_) async => Right(_tUserEntity));
  }

  group('RegisterUseCase', () {
    group('call', () {
      test(
        'returns Right(UserEntity) when repository.register succeeds',
        () async {
          // Arrange
          arrangeRegisterSuccess();

          // Act
          final result = await sut(_tParams);

          // Assert
          expect(result.isRight, isTrue);
          expect(result.right, equals(_tUserEntity));
          verify(
            () => mockRepository.register(
              username: _tUsername,
              email: _tEmail,
              password: _tPassword,
            ),
          ).called(1);
          verifyNoMoreInteractions(mockRepository);
        },
      );

      test(
        'returns Left(ValidationFailure) when email is already in use',
        () async {
          // Arrange
          when(
            () => mockRepository.register(
              email: _tEmail,
              password: _tPassword,
              username: _tUsername,
            ),
          ).thenAnswer(
            (_) async => const Left(
              Failure.validation(
                errors: {'email': 'This email address is already in use.'},
              ),
            ),
          );

          // Act
          final result = await sut(_tParams);

          // Assert
          expect(result.isLeft, isTrue);
          expect(result.left, isA<ValidationFailure>());
          final failure = result.left as ValidationFailure;
          expect(failure.errors, containsPair('email', isNotEmpty));
        },
      );

      test(
        'returns Left(NetworkFailure) when the repository returns NetworkFailure',
        () async {
          // Arrange
          when(
            () => mockRepository.register(
              email: _tEmail,
              password: _tPassword,
              username: _tUsername,
            ),
          ).thenAnswer((_) async => const Left(Failure.network()));

          // Act
          final result = await sut(_tParams);

          // Assert
          expect(result.isLeft, isTrue);
          expect(result.left, isA<NetworkFailure>());
        },
      );

      test(
        'returns Left(ServerFailure) when the repository returns ServerFailure',
        () async {
          // Arrange
          when(
            () => mockRepository.register(
              email: _tEmail,
              password: _tPassword,
              username: _tUsername,
            ),
          ).thenAnswer(
            (_) async => const Left(
              Failure.server(statusCode: 500, message: 'Internal server error'),
            ),
          );

          // Act
          final result = await sut(_tParams);

          // Assert
          expect(result.isLeft, isTrue);
          final failure = result.left as ServerFailure;
          expect(failure.statusCode, equals(500));
        },
      );

      test(
        'delegates to IAuthRepository.register exactly once with correct params',
        () async {
          // Arrange
          arrangeRegisterSuccess();

          // Act
          await sut(_tParams);

          // Assert — use case adds no logic beyond delegation
          verify(
            () => mockRepository.register(
              email: _tEmail,
              password: _tPassword,
              username: _tUsername,
            ),
          ).called(1);
        },
      );
    });
  });
}

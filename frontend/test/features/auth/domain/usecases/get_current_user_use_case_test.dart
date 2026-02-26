import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/core/usecases/use_case.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:youtogether/features/auth/domain/usecases/get_current_user_use_case.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------


class MockAuthRepository extends Mock implements IAuthRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _tUserEntity = UserEntity(
  id: '00000000-0000-0000-0000-000000000001',
  email: 'alice@example.com',
  displayName: 'Alice',
  role: UserRole.authenticated,
  createdAt: DateTime.utc(2025, 1, 1),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthRepository mockRepository;
  late GetCurrentUserUseCase sut;

  setUp(() {
    mockRepository = MockAuthRepository();
    sut = GetCurrentUserUseCase(mockRepository);
  });

  group('GetCurrentUserTestCase', () {
    group('call', () {
      // TC-01 derived: authenticated user
      test(
          'returns Right(UserEntity) when active session exists',
              () async {
            // Arrange
            when(() => mockRepository.getCurrentUser())
                .thenAnswer((_) async => Right(_tUserEntity));

            // Act
            final result = await sut(const NoParams());

            // Assert
            expect(result.isRight, isTrue);
            expect(result.right, equals(_tUserEntity));
            verify(() => mockRepository.getCurrentUser()).called(1);
            verifyNoMoreInteractions(mockRepository);
          }
      );

      // TC-03: unauthenticated — null returned inside Right
      test(
        'returns Right(null) when no valid session exists',
            () async {
          // Arrange
          when(() => mockRepository.getCurrentUser(),)
              .thenAnswer((_) async => Right(null));

          // Act
          final result = await sut(const NoParams());

          // Assert
          expect(result.isRight, isTrue);
          expect(result.right, isNull);
        },
      );

      // AuthFailure propagation
      test(
          'returns Left(AuthFailure) when the stored token is invalid',
              () async {
            // Arrange
            when(() => mockRepository.getCurrentUser())
                .thenAnswer((_) async => Left(Failure.auth(message: 'Token expired')),
            );

            // Act
            final result = await sut(const NoParams());

            // Assert
            expect(result.isLeft, isTrue);
            expect(result.left, isA<AuthFailure>());
          }
      );
    });
  });
}
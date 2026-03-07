import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/usecases/register_use_case.dart';
import 'package:youtogether/features/auth/presentation/bloc/register/register_cubit.dart';
import 'package:youtogether/features/auth/presentation/bloc/register/register_state.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

// Mocktail requires a registered fallback value for custom types used in any().
class FakeRegisterParams extends Fake implements RegisterParams {}

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

const _tValidationFailure = Failure.validation(
  errors: {'email': 'This email address is already in use.'},
);

const _tNetworkFailure = Failure.network();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRegisterParams());
  });

  late MockRegisterUseCase mockRegisterUseCase;

  RegisterCubit buildCubit() =>
      RegisterCubit(registerUseCase: mockRegisterUseCase);

  setUp(() {
    mockRegisterUseCase = MockRegisterUseCase();
  });

  // ---------------------------------------------------------------------------
  // Initial state
  // ---------------------------------------------------------------------------

  group('RegisterCubit — initial state', () {
    test('emits RegisterInitial as the initial state', () {
      expect(buildCubit().state, equals(const RegisterState.initial()));
    });
  });

  // ---------------------------------------------------------------------------
  // register() — success
  // ---------------------------------------------------------------------------

  group('RegisterCubit — register', () {
    blocTest<RegisterCubit, RegisterState>(
      'emits [loading, success] when RegisterUseCase returns Right(UserEntity)',
      build: buildCubit,
      setUp: () {
        when(
          () => mockRegisterUseCase(any()),
        ).thenAnswer((_) async => Right(_tUserEntity));
      },
      act: (cubit) => cubit.register(
        email: _tEmail,
        password: _tPassword,
        username: _tUsername,
      ),
      expect: () => [
        const RegisterState.loading(),
        const RegisterState.success(),
      ],
      verify: (_) {
        verify(() => mockRegisterUseCase(any())).called(1);
      },
    );

    // Email already in use — HTTP 409 mapped to ValidationFailure
    blocTest<RegisterCubit, RegisterState>(
      'emits [loading, failure] when RegisterUseCase returns ValidationFailure',
      build: buildCubit,
      setUp: () {
        when(
          () => mockRegisterUseCase(any()),
        ).thenAnswer((_) async => const Left(_tValidationFailure));
      },
      act: (cubit) => cubit.register(
        email: _tEmail,
        password: _tPassword,
        username: _tUsername,
      ),
      expect: () => [
        const RegisterState.loading(),
        const RegisterState.failure(failure: _tValidationFailure),
      ],
    );

    // Network unavailable
    blocTest<RegisterCubit, RegisterState>(
      'emits [loading, failure] when RegisterUseCase returns NetworkFailure',
      build: buildCubit,
      setUp: () {
        when(
          () => mockRegisterUseCase(any()),
        ).thenAnswer((_) async => const Left(_tNetworkFailure));
      },
      act: (cubit) => cubit.register(
        email: _tEmail,
        password: _tPassword,
        username: _tUsername,
      ),
      expect: () => [
        const RegisterState.loading(),
        const RegisterState.failure(failure: _tNetworkFailure),
      ],
    );

    // Correct params propagation
    blocTest<RegisterCubit, RegisterState>(
      'calls RegisterUseCase with the exact RegisterParams provided',
      build: buildCubit,
      setUp: () {
        when(
          () => mockRegisterUseCase(any()),
        ).thenAnswer((_) async => Right(_tUserEntity));
      },
      act: (cubit) => cubit.register(
        email: _tEmail,
        password: _tPassword,
        username: _tUsername,
      ),
      verify: (_) {
        verify(
          () => mockRegisterUseCase(
            const RegisterParams(
              email: _tEmail,
              password: _tPassword,
              username: _tUsername,
            ),
          ),
        ).called(1);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // reset()
  // ---------------------------------------------------------------------------

  group('RegisterCubit — reset', () {
    blocTest<RegisterCubit, RegisterState>(
      'emits [initial] when reset() is called after a failure',
      build: buildCubit,
      seed: () => const RegisterState.failure(failure: _tNetworkFailure),
      act: (cubit) => cubit.reset(),
      expect: () => [const RegisterState.initial()],
    );

    blocTest<RegisterCubit, RegisterState>(
      'emits [initial] when reset() is called after success',
      build: buildCubit,
      seed: () => const RegisterState.success(),
      act: (cubit) => cubit.reset(),
      expect: () => [const RegisterState.initial()],
    );
  });
}

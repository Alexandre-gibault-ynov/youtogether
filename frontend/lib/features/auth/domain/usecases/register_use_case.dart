import 'package:either_dart/either.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:youtogether/core/usecases/use_case.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:youtogether/features/auth/domain/usecases/login_use_case.dart';

import '../../../../core/error/failures.dart';

part 'register_use_case.freezed.dart';

/// Input parameters for [RegisterUseCase].
///
/// Declared with [@freezed] for immutability and structural equality,
/// consistent with [LoginParams] and all other Params types in the project.
///
/// The [username] field maps to the [UserEntity.displayName] property and
/// the `username` column in the PostgreSQL schema.
@freezed
abstract class RegisterParams with _$RegisterParams {
  const factory RegisterParams({
    /// Display name shown in the UI and rooms.
    required String username,

    /// Email address used as the login credential.
    required String email,

    /// Plain-text password - hashed server-side before persistence.
    /// Never logged or stored client-side beyond the in-memory form state.
    required String password,
  }) = _RegisterParams;
}

/// Creates a new registered user account.
///
/// Delegates to [IAuthRepository.register] and returns the newly created
/// [UserEntity] — with its access and refresh tokens already persisted to
/// local secure storage — on success.
///
/// On failure, propagates the typed [Failure] variant unchanged:
/// - [ValidationFailure] — email already in use or schema violation (HTTP 409 / 422).
/// - [NetworkFailure]    — no connectivity.
/// - [ServerFailure]     — unexpected API error.
///
/// Complies with:
/// - OWASP A07 — registration automatically establishes a session, eliminating
///   the need for a redundant login round-trip immediately after sign-up.
class RegisterUseCase extends UseCase<UserEntity, RegisterParams> {
  final IAuthRepository _repository;

  const RegisterUseCase(this._repository);

  @override
  Future<Either<Failure, UserEntity>> call(RegisterParams params) {
    return _repository.register(
      username: params.username,
      email: params.email,
      password: params.password,
    );
  }
}

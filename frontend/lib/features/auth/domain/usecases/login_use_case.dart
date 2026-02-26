import 'package:either_dart/either.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/use_case.dart';
import '../entities/user_entity.dart';
import '../repositories/i_auth_repository.dart';


part 'login_use_case.freezed.dart';

/// Inputs paramters for [LoginUseCase]
///
/// Declared with [@freezed] to ensure immutability and structural equality,
/// wich is required by test matchers.
@freezed
abstract class LoginParams with _$LoginParams {
  const factory LoginParams({
    required String email,
    required String password
  }) = _LoginParams;
}

/// Authenticates a user with email and password.
///
/// Delegates to [IAuthRepository.login] and returns the authenticated
/// [UserEntity] on success or a typed [Failure] on error.
///
/// This use case performs no additional validation beyond what the repository
/// contract enforces; field-level validation is the responsibility of the
/// presentation layer before dispatching the event.
///
/// Complies with:
/// - secure credential handling via the repository abstraction.
/// - OWASP A07 — credentials are never logged or stored in plain text.
class LoginUseCase extends UseCase<UserEntity, LoginParams> {

  final IAuthRepository _repository;

  LoginUseCase(this._repository);

  @override
  Future<Either<Failure, UserEntity>> call(LoginParams params) {
    return _repository.login(
      email: params.email,
      password: params.password,
    );
  }
}
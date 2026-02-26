import 'package:either_dart/either.dart';
import 'package:youtogether/core/usecases/use_case.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/repositories/i_auth_repository.dart';

import '../../../../core/error/failures.dart';

/// Retrieves the currently authenticated user from the API.
///
/// Delegates to [IAuthRepository.getCurrentUser].  Returns [null] inside
/// [Right] when no valid session exists, which the BLoC interprets as
/// [AuthState.unauthenticated].
///
/// This use case is dispatched on cold start via
/// [AuthEvent.checkStatusRequested] to restore the session state without
/// requiring the user to log in again.
class GetCurrentUserUseCase extends UseCase<UserEntity?, NoParams>{
  final IAuthRepository _repository;

  const GetCurrentUserUseCase(this._repository);

  @override
  Future<Either<Failure, UserEntity?>> call(NoParams params) {
    return _repository.getCurrentUser();
  }
}
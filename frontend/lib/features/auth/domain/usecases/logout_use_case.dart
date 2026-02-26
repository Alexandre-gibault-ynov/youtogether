import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/use_case.dart';
import '../repositories/i_auth_repository.dart';

/// Invalidates the current session and clears all locally stored tokens.
///
/// Delegates to [IAuthRepository.logout], which posts a revocation request
/// to the API and then wipes the local secure storage.
///
/// The caller (typically [AuthBloc]) must transition to
/// [AuthState.unauthenticated] on [Right] and to [AuthState.failure] on
/// [Left].
class LogoutUseCase extends UseCase<void, NoParams> {

  final IAuthRepository _repository;

  LogoutUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) {
    return _repository.logout();
  }
}
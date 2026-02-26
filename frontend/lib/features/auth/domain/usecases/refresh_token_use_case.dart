import 'package:either_dart/either.dart';
import 'package:youtogether/core/usecases/use_case.dart';
import 'package:youtogether/features/auth/domain/repositories/i_auth_repository.dart';

import '../../../../core/error/failures.dart';

/// Silently refreshes the access token using the stored refresh token.
///
/// Implements token rotation: the consumed refresh token is replaced with
/// a new pair (access + refresh) persisted to secure storage.
///
/// This use case is dispatched internally by [AuthBloc] when the Dio HTTP
/// interceptor intercepts a 401 Unauthorized response, in accordance with
/// OWASP A07 — Identification and Authentication Failures.
///
/// Fails with [AuthFailure] if the refresh token is expired, revoked, or
/// absent from local storage.
class RefreshTokenUseCase extends UseCase<void, NoParams> {
  final IAuthRepository _repository;

  const RefreshTokenUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) {
    return _repository.refreshToken();
  }
}
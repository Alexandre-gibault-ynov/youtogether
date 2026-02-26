import 'package:either_dart/either.dart';
import 'package:youtogether/core/error/exceptions.dart';
import 'package:youtogether/features/auth/data/datasources/i_auth_local_datasource.dart';
import 'package:youtogether/features/auth/data/datasources/i_auth_remote_datasource.dart';
import 'package:youtogether/features/auth/data/model/user_model.dart';
import 'package:youtogether/features/auth/domain/repositories/i_auth_repository.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/user_entity.dart';

/// Concrete implementation of [IAuthRepository].
///
/// Orchestrates calls between [IAuthRemoteDataSource] (NestJS REST API) and
/// [IAuthLocalDataSource] (flutter_secure_storage) to fulfil authentication
/// operations.
///
/// Exception-to-failure mapping strategy:
/// - [ServerException]  → [ServerFailure]
/// - [NetworkException] → [NetworkFailure]
/// - [AuthException]    → [AuthFailure]
/// - [CacheException]   → [CacheFailure]
///
/// No exception propagates beyond this class; all errors are returned as
/// [Left<Failure, T>] values.
class AuthRepositoryImpl implements IAuthRepository {
  final IAuthRemoteDatasource _remoteDatasource;
  final IAuthLocalDatasource _localDatasource;

  const AuthRepositoryImpl({
    required IAuthRemoteDatasource remoteDataSource,
    required IAuthLocalDatasource localDataSource,
  }) : _remoteDatasource = remoteDataSource,
       _localDatasource = localDataSource;


  @override
  Future<Either<Failure, UserEntity>> register({required String email, required String password, required String username}) async {
    try{
      final userModel = await _remoteDatasource.register(
        username: username,
        email: email,
        password: password,
      );
      await _persistToken(userModel);
      return Right(userModel.toDomain());
    } on ServerException catch (e) {
      // HTTP 409 Conflict — email already in use.
      if (e.statusCode == 409) {
        return Left(
          Failure.validation(
            errors: {'email': 'This email address is already in use.'},
          ),
        );
      }
      // HTTP 422 Unprocessable Entity — schema validation failure.
      if (e.statusCode == 422) {
        return Left(
          Failure.validation(
            errors: {'form': e.message},
          ),
        );
      }
      return Left(Failure.server(statusCode: e.statusCode, message: e.message));
    } on NetworkException {
      return const Left(Failure.network());
    } on CacheException catch (e) {
      return Left(Failure.cache(message: e.message));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final userModel = await _remoteDatasource.register(
        username: username,
        email: email,
        password: password,
      );
      await _persistToken(userModel);
      return Right(userModel.toDomain());
    } on ServerException catch (e) {
      // HTTP 409 Conflict — email already in use.
      if (e.statusCode == 409) {
        return Left(
          Failure.validation(
            errors: {'email': 'This email address is already in use.'},
          ),
        );
      }
      // HTTP 422 Unprocessable Entity — schema validation failure.
      if (e.statusCode == 422) {
        return Left(Failure.validation(errors: {'form': e.message}));
      }
      return Left(Failure.server(statusCode: e.statusCode, message: e.message));
    } on NetworkException {
      return const Left(Failure.network());
    } on CacheException catch (e) {
      return Left(Failure.cache(message: e.message));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      final userModel = await _remoteDatasource.login(
        email: email,
        password: password,
      );
      await _persistToken(userModel);
      return Right(userModel.toDomain());
    } on AuthException catch (e) {
      return Left(Failure.auth(message: e.message));
    } on NetworkException {
      return Left(Failure.network());
    } on ServerException catch (e) {
      return Left(Failure.server(statusCode: e.statusCode, message: e.message));
    } on CacheException catch (e) {
      return Left(Failure.cache(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _remoteDatasource.logout();
      await _localDatasource.clearTokens();
      return const Right(null);
    } on NetworkException {
      // Even if the network is unavailable, clear local tokens so the user
      // is effectively logged out on the device.
      await _localDatasource.clearTokens();
      return Right(null);
    } on ServerException catch (e) {
      return Left(Failure.server(statusCode: e.statusCode, message: e.message));
    } on CacheException catch (e) {
      return Left(Failure.cache(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> refreshToken() async {
    try {
      final storedRefreshToken = await _localDatasource.getRefreshToken();
      final tokenModel = await _remoteDatasource.refreshToken(
        storedRefreshToken,
      );
      await _localDatasource.saveTokens(
        accessToken: tokenModel.accessToken,
        refreshToken: tokenModel.refreshToken,
      );
      return const Right(null);
    } on AuthException catch (e) {
      return Left(Failure.auth(message: e.message));
    } on CacheException catch (e) {
      return Left(Failure.cache(message: e.message));
    } on NetworkException {
      return Left(Failure.network());
    } on ServerException catch (e) {
      return Left(Failure.server(statusCode: e.statusCode, message: e.message));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    final hasToken = await _localDatasource.hasValidToken();
    if (!hasToken) {
      return Right(null);
    }
    try {
      final userModel = await _remoteDatasource.getCurrentUser();
      return Right(userModel.toDomain());
    } on AuthException catch (e) {
      return Left(Failure.auth(message: e.message));
    } on NetworkException {
      return Left(Failure.network());
    } on ServerException catch (e) {
      return Left(Failure.server(statusCode: e.statusCode, message: e.message));
    }
  }

  @override
  Future<bool> isAuthenticated() {
    return _localDatasource.hasValidToken();
  }

  /// Persists the access and refresh tokens embedded in a [UserModel]
  /// returned from the login endpoints.
  ///
  /// Both tokens are mandatory at login time; their absence indicates an
  /// API contract violation.
  Future<void> _persistToken(UserModel userModel) async {
    final accessToken = userModel.accessToken;
    final refreshToken = userModel.refreshToken;
    if (accessToken == null || refreshToken == null) {
      throw const CacheException(
        message: 'API response is missing access token or refresh token.',
      );
    }
    await _localDatasource.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}

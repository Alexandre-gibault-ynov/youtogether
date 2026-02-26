import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';

/// Repository interface for all authentication operations.
///
/// This abstract class defines the contract that the domain layer depends on.
/// Concrete implementations reside in the data layer and are injected via
/// the service locator (get_it / injectable).
///
/// All methods return [Either<Failure, T>]:
/// - [Left] wraps a typed [Failure] variant.
/// - [Right] wraps the success value.
///
/// No raw exceptions cross this boundary.
abstract class IAuthRepository {
  /// Authenticates a user with [email] and [password].
  ///
  /// On success, stores the access and refresh tokens locally and returns
  /// the authenticated [UserEntity].
  ///
  /// Fails with [AuthFailure] for invalid credentials (HTTP 401 / 403).
  /// Fails with [NetworkFailure] when the device is offline.
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  });

  /// Creates a new registered user account.
  ///
  /// On success, persists the access and refresh tokens to local secure
  /// storage and returns the newly created [UserEntity], establishing a
  /// session immediately without requiring a separate login round-trip.
  ///
  /// Fails with [ValidationFailure] when the email is already in use
  /// (HTTP 409 Conflict) or when the payload violates the API schema
  /// (HTTP 422 Unprocessable Entity).
  /// Fails with [NetworkFailure] when the device is offline.
  /// Fails with [ServerFailure] for any other HTTP error.
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String username,
  });

  /// Invalidates the current session and clears locally stored tokens.
  ///
  /// Posts a logout request to the API so that the refresh token is
  /// revoked server-side, then clears the local secure storage.
  ///
  /// Fails with [NetworkFailure] if the API request cannot be initiated.
  Future<Either<Failure, void>> logout();

  /// Requests a new access token using the stored refresh token.
  ///
  /// Implements token rotation: the old refresh token is consumed and a
  /// new pair (access + refresh) is persisted to secure storage.
  ///
  /// Fails with [AuthFailure] if the refresh token is expired or invalid.
  /// Fails with [CacheFailure] if no refresh token is stored locally.
  Future<Either<Failure, void>> refreshToken();

  /// Returns the currently authenticated [UserEntity], or [null] if no
  /// valid session exists.
  ///
  /// Performs a lightweight GET /auth/me using the locally stored access
  /// token to verify and refresh user data.
  ///
  /// Fails with [AuthFailure] if the stored token is invalid.
  Future<Either<Failure, UserEntity?>> getCurrentUser();

  /// Returns [true] if a non-expired access token exists in local storage.
  ///
  /// This is a purely local, synchronous-equivalent check; it does not
  /// contact the API.
  Future<bool> isAuthenticated();
}
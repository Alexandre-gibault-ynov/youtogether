import '../model/token_model.dart';
import '../model/user_model.dart';

/// Data source interface for remote authentication operations via the
/// backend REST API.
///
/// Implementations use Dio as the HTTP client and throw typed exceptions
/// ([ServerException], [NetworkException], [AuthException]) on failure.
/// No [Failure] objects are returned here; exception-to-failure conversion
/// is the repository's responsibility.
abstract class IAuthRemoteDatasource {
  /// POST /auth/register
  ///
  /// Creates a new user account with [email], [password] and [username].
  /// Returns a [UserModel] containing the user profile and session tokens
  /// on success, establishing a session immediately.
  ///
  /// Throws [ServerException] with statusCode 409 when the email is already
  /// in use, or 422 when the payload fails server-side schema validation.
  /// Throws [NetworkException] when the device is offline.
  Future<UserModel> register({
    required String email,
    required String password,
    required String username,
  });

  /// POST /auth/login
  ///
  /// Authenticates using [email] and [password].
  /// Returns a [UserModel] containing the user profile and tokens on success.
  ///
  /// Throws [ServerException] for HTTP 4xx/5xx responses.
  /// Throws [AuthException] specifically for HTTP 401.
  /// Throws [NetworkException] when the device is offline.
  Future<UserModel> login({
    required String email,
    required String password,
  });

  /// POST /auth/logout
  ///
  /// Sends the stored refresh token to the server to revoke it.
  /// The local token store must be cleared by the repository after this call.
  ///
  /// Throws [ServerException] on API error.
  Future<void> logout();

  /// POST /auth/refresh
  ///
  /// Exchanges [refreshToken] for a new [TokenModel] (access + refresh pair).
  /// The caller must persist the returned tokens to local storage.
  ///
  /// Throws [AuthException] when the refresh token is expired or revoked.
  Future<TokenModel> refreshToken(String refreshToken);

  /// GET /auth/me
  ///
  /// Requires a valid Authorization: `Bearer <accessToken>` header.
  /// Returns the [UserModel] of the currently authenticated user.
  ///
  /// Throws [AuthException] for HTTP 401 (token invalid or expired).
  Future<UserModel> getCurrentUser();
}
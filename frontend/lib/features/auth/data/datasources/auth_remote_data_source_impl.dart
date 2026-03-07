import 'package:dio/dio.dart';
import 'package:youtogether/features/auth/data/datasources/i_auth_remote_data_source.dart';

import '../../../../core/error/exceptions.dart';
import '../models/token_model.dart';
import '../models/user_model.dart';

/// Dio-based implementation of [IAuthRemoteDataSource].
///
/// Maps every NestJS `ErrorResponseBody` to a typed exception so that
/// [AuthRepositoryImpl] can perform exception-to-failure conversion without
/// touching HTTP details.
///
/// Error mapping strategy (aligned with [HttpExceptionFilter] envelope):
/// - 401 → [AuthException]   (invalid or expired token / credentials)
/// - 403 → [AuthException]   (refresh token reuse detected)
/// - 409 → [ServerException] (email conflict — statusCode preserved)
/// - 422 → [ServerException] (validation failure — first errors entry as message)
/// - 5xx → [ServerException]
/// - DioExceptionType.connectionError / receiveTimeout → [NetworkException]
///
/// The base path (`/api`) is expected to be set on the [Dio] instance that
/// is injected; this class appends only the feature-level path (`/auth/…`).
class AuthRemoteDataSourceImpl implements IAuthRemoteDataSource {

  final Dio _dio;

  const AuthRemoteDataSourceImpl({required Dio dio}) : _dio = dio;

  // ---------------------------------------------------------------------------
  // Register
  // ---------------------------------------------------------------------------

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _send(
          () => _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {'email': email, 'password': password, 'username': username},
      ),
    );
    return UserModel.fromJson(response);
  }

  // ---------------------------------------------------------------------------
  // Login
  // ---------------------------------------------------------------------------

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _send(
          () => _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      ),
    );
    return UserModel.fromJson(response);
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

  @override
  Future<void> logout() async {
    await _send(
          () => _dio.post<void>('/auth/logout'),
    );
  }

  // ---------------------------------------------------------------------------
  // Token refresh
  // ---------------------------------------------------------------------------

  @override
  Future<TokenModel> refreshToken(String refreshToken) async {
    // The refresh endpoint expects the refresh token as a Bearer token in
    // the Authorization header, not in the request body.
    final response = await _send(
          () => _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        options: Options(
          headers: {'Authorization': 'Bearer $refreshToken'},
        ),
      ),
    );
    return TokenModel.fromJson(response);
  }

  // ---------------------------------------------------------------------------
  // Get current user
  // ---------------------------------------------------------------------------

  @override
  Future<UserModel> getCurrentUser() async {
    final response = await _send(
          () => _dio.get<Map<String, dynamic>>('/auth/me'),
    );
    return UserModel.fromJson(response);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Executes a Dio request and returns the decoded response body.
  ///
  /// Converts [DioException] into the appropriate typed exception:
  /// - 401 / 403                 → [AuthException]
  /// - 4xx (other) / 5xx        → [ServerException] (with statusCode preserved)
  /// - Connectivity / timeout   → [NetworkException]
  Future<Map<String, dynamic>> _send(
      Future<Response<dynamic>> Function() call,
      ) async {
    try {
      final response = await call();
      // Dio resolves 2xx responses normally; the body may be null for 204.
      final data = response.data;
      if (data == null) return {};
      return data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioException(e);
    }
  }

  /// Translates a [DioException] into a typed exception.
  Never _handleDioException(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionTimeout) {
      throw const NetworkException();
    }

    final response = e.response;
    if (response == null) {
      throw const NetworkException();
    }

    final statusCode = response.statusCode ?? 0;
    final body = response.data;
    final message = _extractMessage(body);

    if (statusCode == 401 || statusCode == 403) {
      throw AuthException(message: message);
    }

    // HTTP 422 — extract field-level validation errors as a single message.
    if (statusCode == 422) {
      final errors = _extractErrors(body);
      final errorMessage = errors.isNotEmpty
          ? errors.entries.map((e) => '${e.key}: ${e.value}').join('; ')
          : message;
      throw ServerException(statusCode: statusCode, message: errorMessage);
    }

    throw ServerException(statusCode: statusCode, message: message);
  }

  /// Extracts the `message` field from a NestJS [ErrorResponseBody].
  String _extractMessage(dynamic body) {
    if (body is Map<String, dynamic>) {
      return body['message']?.toString() ?? 'An unknown error occurred.';
    }
    return 'An unknown error occurred.';
  }

  /// Extracts the `errors` map from a 422 NestJS [ErrorResponseBody].
  Map<String, String> _extractErrors(dynamic body) {
    if (body is Map<String, dynamic>) {
      final errors = body['errors'];
      if (errors is Map) {
        return errors.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
        );
      }
    }
    return {};
  }
}
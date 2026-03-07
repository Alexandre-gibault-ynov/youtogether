import 'package:dio/dio.dart';

import '../error/exceptions.dart';
import '../../features/auth/data/datasources/i_auth_local_data_source.dart';

/// Dio interceptor that attaches the stored access token to every request.
///
/// For each outgoing request, [AuthInterceptor] reads the access token from
/// [IAuthLocalDataSource] and sets the `Authorization: Bearer <token>` header.
///
/// If no token is available (e.g. on the register or login requests made before
/// a session is established), the request proceeds unmodified. The backend
/// is responsible for enforcing route-level authentication via NestJS guards.
///
/// This interceptor deliberately does not handle token refresh on 401 responses.
/// Token refresh is managed by [AuthBloc.AuthTokenRefreshRequested], which is
/// dispatched by the repository layer when a refresh is needed.
class AuthInterceptor extends Interceptor {
  const AuthInterceptor({required IAuthLocalDataSource localDataSource})
      : _localDataSource = localDataSource;

  final IAuthLocalDataSource _localDataSource;

  @override
  Future<void> onRequest(
      RequestOptions options,
      RequestInterceptorHandler handler,
      ) async {
    try {
      final token = await _localDataSource.getAccessToken();
      options.headers['Authorization'] = 'Bearer $token';
    } on CacheException {
      // No token in storage — public endpoint, proceed without header.
      // The backend guard will return 401 for protected routes, which is the
      // correct behaviour when the user is not authenticated.
    }

    handler.next(options);
  }
}
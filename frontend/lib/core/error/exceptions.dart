library;

// Server / HTTP exceptions

/// Thrown when the backend returns an HTTP error responses (4xx / 5xx).
class ServerException implements Exception {
  final int statusCode;
  final String message;

  const ServerException({required this.statusCode, required this.message});

  @override
  String toString() =>
      'ServerException(statusCode: $statusCode, message: $message';
}

//Network Exceptions

/// Thrown when a request cannot be initiated due to absent connectivity.
class NetworkException implements Exception {
  const NetworkException();

  @override
  String toString() => 'NetworkException()';
}

// Cache / local storage exceptions

/// Thrown by [IAuthLocalDataSource] implementations when secure storage
/// operations fails or a required token is absent.
class CacheException implements Exception {
  final String message;

  const CacheException({required this.message});

  @override
  String toString() => 'CacheException(message: $message)';
}

// Authentication Exceptions

/// Thrown when credentials are invalid or an auth token has expired.
class AuthException implements Exception {
  final String message;

  const AuthException({required this.message});

  @override
  String toString() => 'AuthException(message: $message)';
}

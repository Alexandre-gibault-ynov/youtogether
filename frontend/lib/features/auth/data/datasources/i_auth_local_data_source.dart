/// Data source interface for local secure token storage.
///
/// Implementations use [flutter_secure_storage], which encrypts data at rest
/// using AES-256 on Android (Android Keystore) and the Keychain on iOS.
///
/// In accordance with OWASP A02 — Cryptographic Failures, no plain-text
/// credentials or tokens are stored outside of this secure storage layer.
///
/// All methods throw [CacheException] on storage-level errors.
abstract class IAuthLocalDataSource {
  /// Persists the [accessToken] and [refreshToken] to encrypted secure storage.
  ///
  /// Overwrites any previously stored tokens.
  ///
  /// Throws [CacheException] if the write operation fails.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });

  /// Returns the stored access token.
  ///
  /// Throws [CacheException] if no access token is present in storage.
  Future<String> getAccessToken();

  /// Returns the stored refresh token.
  ///
  /// Throws [CacheException] if no refresh token is present in storage.
  Future<String> getRefreshToken();

  /// Removes all stored tokens from secure storage.
  ///
  /// Called on logout to ensure no stale credentials remain on the device.
  ///
  /// Throws [CacheException] if the delete operation fails.
  Future<void> clearTokens();

  /// Returns [true] if a non-expired access token exists in local storage.
  ///
  /// This check is performed without network access; it relies solely on the
  /// presence and validity of the locally stored token.
  Future<bool> hasValidToken();
}

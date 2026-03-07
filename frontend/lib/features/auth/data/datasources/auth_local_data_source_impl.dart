import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:youtogether/features/auth/data/datasources/i_auth_local_data_source.dart';

import '../../../../core/error/exceptions.dart';

/// Storage keys — kept private to this file to avoid magic-string duplication.
const String _kAccessToken = 'access_token';
const String _kRefreshToken = 'refresh_token';

/// [FlutterSecureStorage]-backed implementation of [IAuthLocalDataSource].
///
/// Stores JWT tokens using platform-native encryption:
/// - Android : RSA-OAEP (SHA-256 / MGF1) + AES-GCM-NoPadding, key anchored
///             in the Android Keystore. This replaces the deprecated Jetpack
///             Security `EncryptedSharedPreferences` approach — see migration
///             note below.
/// - iOS/macOS: Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
///
/// OWASP A02 compliance is maintained: tokens are never stored in plain text
/// and the encryption key never leaves the Android Keystore hardware boundary.
///
/// `hasValidToken` performs a presence check only. JWT signature / expiry
/// verification is performed server-side; a client-side expiry parse is out
/// of scope for the MVP.
class AuthLocalDataSourceImpl implements IAuthLocalDataSource {

  final  FlutterSecureStorage _storage;

  const AuthLocalDataSourceImpl({
    required FlutterSecureStorage secureStorage
  }) : _storage = secureStorage;

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: _kAccessToken, value: accessToken),
        _storage.write(key: _kRefreshToken, value: refreshToken),
      ]);
    } catch (e) {
      throw CacheException(message: 'Failed to save tokens: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  @override
  Future<String> getAccessToken() async {
    final token = await _read(_kAccessToken);
    if (token == null || token.isEmpty) {
      throw const CacheException(message: 'No access token found in storage.');
    }
    return token;
  }

  @override
  Future<String> getRefreshToken() async {
    final token = await _read(_kRefreshToken);
    if (token == null || token.isEmpty) {
      throw const CacheException(
        message: 'No refresh token found in storage.',
      );
    }
    return token;
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  @override
  Future<void> clearTokens() async {
    try {
      await Future.wait([
        _storage.delete(key: _kAccessToken),
        _storage.delete(key: _kRefreshToken),
      ]);
    } catch (e) {
      throw CacheException(message: 'Failed to clear tokens: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Check
  // ---------------------------------------------------------------------------

  @override
  Future<bool> hasValidToken() async {
    final token = await _read(_kAccessToken);
    return token != null && token.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      throw CacheException(message: 'Failed to read key "$key": $e');
    }
  }
}
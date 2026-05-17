import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralised wrapper around [FlutterSecureStorage].
///
/// SECURITY (H-6, CWE-312): all values written here must be encrypted at rest.
/// - Android: flutter_secure_storage v10 encrypts every value with its own
///   custom ciphers by default (the legacy `encryptedSharedPreferences` flag
///   is deprecated and ignored — data is no longer stored as plain
///   SharedPreferences). We pin [AndroidOptions] explicitly so the intent is
///   documented and survives a future package change.
/// - iOS: values are scoped to this device only and readable only after the
///   first unlock, so credentials are never written to iCloud/iTunes backups.
class SecureStorageService {
  static const AndroidOptions _androidOptions = AndroidOptions();
  static const IOSOptions _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  static const _storage = FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  // ── API Keys ───────────────────────────────────────────────────────────────
  static Future<void> saveApiKey(String provider, String value) async {
    await _storage.write(key: 'api_key_$provider', value: value);
  }

  static Future<String?> getApiKey(String provider) async {
    return _storage.read(key: 'api_key_$provider');
  }

  static Future<void> deleteApiKey(String provider) async {
    await _storage.delete(key: 'api_key_$provider');
  }

  // ── User tokens ────────────────────────────────────────────────────────────
  // The JWT access token and the long-lived refresh token are credentials and
  // must live in the platform keystore/keychain, never in SharedPreferences.
  static Future<void> saveUserToken(String token) async {
    await _storage.write(key: 'user_token', value: token);
  }

  static Future<String?> getUserToken() async {
    return _storage.read(key: 'user_token');
  }

  static Future<void> deleteUserToken() async {
    await _storage.delete(key: 'user_token');
  }

  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: 'user_refresh_token', value: token);
  }

  static Future<String?> getRefreshToken() async {
    return _storage.read(key: 'user_refresh_token');
  }

  static Future<void> deleteRefreshToken() async {
    await _storage.delete(key: 'user_refresh_token');
  }

  // Delete all secure data (logout)
  static Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}

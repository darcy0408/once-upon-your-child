import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // API Keys
  static Future<void> saveApiKey(String provider, String value) async {
    await _storage.write(key: 'api_key_$provider', value: value);
  }

  static Future<String?> getApiKey(String provider) async {
    return _storage.read(key: 'api_key_$provider');
  }

  static Future<void> deleteApiKey(String provider) async {
    await _storage.delete(key: 'api_key_$provider');
  }

  // User tokens
  static Future<void> saveUserToken(String token) async {
    await _storage.write(key: 'user_token', value: token);
  }

  static Future<String?> getUserToken() async {
    return _storage.read(key: 'user_token');
  }

  // Delete all secure data (logout)
  static Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  // Migrate any previously obfuscated values from SharedPreferences
  static Future<void> migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('secure_storage_migrated') == true) return;

    for (final key in ['api_key_gemini', 'api_key_openai', 'user_token']) {
      final old = prefs.getString(key);
      if (old != null && old.isNotEmpty) {
        // Write to real secure storage and remove from SharedPreferences
        await _storage.write(key: key, value: old);
        await prefs.remove(key);
      }
    }
    await prefs.setBool('secure_storage_migrated', true);
  }
}

// Stub implementation for development - removed flutter_secure_storage dependency
// Uses SharedPreferences as fallback for all operations

import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  // API Keys
  static Future<void> saveApiKey(String provider, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key_$provider', value);
  }

  static Future<String?> getApiKey(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_key_$provider');
  }

  static Future<void> deleteApiKey(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_key_$provider');
  }

  // User tokens
  static Future<void> saveUserToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_token', token);
  }

  static Future<String?> getUserToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_token');
  }

  // Delete all secure data (logout)
  static Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_key_gemini');
    await prefs.remove('api_key_openai');
    await prefs.remove('user_token');
  }

  // Migration helper - no-op since we're using SharedPreferences already
  static Future<void> migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('secure_storage_migrated', true);
  }
}

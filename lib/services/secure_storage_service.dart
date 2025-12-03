import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  // API Keys
  static Future<void> saveApiKey(String provider, String value) async {
    await _executeWithFallback(
      () => _storage.write(key: 'api_key_$provider', value: value),
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('api_key_$provider', value);
      },
    );
  }

  static Future<String?> getApiKey(String provider) async {
    return _executeWithFallback(
      () => _storage.read(key: 'api_key_$provider'),
      () async {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString('api_key_$provider');
      },
    );
  }

  static Future<void> deleteApiKey(String provider) async {
    await _executeWithFallback(
      () => _storage.delete(key: 'api_key_$provider'),
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('api_key_$provider');
      },
    );
  }

  // User tokens
  static Future<void> saveUserToken(String token) async {
    await _executeWithFallback(
      () => _storage.write(key: 'user_token', value: token),
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_token', token);
      },
    );
  }

  static Future<String?> getUserToken() async {
    return _executeWithFallback(
      () => _storage.read(key: 'user_token'),
      () async {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString('user_token');
      },
    );
  }

  // Delete all secure data (logout)
  static Future<void> deleteAll() async {
    await _executeWithFallback(
      () => _storage.deleteAll(),
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('api_key_gemini');
        await prefs.remove('api_key_openai');
        await prefs.remove('user_token');
      },
    );
  }

  // Migration helper - one-time migration from SharedPreferences
  static Future<void> migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Migrate API keys
    final geminiKey = prefs.getString('gemini_api_key');
    if (geminiKey != null) {
      await saveApiKey('gemini', geminiKey);
      await prefs.remove('gemini_api_key');
    }

    final openaiKey = prefs.getString('openai_api_key');
    if (openaiKey != null) {
      await saveApiKey('openai', openaiKey);
      await prefs.remove('openai_api_key');
    }

    // Mark migration complete
    await prefs.setBool('secure_storage_migrated', true);
  }

  static Future<T> _executeWithFallback<T>(
    Future<T> Function() primary,
    Future<T> Function() fallback,
  ) async {
    try {
      return await primary();
    } on MissingPluginException {
      return await fallback();
    }
  }
}

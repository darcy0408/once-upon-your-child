// Stub implementation for development - removed flutter_secure_storage dependency
// Uses SharedPreferences as fallback for all operations

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  // Simple obfuscation key (NOT real encryption, but better than cleartext for basic prevention)
  // In production, use platform-specific secure storage or a real key management system
  static const _key = 'StoryWeaverSecretKey2024';

  static String _encrypt(String value) {
    try {
      final bytes = utf8.encode(value);
      final keyBytes = utf8.encode(_key);
      final encryptedByIds = List<int>.generate(bytes.length, (i) {
        return bytes[i] ^ keyBytes[i % keyBytes.length];
      });
      return base64.encode(encryptedByIds);
    } catch (e) {
      return value; // Fallback
    }
  }

  static String _decrypt(String value) {
    try {
      final bytes = base64.decode(value);
      final keyBytes = utf8.encode(_key);
      final decryptedBytes = List<int>.generate(bytes.length, (i) {
        return bytes[i] ^ keyBytes[i % keyBytes.length];
      });
      return utf8.decode(decryptedBytes);
    } catch (e) {
      // If decryption fails (e.g. old plain text data), return original
      return value; 
    }
  }

  // API Keys
  static Future<void> saveApiKey(String provider, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key_$provider', _encrypt(value));
  }

  static Future<String?> getApiKey(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString('api_key_$provider');
    if (val == null) return null;
    return _decrypt(val);
  }

  static Future<void> deleteApiKey(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_key_$provider');
  }

  // User tokens
  static Future<void> saveUserToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_token', _encrypt(token));
  }

  static Future<String?> getUserToken() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString('user_token');
    if (val == null) return null;
    return _decrypt(val);
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

// lib/services/tts_api_service.dart
//
// Fetches Neural2 MP3 audio from the backend /tts/synthesize endpoint.
// Returns null if the backend is unavailable or credentials are not
// configured — callers should fall back to on-device flutter_tts.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import 'api_service_manager.dart';

class TtsApiService {
  /// Default Neural2 voice — warm female, great for kids' stories.
  static const String defaultVoice = 'en-US-Neural2-F';

  /// Comfortable reading pace for children.
  static const double defaultRate = 0.9;

  /// Synthesize [text] via the backend Google Neural2 endpoint.
  ///
  /// Returns raw MP3 bytes on success, or null if the service is
  /// unavailable (no credentials, network error, etc.) so the caller
  /// can fall back to flutter_tts.
  static Future<Uint8List?> synthesize(
    String text, {
    String voiceId = defaultVoice,
    double speakingRate = defaultRate,
  }) async {
    if (text.trim().isEmpty) return null;

    try {
      final baseUrl = Environment.backendUrl;
      final uri = Uri.parse('$baseUrl/tts/synthesize');
      final headers = await ApiServiceManager.authHeaders();

      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'text': text,
              'voice_id': voiceId,
              'speaking_rate': speakingRate,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final b64 = data['audio_base64'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          return base64Decode(b64);
        }
      }

      // 503 = credentials not configured → expected fallback
      if (response.statusCode != 503) {
        debugPrint(
          '⚠️ TTS API returned ${response.statusCode}: ${response.body}',
        );
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ TTS API unavailable, using on-device TTS: $e');
      return null;
    }
  }
}

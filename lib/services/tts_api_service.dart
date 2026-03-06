// lib/services/tts_api_service.dart
//
// Fetches ElevenLabs MP3 audio from the backend /tts/synthesize endpoint.
// Returns null if the backend is unavailable or ELEVENLABS_API_KEY is not
// configured — callers should fall back to on-device flutter_tts.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../models/elevenlabs_voice.dart';
import 'api_service_manager.dart';

class TtsApiService {
  /// Synthesize [text] via the backend ElevenLabs endpoint.
  ///
  /// [voiceId] defaults to Rachel if not provided.
  /// Returns raw MP3 bytes on success, or null if the service is
  /// unavailable (no API key, network error, etc.).
  static Future<Uint8List?> synthesize(
    String text, {
    String? voiceId,
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
              'voice_id': voiceId ?? ElevenLabsVoice.defaultVoiceId,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final b64 = data['audio_base64'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          return base64Decode(b64);
        }
      }

      // 503 = API key not configured → expected graceful fallback
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

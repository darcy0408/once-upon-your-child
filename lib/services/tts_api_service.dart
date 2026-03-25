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

/// Result from the TTS synthesize endpoint.
/// [wordTimestamps] is empty when the backend could not return timing data
/// (long/chunked stories, dialogue mode, or older backend). The caller should
/// fall back to character-weighted estimation when the list is empty.
class TtsSynthesisResult {
  final Uint8List audioBytes;

  /// Per-word timing from ElevenLabs alignment data.
  /// Each entry is (startMs, endMs) for the word at that index, parallel to
  /// the tokenised word list in the story reader.
  final List<({int startMs, int endMs})> wordTimestamps;

  const TtsSynthesisResult({
    required this.audioBytes,
    required this.wordTimestamps,
  });
}

class TtsApiService {
  /// Synthesize [text] via the backend ElevenLabs endpoint.
  ///
  /// Returns a [TtsSynthesisResult] with audio bytes and optional per-word
  /// timestamps, or null if the service is unavailable.
  static Future<TtsSynthesisResult?> synthesize(
    String text, {
    String? voiceId,
    String? characterVoiceId,
  }) async {
    if (text.trim().isEmpty) return null;

    try {
      final baseUrl = Environment.backendUrl;
      final uri = Uri.parse('$baseUrl/tts/synthesize');
      final headers = await ApiServiceManager.authHeaders();

      final body = <String, dynamic>{
        'text': text,
        'voice_id': voiceId ?? ElevenLabsVoice.defaultVoiceId,
        if (characterVoiceId != null) 'character_voice_id': characterVoiceId,
      };

      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 300));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final b64 = data['audio_base64'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          final audioBytes = base64Decode(b64);

          // Parse word timestamps when available (short single-voice stories).
          final rawTimestamps = data['word_timestamps'] as List<dynamic>?;
          final wordTimestamps = rawTimestamps
                  ?.map((e) {
                    final m = e as Map<String, dynamic>;
                    return (
                      startMs: (m['start_ms'] as num).toInt(),
                      endMs: (m['end_ms'] as num).toInt(),
                    );
                  })
                  .toList() ??
              [];

          return TtsSynthesisResult(
            audioBytes: audioBytes,
            wordTimestamps: wordTimestamps,
          );
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

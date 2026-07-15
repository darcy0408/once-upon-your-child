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

/// Thrown by [TtsApiService.synthesize] when the backend returns HTTP 429.
/// Callers should apply exponential backoff before retrying.
class TtsRateLimitException implements Exception {
  @override
  String toString() => 'TtsRateLimitException: ElevenLabs rate limit exceeded';
}

/// Thrown when the backend refuses synthesis with HTTP 403 and a COPPA
/// age/consent gate code (`AGE_REQUIRED`, `PARENTAL_CONSENT_REQUIRED`,
/// `PARENTAL_CONSENT_UNVERIFIED`): the server has no resolved age (or no
/// verified consent) for this user, so it will not forward text to the TTS
/// vendor. Callers should stay SILENT rather than falling back to the
/// on-device robotic voice — the gate clears as soon as onboarding syncs an
/// age, and a robotic first impression is worse than a quiet one.
class TtsConsentGateException implements Exception {
  /// The backend gate code, e.g. 'AGE_REQUIRED'.
  final String code;

  TtsConsentGateException(this.code);

  @override
  String toString() => 'TtsConsentGateException($code)';
}

/// Thrown when the backend returns HTTP 503 with `code: TTS_CAP_EXCEEDED` —
/// the user has used their monthly premium-voice budget OR the global TTS
/// budget is depleted. Callers should fall back to on-device flutter_tts and
/// surface a one-time-per-month toast inviting upgrade.
class TtsCapExceededException implements Exception {
  /// 'user_cap_exceeded' or 'global_cap_exceeded'.
  final String reason;
  final int charsUsed;
  final int charsLimit;
  final String message;

  TtsCapExceededException({
    required this.reason,
    required this.charsUsed,
    required this.charsLimit,
    required this.message,
  });

  bool get isUserCap => reason == 'user_cap_exceeded';
  bool get isGlobalCap => reason == 'global_cap_exceeded';

  @override
  String toString() =>
      'TtsCapExceededException($reason, $charsUsed/$charsLimit chars)';
}

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
    /// Speaking rate passed to ElevenLabs (0.7–1.2). Defaults to 1.0 (normal
    /// speed). Pass ~0.85 for Sprout/young-child narration.
    double speed = 1.0,
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
        if (speed != 1.0) 'speed': speed,
      };

      var response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 300));

      // On 401 (expired token), force re-auth and retry once.
      if (response.statusCode == 401) {
        await ApiServiceManager.resetAndReauthenticate();
        final retryHeaders = await ApiServiceManager.authHeaders();
        response = await http
            .post(
              uri,
              headers: retryHeaders,
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 300));
      }

      return mapResponse(response);
    } on TtsRateLimitException {
      rethrow;
    } on TtsCapExceededException {
      rethrow;
    } on TtsConsentGateException {
      rethrow;
    } catch (e) {
      debugPrint('⚠️ TTS API unavailable, using on-device TTS: $e');
      return null;
    }
  }

  /// Maps a /tts/synthesize HTTP [response] to a result (200 with audio),
  /// null (unavailable — callers fall back to on-device TTS), or one of the
  /// typed exceptions above. Split out so the status-code contract is unit
  /// testable without network or auth mocking.
  @visibleForTesting
  static TtsSynthesisResult? mapResponse(http.Response response) {
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

    if (response.statusCode == 429) {
      throw TtsRateLimitException();
    }
    // 403 with a COPPA gate code = the server has no resolved age / verified
    // consent for this user (ENFORCE_RESOLVED_AGE et al., flipped ON in prod
    // 2026-07-14). Typed so callers can stay silent instead of speaking the
    // robotic on-device fallback. Other 403s fall through to the generic
    // log + null return.
    if (response.statusCode == 403) {
      String? code;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        code = body['code'] as String?;
      } catch (_) {
        // Body wasn't JSON — treat as a generic failure below.
      }
      if (code == 'AGE_REQUIRED' ||
          code == 'PARENTAL_CONSENT_REQUIRED' ||
          code == 'PARENTAL_CONSENT_UNVERIFIED') {
        throw TtsConsentGateException(code!);
      }
    }
    // 503 = API key not configured (silent fallback) OR cap exceeded
    // (caller-visible fallback with toast). Distinguish via response body.
    if (response.statusCode == 503) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['code'] == 'TTS_CAP_EXCEEDED') {
          throw TtsCapExceededException(
            reason: (body['reason'] as String?) ?? 'user_cap_exceeded',
            charsUsed: (body['chars_used'] as num?)?.toInt() ?? 0,
            charsLimit: (body['chars_limit'] as num?)?.toInt() ?? 0,
            message: (body['message'] as String?) ?? '',
          );
        }
      } on TtsCapExceededException {
        rethrow;
      } catch (_) {
        // Body wasn't JSON or didn't match — silent fallback.
      }
    } else {
      debugPrint(
        '⚠️ TTS API returned ${response.statusCode}: ${response.body}',
      );
    }
    return null;
  }
}

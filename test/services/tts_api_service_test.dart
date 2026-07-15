// Unit tests for TtsApiService.mapResponse — the status-code contract of
// /tts/synthesize. Pinned after the 2026-07-14 incident where the prod COPPA
// flag flip (ENFORCE_RESOLVED_AGE) made every synthesize call 403
// AGE_REQUIRED and the app opened with the robotic on-device voice:
// consent-gate 403s must surface as TtsConsentGateException (callers stay
// silent), never as a generic null (callers fall back to robotic TTS).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:story_weaver_app/services/tts_api_service.dart';

void main() {
  group('TtsApiService.mapResponse', () {
    test('200 with audio returns parsed result with word timestamps', () {
      final resp = http.Response(
        jsonEncode({
          'audio_base64': base64Encode([1, 2, 3, 4]),
          'word_timestamps': [
            {'start_ms': 0, 'end_ms': 250},
            {'start_ms': 250, 'end_ms': 700},
          ],
        }),
        200,
      );
      final result = TtsApiService.mapResponse(resp);
      expect(result, isNotNull);
      expect(result!.audioBytes, [1, 2, 3, 4]);
      expect(result.wordTimestamps.length, 2);
      expect(result.wordTimestamps.first.startMs, 0);
      expect(result.wordTimestamps.last.endMs, 700);
    });

    test('200 without audio returns null (silent fallback)', () {
      final resp = http.Response(jsonEncode({'audio_base64': ''}), 200);
      expect(TtsApiService.mapResponse(resp), isNull);
    });

    test('429 throws TtsRateLimitException', () {
      final resp = http.Response('', 429);
      expect(
        () => TtsApiService.mapResponse(resp),
        throwsA(isA<TtsRateLimitException>()),
      );
    });

    test('429 TTS_QUOTA_EXCEEDED throws TtsQuotaExceededException', () {
      final resp = http.Response(
        jsonEncode({
          'error': 'Daily narration limit reached',
          'code': 'TTS_QUOTA_EXCEEDED',
          'daily_limit': 300,
          'syntheses_used': 300,
        }),
        429,
      );
      expect(
        () => TtsApiService.mapResponse(resp),
        throwsA(
          isA<TtsQuotaExceededException>()
              .having((e) => e.dailyLimit, 'dailyLimit', 300)
              .having((e) => e.synthesesUsed, 'synthesesUsed', 300),
        ),
      );
    });

    test('429 with non-quota JSON body throws TtsRateLimitException', () {
      final resp = http.Response(
        jsonEncode({'error': 'rate limit exceeded'}),
        429,
      );
      expect(
        () => TtsApiService.mapResponse(resp),
        throwsA(isA<TtsRateLimitException>()),
      );
    });

    for (final code in [
      'AGE_REQUIRED',
      'PARENTAL_CONSENT_REQUIRED',
      'PARENTAL_CONSENT_UNVERIFIED',
    ]) {
      test('403 $code throws TtsConsentGateException', () {
        final resp = http.Response(
          jsonEncode({'error': 'blocked', 'code': code}),
          403,
        );
        expect(
          () => TtsApiService.mapResponse(resp),
          throwsA(
            isA<TtsConsentGateException>().having((e) => e.code, 'code', code),
          ),
        );
      });
    }

    test('403 with unrelated code returns null (generic fallback)', () {
      final resp = http.Response(
        jsonEncode({'error': 'nope', 'code': 'SOMETHING_ELSE'}),
        403,
      );
      expect(TtsApiService.mapResponse(resp), isNull);
    });

    test('403 with non-JSON body returns null (generic fallback)', () {
      final resp = http.Response('<html>Forbidden</html>', 403);
      expect(TtsApiService.mapResponse(resp), isNull);
    });

    test('503 TTS_CAP_EXCEEDED throws TtsCapExceededException', () {
      final resp = http.Response(
        jsonEncode({
          'code': 'TTS_CAP_EXCEEDED',
          'reason': 'user_cap_exceeded',
          'chars_used': 100,
          'chars_limit': 100,
          'message': 'budget used',
        }),
        503,
      );
      expect(
        () => TtsApiService.mapResponse(resp),
        throwsA(
          isA<TtsCapExceededException>()
              .having((e) => e.reason, 'reason', 'user_cap_exceeded'),
        ),
      );
    });

    test('503 without cap code returns null (key not configured)', () {
      final resp = http.Response(jsonEncode({'error': 'no key'}), 503);
      expect(TtsApiService.mapResponse(resp), isNull);
    });
  });
}

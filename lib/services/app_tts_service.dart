// lib/services/app_tts_service.dart
//
// Central TTS service — ElevenLabs when available, on-device FlutterTts fallback.
// Common short prompts are pre-fetched into an in-memory cache at startup so
// they play instantly with no API latency.

import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/elevenlabs_voice.dart';
import 'tts_api_service.dart';

/// Common wizard/onboarding phrases pre-warmed at startup.
const List<String> kWarmUpPhrases = [
  "Tap the star to start your adventure!",
  "Hi, what's your name?",
  "How old are you? Tap your number!",
  "What is your hero's name? Tap the microphone to say it!",
  "Pick your hero look! Tap the picture you like.",
  "Tap your buddies to bring them along!",
  "Where will your adventure take place?",
  "Where should your adventure happen? Tap to pick!",
  "Tell me where your adventure takes place.",
  "What kind of story do you want?",
  "You are all set! Tap Make Magic!",
  "Your adventure is ready! Let's go!",
  "Microphone is unavailable. Please type your idea.",
  "Microphone is unavailable right now.",
  "Say your companion name. For example, Whiskers.",
  "Describe what your companion looks like.",
  "Imagine It!",
  "Rainbow Land!",
  "Crystal Cave!",
  "Dragon Friends!",
  "My Big Feelings!",
];

class AppTtsService {
  AppTtsService._();
  static final AppTtsService instance = AppTtsService._();

  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _fallback = FlutterTts();
  final Map<String, Uint8List> _cache = {};
  bool _ready = false;

  /// Call once at app startup. Initialises the fallback TTS engine and
  /// kicks off background pre-fetching of [warmUpPhrases].
  Future<void> init({List<String> warmUpPhrases = kWarmUpPhrases}) async {
    await _fallback.setLanguage('en-US');
    await _fallback.setSpeechRate(0.42);
    await _fallback.setPitch(1.05);
    _ready = true;
    // Fire-and-forget — don't block app startup
    _prewarm(warmUpPhrases);
  }

  Future<void> _prewarm(List<String> phrases) async {
    final voiceId = await _savedVoiceId();
    for (final phrase in phrases) {
      final key = phrase.trim();
      if (_cache.containsKey(key)) continue;
      try {
        final mp3 = await TtsApiService.synthesize(key, voiceId: voiceId);
        if (mp3 != null && mp3.isNotEmpty) _cache[key] = mp3;
      } catch (_) {}
    }
  }

  /// Speak [text] via ElevenLabs (cached or fresh), falling back to
  /// on-device TTS if the network is unavailable.
  ///
  /// Set [awaitCompletion] = true to wait until audio finishes playing
  /// before returning (e.g. speak a prompt, then open the mic).
  Future<void> speak(
    String text, {
    String? voiceId,
    bool awaitCompletion = false,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;
    try {
      Uint8List? mp3 = _cache[cleanText];
      if (mp3 == null) {
        final id = voiceId ?? await _savedVoiceId();
        mp3 = await TtsApiService.synthesize(cleanText, voiceId: id);
        if (mp3 != null && mp3.isNotEmpty) _cache[cleanText] = mp3;
      }
      if (mp3 != null && mp3.isNotEmpty) {
        await _player.stop();
        await _player.play(BytesSource(mp3));
        if (awaitCompletion) {
          await _player.onPlayerComplete.first
              .timeout(const Duration(seconds: 30));
        }
        return;
      }
    } catch (_) {}
    // On-device fallback
    if (_ready) await _fallback.speak(text);
  }

  Future<void> stop() async {
    await _player.stop();
    await _fallback.stop();
  }

  Future<String?> _savedVoiceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(ElevenLabsVoice.prefsKey);
  }
}

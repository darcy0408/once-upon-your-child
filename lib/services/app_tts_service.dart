// lib/services/app_tts_service.dart
//
// Central TTS service — ElevenLabs when available, on-device FlutterTts fallback.
// Common short prompts are pre-fetched into an in-memory cache at startup so
// they play instantly with no API latency.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/elevenlabs_voice.dart';
import '../theme/age_band_theme.dart';
import 'tts_api_service.dart';
import 'web_audio_player_stub.dart'
    if (dart.library.html) 'web_audio_player.dart';

/// Common wizard/onboarding phrases pre-warmed at startup.
const List<String> kWarmUpPhrases = [
  "Tap the star to start your adventure!",
  "Hi, what's your name?",
  "How old are you? Tap your number!",
  "What is your hero's name? Tap the microphone to say it!",
  "Pick your hero look! Tap the picture you like.",
  "Tap your buddies to bring them along!",
  "Where will your adventure take place?",
  "Where should we go? Tap the picture you want.",
  "Tell me where your adventure takes place.",
  "What kind of story do you want?",
  "You are all set! Tap Make Magic!",
  "Your adventure is ready! Let's go!",
  "Microphone is unavailable. Please type your idea.",
  "Microphone is unavailable right now.",
  "Say your companion name. For example, Whiskers.",
  "Describe what your companion looks like.",
  "Make One Up!",
  "Rainbow World!",
  "Cave Full of Crystals!",
  "Friendly Dragons!",
  "Big Feelings!",

  // Avatar wizard — Sprout (3-5) step prompts
  "Are you a girl or a boy?",
  "What color is your hair?",
  "What color are your eyes?",
  "What is your favorite color?",
  "Let's take a photo of your face with a grown-up!",
  "Your magical hero is ready!",
  "Girl",
  "Boy",

  // Walk tier — Magic Ear full prompts
  "What is your hero's name? You can type it or tap the microphone to say it!",
  "Pick your hero's look! Swipe through the pictures and tap the one you like.",
  "Pick a place for your story! You can choose Rainbow World, Cave Full of Crystals, Friendly Dragons, or Make One Up!",
  "Pick your travel buddies! Tap a companion to bring them along. You can pick a tiny dragon, a wise owl, a shadow cat, a star dog, a magic unicorn, or a clever fox.",
  "Here is your story recipe! Check everything looks right, then tap Make Magic to start!",
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
        final ttsResult = await TtsApiService.synthesize(key, voiceId: voiceId);
        final mp3 = ttsResult?.audioBytes;
        if (mp3 != null && mp3.isNotEmpty) _cache[key] = mp3;
      } catch (e) {
        debugPrint('TTS prewarm failed for phrase: $e');
      }
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
    /// Rate multiplier relative to the default (0.42). 1.0 = default.
    /// Use ~0.8 for Sprouts band to slow narration for 3–5 year olds.
    double rateScale = 1.0,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;
    try {
      Uint8List? mp3 = _cache[cleanText];
      if (mp3 == null) {
        final id = voiceId ?? (await _savedVoiceId());
        final ttsResult = await TtsApiService.synthesize(cleanText, voiceId: id);
        mp3 = ttsResult?.audioBytes;
        if (mp3 != null && mp3.isNotEmpty) _cache[cleanText] = mp3;
      }
      if (mp3 != null && mp3.isNotEmpty) {
        if (kIsWeb) {
          // On web, audioplayers' BytesSource converts bytes to a data: URI and
          // connects the element to a Web AudioContext with crossOrigin='anonymous'.
          // This prevents loadeddata from firing in Chrome, triggering the 30-second
          // preparationTimeout. Use a plain blob-URL AudioElement instead.
          await playAudioBytesOnWeb(mp3, awaitCompletion: awaitCompletion);
        } else {
          await _player.stop();
          await _player.play(BytesSource(mp3));
          if (awaitCompletion) {
            await _player.onPlayerComplete.first
                .timeout(const Duration(seconds: 120));
          }
        }
        return;
      }
    } catch (e) {
      debugPrint('TTS ElevenLabs failed, falling back to device: $e');
    }
    // On-device fallback
    if (_ready) {
      if (rateScale != 1.0) await _fallback.setSpeechRate(0.42 * rateScale);
      await _fallback.speak(text);
      if (rateScale != 1.0) await _fallback.setSpeechRate(0.42);
    }
  }

  Future<void> stop() async {
    stopWebAudio(); // no-op on non-web via stub
    await _player.stop();
    await _fallback.stop();
  }

  /// Returns the saved voice ID, or the age-band-appropriate default if none saved.
  Future<String> _savedVoiceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(ElevenLabsVoice.prefsKey);
    if (saved != null && ElevenLabsVoice.byId(saved) != null) return saved;
    final age = prefs.getInt('user_age') ?? 7;
    return ElevenLabsVoice.defaultVoiceIdForBand(ageBandFromAge(age));
  }
}

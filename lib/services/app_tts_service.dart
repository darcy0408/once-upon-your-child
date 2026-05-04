// lib/services/app_tts_service.dart
//
// Central TTS service — ElevenLabs when available, on-device FlutterTts fallback.
// Common short prompts are pre-fetched into an in-memory cache at startup so
// they play instantly with no API latency.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/elevenlabs_voice.dart';
import '../theme/age_band_theme.dart';
import 'api_service_manager.dart';
import 'tts_api_service.dart';
import 'web_audio_player_stub.dart'
    if (dart.library.html) 'web_audio_player.dart';

/// Common wizard/onboarding phrases pre-warmed at startup.
const List<String> kWarmUpPhrases = [
  // "Hi! Welcome to Story Weaver. What's your name?" is intentionally excluded
  // from warm-up so the live speak() call synthesises it at the correct slower
  // rateScale (0.72) rather than playing a default-speed cached version.
  // "How old are you?... Tap your age!" is intentionally excluded from warm-up
  // so the live speak() call synthesises it at the correct slower rateScale
  // (0.72) rather than playing a default-speed cached version.

  // ── HIGH-PRIORITY: Sprout avatar wizard step prompts ────────────────────────
  // These play in rapid succession during the Sprout (3-5) avatar flow. Listed
  // first so they're cached before the child can tap through to the next step
  // and trigger the robotic flutter_tts fallback.
  "Are you a girl or a boy?",
  "What is your favorite color?",
  "Let's take a photo of your face with a grown-up!",
  "Your magical hero is ready!",
  "Girl",
  "Boy",
  "What color is your hair?",
  "What color are your eyes?",

  // ── HIGH-PRIORITY: Sprout favorite-color tap echoes ─────────────────────────
  // Pre-warming prevents the flutter_tts robotic fallback when a child taps a swatch.
  "Red",
  "Orange",
  "Yellow",
  "Green",
  "Blue",
  "Light Blue",
  "Dark Blue",
  "Purple",
  "Pink",
  "Teal",
  "Gold",

  // ── Wizard / onboarding phrases (lower urgency: spoken once per session) ────
  "What is your hero's name? Tap the microphone to say it!",
  "Pick your hero look! Tap the picture you like.",
  "Tap your buddies to bring them along!",
  "Where will your adventure take place?",
  "Where should we go? Tap the picture you want.",
  "Tell me where your adventure takes place.",
  "What kind of story do you want?",
  "You are all set! Tap to begin!",
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

  // Walk tier — Magic Ear full prompts
  "What is your hero's name? You can type it or tap the microphone to say it!",
  "Pick your hero's look! Swipe through the pictures and tap the one you like.",
  "Pick a place for your story! Tap a picture to choose, or tap Make One Up and tell us where you want to go!",
  "Pick your travel buddies! Tap a companion to bring them along. You can pick a tiny dragon, a wise owl, a shadow cat, a star dog, a magic unicorn, or a clever fox.",
  "Here is your story summary! Check everything looks right, then tap to start!",

  // Sprout UX — pre-warm phrases used across all Sprout screens
  "Ready to go? Tap GO!",
  "Tap me!",
  "What's your name?",
  "Happy",
  "Sad",
  "Mad",
  "Scared",
  "Stomp with the Dinosaurs!",
  "The Magical Forest",
  "The Fluffy Cloud Castle",
  "Under the Sea!",

  // Hero Creator & Companion step narration
  "Choose your hero's path!",
  "Who will join you on your quest?",

  // Magic Review countdown
  "3... 2... 1... Let the magic begin!",
  "Your story is about to come alive!",

  // Sprout/Explorer archetype names — pre-warm so ElevenLabs is used, not
  // the robotic on-device fallback, when a child taps an archetype card.
  "Brave Hero!",
  "Art Maker!",
  "Super Fast!",
  "Animal Friend!",
  "The Brave Explorer",
  "The Art Wizard",
  "The Speed Star",
  "The Animal Whisperer",
  "Pebble",
  "Mochi",
  "Sunny",
  "Robin",
];

class AppTtsService {
  AppTtsService._();

  /// Subclass hook for test fakes. Production code uses [AppTtsService._].
  @visibleForTesting
  AppTtsService.forTesting();

  static AppTtsService _instance = AppTtsService._();
  static AppTtsService get instance => _instance;

  /// Test hook: swap the singleton for a fake in widget tests. Pass `null`
  /// to restore the real implementation. Production code never assigns here.
  @visibleForTesting
  static set instance(AppTtsService? value) {
    _instance = value ?? AppTtsService._();
  }

  // Lazy so the @visibleForTesting `forTesting()` constructor can subclass
  // without registering audioplayers / flutter_tts platform channels.
  late final AudioPlayer _player = AudioPlayer();
  late final FlutterTts _fallback = FlutterTts();
  final Map<String, Uint8List> _cache = {};
  bool _ready = false;
  bool _prewarming = false;

  // Bumped on every stop() and every speak() entry. In-flight speak() calls
  // capture their generation and bail at the next await if it changes — this
  // prevents an aborted play() from triggering the on-device fallback with
  // stale text after the caller has moved on to the next screen.
  int _speakGen = 0;

  /// On web, browsers block audio until the user has interacted with the page.
  /// Call [markInteracted] from the first user gesture (e.g. a tap) so that
  /// subsequent speak() calls are allowed. On non-web this flag is always true.
  bool _webInteracted = !kIsWeb;

  /// Call this from any user-gesture handler (tap, button press, etc.) before
  /// the first speak() call. Safe to call multiple times.
  void markInteracted() => _webInteracted = true;

  /// Resolves once the anonymous auth token has been obtained (or failed).
  /// speak() awaits this before hitting /tts/synthesize so it never sends
  /// a request without an Authorization header.
  Future<void>? _authReady;

  /// Call once at app startup. Initialises the fallback TTS engine and
  /// kicks off background pre-fetching of [warmUpPhrases].
  Future<void> init({List<String> warmUpPhrases = kWarmUpPhrases}) async {
    // Kick off auth token fetch synchronously (before any awaits) so that
    // speak() can await _authReady regardless of when it is called.
    _authReady = ApiServiceManager.authHeaders().then((_) {});

    await _fallback.setLanguage('en-US');
    await _fallback.setSpeechRate(0.42);
    await _fallback.setPitch(1.05);
    _ready = true;
    // Start prewarm only after auth is ready — all phrases need a valid token.
    unawaited(_authReady!.then((_) => _prewarm(warmUpPhrases)));
  }

  static const int _maxPrewarmRetries = 4;
  static const int _maxPrewarmConsecutiveNulls = 3;

  Future<void> _prewarm(List<String> phrases) async {
    // Deduplicate concurrent warm-up calls within a session.
    if (_prewarming) return;
    _prewarming = true;
    try {
      final voiceId = await _savedVoiceId();
      var backoffMs = 2000;
      var consecutiveNulls = 0;
      for (final phrase in phrases) {
        final key = phrase.trim();
        if (_cache.containsKey(key)) continue;
        var attempts = 0;
        while (attempts < _maxPrewarmRetries) {
          try {
            final ttsResult =
                await TtsApiService.synthesize(key, voiceId: voiceId);
            if (ttsResult == null) {
              consecutiveNulls++;
            } else {
              consecutiveNulls = 0;
            }
            final mp3 = ttsResult?.audioBytes;
            if (mp3 != null && mp3.isNotEmpty) _cache[key] = mp3;
            backoffMs = 2000; // reset after a successful call
            break;
          } on TtsRateLimitException {
            attempts++;
            if (attempts >= _maxPrewarmRetries) {
              debugPrint(
                'TTS prewarm 429 — giving up after $_maxPrewarmRetries attempts',
              );
              break;
            }
            debugPrint(
              'TTS prewarm 429 — waiting ${backoffMs}ms before retry '
              '($attempts/$_maxPrewarmRetries)',
            );
            await Future<void>.delayed(Duration(milliseconds: backoffMs));
            backoffMs = (backoffMs * 2).clamp(2000, 30000);
          } catch (e) {
            debugPrint('TTS prewarm failed for phrase: $e');
            break;
          }
        }
        if (consecutiveNulls >= _maxPrewarmConsecutiveNulls) {
          debugPrint(
            '[TTS] warm-up aborted: $consecutiveNulls consecutive null returns — service unavailable',
          );
          break;
        }
      }
    } finally {
      _prewarming = false;
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
    double rateScale = 0.85,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;
    // Web browsers block audio until a user gesture has occurred. Skip silently
    // rather than letting the browser throw NotAllowedError.
    if (!_webInteracted) return;
    final myGen = ++_speakGen;
    // Wait for auth token before hitting the backend — avoids 401 → robotic fallback.
    if (_authReady != null) await _authReady;
    if (myGen != _speakGen) return;
    try {
      Uint8List? mp3 = _cache[cleanText];
      if (mp3 == null) {
        final id = voiceId ?? (await _savedVoiceId());
        if (myGen != _speakGen) return;
        // Pass rateScale to ElevenLabs so the actual audio is slower for young
        // children — the fallback device TTS already uses rateScale below.
        final ttsResult = await TtsApiService.synthesize(
          cleanText,
          voiceId: id,
          speed: rateScale.clamp(0.7, 1.2),
        );
        if (myGen != _speakGen) return;
        mp3 = ttsResult?.audioBytes;
        if (mp3 != null && mp3.isNotEmpty) _cache[cleanText] = mp3;
      }
      if (myGen != _speakGen) return;
      if (mp3 != null && mp3.isNotEmpty) {
        if (kIsWeb) {
          // On web, audioplayers' BytesSource converts bytes to a data: URI and
          // connects the element to a Web AudioContext with crossOrigin='anonymous'.
          // This prevents loadeddata from firing in Chrome, triggering the 30-second
          // preparationTimeout. Use a plain blob-URL AudioElement instead.
          await playAudioBytesOnWeb(mp3, awaitCompletion: awaitCompletion);
        } else {
          // Stop both sinks — the fallback may still be speaking if a prior
          // ElevenLabs call failed and fell back to on-device TTS. Not stopping
          // it here causes robotic + ElevenLabs to play simultaneously.
          await _player.stop();
          await _fallback.stop();
          if (myGen != _speakGen) return;
          await _player.play(BytesSource(mp3));
          if (awaitCompletion) {
            await _player.onPlayerComplete.first
                .timeout(const Duration(seconds: 120));
          }
        }
        return;
      }
    } catch (e) {
      // If we were superseded (stop() called or a newer speak() started), the
      // exception is almost certainly an intentional abort — don't fall back to
      // the on-device robotic voice with stale text.
      if (myGen != _speakGen) return;
      debugPrint('TTS ElevenLabs failed, falling back to device: $e');
    }
    if (myGen != _speakGen) return;
    // On-device fallback
    if (_ready) {
      if (rateScale != 1.0) await _fallback.setSpeechRate(0.42 * rateScale);
      if (myGen != _speakGen) return;
      await _fallback.speak(text);
      if (rateScale != 1.0) await _fallback.setSpeechRate(0.42);
    }
  }

  Future<void> stop() async {
    _speakGen++;
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

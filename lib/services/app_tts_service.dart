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
import 'parental_consent_service.dart';
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

  // ── Welcome-screen greetings ────────────────────────────────────────────────
  // Spoken in welcome_screen.dart initState on the resume/teaser paths. Cached
  // here so the FIRST audible line after the user's opening tap is the warm
  // voice, not the robotic on-device fallback (web blocks all audio until that
  // first gesture, so the greeting must already be in cache when it fires).
  "Welcome back! What's your name?",
  "Welcome back! What should we call you?",
  "Welcome to Once Upon YOUR Child! Where you are the hero.",
  "What should we call you?",
  "Happy",
  "Sad",
  "Mad",
  "Scared",
  "Stomp with the Dinosaurs!",
  "The Magical Forest",
  "The Fluffy Cloud Castle",
  "Under the Sea!",

  // Hero Creator & Companion step narration
  // Page-1 greetings are name-agnostic (see hero_creator_step _speakPagePrompt)
  // so they cache here and play warm on the first tap of the consent-CTA path,
  // which lands straight on Pick Hero seconds after a cold launch.
  "Hi there! Get ready for a brand-new adventure. Let's create your hero!",
  "Hey there! Your next adventure is about to begin. Let's build your hero.",
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

/// Notice surfaced when the backend reports the user (or global) ElevenLabs
/// budget is depleted for the month. UI can listen on
/// [AppTtsService.capNoticeBus] and show a one-time-per-month upgrade toast.
class TtsCapNotice {
  /// 'user_cap_exceeded' or 'global_cap_exceeded'.
  final String reason;
  final String message;
  final DateTime timestamp;
  const TtsCapNotice({
    required this.reason,
    required this.message,
    required this.timestamp,
  });
  bool get isUserCap => reason == 'user_cap_exceeded';
  bool get isGlobalCap => reason == 'global_cap_exceeded';
}

class AppTtsService {
  AppTtsService._();

  /// Surfaces TTS cap-exceeded notices to the UI. The result screen (or any
  /// listener) reads this to show an upgrade toast and consume by setting
  /// `value = null`. One notice value can cover the whole session — the
  /// "show only once per month" debounce is the listener's responsibility
  /// (typically via SharedPreferences with a YYYY-MM key).
  static final ValueNotifier<TtsCapNotice?> capNoticeBus =
      ValueNotifier<TtsCapNotice?>(null);

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

  // Set when a synthesize call was refused by the server's COPPA age/consent
  // gate (403 AGE_REQUIRED / PARENTAL_CONSENT_*). The warm-up pass aborts
  // while the gate is engaged; the first successful speak() after the gate
  // clears re-kicks it.
  bool _consentGatePrewarmPending = false;

  // Set when the server reports the DAILY per-user synthesis quota is spent
  // (429 TTS_QUOTA_EXCEEDED). Unlike a transient rate limit it won't clear
  // until the next UTC day, so speak() stops issuing backend requests for the
  // rest of the session — cached phrases still play, everything else stays
  // SILENT (owner rule: never the robotic fallback).
  bool _quotaExhausted = false;

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
    //
    // Chained behind auth: back-fill the locally-stored declared age to the
    // server. Sessions that set their age before MT-351 shipped the
    // onboarding sync (or whose fire-and-forget sync raced auth and was
    // dropped) have declared_age = NULL server-side, and with
    // ENFORCE_RESOLVED_AGE ON in prod every /tts/synthesize call 403s —
    // the app opened with the robotic on-device voice (2026-07-14 report).
    // Ordering matters: speak() and _prewarm await this chain, so the FIRST
    // utterance of the session is already the warm voice. Best-effort and
    // time-bounded — a slow or failed sync must never wedge TTS.
    _authReady = ApiServiceManager.authHeaders()
        .then(
          (_) => ParentalConsentService()
              .syncStoredAgeToBackend()
              .timeout(const Duration(seconds: 10)),
        )
        .catchError((Object e) {
      debugPrint('TTS init: declared-age back-fill skipped: $e');
    });

    await _fallback.setLanguage('en-US');
    await _fallback.setSpeechRate(0.42);
    await _fallback.setPitch(1.05);
    _ready = true;
    // Start prewarm only after auth is ready — all phrases need a valid token.
    unawaited(_authReady!.then((_) => _prewarm(warmUpPhrases)));
  }

  static const int _maxPrewarmRetries = 4;
  static const int _maxPrewarmConsecutiveNulls = 3;

  // Cap how many phrases one warm-up pass may fetch. Every fetch counts
  // against the user's DAILY synthesis quota (2026-07-15: free tier burned
  // its whole day's quota on a single 130-phrase warm-up and went robotic
  // for everything after). kWarmUpPhrases is ordered most-urgent-first, so
  // the cap keeps the rapid-tap Sprout/welcome phrases instant; the tail
  // synthesizes warm on first use instead. Remove once the backend serves
  // common phrases from a shared cache that doesn't count against quota.
  static const int _maxPrewarmPhrases = 40;

  Future<void> _prewarm(List<String> phrases) async {
    // Deduplicate concurrent warm-up calls within a session.
    if (_prewarming) return;
    _prewarming = true;
    try {
      final voiceId = await _savedVoiceId();
      var backoffMs = 2000;
      var consecutiveNulls = 0;
      for (final phrase in phrases.take(_maxPrewarmPhrases)) {
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
          } on TtsQuotaExceededException catch (e) {
            // Daily quota spent — every further request today 429s the same
            // way. Abort the pass and stop hitting the backend this session.
            _quotaExhausted = true;
            debugPrint('[TTS] warm-up aborted: daily quota spent ($e)');
            return;
          } on TtsConsentGateException {
            // COPPA gate — every phrase would 403 identically, so abort the
            // whole pass instead of burning one doomed request per phrase.
            // speak() re-kicks the warm-up after the gate clears.
            _consentGatePrewarmPending = true;
            debugPrint('[TTS] warm-up aborted: server age/consent gate');
            return;
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
        // Daily quota already spent this session: every request would 429.
        // Cached phrases (above) still play; everything else stays silent.
        if (_quotaExhausted) return;
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
        // A successful synth means the consent gate (if it was ever engaged)
        // has cleared — re-run the warm-up pass it aborted.
        if (_consentGatePrewarmPending) {
          _consentGatePrewarmPending = false;
          unawaited(_prewarm(kWarmUpPhrases));
        }
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
    } on TtsConsentGateException catch (e) {
      // COPPA gate: the server has no resolved age/consent for this user yet,
      // so it refuses to forward text to the TTS vendor. Stay SILENT — do NOT
      // speak the robotic on-device fallback; a robotic greeting is worse
      // than a quiet one. The gate clears as soon as the age gate / consent
      // flow syncs an age, and the next speak() plays the warm voice (and
      // re-kicks the aborted warm-up pass).
      if (myGen != _speakGen) return;
      _consentGatePrewarmPending = true;
      debugPrint('TTS blocked by ${e.code}; staying silent (no robotic fallback)');
      return;
    } on TtsQuotaExceededException catch (e) {
      // Daily synthesis quota spent (429 TTS_QUOTA_EXCEEDED) — won't clear
      // until tomorrow. Stay SILENT (never robotic) and stop issuing backend
      // requests for the rest of the session.
      if (myGen != _speakGen) return;
      _quotaExhausted = true;
      debugPrint('TTS daily quota spent ($e); staying silent');
      return;
    } on TtsRateLimitException {
      // Transient rate limit. The next utterance may well succeed — but THIS
      // one stays silent rather than robotic (2026-07-15 owner rule: the
      // robotic fallback is worse than a quiet miss).
      if (myGen != _speakGen) return;
      debugPrint('TTS rate limited; staying silent for this utterance');
      return;
    } on TtsCapExceededException catch (e) {
      // Premium voice budget exhausted — fall through to flutter_tts and
      // surface a notice the UI can present as an upgrade toast.
      if (myGen != _speakGen) return;
      AppTtsService.capNoticeBus.value = TtsCapNotice(
        reason: e.reason,
        message: e.message.isNotEmpty
            ? e.message
            : "You've used your premium voice for this month — Read Aloud will continue with the in-app voice.",
        timestamp: DateTime.now(),
      );
      debugPrint('TTS cap exceeded (${e.reason}); using device voice');
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

  /// Test seam for [_savedVoiceId] — voice resolution is otherwise only
  /// observable through a live synthesis call.
  @visibleForTesting
  Future<String> resolveVoiceId() => _savedVoiceId();

  /// Returns the saved voice ID, or the age-band-appropriate default if none saved.
  Future<String> _savedVoiceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(ElevenLabsVoice.prefsKey);
    if (saved != null && ElevenLabsVoice.byId(saved) != null) return saved;
    final age = prefs.getInt('user_age');
    // Before an age has been declared, don't assume one. A hard-coded age-7
    // default meant every first-launch utterance — the welcome teaser and the
    // name prompt, both spoken before the age picker — resolved to the explorer
    // band's Gigi, which Azure synthesizes as en-US-AnaNeural, a child voice.
    // The person completing setup is often the parent. Use the neutral adult
    // storyteller until the user actually picks an age.
    if (age == null) return ElevenLabsVoice.defaultVoiceId;
    return ElevenLabsVoice.defaultVoiceIdForBand(ageBandFromAge(age));
  }
}

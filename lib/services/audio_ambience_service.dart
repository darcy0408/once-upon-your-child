import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle theme-based background ambience audio.
class AudioAmbienceService {
  static final AudioAmbienceService _instance =
      AudioAmbienceService._internal();
  factory AudioAmbienceService() => _instance;
  AudioAmbienceService._internal();

  static const String _kMutedKey = 'audio_ambience_muted';

  final AudioPlayer _player = AudioPlayer();
  String? _currentTheme;
  bool _isPlaying = false;
  bool _autoplayBlocked = false;
  String? _pendingTheme;
  double _volume = 0.15;
  bool _isMuted = false;

  /// Returns whether ambience is currently muted.
  bool get isMuted => _isMuted;

  /// Loads the persisted mute preference. Call once at app startup or before first play.
  Future<void> loadMutePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isMuted = prefs.getBool(_kMutedKey) ?? false;
  }

  /// Toggles mute on/off and persists the choice.
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMutedKey, _isMuted);
    try {
      await _player.setVolume(_isMuted ? 0 : _volume);
    } catch (_) {}
  }

  /// Map of story themes to their corresponding audio assets.
  final Map<String, String> _themeAudioMap = {
    'Adventure': 'sounds/adventure_wind.mp3',
    'Space': 'sounds/space_hum.mp3',
    'Forest': 'sounds/forest_crickets.mp3',
    'Magic': 'sounds/magical_shimmer.mp3',
    'Ocean': 'sounds/ocean_waves.mp3',
  };

  /// Optional max playback duration for one-shot SFX assets.
  static const Map<String, Duration> _sfxPlaybackLimits = {
    'sounds/magical_shimmer.mp3': Duration(milliseconds: 900),
  };

  /// Plays a one-shot sound effect (respects mute).
  Future<void> playSfx(String sfxPath) async {
    if (_isMuted) return;

    try {
      final sfxPlayer = AudioPlayer();
      await sfxPlayer.setReleaseMode(ReleaseMode.release);
      await sfxPlayer.play(AssetSource(sfxPath));

      var disposed = false;
      Future<void> safeDispose({bool stopFirst = false}) async {
        if (disposed) return;
        disposed = true;
        if (stopFirst) {
          try {
            await sfxPlayer.stop();
          } catch (_) {}
        }
        try {
          await sfxPlayer.dispose();
        } catch (_) {}
      }

      // Cleanup player after completion.
      sfxPlayer.onPlayerComplete.listen((_) => unawaited(safeDispose()));

      // For long sparkle-pad files, force a short one-shot playback.
      final maxDuration = _sfxPlaybackLimits[sfxPath];
      if (maxDuration != null) {
        unawaited(Future<void>.delayed(maxDuration, () async {
          await safeDispose(stopFirst: true);
        }));
      }
    } catch (_) {
      // Non-critical effect; fail silently.
    }
  }

  /// Starts playing ambience for a specific theme.
  Future<void> startAmbience(String theme) async {
    // Normalize theme name
    final normalizedTheme = _normalizeTheme(theme);

    if (_currentTheme == normalizedTheme && _isPlaying) return;

    String? assetPath = _themeAudioMap[normalizedTheme];

    // Fallback to "Magic" if no specific theme match is found
    if (assetPath == null) {
      debugPrint(
          'No specific ambience for theme: $theme. Falling back to Magic.');
      assetPath = _themeAudioMap['Magic'];
    }

    if (assetPath == null) {
      debugPrint('CRITICAL: No audio asset found even for fallback!');
      await stopAmbience();
      return;
    }

    try {
      _pendingTheme = normalizedTheme;
      _autoplayBlocked = false;

      await _player.stop();
      await _player
          .setReleaseMode(ReleaseMode.loop); // Loop for continuous ambience
      await _player.setVolume(_isMuted ? 0 : _volume);
      await _player.play(AssetSource(assetPath));
      _currentTheme = normalizedTheme;
      _isPlaying = true;
      _pendingTheme = null;
      debugPrint('Started ambience: $assetPath (Theme: $theme)');
    } catch (e) {
      debugPrint('Error playing ambience audio: $e');
      _isPlaying = false;

      // Web browsers often block autoplay until a user gesture.
      if (kIsWeb) {
        _autoplayBlocked = true;
        _pendingTheme = normalizedTheme;
      }
    }
  }

  /// Call from a user interaction (tap/flip) to retry starting ambience if a
  /// platform blocked autoplay (notably web).
  Future<void> onUserGesture() async {
    if (!_autoplayBlocked) return;
    final theme = _pendingTheme;
    if (theme == null) return;

    try {
      final assetPath = _themeAudioMap[theme];
      if (assetPath == null) return;

      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop); // Loop for continuous ambience
      await _player.setVolume(_isMuted ? 0 : _volume);
      await _player.play(AssetSource(assetPath));

      _currentTheme = theme;
      _isPlaying = true;
      _autoplayBlocked = false;
      _pendingTheme = null;
      debugPrint('Ambience started after user gesture for theme: $theme');
    } catch (e) {
      debugPrint('Error retrying ambience after user gesture: $e');
    }
  }

  /// Stops the current ambience audio.
  Future<void> stopAmbience() async {
    try {
      await _player.stop();
      _currentTheme = null;
      _isPlaying = false;
      _autoplayBlocked = false;
      _pendingTheme = null;
      debugPrint('Stopped ambience audio');
    } catch (e) {
      debugPrint('Error stopping ambience audio: $e');
    }
  }

  /// Adjusts the volume of the ambience.
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    try {
      await _player.setVolume(_volume);
    } catch (_) {
      // Ignore; can fail if not yet initialized on some platforms.
    }
  }

  String _normalizeTheme(String theme) {
    final lower = theme.toLowerCase();
    if (lower.contains('adventure')) return 'Adventure';
    if (lower.contains('space') ||
        lower.contains('sky') ||
        lower.contains('stars')) {
      return 'Space';
    }
    if (lower.contains('forest') ||
        lower.contains('jungle') ||
        lower.contains('meadow') ||
        lower.contains('field')) {
      return 'Forest';
    }
    if (lower.contains('magic') ||
        lower.contains('crystal') ||
        lower.contains('firefly') ||
        lower.contains('glow')) {
      return 'Magic';
    }
    if (lower.contains('ocean') ||
        lower.contains('water') ||
        lower.contains('waves') ||
        lower.contains('falls')) {
      return 'Ocean';
    }
    if (lower.contains('storm')) return 'Adventure'; // Wind fits storm
    return theme;
  }

  void dispose() {
    _player.dispose();
  }
}

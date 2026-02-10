import 'package:flutter/foundation.dart';

/// Service to handle theme-based background ambience audio.
class AudioAmbienceService {
  static final AudioAmbienceService _instance = AudioAmbienceService._internal();
  factory AudioAmbienceService() => _instance;
  AudioAmbienceService._internal();

  // final AudioPlayer _player = AudioPlayer();
  String? _currentTheme;
  bool _isPlaying = false;

  /// Map of story themes to their corresponding audio assets.
  final Map<String, String> _themeAudioMap = {
    'Adventure': 'sounds/adventure_wind.mp3',
    'Space': 'sounds/space_hum.mp3',
    'Forest': 'sounds/forest_crickets.mp3',
    'Magic': 'sounds/magical_shimmer.mp3',
    'Ocean': 'sounds/ocean_waves.mp3',
  };

  /// Starts playing ambience for a specific theme.
  Future<void> startAmbience(String theme) async {
    // Normalize theme name
    final normalizedTheme = _normalizeTheme(theme);
    
    if (_currentTheme == normalizedTheme && _isPlaying) return;

    final assetPath = _themeAudioMap[normalizedTheme];
    if (assetPath == null) {
      debugPrint('No ambience audio for theme: $theme');
      await stopAmbience();
      return;
    }

    try {
      // await _player.stop();
      // await _player.setReleaseMode(ReleaseMode.loop);
      // await _player.setVolume(0.15); // Low volume background
      // await _player.play(AssetSource(assetPath));
      _currentTheme = normalizedTheme;
      _isPlaying = true;
      debugPrint('Started ambience for theme: $normalizedTheme');
    } catch (e) {
      debugPrint('Error playing ambience audio: $e');
      _isPlaying = false;
    }
  }

  /// Stops the current ambience audio.
  Future<void> stopAmbience() async {
    try {
      // await _player.stop();
      _currentTheme = null;
      _isPlaying = false;
      debugPrint('Stopped ambience audio');
    } catch (e) {
      debugPrint('Error stopping ambience audio: $e');
    }
  }

  /// Adjusts the volume of the ambience.
  Future<void> setVolume(double volume) async {
    // await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  String _normalizeTheme(String theme) {
    if (theme.contains('Adventure')) return 'Adventure';
    if (theme.contains('Space')) return 'Space';
    if (theme.contains('Forest')) return 'Forest';
    if (theme.contains('Magic')) return 'Magic';
    if (theme.contains('Ocean')) return 'Ocean';
    return theme;
  }

  void dispose() {
    // _player.dispose();
  }
}

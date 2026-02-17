// lib/story_narrator.dart

import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';

class StoryNarrator {
  final FlutterTts _tts = FlutterTts();
  bool _isNarrating = false;
  bool _isPaused = false;
  int _currentWordIndex = 0;
  List<String> _words = [];

  // Callbacks
  Function(int)? onWordHighlight;
  Function()? onNarrationComplete;
  Function(bool)? onPlayingStateChanged;

  StoryNarrator() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.4);
    await _tts.setPitch(1.1);
    await _tts.setVolume(1.0);

    _tts.setCompletionHandler(() {
      _isNarrating = false;
      _isPaused = false;
      _currentWordIndex = 0;
      onPlayingStateChanged?.call(false);
      onNarrationComplete?.call();
    });

    // Set up progress handler for accurate word highlighting
    _tts.setProgressHandler((String text, int startOffset, int endOffset, String word) {
      _updateCurrentWord(word);
    });
  }

  void _updateCurrentWord(String spokenWord) {
    if (spokenWord.isEmpty) return;

    // Find the word in our word list
    for (int i = _currentWordIndex; i < _words.length; i++) {
      final cleanWord = _words[i].toLowerCase().replaceAll(RegExp(r'''[.,!?;:'"!]'''), '');
      if (cleanWord.isNotEmpty && cleanWord == spokenWord.toLowerCase()) {
        _currentWordIndex = i;
        onWordHighlight?.call(i);
        break;
      }
    }
  }

  Future<void> startNarration(String storyText, {double? speed, double? pitch}) async {
    if (_isNarrating && !_isPaused) return;

    if (speed != null) await _tts.setSpeechRate(speed);
    if (pitch != null) await _tts.setPitch(pitch);

    _words = _parseWords(storyText);
    _currentWordIndex = 0;

    if (_isPaused) {
      // Resume from pause
      await _tts.speak(storyText);
      _isPaused = false;
    } else {
      // Start fresh
      _isNarrating = true;
      await _tts.speak(storyText);
    }

    onPlayingStateChanged?.call(true);
  }

  Future<void> pauseNarration() async {
    if (!_isNarrating) return;

    await _tts.pause();
    _isPaused = true;
    onPlayingStateChanged?.call(false);
  }

  Future<void> stopNarration() async {
    await _tts.stop();
    _isNarrating = false;
    _isPaused = false;
    _currentWordIndex = 0;
    onPlayingStateChanged?.call(false);
  }

  Future<void> updateSpeed(double speed) async {
    await _tts.setSpeechRate(speed);
  }

  Future<void> updatePitch(double pitch) async {
    await _tts.setPitch(pitch);
  }

  Future<void> speakWord(String word, {double? speed}) async {
    final originalSpeed = speed ?? 0.4;
    await _tts.setSpeechRate(0.3);
    await _tts.speak(word);
    await Future.delayed(const Duration(milliseconds: 500));
    await _tts.setSpeechRate(originalSpeed);
  }

  Future<void> speakPhonemes(List<String> phonemes, {double? speed}) async {
    final originalSpeed = speed ?? 0.4;
    await _tts.setSpeechRate(0.2);

    for (final phoneme in phonemes) {
      await _tts.speak(phoneme);
      await Future.delayed(const Duration(milliseconds: 600));
    }

    await _tts.setSpeechRate(originalSpeed);
  }

  List<String> _parseWords(String text) {
    return text.split(RegExp(r'\s+'));
  }

  bool get isNarrating => _isNarrating;
  bool get isPaused => _isPaused;
  int get currentWordIndex => _currentWordIndex;

  void dispose() {
    _tts.stop();
  }
}

class NarrationSettings {
  final double speed;
  final double pitch;
  final bool autoHighlight;
  final bool autoScroll;

  const NarrationSettings({
    this.speed = 0.4,
    this.pitch = 1.1,
    this.autoHighlight = true,
    this.autoScroll = true,
  });

  NarrationSettings copyWith({
    double? speed,
    double? pitch,
    bool? autoHighlight,
    bool? autoScroll,
  }) {
    return NarrationSettings(
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      autoHighlight: autoHighlight ?? this.autoHighlight,
      autoScroll: autoScroll ?? this.autoScroll,
    );
  }
}

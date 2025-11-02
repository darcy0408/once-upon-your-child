// lib/cloud_tts_service.dart
// Google Cloud Text-to-Speech integration for high-quality, natural narration

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceOption {
  final String id;
  final String name;
  final String gender;
  final String description;
  final bool recommended;

  const VoiceOption({
    required this.id,
    required this.name,
    required this.gender,
    required this.description,
    this.recommended = false,
  });

  factory VoiceOption.fromJson(Map<String, dynamic> json) {
    return VoiceOption(
      id: json['id'] as String,
      name: json['name'] as String,
      gender: json['gender'] as String,
      description: json['description'] as String,
      recommended: json['recommended'] as bool? ?? false,
    );
  }
}

class CloudTTSService {
  final String baseUrl;
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? _currentAudioPath;
  bool _isPlaying = false;

  // Callbacks
  Function()? onComplete;
  Function(Duration)? onProgress;
  Function(bool)? onPlayingStateChanged;

  CloudTTSService({this.baseUrl = 'http://127.0.0.1:5000'});

  /// Get available narrator voices from backend
  Future<List<VoiceOption>> getAvailableVoices() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get-voices'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final voicesList = data['voices'] as List;
        return voicesList.map((v) => VoiceOption.fromJson(v)).toList();
      } else {
        throw Exception('Failed to load voices');
      }
    } catch (e) {
      throw Exception('Error fetching voices: $e');
    }
  }

  /// Generate speech audio from text
  /// Returns the local file path where audio is saved
  Future<String> generateSpeech({
    required String text,
    String voiceName = 'en-US-Neural2-F',
    double speakingRate = 1.0,
    double pitch = 0.0,
    bool useSSML = true,
  }) async {
    try {
      // Call backend to generate speech
      final response = await http.post(
        Uri.parse('$baseUrl/generate-speech'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'voice_name': voiceName,
          'speaking_rate': speakingRate,
          'pitch': pitch,
          'use_ssml': useSSML,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to generate speech: ${response.statusCode}');
      }

      // Save audio to temporary file
      final tempDir = await getTemporaryDirectory();
      final audioPath = '${tempDir.path}/narration_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final file = File(audioPath);
      await file.writeAsBytes(response.bodyBytes);

      _currentAudioPath = audioPath;
      return audioPath;
    } catch (e) {
      throw Exception('Error generating speech: $e');
    }
  }

  /// Play the generated audio
  Future<void> play() async {
    if (_currentAudioPath == null) {
      throw Exception('No audio to play. Generate speech first.');
    }

    try {
      await _audioPlayer.play(DeviceFileSource(_currentAudioPath!));
      _isPlaying = true;
      onPlayingStateChanged?.call(true);

      // Listen for completion
      _audioPlayer.onPlayerComplete.listen((_) {
        _isPlaying = false;
        onPlayingStateChanged?.call(false);
        onComplete?.call();
      });

      // Listen for position updates
      _audioPlayer.onPositionChanged.listen((position) {
        onProgress?.call(position);
      });
    } catch (e) {
      throw Exception('Error playing audio: $e');
    }
  }

  /// Pause playback
  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    onPlayingStateChanged?.call(false);
  }

  /// Resume playback
  Future<void> resume() async {
    await _audioPlayer.resume();
    _isPlaying = true;
    onPlayingStateChanged?.call(true);
  }

  /// Stop playback
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    onPlayingStateChanged?.call(false);
  }

  /// Get current playback position
  Future<Duration?> getCurrentPosition() async {
    return _audioPlayer.getCurrentPosition();
  }

  /// Get total duration
  Future<Duration?> getDuration() async {
    return _audioPlayer.getDuration();
  }

  /// Set playback speed (0.5 to 2.0)
  Future<void> setPlaybackRate(double rate) async {
    await _audioPlayer.setPlaybackRate(rate);
  }

  /// Clean up audio file
  Future<void> cleanup() async {
    if (_currentAudioPath != null) {
      try {
        final file = File(_currentAudioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Silently fail cleanup
      }
      _currentAudioPath = null;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _audioPlayer.dispose();
    await cleanup();
  }

  bool get isPlaying => _isPlaying;
}

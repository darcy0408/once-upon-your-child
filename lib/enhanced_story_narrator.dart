// lib/enhanced_story_narrator.dart
// Advanced narrator with high-quality Google Cloud TTS voices

import 'package:flutter/material.dart';
import 'cloud_tts_service.dart';
import 'story_narrator.dart'; // Fallback to device TTS

class EnhancedStoryNarrator {
  final CloudTTSService _cloudTTS = CloudTTSService();
  StoryNarrator? _fallbackNarrator;

  bool _useCloudTTS = true;
  bool _isNarrating = false;
  String _selectedVoice = 'en-US-Neural2-F'; // Default: warm female voice
  double _speakingRate = 1.0;
  double _pitch = 0.0;

  // Callbacks
  Function(bool)? onPlayingStateChanged;
  Function()? onNarrationComplete;
  Function(Duration)? onProgress;

  EnhancedStoryNarrator() {
    _setupCallbacks();
  }

  void _setupCallbacks() {
    _cloudTTS.onPlayingStateChanged = (playing) {
      _isNarrating = playing;
      onPlayingStateChanged?.call(playing);
    };

    _cloudTTS.onComplete = () {
      _isNarrating = false;
      onNarrationComplete?.call();
    };

    _cloudTTS.onProgress = (position) {
      onProgress?.call(position);
    };
  }

  /// Get available narrator voices
  Future<List<VoiceOption>> getAvailableVoices() async {
    try {
      return await _cloudTTS.getAvailableVoices();
    } catch (e) {
      debugPrint('Could not fetch cloud voices: $e');
      return [];
    }
  }

  /// Set the narrator voice
  void setVoice(String voiceId) {
    _selectedVoice = voiceId;
  }

  /// Set speaking rate (0.25 to 4.0, default 1.0)
  void setSpeakingRate(double rate) {
    _speakingRate = rate.clamp(0.25, 4.0);
  }

  /// Set voice pitch (-20.0 to 20.0, default 0.0)
  void setPitch(double pitch) {
    _pitch = pitch.clamp(-20.0, 20.0);
  }

  /// Start narration with high-quality cloud TTS
  Future<void> startNarration(
    String storyText, {
    double? speed,
    double? pitch,
    Function(int)? onWordHighlight, // For word highlighting (future enhancement)
  }) async {
    if (_isNarrating) return;

    if (speed != null) setSpeakingRate(speed);
    if (pitch != null) setPitch(pitch);

    try {
      // Try cloud TTS first
      if (_useCloudTTS) {
        debugPrint('Generating high-quality narration...');

        await _cloudTTS.generateSpeech(
          text: storyText,
          voiceName: _selectedVoice,
          speakingRate: _speakingRate,
          pitch: _pitch,
          useSSML: true, // Enable natural pauses and inflection
        );

        await _cloudTTS.play();
        debugPrint('Playing cloud TTS narration');
      }
    } catch (e) {
      debugPrint('Cloud TTS failed: $e. Falling back to device TTS.');

      // Fall back to device TTS
      _fallbackNarrator ??= StoryNarrator();
      _fallbackNarrator!.onPlayingStateChanged = onPlayingStateChanged;
      _fallbackNarrator!.onNarrationComplete = onNarrationComplete;
      _fallbackNarrator!.onWordHighlight = onWordHighlight;

      await _fallbackNarrator!.startNarration(
        storyText,
        speed: _speakingRate,
        pitch: _pitch,
      );
    }
  }

  /// Pause narration
  Future<void> pauseNarration() async {
    if (_useCloudTTS && _cloudTTS.isPlaying) {
      await _cloudTTS.pause();
    } else if (_fallbackNarrator != null) {
      await _fallbackNarrator!.pauseNarration();
    }
  }

  /// Resume narration
  Future<void> resumeNarration() async {
    if (_useCloudTTS) {
      await _cloudTTS.resume();
    } else if (_fallbackNarrator != null) {
      await _fallbackNarrator!.startNarration('', speed: _speakingRate, pitch: _pitch);
    }
  }

  /// Stop narration
  Future<void> stopNarration() async {
    if (_useCloudTTS) {
      await _cloudTTS.stop();
    }
    if (_fallbackNarrator != null) {
      await _fallbackNarrator!.stopNarration();
    }
    _isNarrating = false;
  }

  /// Speak a single word (for word learning)
  Future<void> speakWord(String word, {double? speed}) async {
    try {
      final rate = speed ?? _speakingRate * 0.7; // Slower for learning
      await _cloudTTS.generateSpeech(
        text: word,
        voiceName: _selectedVoice,
        speakingRate: rate,
        useSSML: false,
      );
      await _cloudTTS.play();
    } catch (e) {
      // Fall back to device TTS
      _fallbackNarrator ??= StoryNarrator();
      await _fallbackNarrator!.speakWord(word, speed: speed);
    }
  }

  /// Get current playback position
  Future<Duration?> getCurrentPosition() async {
    if (_useCloudTTS) {
      return await _cloudTTS.getCurrentPosition();
    }
    return null;
  }

  /// Get total duration
  Future<Duration?> getDuration() async {
    if (_useCloudTTS) {
      return await _cloudTTS.getDuration();
    }
    return null;
  }

  /// Set playback speed during playback (0.5 to 2.0)
  Future<void> setPlaybackRate(double rate) async {
    if (_useCloudTTS) {
      await _cloudTTS.setPlaybackRate(rate);
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    await _cloudTTS.dispose();
    _fallbackNarrator?.dispose();
  }

  bool get isNarrating => _isNarrating;
  String get selectedVoice => _selectedVoice;
  double get speakingRate => _speakingRate;
  double get pitch => _pitch;
}

/// Voice settings widget for user to choose narrator
class VoiceSettingsDialog extends StatefulWidget {
  final EnhancedStoryNarrator narrator;
  final String currentVoice;
  final double currentSpeed;

  const VoiceSettingsDialog({
    super.key,
    required this.narrator,
    required this.currentVoice,
    required this.currentSpeed,
  });

  @override
  State<VoiceSettingsDialog> createState() => _VoiceSettingsDialogState();
}

class _VoiceSettingsDialogState extends State<VoiceSettingsDialog> {
  List<VoiceOption> _voices = [];
  bool _isLoading = true;
  String? _selectedVoice;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _selectedVoice = widget.currentVoice;
    _speed = widget.currentSpeed;
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    try {
      final voices = await widget.narrator.getAvailableVoices();
      setState(() {
        _voices = voices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Narrator Voice Settings'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Voice selection
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_voices.isEmpty)
              const Text('No voices available')
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _voices.length,
                  itemBuilder: (context, index) {
                    final voice = _voices[index];
                    final isSelected = _selectedVoice == voice.id;
                    return ListTile(
                      leading: Icon(
                        voice.gender == 'female' ? Icons.face : Icons.face_2,
                        color: isSelected ? Colors.deepPurple : Colors.grey,
                      ),
                      title: Text(voice.name),
                      subtitle: Text(voice.description),
                      trailing: voice.recommended
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Recommended',
                                style: TextStyle(fontSize: 10),
                              ),
                            )
                          : null,
                      selected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedVoice = voice.id;
                        });
                      },
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // Speed control
            const Text('Reading Speed'),
            Slider(
              value: _speed,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: '${_speed.toStringAsFixed(1)}x',
              onChanged: (value) {
                setState(() {
                  _speed = value;
                });
              },
            ),
            Text(
              _speed < 0.8
                  ? 'Slow (Good for learning)'
                  : _speed < 1.2
                      ? 'Normal'
                      : 'Fast',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.narrator.setVoice(_selectedVoice!);
            widget.narrator.setSpeakingRate(_speed);
            Navigator.pop(context, {
              'voice': _selectedVoice,
              'speed': _speed,
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

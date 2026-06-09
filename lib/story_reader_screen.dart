// lib/story_reader_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models/elevenlabs_voice.dart';
import 'package:story_weaver_app/providers/age_band_provider.dart';
import 'package:story_weaver_app/providers/highlight_color_provider.dart';
import 'package:story_weaver_app/providers/voice_preference_provider.dart';
import 'package:story_weaver_app/services/audio_ambience_service.dart';
import 'package:story_weaver_app/services/tts_api_service.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/theme/app_theme.dart';
import 'package:story_weaver_app/utils/motion_utils.dart';
import 'package:story_weaver_app/widgets/voice_picker_sheet.dart';

class StoryReaderScreen extends ConsumerStatefulWidget {
  final String title;
  final String storyText;
  final String? characterName;
  /// When true, TTS starts automatically when the screen loads.
  /// Also auto-triggers for sprout/explorer age bands regardless of this flag.
  final bool autoPlay;
  /// Story theme for ambient audio (e.g. 'Adventure', 'Forest', 'Magic').
  final String? theme;

  const StoryReaderScreen({
    super.key,
    required this.title,
    required this.storyText,
    this.characterName,
    this.autoPlay = false,
    this.theme,
  });

  @override
  ConsumerState<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends ConsumerState<StoryReaderScreen> with SingleTickerProviderStateMixin {
  late final FlutterTts _tts;
  late final List<_StoryToken> _tokens;
  late final List<int> _wordTokenIndices;
  bool _isPlaying = false;
  int _currentWordIndex = -1;
  double _playbackRate = 1.0; // Initialised from age band in _onFirstFrame
  bool _autoPlayTriggered = false;

  // Character-weighted word highlighting
  late final List<int> _wordCharOffsets;
  int _totalStoryChars = 0;

  // Bookmark / resume
  String? _storyKey;
  DateTime? _lastSaveTime;
  bool _resumeBannerVisible = false;
  Duration _resumePosition = Duration.zero;
  Duration? _pendingResumePosition;

  // Ambient sound
  bool _ambienceMuted = false;

  // Sprout simplified controls
  bool _sproutUnlocked = false;

  // Neural2 (ElevenLabs via backend)
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _usingNeural2 = false;
  bool _isLoadingAudio = false;
  Duration _audioDuration = Duration.zero;
  final List<StreamSubscription<dynamic>> _audioSubs = [];

  // Exact word timestamps from ElevenLabs alignment (empty = use char-weighted estimation)
  List<({int startMs, int endMs})> _wordTimestamps = [];

  // Animation for the "active" reading state
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _storyKey = widget.storyText.substring(0, min(80, widget.storyText.length));
    _tts = FlutterTts();
    _configureTts();
    _prepareTokens();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _setupAudioPlayerListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) => _onFirstFrame());
  }

  /// Starts the "now playing" pulse on the play button — but only when motion
  /// is allowed. Under reduce-motion the looping pulse is skipped (WCAG 2.2 AA
  /// SC 2.2.2 Pause, Stop, Hide); playback state is still conveyed via the
  /// play/stop icon, so no information is lost.
  void _startPlayPulse() {
    if (MotionPrefs.reduceMotion(context)) return;
    _pulseController.repeat(reverse: true);
  }

  /// Age-band-appropriate playback rate (AudioPlayer scale: 1.0 = normal).
  static double _defaultRateForBand(AgeBand band) {
    switch (band) {
      case AgeBand.sprout:
        return 0.85;
      case AgeBand.explorer:
        return 0.90;
      case AgeBand.adventurer:
        return 0.95;
      case AgeBand.creator:
      case AgeBand.adolescent:
      case AgeBand.adult:
        return 1.0;
    }
  }

  /// Maps AudioPlayer rate scale (1.0 = normal) to FlutterTts scale (0.5 = normal).
  static double _toFlutterTtsRate(double audioPlayerRate) {
    // FlutterTts: 0.0 = stopped, 0.5 = normal, 1.0 = fastest
    // AudioPlayer: 1.0 = normal, 2.0 = double speed
    return (audioPlayerRate * 0.5).clamp(0.1, 1.0);
  }

  Future<void> _onFirstFrame() async {
    if (!mounted) return;

    // 1. Band default rate
    final band = ref.read(ageBandNotifierProvider).band;
    setState(() => _playbackRate = _defaultRateForBand(band));

    // 2. Persisted user override (beats band default)
    await _loadPersistedRate();

    // 3. Load ambience mute state
    await AudioAmbienceService().loadMutePreference();
    if (mounted) setState(() => _ambienceMuted = AudioAmbienceService().isMuted);

    // 4. Check for bookmark
    await _checkForResume();

    // 5. Auto-play only for young bands (sprout/explorer).
    // Creator+ bands must tap play — unexpected audio is embarrassing for older users.
    if (!_autoPlayTriggered && !_isPlaying) {
      if (band.isYoung) {
        _autoPlayTriggered = true;
        _startReading();
      }
    }
  }

  Future<void> _loadPersistedRate() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(ElevenLabsVoice.playbackRatePrefsKey);
    if (saved != null && mounted) {
      setState(() => _playbackRate = saved.clamp(0.75, 2.0));
    }
  }

  Future<void> _checkForResume() async {
    if (_storyKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    final savedMs = prefs.getInt('playback_pos_$_storyKey');
    if (savedMs == null || savedMs < 30000) return; // < 30s not worth resuming
    if (!mounted) return;
    setState(() {
      _resumePosition = Duration(milliseconds: savedMs);
      _resumeBannerVisible = true;
    });
  }

  Future<void> _doResume() async {
    setState(() => _resumeBannerVisible = false);
    _pendingResumePosition = _resumePosition;
    if (!_isPlaying && !_isLoadingAudio) {
      await _startReading();
    }
    // If already playing/loading, pending seek fires in onDurationChanged.
  }

  Future<void> _persistPosition(Duration pos) async {
    if (_storyKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('playback_pos_$_storyKey', pos.inMilliseconds);
  }

  String _formatDuration(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  String get _effectiveTheme => widget.theme ?? 'Magic';

  Future<void> _setPlaybackRate(double rate) async {
    setState(() => _playbackRate = rate);
    if (_usingNeural2) {
      await _audioPlayer.setPlaybackRate(rate);
    } else {
      await _tts.setSpeechRate(_toFlutterTtsRate(rate));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(ElevenLabsVoice.playbackRatePrefsKey, rate);
  }

  void _setupAudioPlayerListeners() {
    // Track audio duration so we can estimate word position
    _audioSubs.add(
      _audioPlayer.onDurationChanged.listen((duration) {
        if (!mounted) return;
        setState(() => _audioDuration = duration);
        // Execute pending seek from bookmark resume
        if (_pendingResumePosition != null) {
          final seekTo = _pendingResumePosition!;
          _pendingResumePosition = null;
          if (seekTo < duration) {
            _audioPlayer.seek(seekTo);
          }
        }
      }),
    );

    // Highlight current word from playback position.
    // Prefers exact ElevenLabs timestamps; falls back to character-weighted estimation.
    _audioSubs.add(
      _audioPlayer.onPositionChanged.listen((position) {
        if (!mounted || !_usingNeural2 || _audioDuration == Duration.zero) {
          return;
        }

        int wordIndex;
        if (_wordTimestamps.isNotEmpty) {
          // Exact path: binary search on ElevenLabs alignment timestamps.
          final posMs = position.inMilliseconds;
          var lo = 0;
          var hi = _wordTimestamps.length - 1;
          wordIndex = 0;
          while (lo <= hi) {
            final mid = (lo + hi) ~/ 2;
            if (_wordTimestamps[mid].startMs <= posMs) {
              wordIndex = mid;
              lo = mid + 1;
            } else {
              hi = mid - 1;
            }
          }
          wordIndex = wordIndex.clamp(0, _wordTokenIndices.length - 1);
        } else {
          // Fallback: character-weighted estimation from audio progress.
          final progress =
              position.inMilliseconds / _audioDuration.inMilliseconds;
          if (_totalStoryChars > 0) {
            final targetChars = (progress * _totalStoryChars).round();
            var lo = 0;
            var hi = _wordCharOffsets.length - 1;
            wordIndex = 0;
            while (lo <= hi) {
              final mid = (lo + hi) ~/ 2;
              if (_wordCharOffsets[mid] <= targetChars) {
                wordIndex = mid;
                lo = mid + 1;
              } else {
                hi = mid - 1;
              }
            }
            wordIndex = wordIndex.clamp(0, _wordTokenIndices.length - 1);
          } else {
            wordIndex = (progress * _wordTokenIndices.length)
                .floor()
                .clamp(0, _wordTokenIndices.length - 1);
          }
        }

        if (wordIndex != _currentWordIndex) {
          setState(() => _currentWordIndex = wordIndex);
        }

        // Throttled position save for bookmark/resume (every 10s)
        final now = DateTime.now();
        if (_lastSaveTime == null ||
            now.difference(_lastSaveTime!) > const Duration(seconds: 10)) {
          _lastSaveTime = now;
          _persistPosition(position);
        }
      }),
    );

    // Playback complete
    _audioSubs.add(
      _audioPlayer.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _usingNeural2 = false;
          _currentWordIndex = -1;
          _wordTimestamps = [];
          _pulseController.stop();
        });
        // Clear saved bookmark now that the story is finished
        if (_storyKey != null) {
          SharedPreferences.getInstance()
              .then((p) => p.remove('playback_pos_$_storyKey'));
        }
      }),
    );
  }

  void _prepareTokens() {
    _tokens = _tokenize(widget.storyText);
    _wordTokenIndices = [];
    for (var i = 0; i < _tokens.length; i++) {
      if (!_tokens[i].isWhitespace) {
        _wordTokenIndices.add(i);
      }
    }
    // Precompute cumulative character offsets for character-weighted highlighting.
    // _wordCharOffsets[i] = total chars before word i. Words get time proportional
    // to their character length, so long words like "incomprehensible" drift less.
    _wordCharOffsets = [];
    var cumulative = 0;
    for (final wi in _wordTokenIndices) {
      _wordCharOffsets.add(cumulative);
      cumulative += _tokens[wi].text.length;
    }
    _totalStoryChars = cumulative;
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_toFlutterTtsRate(_playbackRate));
    await _tts.setPitch(1.0);

    // Optimize for web if needed -> handled by flutter_tts mostly

    _tts.setProgressHandler((text, start, end, word) {
      if (!mounted) return;
      if (word.trim().isEmpty) return;

      // Create regex for word boundary matching
      final wordRegex = RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false);
      final wordNormalized = _normalize(word);

      for (var nextIndex = _currentWordIndex + 1;
          nextIndex < _wordTokenIndices.length;
          nextIndex++) {
        final token = _tokens[_wordTokenIndices[nextIndex]];
        
        // 1. Try regex match (handles punctuation, "It's" vs "It")
        if (wordRegex.hasMatch(token.text)) {
          setState(() {
            _currentWordIndex = nextIndex;
          });
          break;
        }

        // 2. Fallback to normalized match
        final tokenNormalized = _normalize(token.text);
        if (tokenNormalized.isNotEmpty && tokenNormalized == wordNormalized) {
          setState(() {
             _currentWordIndex = nextIndex;
          });
          break;
        }
      }
    });

    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _currentWordIndex = -1;
        _pulseController.stop();
      });
    });

    _tts.setCancelHandler(() {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _currentWordIndex = -1;
        _pulseController.stop();
      });
    });

    _tts.setPauseHandler(() {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _pulseController.stop();
      });
    });
  }

  @override
  void dispose() {
    AudioAmbienceService().stopAmbience();
    _tts.stop();
    _audioPlayer.dispose();
    for (final sub in _audioSubs) {
      sub.cancel();
    }
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startReading() async {
    AudioAmbienceService().startAmbience(_effectiveTheme);
    // Try ElevenLabs via backend first
    final voiceId = ref.read(voicePreferenceNotifierProvider);
    final characterVoiceId = ElevenLabsVoice.characterVoiceForNarrator(voiceId);
    setState(() => _isLoadingAudio = true);
    final result = await TtsApiService.synthesize(
      widget.storyText,
      voiceId: voiceId,
      characterVoiceId: characterVoiceId,
    );
    if (!mounted) return;

    if (result != null) {
      // ── Neural2 path ────────────────────────────────────────────────
      await _tts.stop();
      setState(() {
        _isLoadingAudio = false;
        _isPlaying = true;
        _usingNeural2 = true;
        _currentWordIndex = -1;
        _wordTimestamps = result.wordTimestamps;
        _startPlayPulse();
      });
      await _audioPlayer.play(BytesSource(result.audioBytes));
      await _audioPlayer.setPlaybackRate(_playbackRate);
    } else {
      // ── flutter_tts fallback ────────────────────────────────────────
      await _tts.stop();
      await _tts.setSpeechRate(_toFlutterTtsRate(_playbackRate));
      setState(() {
        _isLoadingAudio = false;
        _isPlaying = true;
        _usingNeural2 = false;
        _currentWordIndex = -1;
        _startPlayPulse();
      });
      await _tts.speak(widget.storyText);
    }
  }

  Widget _buildSpeedChips() {
    const speeds = [0.75, 1.0, 1.25, 1.5];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: speeds.map((speed) {
        final isActive = (_playbackRate - speed).abs() < 0.01;
        final label = speed == 1.0 ? '1×' : '$speed×';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: GestureDetector(
            onTap: () => _setPlaybackRate(speed),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.gold.withValues(alpha: 0.25)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? AppColors.gold.withValues(alpha: 0.8)
                      : AppColors.gold.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: isActive
                      ? AppColors.gold
                      : AppColors.gold.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResumeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bookmark, size: 14, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(
            'Resume from ${_formatDuration(_resumePosition)}?',
            style: GoogleFonts.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: _doResume,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Yes',
              style: GoogleFonts.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.gold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _resumeBannerVisible = false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Dismiss',
              style: GoogleFonts.quicksand(
                fontSize: 12,
                color: AppColors.gold.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pauseReading() async {
    AudioAmbienceService().stopAmbience();
    if (_usingNeural2) {
      await _audioPlayer.pause();
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _pulseController.stop();
      });
    } else {
      final result = await _tts.pause();
      if (result == 1 && mounted) {
        setState(() {
          _isPlaying = false;
          _pulseController.stop();
        });
      }
    }
  }

  Future<void> _resumeReading() async {
    AudioAmbienceService().startAmbience(_effectiveTheme);
    if (_usingNeural2) {
      await _audioPlayer.setPlaybackRate(_playbackRate);
      await _audioPlayer.resume();
      if (!mounted) return;
      setState(() {
        _isPlaying = true;
        _startPlayPulse();
      });
    } else {
      await _tts.speak(widget.storyText);
      if (!mounted) return;
      setState(() {
        _isPlaying = true;
        _startPlayPulse();
      });
    }
  }

  Future<void> _stopReading() async {
    AudioAmbienceService().stopAmbience();
    await _audioPlayer.stop();
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _usingNeural2 = false;
      _isLoadingAudio = false;
      _currentWordIndex = -1;
      _pulseController.stop();
    });
  }

  List<_StoryToken> _tokenize(String input) {
    if (input.isEmpty) return [];

    final tokens = <_StoryToken>[];
    final buffer = StringBuffer();
    bool? currentWhitespace;

    void flush() {
      if (buffer.isEmpty) return;
      tokens.add(_StoryToken(
        buffer.toString(),
        currentWhitespace ?? false,
      ));
      buffer.clear();
    }

    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final isWhitespace = char.trim().isEmpty;

      if (currentWhitespace == null) {
        currentWhitespace = isWhitespace;
      } else if (isWhitespace != currentWhitespace) {
        flush();
        currentWhitespace = isWhitespace;
      }

      buffer.write(char);
    }
    flush();
    return tokens;
  }

  String _normalize(String text) {
    return text.replaceAll(RegExp(r"[^a-zA-Z0-9']"), '').toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.magicalBackground,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Navigation Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: GoogleFonts.merriweather(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              if (widget.characterName != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.gold, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'A story for ${widget.characterName}',
                        style: GoogleFonts.quicksand(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              // Main Story Area
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E7), // Magical parchment
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: AppColors.gold.withValues(alpha: 0.1),
                                    blurRadius: 0,
                                    spreadRadius: 4, 
                                    offset: const Offset(0, 0),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  // Controls Header
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9F1DC), // Slightly darker parchment
                                      border: Border(
                                        bottom: BorderSide(
                                          color: AppColors.gold.withValues(alpha: 0.2),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Sprout gets simplified controls; other bands get full controls
                                        if (ref.watch(ageBandNotifierProvider).band == AgeBand.sprout && !_sproutUnlocked)
                                          _buildSproutControls()
                                        else
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            _buildControlButton(
                                              icon: Icons.stop_rounded,
                                              label: 'Stop',
                                              onPressed: _isPlaying || _currentWordIndex != -1
                                                  ? _stopReading
                                                  : null,
                                              isPrimary: false,
                                            ),
                                            const SizedBox(width: 16),
                                            ScaleTransition(
                                              scale: _pulseAnimation,
                                              child: _isLoadingAudio
                                                  ? _buildLoadingButton()
                                                  : _buildControlButton(
                                                      icon: _isPlaying
                                                          ? Icons.pause_rounded
                                                          : Icons.play_arrow_rounded,
                                                      label: _isPlaying ? 'Pause' : 'Read',
                                                      onPressed: _isPlaying
                                                          ? _pauseReading
                                                          : (_currentWordIndex != -1
                                                              ? _resumeReading
                                                              : _startReading),
                                                      isPrimary: true,
                                                      size: 56,
                                                    ),
                                            ),
                                            const SizedBox(width: 16),
                                            // Ambience mute button
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.gold.withValues(alpha: 0.15),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: AppColors.gold.withValues(alpha: 0.5),
                                                    ),
                                                  ),
                                                  child: IconButton(
                                                    icon: Icon(
                                                      _ambienceMuted
                                                          ? Icons.volume_off
                                                          : Icons.volume_up,
                                                      color: AppColors.gold,
                                                    ),
                                                    iconSize: 22,
                                                    tooltip: _ambienceMuted
                                                        ? 'Unmute sounds'
                                                        : 'Mute sounds',
                                                    onPressed: () async {
                                                      await AudioAmbienceService().toggleMute();
                                                      if (mounted) {
                                                        setState(() => _ambienceMuted =
                                                            AudioAmbienceService().isMuted);
                                                      }
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _ambienceMuted ? 'Sound off' : 'Sound on',
                                                  style: GoogleFonts.quicksand(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.gold.withValues(alpha: 0.85),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 16),
                                            // Voice picker button
                                            Consumer(
                                              builder: (context, ref, _) {
                                                final voice = ref
                                                    .watch(voicePreferenceNotifierProvider.notifier)
                                                    .currentVoice;
                                                return Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 48,
                                                      height: 48,
                                                      decoration: BoxDecoration(
                                                        color: AppColors.gold.withValues(alpha: 0.15),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: AppColors.gold.withValues(alpha: 0.5),
                                                        ),
                                                      ),
                                                      child: IconButton(
                                                        icon: const Icon(Icons.record_voice_over,
                                                            color: AppColors.gold),
                                                        iconSize: 22,
                                                        tooltip: 'Change voice',
                                                        onPressed: () => VoicePickerSheet.show(context),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      voice.name,
                                                      style: GoogleFonts.quicksand(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppColors.gold.withValues(alpha: 0.85),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        // Speed chips hidden for sprout (no speed chips visible)
                                        if ((_isPlaying || _currentWordIndex != -1) &&
                                            !(ref.watch(ageBandNotifierProvider).band == AgeBand.sprout && !_sproutUnlocked)) ...[
                                          const SizedBox(height: 10),
                                          _buildSpeedChips(),
                                        ],
                                        // Resume banner
                                        if (_resumeBannerVisible) ...[
                                          const SizedBox(height: 8),
                                          _buildResumeBanner(),
                                        ],
                                        if (_usingNeural2) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.auto_awesome,
                                                  size: 11,
                                                  color: AppColors.gold.withValues(alpha: 0.8)),
                                              const SizedBox(width: 3),
                                              Text(
                                                'ElevenLabs voice',
                                                style: GoogleFonts.quicksand(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.gold.withValues(alpha: 0.8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  
                                  // Text Content
                                  Expanded(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(32),
                                      child: RichText(
                                        textAlign: TextAlign.left,
                                        text: TextSpan(
                                          style: GoogleFonts.merriweather(
                                            fontSize: 22,
                                            height: 1.8,
                                            color: const Color(0xFF2C3E50),
                                          ),
                                          children: _buildSpans(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppGradients.purpleGlow,
              shape: BoxShape.circle,
            ),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Loading…',
          style: GoogleFonts.quicksand(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  /// Simplified 2-button controls for sprout band (play/pause + start over).
  /// A small lock icon lets parents long-press 2s to reveal full controls.
  Widget _buildSproutControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Start Over button
        _buildControlButton(
          icon: Icons.replay_rounded,
          label: 'Start Over',
          onPressed: _isPlaying || _currentWordIndex != -1
              ? () async {
                  await _stopReading();
                  if (mounted) _startReading();
                }
              : null,
          isPrimary: false,
        ),
        const SizedBox(width: 20),
        // Big play / pause button
        ScaleTransition(
          scale: _pulseAnimation,
          child: _isLoadingAudio
              ? _buildLoadingButton()
              : _buildControlButton(
                  icon: _isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  label: _isPlaying ? 'Pause' : 'Play',
                  onPressed: _isPlaying
                      ? _pauseReading
                      : (_currentWordIndex != -1
                          ? _resumeReading
                          : _startReading),
                  isPrimary: true,
                  size: 64,
                ),
        ),
        const SizedBox(width: 20),
        // Parent lock — 2s long-press to unlock full controls
        GestureDetector(
          onLongPress: () {
            setState(() => _sproutUnlocked = true);
          },
          child: Tooltip(
            message: 'Hold 2s to unlock parent controls',
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(
                Icons.lock_outline,
                size: 20,
                color: AppColors.gold.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isPrimary,
    double size = 48,
  }) {
    final isEnabled = onPressed != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: isPrimary && isEnabled
              ? AppGradients.purpleGlow 
              : null,
            color: !isPrimary && isEnabled 
              ? Colors.white 
              : (isEnabled ? null : Colors.grey.withValues(alpha: 0.1)),
            shape: BoxShape.circle,
            border: Border.all(
              color: isEnabled 
                ? (isPrimary ? Colors.transparent : AppColors.primary) 
                : Colors.grey.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: (isPrimary ? AppColors.primary : Colors.black).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Semantics(
                button: true,
                enabled: isEnabled,
                label: label,
                child: Icon(
                  icon,
                  color: isPrimary && isEnabled 
                    ? Colors.white 
                    : (isEnabled ? AppColors.primary : Colors.grey.withValues(alpha: 0.5)),
                  size: size * 0.6,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.quicksand(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isEnabled ? AppColors.primary : Colors.grey.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  List<InlineSpan> _buildSpans() {
    // A11Y-LTR-03: the word-highlight color is parent-configurable.
    final highlightColor = ref.watch(highlightColorProvider);
    final spans = <InlineSpan>[];
    for (var i = 0; i < _tokens.length; i++) {
      final token = _tokens[i];
      final isHighlighted = _currentWordIndex >= 0 &&
          _currentWordIndex < _wordTokenIndices.length &&
          _wordTokenIndices[_currentWordIndex] == i;

      spans.add(
        TextSpan(
          text: token.text,
          style: token.isWhitespace
              ? null
              : TextStyle(
                  backgroundColor: isHighlighted
                      ? highlightColor.withValues(alpha: 0.4)
                      : null,
                  decoration: isHighlighted
                      ? TextDecoration.underline
                      : null,
                  decorationColor: highlightColor,
                  decorationThickness: 2,
                  fontWeight:
                      isHighlighted ? FontWeight.w700 : FontWeight.normal,
                ),
        ),
      );
    }
    return spans;
  }
}

class _StoryToken {
  final String text;
  final bool isWhitespace;
  const _StoryToken(this.text, this.isWhitespace);
}

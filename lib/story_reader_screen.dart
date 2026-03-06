// lib/story_reader_screen.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:story_weaver_app/providers/voice_preference_provider.dart';
import 'package:story_weaver_app/services/tts_api_service.dart';
import 'package:story_weaver_app/theme/app_theme.dart';
import 'package:story_weaver_app/widgets/voice_picker_sheet.dart';

class StoryReaderScreen extends ConsumerStatefulWidget {
  final String title;
  final String storyText;
  final String? characterName;

  const StoryReaderScreen({
    super.key,
    required this.title,
    required this.storyText,
    this.characterName,
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
  final double _speechRate = 0.52; // Default slow/comfortable pace for kids

  // Neural2 (Google Cloud TTS via backend)
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _usingNeural2 = false;
  bool _isLoadingAudio = false;
  Duration _audioDuration = Duration.zero;
  final List<StreamSubscription<dynamic>> _audioSubs = [];

  // Animation for the "active" reading state
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
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
  }

  void _setupAudioPlayerListeners() {
    // Track audio duration so we can estimate word position
    _audioSubs.add(
      _audioPlayer.onDurationChanged.listen((duration) {
        if (mounted) setState(() => _audioDuration = duration);
      }),
    );

    // Estimate current word from playback position
    _audioSubs.add(
      _audioPlayer.onPositionChanged.listen((position) {
        if (!mounted || !_usingNeural2 || _audioDuration == Duration.zero) {
          return;
        }
        final progress =
            position.inMilliseconds / _audioDuration.inMilliseconds;
        final wordIndex =
            (progress * _wordTokenIndices.length).floor().clamp(
              0,
              _wordTokenIndices.length - 1,
            );
        if (wordIndex != _currentWordIndex) {
          setState(() => _currentWordIndex = wordIndex);
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
          _pulseController.stop();
        });
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
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_speechRate);
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
    _tts.stop();
    _audioPlayer.dispose();
    for (final sub in _audioSubs) {
      sub.cancel();
    }
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startReading() async {
    // Try ElevenLabs via backend first
    final voiceId = ref.read(voicePreferenceNotifierProvider);
    setState(() => _isLoadingAudio = true);
    final Uint8List? mp3Bytes = await TtsApiService.synthesize(
      widget.storyText,
      voiceId: voiceId,
    );
    if (!mounted) return;

    if (mp3Bytes != null) {
      // ── Neural2 path ────────────────────────────────────────────────
      await _tts.stop();
      setState(() {
        _isLoadingAudio = false;
        _isPlaying = true;
        _usingNeural2 = true;
        _currentWordIndex = -1;
        _pulseController.repeat(reverse: true);
      });
      await _audioPlayer.play(BytesSource(mp3Bytes));
    } else {
      // ── flutter_tts fallback ────────────────────────────────────────
      await _tts.stop();
      await _tts.setSpeechRate(_speechRate);
      setState(() {
        _isLoadingAudio = false;
        _isPlaying = true;
        _usingNeural2 = false;
        _currentWordIndex = -1;
        _pulseController.repeat(reverse: true);
      });
      await _tts.speak(widget.storyText);
    }
  }

  Future<void> _pauseReading() async {
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
    if (_usingNeural2) {
      await _audioPlayer.resume();
      if (!mounted) return;
      setState(() {
        _isPlaying = true;
        _pulseController.repeat(reverse: true);
      });
    } else {
      await _tts.speak(widget.storyText);
      if (!mounted) return;
      setState(() {
        _isPlaying = true;
        _pulseController.repeat(reverse: true);
      });
    }
  }

  Future<void> _stopReading() async {
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
                      ? AppColors.gold.withValues(alpha: 0.4)
                      : null,
                  decoration: isHighlighted 
                      ? TextDecoration.underline 
                      : null,
                  decorationColor: AppColors.gold,
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

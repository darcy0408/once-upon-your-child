// lib/story_reader_screen.dart
// Simple read-aloud experience with word highlighting using Flutter TTS.

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class StoryReaderScreen extends StatefulWidget {
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
  State<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends State<StoryReaderScreen> {
  late final FlutterTts _tts;
  late final List<_StoryToken> _tokens;
  late final List<int> _wordTokenIndices;
  bool _isPlaying = false;
  int _currentWordIndex = -1;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _configureTts();
    _prepareTokens();
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
    await _tts.setSpeechRate(0.52);
    await _tts.setPitch(1.0);

    _tts.setProgressHandler((text, start, end, word) {
      if (!mounted) return;
      final normalizedWord = _normalize(word);
      if (normalizedWord.isEmpty) return;

      for (var nextIndex = _currentWordIndex + 1;
          nextIndex < _wordTokenIndices.length;
          nextIndex++) {
        final token = _tokens[_wordTokenIndices[nextIndex]];
        final tokenNormalized = _normalize(token.text);
        if (tokenNormalized.isEmpty) {
          continue;
        }
        if (tokenNormalized == normalizedWord) {
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
      });
    });

    _tts.setCancelHandler(() {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _currentWordIndex = -1;
      });
    });

    _tts.setPauseHandler(() {
      if (!mounted) return;
      setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _startReading() async {
    await _tts.stop();
    setState(() {
      _isPlaying = true;
      _currentWordIndex = -1;
    });
    await _tts.speak(widget.storyText);
  }

  Future<void> _pauseReading() async {
    final result = await _tts.pause();
    if (result == 1) {
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _stopReading() async {
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _currentWordIndex = -1;
    });
  }

  List<_StoryToken> _tokenize(String input) {
    if (input.isEmpty) {
      return [];
    }

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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: theme.colorScheme.primary,
      ),
      body: Column(
        children: [
          if (widget.characterName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Featuring ${widget.characterName}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Read-Aloud Controls',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isPlaying ? null : _startReading,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isPlaying ? _pauseReading : null,
                          icon: const Icon(Icons.pause),
                          label: const Text('Pause'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isPlaying || _currentWordIndex != -1
                              ? _stopReading
                              : null,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                        color: Colors.black87,
                        fontSize: 18,
                      ),
                      children: _buildSpans(theme),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _buildSpans(ThemeData theme) {
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
                      ? theme.colorScheme.secondary.withOpacity(0.4)
                      : null,
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

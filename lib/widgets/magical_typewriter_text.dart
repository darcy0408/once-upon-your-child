import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A widget that reveals text one word at a time with a magical "flicker" and glow.
/// Designed to simulate the "magic" of a story being woven.
class MagicalTypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  /// Optional override for word reveal delay. If not provided, the delay is
  /// derived from [readerAge].
  final Duration? wordDelay;

  /// Optional reading age used to calibrate reveal speed.
  /// Younger ages reveal slower; older ages reveal faster.
  final int? readerAge;
  final VoidCallback? onComplete;

  const MagicalTypewriterText({
    super.key,
    required this.text,
    this.style,
    this.wordDelay,
    this.readerAge,
    this.onComplete,
  });

  @override
  State<MagicalTypewriterText> createState() => _MagicalTypewriterTextState();
}

class _MagicalTypewriterTextState extends State<MagicalTypewriterText>
    with TickerProviderStateMixin {
  late List<_TypewriterToken> _tokens;
  late List<int> _wordTokenIndices;

  int _currentWordIndex = 0; // index into _wordTokenIndices
  int _currentTokenIndex = -1; // index into _tokens (inclusive)
  Timer? _timer;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _rebuildTokens();
    _startTyping();
  }

  @override
  void didUpdateWidget(MagicalTypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _timer?.cancel();
      setState(() {
        _rebuildTokens();
        _currentWordIndex = 0;
        _currentTokenIndex = -1;
        _isComplete = false;
      });
      _startTyping();
    }
  }

  void _rebuildTokens() {
    _tokens = _tokenize(widget.text);
    _wordTokenIndices = <int>[];
    for (var i = 0; i < _tokens.length; i++) {
      if (!_tokens[i].isWhitespace) {
        _wordTokenIndices.add(i);
      }
    }
  }

  List<_TypewriterToken> _tokenize(String input) {
    if (input.isEmpty) return const <_TypewriterToken>[];

    final tokens = <_TypewriterToken>[];
    final ws = RegExp(r'\s+');
    var last = 0;
    for (final m in ws.allMatches(input)) {
      if (m.start > last) {
        tokens.add(_TypewriterToken(
          text: input.substring(last, m.start),
          isWhitespace: false,
        ));
      }
      tokens.add(_TypewriterToken(
        text: input.substring(m.start, m.end),
        isWhitespace: true,
      ));
      last = m.end;
    }
    if (last < input.length) {
      tokens.add(_TypewriterToken(text: input.substring(last), isWhitespace: false));
    }
    return tokens;
  }

  void _startTyping() {
    _timer?.cancel();

    if (_wordTokenIndices.isEmpty) {
      _handleComplete();
      return;
    }

    // Reveal the first word immediately.
    setState(() {
      _currentWordIndex = 0;
      _currentTokenIndex = _lastTokenIndexForWord(_currentWordIndex);
    });

    _scheduleNext();
  }

  void _scheduleNext() {
    if (!mounted) return;
    if (_currentWordIndex >= _wordTokenIndices.length - 1) {
      _handleComplete();
      return;
    }

    final delay = _delayForCurrentWord();
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        _currentWordIndex++;
        _currentTokenIndex = _lastTokenIndexForWord(_currentWordIndex);
      });
      _scheduleNext();
    });
  }

  Duration _delayForCurrentWord() {
    final base = widget.wordDelay ?? _delayFromAge(widget.readerAge) ?? const Duration(milliseconds: 80);

    final tokenIndex = _wordTokenIndices[_currentWordIndex];
    final word = _tokens[tokenIndex].text.trimRight();

    // Give the eye a beat on punctuation and paragraph breaks.
    var multiplier = 1.0;
    if (word.endsWith('.') || word.endsWith('!') || word.endsWith('?')) {
      multiplier = 2.2;
    } else if (word.endsWith(',') || word.endsWith(';') || word.endsWith(':')) {
      multiplier = 1.45;
    }

    // If this word is followed by a newline chunk, slow down a bit more.
    final lastToken = _lastTokenIndexForWord(_currentWordIndex);
    if (lastToken + 1 < _tokens.length) {
      final next = _tokens[lastToken + 1];
      if (next.isWhitespace && next.text.contains('\n')) {
        multiplier = multiplier < 1.9 ? 1.9 : multiplier;
      }
    }

    final ms = (base.inMilliseconds * multiplier).round().clamp(20, 400);
    return Duration(milliseconds: ms);
  }

  Duration? _delayFromAge(int? age) {
    if (age == null) return null;
    final a = age.clamp(3, 18);

    // 3yo: 150ms/word, 6yo: 110ms, 9yo: 80ms, 12yo: 60ms, 18yo: 45ms.
    final ms = switch (a) {
      <= 4 => 150,
      <= 5 => 130,
      <= 6 => 110,
      <= 7 => 95,
      <= 9 => 80,
      <= 12 => 60,
      _ => 45,
    };
    return Duration(milliseconds: ms);
  }

  int _lastTokenIndexForWord(int wordIndex) {
    final tokenIndex = _wordTokenIndices[wordIndex];

    // Include any whitespace immediately following this word so spacing/newlines
    // don't "jump" later.
    var i = tokenIndex;
    while (i + 1 < _tokens.length && _tokens[i + 1].isWhitespace) {
      i++;
    }
    return i;
  }

  void _handleComplete() {
    _timer?.cancel();
    if (_isComplete) return;
    setState(() => _isComplete = true);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ??
        GoogleFonts.merriweather(
          fontSize: 20,
          height: 1.8,
          color: const Color(0xFF2C3E50),
        );

    final displayedText = _currentTokenIndex < 0
        ? ''
        : _tokens.take(_currentTokenIndex + 1).map((t) => t.text).join();

    return SelectionArea(
      child: RichText(
        text: TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: displayedText),
            if (!_isComplete)
              WidgetSpan(
                child: _MagicalCursor(color: baseStyle.color ?? Colors.black),
                alignment: PlaceholderAlignment.middle,
              ),
          ],
        ),
      ),
    );
  }
}

class _TypewriterToken {
  const _TypewriterToken({
    required this.text,
    required this.isWhitespace,
  });

  final String text;
  final bool isWhitespace;
}

class _MagicalCursor extends StatefulWidget {
  final Color color;

  const _MagicalCursor({required this.color});

  @override
  State<_MagicalCursor> createState() => _MagicalCursorState();
}

class _MagicalCursorState extends State<_MagicalCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.2, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.5),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.auto_awesome,
            size: 8,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

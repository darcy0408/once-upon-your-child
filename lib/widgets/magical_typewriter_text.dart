import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A widget that reveals text one word at a time with a magical "flicker" and glow.
/// Designed to simulate the "magic" of a story being woven.
class MagicalTypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration wordDelay;
  final VoidCallback? onComplete;

  const MagicalTypewriterText({
    super.key,
    required this.text,
    this.style,
    this.wordDelay = const Duration(milliseconds: 80),
    this.onComplete,
  });

  @override
  State<MagicalTypewriterText> createState() => _MagicalTypewriterTextState();
}

class _MagicalTypewriterTextState extends State<MagicalTypewriterText>
    with TickerProviderStateMixin {
  late List<String> _words;
  int _currentWordIndex = 0;
  Timer? _timer;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _words = widget.text.split(' ');
    _startTyping();
  }

  @override
  void didUpdateWidget(MagicalTypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _timer?.cancel();
      setState(() {
        _words = widget.text.split(' ');
        _currentWordIndex = 0;
        _isComplete = false;
      });
      _startTyping();
    }
  }

  void _startTyping() {
    if (_words.isEmpty) {
      _handleComplete();
      return;
    }

    _timer = Timer.periodic(widget.wordDelay, (timer) {
      if (_currentWordIndex < _words.length - 1) {
        setState(() {
          _currentWordIndex++;
        });
      } else {
        _handleComplete();
      }
    });
  }

  void _handleComplete() {
    _timer?.cancel();
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

    // Join the words up to the current index
    final displayedText = _words.take(_currentWordIndex + 1).join(' ');

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
          color: widget.color.withOpacity(0.5),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.3),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// A pulsing mic button that records speech and returns the transcribed text.
///
/// Usage:
/// ```dart
/// VoiceMicButton(
///   onResult: (text) => print('Heard: $text'),
///   hint: 'Say your choice...',
/// )
/// ```
class VoiceMicButton extends StatefulWidget {
  final void Function(String text) onResult;
  final String hint;
  final bool disabled;
  final double size;

  const VoiceMicButton({
    super.key,
    required this.onResult,
    this.hint = 'Tap to speak...',
    this.disabled = false,
    this.size = 56,
  });

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _listening = false;
  String _lastHeard = '';

  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (_) => _stopListening(),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _listening = false);
          _pulseController.stop();
        }
      },
    );
    if (mounted) setState(() => _initialized = available);
  }

  Future<void> _toggleListening() async {
    if (!_initialized || widget.disabled) return;

    if (_listening) {
      await _stopListening();
      return;
    }

    setState(() {
      _listening = true;
      _lastHeard = '';
    });
    _pulseController.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _lastHeard = result.recognizedWords);
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          widget.onResult(result.recognizedWords);
          _stopListening();
        }
      },
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    _pulseController.stop();
    if (mounted) setState(() => _listening = false);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unavailable = !_initialized || widget.disabled;
    final color = _listening
        ? Colors.red.shade400
        : unavailable
            ? Colors.grey.shade400
            : Colors.deepPurple;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: unavailable ? null : _toggleListening,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Transform.scale(
              scale: _listening ? _pulse.value : 1.0,
              child: child,
            ),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
                border: Border.all(color: color, width: 2),
                boxShadow: _listening
                    ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)]
                    : null,
              ),
              child: Icon(
                _listening ? Icons.mic : Icons.mic_none,
                color: color,
                size: widget.size * 0.45,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _listening
                ? (_lastHeard.isEmpty ? 'Listening...' : '"$_lastHeard"')
                : unavailable
                    ? 'Mic unavailable'
                    : widget.hint,
            key: ValueKey(_listening ? _lastHeard : widget.hint),
            style: TextStyle(
              fontSize: 12,
              color: _listening ? Colors.deepPurple.shade700 : Colors.grey.shade600,
              fontStyle: _lastHeard.isNotEmpty && _listening ? FontStyle.italic : FontStyle.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

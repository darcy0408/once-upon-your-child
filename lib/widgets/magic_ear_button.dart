import 'package:flutter/material.dart';
import '../services/app_tts_service.dart';

/// A golden speaker button that reads a prompt aloud via TTS.
/// Place in the AppBar or header row of each wizard step.
class MagicEarButton extends StatefulWidget {
  /// The full text to speak (question + choices).
  final String spokenText;
  final double size;

  const MagicEarButton({
    super.key,
    required this.spokenText,
    this.size = 36,
  });

  @override
  State<MagicEarButton> createState() => _MagicEarButtonState();
}

class _MagicEarButtonState extends State<MagicEarButton>
    with SingleTickerProviderStateMixin {
  bool _isSpeaking = false;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  Future<void> _toggle() async {
    if (_isSpeaking) {
      await AppTtsService.instance.stop();
      _pulseCtrl.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }
    setState(() => _isSpeaking = true);
    _pulseCtrl.repeat(reverse: true);
    try {
      await AppTtsService.instance.speak(
        widget.spokenText,
        awaitCompletion: true,
      );
    } catch (_) {
      // Stop the animation even if the audio layer times out.
    }
    _pulseCtrl.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _isSpeaking ? 'Stop reading aloud' : 'Read this question aloud',
      child: GestureDetector(
        onTap: _toggle,
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, child) => Transform.scale(
            scale: _isSpeaking ? 1.0 + (_pulseCtrl.value * 0.15) : 1.0,
            child: child,
          ),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isSpeaking
                  ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                  : const Color(0xFFFFD700).withValues(alpha: 0.15),
              border: Border.all(
                color: const Color(0xFFFFD700),
                width: 2,
              ),
            ),
            child: Icon(
              _isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
              color: const Color(0xFFFFD700),
              size: widget.size * 0.55,
            ),
          ),
        ),
      ),
    );
  }
}

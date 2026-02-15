import 'package:flutter/material.dart';

/// Subtle "breathing" animation wrapper for an avatar.
///
/// Intended for Story Reading mode: keeps the character feeling "alive" without
/// being distracting.
class BreathingAvatar extends StatefulWidget {
  const BreathingAvatar({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 3200),
    this.minScale = 0.98,
    this.maxScale = 1.04,
    this.glowColor,
  });

  final Widget child;
  final Duration period;
  final double minScale;
  final double maxScale;
  final Color? glowColor;

  @override
  State<BreathingAvatar> createState() => _BreathingAvatarState();
}

class _BreathingAvatarState extends State<BreathingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: widget.minScale, end: widget.maxScale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant BreathingAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller.duration = widget.period;
      if (_controller.isAnimating) {
        _controller
          ..stop()
          ..repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.glowColor;
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        final s = _scale.value;
        return Transform.scale(
          scale: s,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: glow == null
                  ? null
                  : [
                      BoxShadow(
                        color: glow.withValues(alpha: 0.18),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}


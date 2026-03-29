import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/motion_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WiggleWidget
// Rotates its child back-and-forth to signal "tap me!".
// Respects MotionPrefs.reduceMotion — returns bare child if true.
// ─────────────────────────────────────────────────────────────────────────────

class WiggleWidget extends StatefulWidget {
  const WiggleWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.angle = 0.05,
    this.repeat = false,
    this.delayMs = 0,
  });

  final Widget child;
  final Duration duration;
  /// Max rotation angle in radians.
  final double angle;
  /// Whether to loop continuously.
  final bool repeat;
  /// Initial delay before the first wiggle (for staggering multiple cards).
  final int delayMs;

  @override
  State<WiggleWidget> createState() => _WiggleWidgetState();
}

class _WiggleWidgetState extends State<WiggleWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _rotate = Tween<double>(begin: -widget.angle, end: widget.angle).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
    if (widget.delayMs > 0) {
      Future.delayed(Duration(milliseconds: widget.delayMs), _start);
    } else {
      _start();
    }
  }

  void _start() {
    if (!mounted) return;
    if (widget.repeat) {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MotionPrefs.reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _rotate,
      child: widget.child,
      builder: (context, child) =>
          Transform.rotate(angle: _rotate.value, child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BounceOnTapWidget
// Scales child down on press, back up on release, then fires onTap.
// Respects MotionPrefs.reduceMotion — falls back to plain GestureDetector.
// ─────────────────────────────────────────────────────────────────────────────

class BounceOnTapWidget extends StatefulWidget {
  const BounceOnTapWidget({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleTo = 0.88,
    this.duration = const Duration(milliseconds: 180),
  });

  final Widget child;
  final VoidCallback onTap;
  final double scaleTo;
  final Duration duration;

  @override
  State<BounceOnTapWidget> createState() => _BounceOnTapWidgetState();
}

class _BounceOnTapWidgetState extends State<BounceOnTapWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: 1.0, end: widget.scaleTo).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleTapDown(TapDownDetails _) async {
    if (MotionPrefs.reduceMotion(context)) return;
    await _ctrl.forward();
  }

  Future<void> _handleTapUp(TapUpDetails _) async {
    await _ctrl.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (MotionPrefs.reduceMotion(context)) {
      return GestureDetector(onTap: widget.onTap, child: widget.child);
    }
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scale,
        child: widget.child,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FeelingPulseWidget
// Per-feeling expressive animation. Each feeling maps to a distinct motion:
//   Happy  → gentle scale pulse
//   Sad    → slow opacity + downward drift
//   Mad    → fast horizontal shake
//   Scared → rapid shiver (rotation + scale)
//   other  → gentle breathing scale
// Respects MotionPrefs.reduceMotion — returns bare child if true.
// ─────────────────────────────────────────────────────────────────────────────

class FeelingPulseWidget extends StatefulWidget {
  const FeelingPulseWidget({
    super.key,
    required this.feelingId,
    required this.child,
  });

  final String feelingId;
  final Widget child;

  @override
  State<FeelingPulseWidget> createState() => _FeelingPulseWidgetState();
}

class _FeelingPulseWidgetState extends State<FeelingPulseWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Shared animations — only the ones relevant to the feelingId are used.
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _translateY;
  late final Animation<double> _translateX;
  late final Animation<double> _rotation;

  String get _id => widget.feelingId.toLowerCase();

  Duration get _period {
    switch (_id) {
      case 'mad':
        return const Duration(milliseconds: 280);
      case 'scared':
        return const Duration(milliseconds: 380);
      case 'happy':
        return const Duration(milliseconds: 1400);
      case 'sad':
        return const Duration(milliseconds: 2400);
      default:
        return const Duration(milliseconds: 2200);
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _period)
      ..repeat(reverse: true);

    _scale = Tween<double>(
      begin: _id == 'happy' ? 1.0 : (_id == 'scared' ? 0.96 : 0.98),
      end: _id == 'happy' ? 1.08 : (_id == 'scared' ? 1.0 : 1.02),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine));

    _opacity = Tween<double>(
      begin: _id == 'sad' ? 0.75 : 1.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _translateY = Tween<double>(
      begin: 0.0,
      end: _id == 'sad' ? 3.0 : 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _translateX = Tween<double>(
      begin: _id == 'mad' ? -5.0 : 0.0,
      end: _id == 'mad' ? 5.0 : 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine));

    _rotation = Tween<double>(
      begin: _id == 'scared' ? -0.04 : 0.0,
      end: _id == 'scared' ? 0.04 : 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MotionPrefs.reduceMotion(context)) return widget.child;

    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) {
        Widget result = Transform.scale(scale: _scale.value, child: child);

        if (_id == 'mad' || _id == 'scared') {
          result = Transform(
            transform: Matrix4.translationValues(
                _translateX.value, 0.0, 0.0)
              ..rotateZ(_rotation.value),
            alignment: Alignment.center,
            child: result,
          );
        } else if (_id == 'sad') {
          result = Opacity(
            opacity: _opacity.value,
            child: Transform.translate(
              offset: Offset(0, _translateY.value),
              child: result,
            ),
          );
        }

        return result;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DragonBreathAnimation
// Animated circle that inflates/deflates — used for the "Dragon Breath"
// coping tool card in the Big Feelings Flow (Sprout band).
// ─────────────────────────────────────────────────────────────────────────────

class DragonBreathAnimation extends StatefulWidget {
  const DragonBreathAnimation({super.key, this.size = 56.0});
  final double size;

  @override
  State<DragonBreathAnimation> createState() => _DragonBreathAnimationState();
}

class _DragonBreathAnimationState extends State<DragonBreathAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<Color?> _color;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic),
    );
    _color = ColorTween(
      begin: const Color(0xFF64B5F6), // soft blue — inhale
      end: const Color(0xFFFF8A50),   // warm orange — exhale
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MotionPrefs.reduceMotion(context)) {
      return Icon(Icons.air_rounded,
          size: widget.size, color: const Color(0xFF64B5F6));
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final s = widget.size * _scale.value;
        return Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _color.value?.withValues(alpha: 0.85),
              boxShadow: [
                BoxShadow(
                  color: (_color.value ?? Colors.blue).withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CountToFiveAnimation
// Numbers 1-5 appear sequentially — used for "Count to 5" coping tool.
// ─────────────────────────────────────────────────────────────────────────────

class CountToFiveAnimation extends StatefulWidget {
  const CountToFiveAnimation({super.key, this.size = 48.0});
  final double size;

  @override
  State<CountToFiveAnimation> createState() => _CountToFiveAnimationState();
}

class _CountToFiveAnimationState extends State<CountToFiveAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // 0.0–1.0 split into 5 equal segments
  int get _currentNumber {
    final v = _ctrl.value;
    if (v < 0.2) return 1;
    if (v < 0.4) return 2;
    if (v < 0.6) return 3;
    if (v < 0.8) return 4;
    return 5;
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MotionPrefs.reduceMotion(context)) {
      return Text('1-5',
          style: TextStyle(
              fontSize: widget.size * 0.55,
              fontWeight: FontWeight.bold,
              color: Colors.white));
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final n = _currentNumber;
        // Progress within current segment (0.0–1.0)
        final segProgress = (_ctrl.value * 5) - (n - 1);
        // Fade in quickly, hold, fade out
        final opacity = segProgress < 0.2
            ? math.min(1.0, segProgress / 0.2)
            : segProgress > 0.75
                ? math.max(0.0, 1.0 - (segProgress - 0.75) / 0.25)
                : 1.0;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Opacity(
            key: ValueKey(n),
            opacity: opacity.clamp(0.0, 1.0),
            child: Text(
              '$n',
              style: TextStyle(
                fontSize: widget.size * 0.85,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../utils/motion_utils.dart';

/// Reusable star-burst celebration effect.
///
/// Call [StarBurstCelebrationController.trigger()] to play the animation.
/// The burst paints [starCount] 4-pointed stars radiating outward, fading
/// in/out over [duration].
///
/// Reduced-motion fallback: a brief opacity flash instead of animated stars.
class StarBurstCelebration extends StatefulWidget {
  final StarBurstCelebrationController controller;

  /// Number of stars. Defaults to 12 (full burst). Use 4-6 for mini badges.
  final int starCount;

  /// How far stars travel from center (relative to widget width). Default 0.55.
  final double radiusFactor;

  /// Override the default color palette.
  final List<Color>? colors;

  /// Duration of the full burst cycle.
  final Duration duration;

  const StarBurstCelebration({
    super.key,
    required this.controller,
    this.starCount = 12,
    this.radiusFactor = 0.55,
    this.colors,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<StarBurstCelebration> createState() => _StarBurstCelebrationState();
}

class _StarBurstCelebrationState extends State<StarBurstCelebration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const _defaultColors = [
    Color(0xFFFFD700),
    Color(0xFFFF8CFF),
    Color(0xFF7FFFCF),
    Color(0xFFFFAA44),
    Color(0xFFB388FF),
    Color(0xFFFFFFFF),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    widget.controller._attach(_controller);
  }

  @override
  void dispose() {
    widget.controller._detach();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MotionPrefs.reduceMotion(context);
    if (reduce) {
      // Reduced-motion: brief opacity flash
      return AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Opacity(
          opacity: _controller.isAnimating ? 0.6 : 0.0,
          child: const SizedBox.expand(),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: _StarBurstPainter(
          progress: _controller.value,
          starCount: widget.starCount,
          radiusFactor: widget.radiusFactor,
          colors: widget.colors ?? _defaultColors,
        ),
      ),
    );
  }
}

/// Controller for [StarBurstCelebration]. Create one and pass it to the widget,
/// then call [trigger()] to play the burst.
class StarBurstCelebrationController {
  AnimationController? _animController;

  void _attach(AnimationController c) => _animController = c;
  void _detach() => _animController = null;

  /// Play the burst animation once from the beginning.
  Future<void> trigger() async {
    final c = _animController;
    if (c == null) return;
    c.reset();
    await c.forward();
  }

  void dispose() {
    _animController = null;
  }
}

class _StarBurstPainter extends CustomPainter {
  final double progress;
  final int starCount;
  final double radiusFactor;
  final List<Color> colors;

  const _StarBurstPainter({
    required this.progress,
    required this.starCount,
    required this.radiusFactor,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height) * radiusFactor;
    // Bright 0→0.6, fade 0.6→1.0
    final opacity = progress < 0.6
        ? progress / 0.6
        : 1.0 - (progress - 0.6) / 0.4;

    for (int i = 0; i < starCount; i++) {
      final angle = (i / starCount) * 2 * math.pi;
      final dist = maxRadius * progress;
      final cx = center.dx + dist * math.cos(angle);
      final cy = center.dy + dist * math.sin(angle);
      final color = colors[i % colors.length]
          .withValues(alpha: opacity.clamp(0.0, 1.0));
      final starSize =
          (4.0 + 4.0 * math.sin(progress * math.pi)) * (1 - progress * 0.3);

      _drawStar(
        canvas,
        Offset(cx, cy),
        starSize,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    const points = 4;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final radius = i.isEven ? r : r * 0.4;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StarBurstPainter old) => old.progress != progress;
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Wraps any widget with a magical star cursor overlay on web.
/// On non-web platforms the child is returned unchanged.
class MagicStarCursor extends StatefulWidget {
  const MagicStarCursor({super.key, required this.child});

  final Widget child;

  @override
  State<MagicStarCursor> createState() => _MagicStarCursorState();
}

class _MagicStarCursorState extends State<MagicStarCursor> {
  final List<_Sparkle> _sparkles = [];
  Offset _cursor = Offset.zero;
  Timer? _cleanupTimer;
  final _rand = Random();

  void _onHover(PointerEvent event) {
    if (!mounted) return;
    setState(() {
      _cursor = event.localPosition;
      // Add 2-3 sparkles at the cursor position
      for (int i = 0; i < 2 + _rand.nextInt(2); i++) {
        _sparkles.add(_Sparkle(
          position: _cursor + Offset(
            (_rand.nextDouble() - 0.5) * 18,
            (_rand.nextDouble() - 0.5) * 18,
          ),
          createdAt: DateTime.now(),
          color: _sparkleColor(),
          size: 4 + _rand.nextDouble() * 7,
          angle: _rand.nextDouble() * pi * 2,
        ));
      }
      // Remove sparkles older than 600ms
      final cutoff = DateTime.now().subtract(const Duration(milliseconds: 600));
      _sparkles.removeWhere((s) => s.createdAt.isBefore(cutoff));
    });
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _sparkles.clear());
    });
  }

  Color _sparkleColor() {
    const colors = [
      Color(0xFFFFD700),
      Color(0xFFFFE066),
      Color(0xFFB87FFF),
      Color(0xFFFFFFFF),
      Color(0xFFFF88FF),
    ];
    return colors[_rand.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only apply on web
    if (!kIsWeb) return widget.child;

    return MouseRegion(
      cursor: SystemMouseCursors.none,
      onHover: _onHover,
      child: Stack(
        children: [
          widget.child,
          // Sparkle trail
          ..._sparkles.map((s) {
            final age = DateTime.now().difference(s.createdAt).inMilliseconds;
            final opacity = (1.0 - age / 600.0).clamp(0.0, 1.0);
            return Positioned(
              left: s.position.dx - s.size / 2,
              top: s.position.dy - s.size / 2,
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: s.angle,
                  child: _StarShape(size: s.size, color: s.color),
                ),
              ),
            );
          }),
          // Main star cursor
          Positioned(
            left: _cursor.dx - 16,
            top: _cursor.dy - 16,
            child: IgnorePointer(
              child: _AnimatedStar(size: 32),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sparkle {
  final Offset position;
  final DateTime createdAt;
  final Color color;
  final double size;
  final double angle;

  const _Sparkle({
    required this.position,
    required this.createdAt,
    required this.color,
    required this.size,
    required this.angle,
  });
}

/// Animated glowing star that pulses
class _AnimatedStar extends StatefulWidget {
  const _AnimatedStar({required this.size});
  final double size;

  @override
  State<_AnimatedStar> createState() => _AnimatedStarState();
}

class _AnimatedStarState extends State<_AnimatedStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Transform.scale(
        scale: _pulse.value,
        child: _StarShape(
          size: widget.size,
          color: const Color(0xFFFFE066),
          glowing: true,
        ),
      ),
    );
  }
}

/// A 4-pointed star shape painted via CustomPainter
class _StarShape extends StatelessWidget {
  const _StarShape({required this.size, required this.color, this.glowing = false});
  final double size;
  final Color color;
  final bool glowing;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _StarPainter(color: color, glowing: glowing),
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter({required this.color, required this.glowing});
  final Color color;
  final bool glowing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    if (glowing) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.35);
    }

    final cx = size.width / 2;
    final cy = size.height / 2;
    final outer = size.width / 2;
    final inner = outer * 0.25;
    const points = 4;

    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final angle = (i * pi / points) - pi / 2;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);

    // Solid core on top of glow
    if (glowing) {
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color || old.glowing != glowing;
}

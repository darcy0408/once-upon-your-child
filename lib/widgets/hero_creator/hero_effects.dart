import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../utils/motion_utils.dart';

class StarBurstOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const StarBurstOverlay({super.key, required this.onComplete});

  @override
  State<StarBurstOverlay> createState() => _StarBurstOverlayState();
}

class _StarBurstOverlayState extends State<StarBurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_StarParticle> _particles;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward().then((_) => widget.onComplete());

    _particles = List.generate(22, (_) => _StarParticle(_rng));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Stack(
            children: _particles.map((p) {
              final t = _ctrl.value;
              final x = size.width / 2 + p.dx * t * 220;
              final y = size.height / 2 + p.dy * t * 260 + 120 * t * t;
              final opacity = (1.0 - t * 1.4).clamp(0.0, 1.0);
              final scale = (1.0 - t * 0.6).clamp(0.1, 1.0);
              return Positioned(
                left: x - 10,
                top: y - 10,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Text(
                      p.emoji,
                      style: TextStyle(fontSize: 18 + p.size),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _StarParticle {
  final double dx;
  final double dy;
  final double size;
  final String emoji;

  static const _emojis = ['⭐', '✨', '🌟', '💫', '🔮', '🪄', '💜', '⚡'];

  _StarParticle(math.Random rng)
      : dx = (rng.nextDouble() * 2 - 1),
        dy = (rng.nextDouble() * 2 - 1),
        size = rng.nextDouble() * 8,
        emoji = _emojis[rng.nextInt(_emojis.length)];
}

class AmbientSparkleLayer extends StatefulWidget {
  const AmbientSparkleLayer({super.key});

  @override
  State<AmbientSparkleLayer> createState() => _AmbientSparkleLayerState();
}

class _AmbientSparkleLayerState extends State<AmbientSparkleLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_AmbientParticle> _particles;
  final _rng = math.Random(42);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _particles = List.generate(14, (_) => _AmbientParticle(_rng));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!MotionPrefs.showParticles(context)) {
      return const SizedBox.expand();
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _AmbientSparklePainter(
            particles: _particles,
            progress: _ctrl.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _AmbientParticle {
  final double xFraction;
  final double phase;
  final double speed;
  final double size;
  final double drift;

  _AmbientParticle(math.Random rng)
      : xFraction = rng.nextDouble(),
        phase = rng.nextDouble(),
        speed = 0.4 + rng.nextDouble() * 0.6,
        size = 2.0 + rng.nextDouble() * 3.0,
        drift = (rng.nextDouble() - 0.5) * 20;
}

class _AmbientSparklePainter extends CustomPainter {
  final List<_AmbientParticle> particles;
  final double progress;

  const _AmbientSparklePainter(
      {required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = ((progress * p.speed + p.phase) % 1.0);
      final y = size.height * (1.0 - t);
      final x = size.width * p.xFraction + p.drift * math.sin(t * math.pi * 2);

      final opacity = t < 0.15
          ? t / 0.15
          : t > 0.75
              ? (1.0 - t) / 0.25
              : 1.0;

      final paint = Paint()
        ..color = const Color(0xFFFFE082).withAlpha((60 * opacity).round())
        ..style = PaintingStyle.fill;

      _drawTinyStar(canvas, Offset(x, y), p.size, paint);
    }
  }

  void _drawTinyStar(Canvas canvas, Offset center, double r, Paint paint) {
    final inner = r * 0.38;
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - math.pi / 2;
      final radius = i.isEven ? r : inner;
      final px = center.dx + radius * math.cos(angle);
      final py = center.dy + radius * math.sin(angle);
      i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_AmbientSparklePainter old) => old.progress != progress;
}

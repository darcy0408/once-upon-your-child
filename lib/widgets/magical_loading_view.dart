import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/motion_utils.dart';

/// A magical loading view with a central weaving "loom" animation,
/// orbiting sparkles, rotating flavor messages, and layered aura glows.
class MagicalLoadingView extends StatefulWidget {
  final String status;
  final VoidCallback? onCancel;

  const MagicalLoadingView({
    super.key,
    required this.status,
    this.onCancel,
  });

  @override
  State<MagicalLoadingView> createState() => _MagicalLoadingViewState();
}

class _MagicalLoadingViewState extends State<MagicalLoadingView>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rotationController;
  late final AnimationController _weaveController;

  final List<_Sparkle> _sparkles = <_Sparkle>[];
  final Random _random = Random();

  static const List<String> _phaseMessages = <String>[
    'Threading moonlight through the loom...',
    'Spinning stardust into story cloth...',
    'Tuning crystal harmonics...',
    'Gathering brave thoughts and gentle feelings...',
    'Architecting a complex world of wonder...',
    'Stitching surprises into the next scene...',
    'Weaving themes of resilience and hope...',
    'Crafting deep character motivations...',
    'Polishing the prose for maximum magic...',
    'Building a satisfying emotional journey...',
    'Warming the ending with a soft glow...',
  ];

  Timer? _messageTimer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _weaveController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();

    // A lightweight particle field: orbit + drift + twinkle.
    for (int i = 0; i < 22; i++) {
      _sparkles.add(
        _Sparkle(
          angle: _random.nextDouble() * 2 * pi,
          distance: 42.0 + _random.nextDouble() * 50.0,
          size: 3.0 + _random.nextDouble() * 7.0,
          speed: 0.5 + _random.nextDouble() * 1.5,
          twinklePhase: _random.nextDouble() * 2 * pi,
          twinkleSpeed: 0.8 + _random.nextDouble() * 2.4,
          driftPhase: _random.nextDouble() * 2 * pi,
          driftSpeed: 0.15 + _random.nextDouble() * 0.9,
        ),
      );
    }

    // Rotate flavor messages independent of backend status updates.
    _messageTimer = Timer.periodic(const Duration(milliseconds: 4200), (_) {
      if (!mounted) return;
      setState(() => _messageIndex = (_messageIndex + 1) % _phaseMessages.length);
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _pulseController.dispose();
    _rotationController.dispose();
    _weaveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final stageSize = (screenWidth * 0.42).clamp(150.0, 210.0);
    final panelWidth = screenWidth.clamp(280.0, 460.0);
    final reduced = MotionPrefs.reduceMotion(context);
    final particles = MotionPrefs.showParticles(context);
    final intensity = MotionPrefs.sparkleIntensity(context);
    final particleCount = (22 * intensity).round();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: panelWidth),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFF4D1).withValues(alpha: 0.72),
              const Color(0xFFE7C5FF).withValues(alpha: 0.78),
              const Color(0xFFBCE8FF).withValues(alpha: 0.74),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.18),
              blurRadius: 26,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.14),
              blurRadius: 34,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reduced) ...[
              // Static fallback for reduced-motion users
              SizedBox(
                height: stageSize,
                width: stageSize,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Icon(
                        Icons.auto_awesome,
                        size: 36,
                        color: AppColors.primary.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
            SizedBox(
              height: stageSize,
              width: stageSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Layered aura (3 gradient layers)
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return _AuraHalo(
                        size: stageSize,
                        t: _pulseController.value,
                        primary: AppColors.gold,
                        secondary: AppColors.primary,
                        tertiary: const Color(0xFF80DEEA),
                      );
                    },
                  ),

                  // Rotating magical ring
                  AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, child) {
                      final ringSize = stageSize * 0.80;
                      return Transform.rotate(
                        angle: _rotationController.value * 2 * pi,
                        child: Container(
                          width: ringSize,
                          height: ringSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.28),
                              width: 2,
                            ),
                            gradient: SweepGradient(
                              colors: [
                                AppColors.gold.withValues(alpha: 0.0),
                                AppColors.gold.withValues(alpha: 0.55),
                                AppColors.gold.withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Central "magic loom" weaving animation
                  AnimatedBuilder(
                    animation: Listenable.merge([_weaveController, _pulseController]),
                    builder: (context, child) {
                      final loomSize = stageSize * 0.60;
                      final pulse = _pulseController.value;
                      return Transform.scale(
                        scale: 0.98 + (pulse * 0.04),
                        child: CustomPaint(
                          size: Size.square(loomSize),
                          painter: _MagicLoomPainter(
                            phase: _weaveController.value,
                            glow: AppColors.gold,
                            accent: AppColors.primary,
                          ),
                        ),
                      );
                    },
                  ),

                  // Center sigil
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final pulse = _pulseController.value;
                      final sigilSize = stageSize * 0.34;
                      return Transform.scale(
                        scale: 1.0 + (pulse * 0.08),
                        child: Container(
                          width: sigilSize,
                          height: sigilSize,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.30 * pulse),
                                blurRadius: 20 * pulse,
                                spreadRadius: 5 * pulse,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 36,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
                  ),

                  // Orbiting sparkles (respects particle prefs + intensity)
                  if (particles)
                    ..._sparkles.take(particleCount).map((sparkle) {
                      return _AnimatedSparkle(
                        controller: _rotationController,
                        twinkleController: _weaveController,
                        sparkle: sparkle,
                      );
                    }),
                ],
              ),
            ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              widget.status,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Quicksand',
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 54, maxHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.36),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.58),
                  width: 1,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 650),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) {
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  );
                },
                child: Center(
                  child: Text(
                    _phaseMessages[_messageIndex],
                    key: ValueKey<int>(_messageIndex),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF4D3D6A),
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
            if (widget.onCancel != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Sparkle {
  final double angle;
  final double distance;
  final double size;
  final double speed;
  final double twinklePhase;
  final double twinkleSpeed;
  final double driftPhase;
  final double driftSpeed;

  _Sparkle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.speed,
    required this.twinklePhase,
    required this.twinkleSpeed,
    required this.driftPhase,
    required this.driftSpeed,
  });
}

class _AnimatedSparkle extends StatelessWidget {
  final AnimationController controller;
  final AnimationController twinkleController;
  final _Sparkle sparkle;

  const _AnimatedSparkle({
    required this.controller,
    required this.twinkleController,
    required this.sparkle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, twinkleController]),
      builder: (context, child) {
        final orbitAngle = sparkle.angle + (controller.value * 2 * pi * sparkle.speed);
        final drift = 1.0 + (0.07 * sin((controller.value * 2 * pi * sparkle.driftSpeed) + sparkle.driftPhase));
        final dx = cos(orbitAngle) * sparkle.distance * drift;
        final dy = sin(orbitAngle) * sparkle.distance * drift;

        final tw = 0.5 + 0.5 * sin((twinkleController.value * 2 * pi * sparkle.twinkleSpeed) + sparkle.twinklePhase);
        final opacity = (0.18 + (0.82 * tw)).clamp(0.0, 1.0);
        final s = sparkle.size * (0.80 + (0.45 * tw));

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Opacity(
            opacity: opacity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: AppColors.gold.withValues(alpha: 0.45),
                  size: s * 1.55,
                ),
                Icon(
                  Icons.star_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
                  size: s,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AuraHalo extends StatelessWidget {
  final double size;
  final double t;
  final Color primary;
  final Color secondary;
  final Color tertiary;

  const _AuraHalo({
    required this.size,
    required this.t,
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  @override
  Widget build(BuildContext context) {
    final s1 = size * (0.95 + (0.04 * t));
    final s2 = size * (0.78 + (0.03 * (1 - t)));
    final s3 = size * (0.62 + (0.02 * t));

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: s1,
          height: s1,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                tertiary.withValues(alpha: 0.0),
                tertiary.withValues(alpha: 0.10 + (0.06 * t)),
                Colors.transparent,
              ],
              stops: const [0.0, 0.65, 1.0],
            ),
          ),
        ),
        Container(
          width: s2,
          height: s2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                secondary.withValues(alpha: 0.12 + (0.06 * t)),
                primary.withValues(alpha: 0.10 + (0.08 * t)),
                Colors.transparent,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
        Container(
          width: s3,
          height: s3,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                primary.withValues(alpha: 0.16 + (0.08 * t)),
                Colors.white.withValues(alpha: 0.06 + (0.04 * t)),
                Colors.transparent,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _MagicLoomPainter extends CustomPainter {
  final double phase; // 0..1
  final Color glow;
  final Color accent;

  _MagicLoomPainter({
    required this.phase,
    required this.glow,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.46;

    // Soft glow backplate
    final back = Paint()
      ..color = glow.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, r * 0.92, back);

    // Loom frame ring
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.05).clamp(3.0, 7.0)
      ..shader = SweepGradient(
        colors: [
          glow.withValues(alpha: 0.0),
          glow.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.25),
          glow.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 0.65, 1.0],
        transform: GradientRotation(phase * 2 * pi),
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, ring);

    // Warp threads (vertical)
    final warpPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (size.width * 0.012).clamp(1.0, 2.4)
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: 0.0),
          accent.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.25),
          accent.withValues(alpha: 0.25),
          accent.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.18, 0.5, 0.82, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));

    final left = center.dx - (r * 0.72);
    final right = center.dx + (r * 0.72);
    final top = center.dy - (r * 0.70);
    final bottom = center.dy + (r * 0.70);

    const threadCount = 9;
    for (int i = 0; i < threadCount; i++) {
      final x = left + (i / (threadCount - 1)) * (right - left);
      final wobble = 1.0 + 0.03 * sin((phase * 2 * pi) + i * 0.7);
      canvas.drawLine(Offset(x, top), Offset(x, bottom * wobble), warpPaint);
    }

    // Weft thread (horizontal wave moving downward)
    final weftY = top + (phase * (bottom - top));
    final weft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (size.width * 0.020).clamp(1.4, 3.2)
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          glow.withValues(alpha: 0.0),
          glow.withValues(alpha: 0.65),
          Colors.white.withValues(alpha: 0.5),
          glow.withValues(alpha: 0.65),
          glow.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(left, weftY - 20, right - left, 40));

    final path = Path();
    const segments = 18;
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final x = left + t * (right - left);
      final wave = sin((t * 2 * pi * 2) + (phase * 2 * pi * 1.3)) * (r * 0.08);
      final y = weftY + wave;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, weft);

    // Small glints on the ring
    final glint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.plus;
    final a1 = (phase * 2 * pi);
    final a2 = a1 + pi * 0.78;
    canvas.drawCircle(center + Offset(cos(a1), sin(a1)) * r, (size.width * 0.02).clamp(1.2, 3.0), glint);
    canvas.drawCircle(center + Offset(cos(a2), sin(a2)) * r, (size.width * 0.015).clamp(1.0, 2.6), glint);
  }

  @override
  bool shouldRepaint(covariant _MagicLoomPainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.glow != glow || oldDelegate.accent != accent;
  }
}

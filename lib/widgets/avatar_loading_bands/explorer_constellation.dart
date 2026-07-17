import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/age_band_theme.dart';
import '../../utils/motion_utils.dart';

// ── Public widget ─────────────────────────────────────────────────────────────

/// Explorer (6-8) avatar loading: a star constellation that draws itself.
///
/// Stars appear one-by-one as [progress] advances. Golden lines connect them.
/// Sparkle particles orbit around the constellation. Drifting tap-targets let
/// the child interact while they wait.
class ExplorerConstellation extends StatefulWidget {
  final double stageSize;

  /// Generation progress from 0.0 (nothing drawn) to 1.0 (complete).
  final double progress;

  final VoidCallback onTap;

  const ExplorerConstellation({
    super.key,
    required this.stageSize,
    required this.progress,
    required this.onTap,
  });

  @override
  State<ExplorerConstellation> createState() => _ExplorerConstellationState();
}

// ── State ─────────────────────────────────────────────────────────────────────

class _ExplorerConstellationState extends State<ExplorerConstellation>
    with TickerProviderStateMixin {
  // Controllers
  late final AnimationController _sparkleOrbitCtrl;
  late final AnimationController _twinkleCtrl;
  late final AnimationController _starRevealCtrl; // drives per-star fade-in

  // Tap targets
  final List<_TapTarget> _tapTargets = [];
  Timer? _spawnTimer;
  final Random _rng = Random();

  // Burst effects
  final List<_BurstEffect> _bursts = [];

  // Firework palettes for tap bursts (mirrors MagicalLoadingView's set so
  // catching a star feels the same here as during story generation).
  static const List<List<Color>> _fireworkPalettes = <List<Color>>[
    [Color(0xFFFFD700), Color(0xFFFFAB00), Color(0xFFFFFFFF)], // sunburst
    [Color(0xFFFF4081), Color(0xFFFF80AB), Color(0xFFFFFFFF)], // pink pop
    [Color(0xFF40E0FF), Color(0xFF80DEEA), Color(0xFFFFFFFF)], // aqua wish
    [Color(0xFFB388FF), Color(0xFFE1BEE7), Color(0xFFFFD700)], // royal sparkle
    [
      Color(0xFFFFD700),
      Color(0xFFFF4081),
      Color(0xFF40E0FF),
      Color(0xFF7CFC00),
    ], // rainbow mix
  ];

  @override
  void initState() {
    super.initState();

    // Looping controllers; repeats started in didChangeDependencies so
    // MotionPrefs.reduceMotion is honored at runtime (A11Y-007 sweep).
    _sparkleOrbitCtrl = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    _twinkleCtrl = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    // Used to drive per-star appearance animations; never explicitly ticked
    // beyond triggering rebuilds — each star's threshold is driven by progress.
    _starRevealCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _startSpawnTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPrefs.reduceMotion(context)) {
      _sparkleOrbitCtrl.stop();
      _sparkleOrbitCtrl.value = 0.0;
      _twinkleCtrl.stop();
      _twinkleCtrl.value = 0.5;
    } else {
      if (!_sparkleOrbitCtrl.isAnimating) _sparkleOrbitCtrl.repeat();
      if (!_twinkleCtrl.isAnimating) _twinkleCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _sparkleOrbitCtrl.dispose();
    _twinkleCtrl.dispose();
    _starRevealCtrl.dispose();
    _spawnTimer?.cancel();
    for (final t in _tapTargets) {
      t.ctrl.dispose();
    }
    for (final b in _bursts) {
      b.ctrl.dispose();
    }
    super.dispose();
  }

  // ── Tap-target lifecycle ───────────────────────────────────────────────────

  void _startSpawnTimer() {
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!mounted) return;
      setState(() {
        _pruneExpired();
        if (_tapTargets.length < 3) {
          _spawnTarget();
        }
      });
    });
  }

  void _pruneExpired() {
    final now = DateTime.now();
    final expired = _tapTargets
        .where((t) => now.difference(t.spawnTime).inMilliseconds > t.lifetimeMs)
        .toList();
    for (final t in expired) {
      t.ctrl.dispose();
    }
    _tapTargets.removeWhere(
      (t) => now.difference(t.spawnTime).inMilliseconds > t.lifetimeMs,
    );
  }

  void _spawnTarget() {
    final halfStage = widget.stageSize / 2;
    // Keep targets within an inner circle so they don't clip edges
    final maxR = halfStage * 0.75;
    final angle = _rng.nextDouble() * 2 * pi;
    final dist = 20.0 + _rng.nextDouble() * (maxR - 20.0);
    final cx = halfStage + cos(angle) * dist;
    final cy = halfStage + sin(angle) * dist;
    final lifetime = 2500 + _rng.nextInt(1000); // 2.5-3.5 s

    final ctrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();

    _tapTargets.add(_TapTarget(
      center: Offset(cx, cy),
      spawnTime: DateTime.now(),
      lifetimeMs: lifetime,
      ctrl: ctrl,
    ));
  }

  void _onHitTarget(_TapTarget target) {
    HapticFeedback.lightImpact();
    widget.onTap();

    // Spawn a firework burst at the target position. Under reduced motion
    // the burst still fires (it's direct tap feedback) but with fewer,
    // shorter-lived sparks — same convention as MagicalLoadingView.
    final reduced = MotionPrefs.reduceMotion(context);
    final palette = _fireworkPalettes[_rng.nextInt(_fireworkPalettes.length)];
    final particleCount = reduced ? 5 : (10 + _rng.nextInt(4));
    final particles = List<_FireworkParticle>.generate(particleCount, (i) {
      final base = (i / particleCount) * 2 * pi;
      final jitter = (_rng.nextDouble() - 0.5) * 0.45;
      return _FireworkParticle(
        angle: base + jitter,
        distance: (reduced ? 32.0 : 58.0) + _rng.nextDouble() * 38.0,
        color: palette[_rng.nextInt(palette.length)],
        size: 5.0 + _rng.nextDouble() * 4.5,
      );
    });

    final burstCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    burstCtrl.forward().then((_) {
      if (!mounted) return;
      setState(() {
        _bursts.removeWhere((b) => b.ctrl == burstCtrl);
        burstCtrl.dispose();
      });
    });

    setState(() {
      target.ctrl.dispose();
      _tapTargets.remove(target);
      _bursts.add(_BurstEffect(
        center: target.center,
        ctrl: burstCtrl,
        particles: particles,
      ));
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final reduced = MotionPrefs.reduceMotion(context);
    final showP = MotionPrefs.showParticles(context);
    final intensity = MotionPrefs.sparkleIntensity(context);
    final bt = Theme.of(context).extension<AgeBandThemeData>() ??
        themeForBand(AgeBand.explorer);

    return SizedBox(
      width: widget.stageSize,
      height: widget.stageSize,
      child: AnimatedBuilder(
        animation: Listenable.merge([_sparkleOrbitCtrl, _twinkleCtrl]),
        builder: (context, _) {
          _pruneExpired();

          return Stack(
            children: [
              // ── Constellation painter ──────────────────────────────────────
              CustomPaint(
                size: Size(widget.stageSize, widget.stageSize),
                painter: _ConstellationPainter(
                  progress: widget.progress,
                  stageSize: widget.stageSize,
                  accentColor: bt.accent,
                  lineColor: bt.primary,
                  orbitPhase: reduced ? 0.0 : _sparkleOrbitCtrl.value,
                  twinklePhase: reduced ? 0.5 : _twinkleCtrl.value,
                  sparkleIntensity: reduced ? 0.0 : intensity,
                  showParticles: !reduced && showP,
                  reduceMotion: reduced,
                ),
              ),

              // ── Tap targets ────────────────────────────────────────────────
              for (final target in List.of(_tapTargets))
                _TapTargetWidget(
                  target: target,
                  accentColor: bt.accent,
                  reduceMotion: reduced,
                  onTap: () => _onHitTarget(target),
                ),

              // ── Firework bursts (on top so they read clearly) ──────────────
              //
              // NOTE: nothing tappable may sit above the tap targets — a
              // previous full-stage GestureDetector here won the gesture arena
              // and silently swallowed every star tap (topmost recognizer
              // wins, even with HitTestBehavior.translucent).
              for (final burst in _bursts)
                AnimatedBuilder(
                  animation: burst.ctrl,
                  builder: (_, __) {
                    const burstStage = 220.0;
                    return Positioned(
                      left: burst.center.dx - burstStage / 2,
                      top: burst.center.dy - burstStage / 2,
                      child: IgnorePointer(
                        child: CustomPaint(
                          size: const Size(burstStage, burstStage),
                          painter: _FireworkBurstPainter(
                            progress: burst.ctrl.value,
                            particles: burst.particles,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Tap-target widget ─────────────────────────────────────────────────────────

class _TapTargetWidget extends StatelessWidget {
  final _TapTarget target;
  final Color accentColor;
  final bool reduceMotion;
  final VoidCallback onTap;

  const _TapTargetWidget({
    required this.target,
    required this.accentColor,
    required this.reduceMotion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    return Positioned(
      left: target.center.dx - size / 2,
      top: target.center.dy - size / 2,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedBuilder(
          animation: target.ctrl,
          builder: (_, __) {
            final v = target.ctrl.value;
            final scale = reduceMotion ? 1.0 : Curves.elasticOut.transform(v);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.85),
                  boxShadow: reduceMotion
                      ? null
                      : [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                ),
                child: const Icon(
                  Icons.star,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── CustomPainter ─────────────────────────────────────────────────────────────

class _ConstellationPainter extends CustomPainter {
  final double progress;
  final double stageSize;
  final Color accentColor;
  final Color lineColor;
  final double orbitPhase;
  final double twinklePhase;
  final double sparkleIntensity;
  final bool showParticles;
  final bool reduceMotion;

  _ConstellationPainter({
    required this.progress,
    required this.stageSize,
    required this.accentColor,
    required this.lineColor,
    required this.orbitPhase,
    required this.twinklePhase,
    required this.sparkleIntensity,
    required this.showParticles,
    required this.reduceMotion,
  });

  // ── Normalized star positions forming a rough hero/person shape ─────────────
  //
  // Coordinate system: (0,0) = top-left, (1,1) = bottom-right.
  // Layout intent:
  //  0: head top
  //  1: head left
  //  2: head right
  //  3: neck / upper body center
  //  4: left shoulder
  //  5: right shoulder
  //  6: left elbow
  //  7: right elbow
  //  8: torso center
  //  9: left hip
  // 10: right hip
  // 11: feet center (low)
  static const List<Offset> _normStars = [
    Offset(0.50, 0.10), // 0 head top
    Offset(0.43, 0.17), // 1 head left
    Offset(0.57, 0.17), // 2 head right
    Offset(0.50, 0.28), // 3 neck / upper body
    Offset(0.35, 0.35), // 4 left shoulder
    Offset(0.65, 0.35), // 5 right shoulder
    Offset(0.24, 0.50), // 6 left elbow
    Offset(0.76, 0.50), // 7 right elbow
    Offset(0.50, 0.52), // 8 torso center
    Offset(0.38, 0.68), // 9 left hip
    Offset(0.62, 0.68), // 10 right hip
    Offset(0.50, 0.88), // 11 feet center
  ];

  // Adjacent pairs that get connecting lines (indices into _normStars)
  static const List<List<int>> _edges = [
    [0, 1], [0, 2], [1, 2], // head triangle
    [1, 3], [2, 3],         // head to neck
    [3, 4], [3, 5],         // shoulders
    [4, 6], [5, 7],         // elbows
    [4, 8], [5, 8],         // torso sides
    [8, 9], [8, 10],        // hips
    [9, 11], [10, 11],      // legs to feet
  ];

  // Sparkle data (deterministic, seeded layout)
  static final List<_SparkleData> _sparkles = _buildSparkles();

  static List<_SparkleData> _buildSparkles() {
    const rng = _SeededRandom(42);
    return List.generate(22, (i) {
      final angle = rng.nextDouble(i * 7) * 2 * pi;
      final dist = 40.0 + rng.nextDouble(i * 7 + 1) * 50.0; // 40-90 px
      final speed = 0.3 + rng.nextDouble(i * 7 + 2) * 1.2; // 0.3-1.5 x
      final twinklePhase = rng.nextDouble(i * 7 + 3) * 2 * pi;
      final twinkleSpeed = 0.5 + rng.nextDouble(i * 7 + 4) * 1.5;
      final dotSize = 3.0 + rng.nextDouble(i * 7 + 5) * 4.0; // 3-7 px
      return _SparkleData(
        angle: angle,
        distance: dist,
        speed: speed,
        twinklePhase: twinklePhase,
        twinkleSpeed: twinkleSpeed,
        size: dotSize,
      );
    });
  }

  // ── Paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.width; // normalize [0,1] → pixels

    // Convert normalized positions to canvas coordinates
    final List<Offset> starPositions = _normStars
        .map((n) => Offset(n.dx * scale, n.dy * scale))
        .toList();

    // How many stars are revealed?
    final revealedCount = (progress * _normStars.length).ceil().clamp(0, _normStars.length);

    // ── Draw connecting lines ────────────────────────────────────────────────
    _drawLines(canvas, starPositions, revealedCount, scale);

    // ── Draw stars ──────────────────────────────────────────────────────────
    _drawStars(canvas, starPositions, revealedCount, scale);

    // ── Draw orbiting sparkles ───────────────────────────────────────────────
    if (showParticles && sparkleIntensity > 0.0) {
      _drawSparkles(canvas, cx, cy);
    }
  }

  void _drawLines(
      Canvas canvas, List<Offset> positions, int revealedCount, double scale) {
    for (final edge in _edges) {
      final a = edge[0];
      final b = edge[1];

      // Only draw if both endpoints are revealed
      if (a >= revealedCount || b >= revealedCount) continue;

      // Line progress: how much of this edge is drawn
      // The edge becomes fully drawn once both stars are revealed
      final aThreshold = a / _normStars.length;
      final bThreshold = b / _normStars.length;
      final edgeRevealStart = max(aThreshold, bThreshold);
      final edgeRevealEnd = edgeRevealStart + (1.0 / _normStars.length);
      final lineProgress =
          ((progress - edgeRevealStart) / (edgeRevealEnd - edgeRevealStart))
              .clamp(0.0, 1.0);

      if (lineProgress <= 0.0) continue;

      final pA = positions[a];
      final pB = positions[b];

      // Gradient paint along line
      final gradient = LinearGradient(
        colors: [
          lineColor.withValues(alpha: 0.6),
          lineColor.withValues(alpha: 0.3),
        ],
      );
      final linePaint = Paint()
        ..shader = gradient.createShader(Rect.fromPoints(pA, pB))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      if (reduceMotion || lineProgress >= 1.0) {
        canvas.drawLine(pA, pB, linePaint);
      } else {
        // Animate line drawing via PathMetrics
        final path = Path()
          ..moveTo(pA.dx, pA.dy)
          ..lineTo(pB.dx, pB.dy);
        final metrics = path.computeMetrics().first;
        final revealedPath =
            metrics.extractPath(0, metrics.length * lineProgress);
        canvas.drawPath(revealedPath, linePaint);
      }
    }
  }

  void _drawStars(
      Canvas canvas, List<Offset> positions, int revealedCount, double scale) {
    for (int i = 0; i < revealedCount; i++) {
      final threshold = i / _normStars.length;
      // Per-star fade-in: the star spends 1 star-slot fading in
      final starSlot = 1.0 / _normStars.length;
      final starProgress =
          ((progress - threshold) / starSlot).clamp(0.0, 1.0);
      final alpha = reduceMotion ? 1.0 : starProgress;
      final starScale = reduceMotion ? 1.0 : Curves.elasticOut.transform(starProgress);

      final pos = positions[i];
      final baseSize = scale * 0.035; // ~3.5% of stage width

      final paint = Paint()
        ..color = accentColor.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      // Glow
      final glowPaint = Paint()
        ..color = accentColor.withValues(alpha: alpha * 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseSize * 0.8);
      canvas.drawCircle(pos, baseSize * starScale * 1.2, glowPaint);

      // Draw 4-pointed star
      _draw4PointStar(canvas, pos, baseSize * starScale, paint);
    }
  }

  /// Draws a 4-pointed star (diamond cross shape) centered at [center].
  void _draw4PointStar(
      Canvas canvas, Offset center, double radius, Paint paint) {
    final inner = radius * 0.35;
    final path = Path();

    for (int spike = 0; spike < 4; spike++) {
      final outerAngle = -pi / 2 + spike * pi / 2;
      final innerAngle1 = outerAngle - pi / 4;
      final innerAngle2 = outerAngle + pi / 4;

      final tip = Offset(
        center.dx + cos(outerAngle) * radius,
        center.dy + sin(outerAngle) * radius,
      );
      final left = Offset(
        center.dx + cos(innerAngle1) * inner,
        center.dy + sin(innerAngle1) * inner,
      );
      final right = Offset(
        center.dx + cos(innerAngle2) * inner,
        center.dy + sin(innerAngle2) * inner,
      );

      if (spike == 0) {
        path.moveTo(left.dx, left.dy);
      } else {
        path.lineTo(left.dx, left.dy);
      }
      path.lineTo(tip.dx, tip.dy);
      path.lineTo(right.dx, right.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawSparkles(Canvas canvas, double cx, double cy) {
    for (final s in _sparkles) {
      // Orbit: base angle + speed-scaled phase
      final orbitAngle = s.angle + orbitPhase * 2 * pi * s.speed;
      final sx = cx + cos(orbitAngle) * s.distance;
      final sy = cy + sin(orbitAngle) * s.distance;

      // Twinkle opacity
      final twinkle =
          0.4 + 0.6 * (0.5 + 0.5 * sin(twinklePhase * 2 * pi * s.twinkleSpeed + s.twinklePhase));
      final alpha = (twinkle * sparkleIntensity).clamp(0.0, 1.0);

      // Color: lerp white → accentColor
      final blendT = 0.5 + 0.5 * sin(s.twinklePhase);
      final sparkleColor = Color.lerp(Colors.white, accentColor, blendT)!
          .withValues(alpha: alpha);

      final paint = Paint()..color = sparkleColor;
      canvas.drawCircle(Offset(sx, sy), s.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) =>
      old.progress != progress ||
      old.orbitPhase != orbitPhase ||
      old.twinklePhase != twinklePhase ||
      old.sparkleIntensity != sparkleIntensity;
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _SparkleData {
  final double angle;
  final double distance;
  final double speed;
  final double twinklePhase;
  final double twinkleSpeed;
  final double size;

  const _SparkleData({
    required this.angle,
    required this.distance,
    required this.speed,
    required this.twinklePhase,
    required this.twinkleSpeed,
    required this.size,
  });
}

class _TapTarget {
  final Offset center;
  final DateTime spawnTime;
  final int lifetimeMs;
  final AnimationController ctrl;

  _TapTarget({
    required this.center,
    required this.spawnTime,
    required this.lifetimeMs,
    required this.ctrl,
  });
}

class _BurstEffect {
  final Offset center;
  final AnimationController ctrl;
  final List<_FireworkParticle> particles;

  _BurstEffect({
    required this.center,
    required this.ctrl,
    required this.particles,
  });
}

class _FireworkParticle {
  final double angle; // radians, direction of travel
  final double distance; // peak travel distance in px
  final Color color;
  final double size; // sparkle radius at peak

  _FireworkParticle({
    required this.angle,
    required this.distance,
    required this.color,
    required this.size,
  });
}

/// Firework burst painter — ported from MagicalLoadingView so star-catch
/// feedback matches the story-generation mini-game.
class _FireworkBurstPainter extends CustomPainter {
  final double progress; // 0..1
  final List<_FireworkParticle> particles;

  _FireworkBurstPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final eased = Curves.easeOutCubic.transform(progress);
    const fadeStart = 0.55;
    final opacity = progress < fadeStart
        ? 1.0
        : (1.0 - (progress - fadeStart) / (1.0 - fadeStart)).clamp(0.0, 1.0);

    for (final p in particles) {
      final gravity = progress * progress * 14.0;
      final dx = cos(p.angle) * p.distance * eased;
      final dy = sin(p.angle) * p.distance * eased + gravity;
      final pos = center + Offset(dx, dy);

      // Streak from ~55% behind current pos to current pos so each spark
      // reads as a moving sparkle, not a static dot.
      const tailFrac = 0.55;
      final tailEased = eased * tailFrac;
      final tailGravity = gravity * tailFrac * tailFrac;
      final tail = center +
          Offset(
            cos(p.angle) * p.distance * tailEased,
            sin(p.angle) * p.distance * tailEased + tailGravity,
          );
      canvas.drawLine(
        tail,
        pos,
        Paint()
          ..color = p.color.withValues(alpha: 0.45 * opacity)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );

      _drawSparkle(
          canvas, pos, p.size * (1.0 - 0.35 * progress), p.color, opacity);
    }
  }

  /// Four-point sparkle (rounded diamond cross) — visually distinct from the
  /// solid star icon used for tap targets.
  void _drawSparkle(
      Canvas canvas, Offset c, double r, Color color, double alpha) {
    if (r <= 0) return;
    final r2 = r * 0.32;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r2, c.dy - r2)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx + r2, c.dy + r2)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r2, c.dy + r2)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx - r2, c.dy - r2)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: alpha * 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha));
  }

  @override
  bool shouldRepaint(covariant _FireworkBurstPainter old) =>
      old.progress != progress || old.particles != particles;
}

// ── Minimal seeded pseudo-random (compile-time constant) ──────────────────────
//
// Used to produce deterministic sparkle layout without dart:math Random state.

class _SeededRandom {
  final int seed;

  const _SeededRandom(this.seed);

  /// Returns a value in [0.0, 1.0) for the given index.
  double nextDouble(int index) {
    // LCG with large multiplier — enough variety for ≤ 22×6 = 132 calls.
    int v = seed ^ (index * 2654435761);
    v = ((v >> 16) ^ v) * 0x45d9f3b;
    v = ((v >> 16) ^ v) * 0x45d9f3b;
    v = (v >> 16) ^ v;
    return (v.abs() % 100000) / 100000.0;
  }
}

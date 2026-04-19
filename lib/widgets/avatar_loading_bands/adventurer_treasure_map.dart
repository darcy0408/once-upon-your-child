import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/age_band_theme.dart';
import '../../utils/motion_utils.dart';

/// Adventurer (9-11) avatar loading: a parchment treasure map where an ink
/// trail draws itself across the map over the loading duration.
///
/// Four landmarks (compass rose, castle, dragon, treasure chest) appear with
/// a scale-in animation as the ink trail reaches them. Compass-rose pulse
/// points on each landmark respond to taps with haptic feedback and a burst.
class AdventurerTreasureMap extends StatefulWidget {
  final double stageSize;

  /// Loading progress from 0.0 (start) to 1.0 (complete).
  final double progress;

  /// Called when the user taps any compass-rose pulse point.
  final VoidCallback onTap;

  const AdventurerTreasureMap({
    super.key,
    required this.stageSize,
    required this.progress,
    required this.onTap,
  });

  @override
  State<AdventurerTreasureMap> createState() => _AdventurerTreasureMapState();
}

// ---------------------------------------------------------------------------
// Landmark data
// ---------------------------------------------------------------------------

enum _LandmarkKind { compassRose, castle, dragon, treasureChest }

class _Landmark {
  final _LandmarkKind kind;

  /// Position as a fraction of the map size (0.0–1.0).
  final Offset position;

  /// Progress value (0.0–1.0) at which this landmark is reached by the trail.
  final double revealAt;

  const _Landmark({
    required this.kind,
    required this.position,
    required this.revealAt,
  });
}

// ---------------------------------------------------------------------------
// Particle data
// ---------------------------------------------------------------------------

class _Particle {
  Offset pos;
  Offset vel;
  double life; // 0.0 = dead, 1.0 = fresh
  double size;
  double angle;

  _Particle({
    required this.pos,
    required this.vel,
    required this.life,
    required this.size,
    required this.angle,
  });
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _AdventurerTreasureMapState extends State<AdventurerTreasureMap>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _particleCtrl;

  // One burst controller per landmark (nullable until triggered).
  final Map<int, AnimationController> _burstCtrls = {};

  // Landmark scale animations (triggered when trail reaches them).
  final Map<int, AnimationController> _landmarkScaleCtrls = {};
  final Set<int> _landmarkRevealed = {};

  final List<_Particle> _particles = [];
  final Random _rng = Random();

  static const int _particleCount = 9;

  // The four landmarks with normalized positions and reveal thresholds.
  static const List<_Landmark> _landmarks = [
    _Landmark(
      kind: _LandmarkKind.compassRose,
      position: Offset(0.18, 0.22),
      revealAt: 0.0, // visible from the start (trail starts here)
    ),
    _Landmark(
      kind: _LandmarkKind.castle,
      position: Offset(0.72, 0.18),
      revealAt: 0.28,
    ),
    _Landmark(
      kind: _LandmarkKind.dragon,
      position: Offset(0.62, 0.68),
      revealAt: 0.56,
    ),
    _Landmark(
      kind: _LandmarkKind.treasureChest,
      position: Offset(0.22, 0.78),
      revealAt: 0.85,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _particleCtrl = AnimationController(
      duration: const Duration(milliseconds: 80),
      vsync: this,
    )..addListener(_tickParticles)
      ..repeat();

    // Landmark scale controllers (one per landmark index).
    for (int i = 0; i < _landmarks.length; i++) {
      _landmarkScaleCtrls[i] = AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      );
    }

    // Initialise particles off-screen; they'll be positioned on first tick.
    for (int i = 0; i < _particleCount; i++) {
      _particles.add(_Particle(
        pos: Offset.zero,
        vel: Offset.zero,
        life: 0.0,
        size: 2.0 + _rng.nextDouble() * 3.0,
        angle: _rng.nextDouble() * 2 * pi,
      ));
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _particleCtrl.dispose();
    for (final c in _burstCtrls.values) {
      c.dispose();
    }
    for (final c in _landmarkScaleCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // didUpdateWidget — trigger landmark reveal animations
  // ---------------------------------------------------------------------------

  @override
  void didUpdateWidget(AdventurerTreasureMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    for (int i = 0; i < _landmarks.length; i++) {
      if (!_landmarkRevealed.contains(i) &&
          widget.progress >= _landmarks[i].revealAt) {
        _landmarkRevealed.add(i);
        _landmarkScaleCtrls[i]?.forward(from: 0.0);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Particles
  // ---------------------------------------------------------------------------

  void _tickParticles() {
    if (!mounted) return;
    final mapSize = widget.stageSize;
    final tipPos = _trailTipPosition(widget.progress, mapSize);

    setState(() {
      for (final p in _particles) {
        if (p.life <= 0.0) {
          // Respawn near the ink tip with random scatter.
          p.pos = tipPos +
              Offset(
                (_rng.nextDouble() - 0.5) * 12,
                (_rng.nextDouble() - 0.5) * 12,
              );
          p.vel = Offset(
            (_rng.nextDouble() - 0.5) * 1.2,
            (_rng.nextDouble() - 0.75) * 1.4,
          );
          p.life = 0.7 + _rng.nextDouble() * 0.3;
          p.size = 2.0 + _rng.nextDouble() * 3.0;
          p.angle = _rng.nextDouble() * 2 * pi;
        } else {
          p.pos += p.vel;
          p.vel = Offset(p.vel.dx * 0.96, p.vel.dy * 0.96 + 0.04);
          p.life -= 0.04;
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Interaction
  // ---------------------------------------------------------------------------

  void _onLandmarkTap(int index) {
    HapticFeedback.lightImpact();
    widget.onTap();

    _burstCtrls[index]?.dispose();
    final burst = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    )..forward();
    _burstCtrls[index] = burst;
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final reduced = MotionPrefs.reduceMotion(context);
    final bt = Theme.of(context).extension<AgeBandThemeData>() ??
        themeForBand(AgeBand.adventurer);
    final size = widget.stageSize;
    final sparkle = MotionPrefs.sparkleIntensity(context); // ~0.3 for this band

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Parchment + static map elements ──────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: reduced
                  ? const AlwaysStoppedAnimation(0.0)
                  : _pulseCtrl,
              builder: (_, __) {
                return CustomPaint(
                  painter: _TreasureMapPainter(
                    progress: widget.progress,
                    pulsePhase: reduced ? 0.5 : _pulseCtrl.value,
                    inkColor: bt.accent,
                    landmarkColor: bt.primary,
                    landmarks: _landmarks,
                    landmarkScales: {
                      for (int i = 0; i < _landmarks.length; i++)
                        i: reduced
                            ? (widget.progress >= _landmarks[i].revealAt
                                ? 1.0
                                : 0.0)
                            : (_landmarkScaleCtrls[i]?.value ?? 0.0),
                    },
                    burstValues: {
                      for (final e in _burstCtrls.entries) e.key: e.value.value,
                    },
                    reduceMotion: reduced,
                  ),
                );
              },
            ),
          ),

          // ── Particle trail near ink tip ───────────────────────────────────
          if (!reduced && sparkle > 0.0)
            Positioned.fill(
              child: CustomPaint(
                painter: _ParticlePainter(
                  particles: _particles,
                  color: bt.accent,
                  opacity: sparkle,
                ),
              ),
            ),

          // ── Tap targets (invisible hit areas over each landmark) ──────────
          for (int i = 0; i < _landmarks.length; i++)
            _buildLandmarkTapTarget(i, size, reduced),
        ],
      ),
    );
  }

  Widget _buildLandmarkTapTarget(int index, double size, bool reduced) {
    final lm = _landmarks[index];
    final revealed = widget.progress >= lm.revealAt;
    if (!revealed) return const SizedBox.shrink();

    final cx = lm.position.dx * size;
    final cy = lm.position.dy * size;
    const hitSize = 48.0;

    return Positioned(
      left: cx - hitSize / 2,
      top: cy - hitSize / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _onLandmarkTap(index),
        child: SizedBox(width: hitSize, height: hitSize),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Trail tip position (matches the path segments in the painter)
  // ---------------------------------------------------------------------------

  Offset _trailTipPosition(double progress, double mapSize) {
    return _TreasureMapPainter.trailTipOffset(progress, mapSize);
  }
}

// ---------------------------------------------------------------------------
// CustomPainter
// ---------------------------------------------------------------------------

class _TreasureMapPainter extends CustomPainter {
  final double progress;
  final double pulsePhase;
  final Color inkColor;
  final Color landmarkColor;
  final List<_Landmark> landmarks;
  final Map<int, double> landmarkScales;
  final Map<int, double> burstValues;
  final bool reduceMotion;

  _TreasureMapPainter({
    required this.progress,
    required this.pulsePhase,
    required this.inkColor,
    required this.landmarkColor,
    required this.landmarks,
    required this.landmarkScales,
    required this.burstValues,
    required this.reduceMotion,
  });

  // ── Path definition (normalized 0–1 coordinates, scaled at paint time) ──

  /// Returns the full trail path scaled to [size].
  static Path _buildFullPath(Size size) {
    final w = size.width;
    final h = size.height;

    // 5-segment bezier path winding through the 4 landmark positions.
    // Landmark positions (normalized): compassRose(0.18,0.22), castle(0.72,0.18),
    // dragon(0.62,0.68), treasureChest(0.22,0.78).
    final path = Path();
    path.moveTo(0.18 * w, 0.22 * h);

    // Segment 1: compassRose → castle
    path.cubicTo(
      0.35 * w, 0.08 * h,
      0.55 * w, 0.10 * h,
      0.72 * w, 0.18 * h,
    );

    // Segment 2: castle → midpoint east
    path.cubicTo(
      0.88 * w, 0.28 * h,
      0.90 * w, 0.48 * h,
      0.80 * w, 0.58 * h,
    );

    // Segment 3: east → dragon
    path.cubicTo(
      0.76 * w, 0.63 * h,
      0.70 * w, 0.65 * h,
      0.62 * w, 0.68 * h,
    );

    // Segment 4: dragon → south crossing
    path.cubicTo(
      0.52 * w, 0.72 * h,
      0.40 * w, 0.70 * h,
      0.30 * w, 0.76 * h,
    );

    // Segment 5: south crossing → treasureChest
    path.cubicTo(
      0.26 * w, 0.79 * h,
      0.23 * w, 0.80 * h,
      0.22 * w, 0.78 * h,
    );

    return path;
  }

  /// Returns the position of the ink tip at the given [progress] in [mapSize].
  static Offset trailTipOffset(double progress, double mapSize) {
    if (progress <= 0.0) return Offset(0.18 * mapSize, 0.22 * mapSize);
    final size = Size(mapSize, mapSize);
    final path = _buildFullPath(size);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return Offset(0.18 * mapSize, 0.22 * mapSize);

    final totalLength = metrics.fold<double>(0, (sum, m) => sum + m.length);
    final target = (totalLength * progress.clamp(0.0, 1.0));
    double accumulated = 0;
    for (final metric in metrics) {
      if (accumulated + metric.length >= target) {
        final t = target - accumulated;
        final tangent = metric.getTangentForOffset(t.clamp(0, metric.length));
        return tangent?.position ?? Offset(0.18 * mapSize, 0.22 * mapSize);
      }
      accumulated += metric.length;
    }
    return Offset(0.22 * mapSize, 0.78 * mapSize); // end
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawParchment(canvas, size);
    _drawDecorativeElements(canvas, size);
    _drawTrail(canvas, size);
    _drawLandmarks(canvas, size);
    _drawInkTipGlow(canvas, size);
  }

  // ── Parchment background ──────────────────────────────────────────────────

  void _drawParchment(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    );

    // Main parchment fill.
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.1, -0.2),
        radius: 1.2,
        colors: const [
          Color(0xFFFAEDD4),
          Color(0xFFF5E6C8),
          Color(0xFFEDD9B0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(rrect, bgPaint);

    // Aged border.
    final borderPaint = Paint()
      ..color = const Color(0xFFD4B896)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRRect(rrect, borderPaint);

    // Inner dotted border.
    _drawDottedBorder(canvas, size);
  }

  void _drawDottedBorder(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = const Color(0xFFB89A70).withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    const inset = 8.0;
    const dotRadius = 1.8;
    const spacing = 10.0;

    // Top row
    double x = inset + spacing;
    while (x < size.width - inset) {
      canvas.drawCircle(Offset(x, inset), dotRadius, dotPaint);
      x += spacing;
    }
    // Bottom row
    x = inset + spacing;
    while (x < size.width - inset) {
      canvas.drawCircle(Offset(x, size.height - inset), dotRadius, dotPaint);
      x += spacing;
    }
    // Left column
    double y = inset + spacing;
    while (y < size.height - inset) {
      canvas.drawCircle(Offset(inset, y), dotRadius, dotPaint);
      y += spacing;
    }
    // Right column
    y = inset + spacing;
    while (y < size.height - inset) {
      canvas.drawCircle(Offset(size.width - inset, y), dotRadius, dotPaint);
      y += spacing;
    }
  }

  // ── Decorative corner compass lines ──────────────────────────────────────

  void _drawDecorativeElements(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFC4A070).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Four corner cross-hatches (compass direction lines).
    final corners = [
      Offset(20, 20),
      Offset(size.width - 20, 20),
      Offset(20, size.height - 20),
      Offset(size.width - 20, size.height - 20),
    ];
    const lineLen = 10.0;
    for (final c in corners) {
      canvas.drawLine(Offset(c.dx - lineLen, c.dy), Offset(c.dx + lineLen, c.dy), linePaint);
      canvas.drawLine(Offset(c.dx, c.dy - lineLen), Offset(c.dx, c.dy + lineLen), linePaint);
    }

    // Subtle aged texture lines (horizontal).
    final texturePaint = Paint()
      ..color = const Color(0xFFD4B896).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 1; i < 8; i++) {
      final y = size.height * i / 8.0;
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), texturePaint);
    }
  }

  // ── Ink trail ─────────────────────────────────────────────────────────────

  void _drawTrail(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final fullPath = _buildFullPath(size);
    final metrics = fullPath.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final totalLength = metrics.fold<double>(0, (sum, m) => sum + m.length);
    final drawLength = totalLength * progress.clamp(0.0, 1.0);

    // Build the partial path.
    final partialPath = Path();
    double accumulated = 0;
    for (final metric in metrics) {
      final remaining = drawLength - accumulated;
      if (remaining <= 0) break;
      final segLen = remaining.clamp(0.0, metric.length);
      partialPath.addPath(
        metric.extractPath(0, segLen),
        Offset.zero,
      );
      accumulated += metric.length;
      if (accumulated >= drawLength) break;
    }

    // Draw a thin shadow first for parchment depth.
    final shadowPaint = Paint()
      ..color = const Color(0xFF8B6914).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(partialPath, shadowPaint);

    // Main ink stroke.
    final inkPaint = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(partialPath, inkPaint);
  }

  // ── Landmark icons ────────────────────────────────────────────────────────

  void _drawLandmarks(Canvas canvas, Size size) {
    for (int i = 0; i < landmarks.length; i++) {
      final lm = landmarks[i];
      final scale = landmarkScales[i] ?? 0.0;
      if (scale <= 0.0) continue;

      final cx = lm.position.dx * size.width;
      final cy = lm.position.dy * size.height;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(scale, scale);

      switch (lm.kind) {
        case _LandmarkKind.compassRose:
          _drawCompassRose(canvas, size, i);
          break;
        case _LandmarkKind.castle:
          _drawCastle(canvas);
          break;
        case _LandmarkKind.dragon:
          _drawDragon(canvas);
          break;
        case _LandmarkKind.treasureChest:
          _drawTreasureChest(canvas);
          break;
      }

      canvas.restore();
    }
  }

  void _drawCompassRose(Canvas canvas, Size size, int index) {
    final burstVal = burstValues[index] ?? 0.0;

    // Pulsing glow ring.
    final pulseRadius = reduceMotion
        ? 14.0
        : 10.0 + pulsePhase * 6.0 + burstVal * 10.0;
    final pulseAlpha = reduceMotion
        ? 0.0
        : (0.35 + pulsePhase * 0.2) * (1 - burstVal * 0.5);

    if (!reduceMotion) {
      final pulsePaint = Paint()
        ..color = inkColor.withValues(alpha: pulseAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(Offset.zero, pulseRadius, pulsePaint);
    } else {
      // Static border for reduced motion.
      final staticPaint = Paint()
        ..color = inkColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset.zero, 14.0, staticPaint);
    }

    // Burst rings on tap.
    if (!reduceMotion && burstVal > 0.0) {
      final burstRadius = 14.0 + burstVal * 20.0;
      final burstPaint = Paint()
        ..color = inkColor.withValues(alpha: (1.0 - burstVal) * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1 - burstVal);
      canvas.drawCircle(Offset.zero, burstRadius, burstPaint);
    }

    // Icon background circle.
    final bgPaint = Paint()..color = landmarkColor.withValues(alpha: 0.15);
    canvas.drawCircle(Offset.zero, 12.0, bgPaint);

    // Compass rose — 4 cardinal direction points.
    final rosePaint = Paint()
      ..color = landmarkColor
      ..style = PaintingStyle.fill;
    final roseStroke = Paint()
      ..color = landmarkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    // N/S/E/W arrow points.
    const r = 9.0;
    const inner = 3.5;
    for (int d = 0; d < 4; d++) {
      final angle = d * pi / 2 - pi / 2; // start North
      final tipX = cos(angle) * r;
      final tipY = sin(angle) * r;
      final lX = cos(angle + pi / 2) * inner;
      final lY = sin(angle + pi / 2) * inner;
      final rX = cos(angle - pi / 2) * inner;
      final rY = sin(angle - pi / 2) * inner;
      final arrowPath = Path()
        ..moveTo(tipX, tipY)
        ..lineTo(lX, lY)
        ..lineTo(rX, rY)
        ..close();
      canvas.drawPath(arrowPath, d == 0 ? rosePaint : rosePaint..color = landmarkColor.withValues(alpha: 0.5));
    }
    // Centre dot.
    canvas.drawCircle(Offset.zero, 2.5, rosePaint..color = landmarkColor);
    canvas.drawLine(const Offset(0, -r), const Offset(0, r), roseStroke);
    canvas.drawLine(const Offset(-r, 0), const Offset(r, 0), roseStroke);
  }

  void _drawCastle(Canvas canvas) {
    final paint = Paint()
      ..color = landmarkColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = landmarkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Background circle.
    canvas.drawCircle(Offset.zero, 12.0, Paint()..color = landmarkColor.withValues(alpha: 0.12));

    // Tower base.
    const tw = 14.0;
    const th = 10.0;
    canvas.drawRect(Rect.fromCenter(center: const Offset(0, 2), width: tw, height: th), paint);

    // Battlements — 3 merlons.
    const mw = 3.5;
    const mh = 3.5;
    for (int i = 0; i < 3; i++) {
      final x = -tw / 2 + mw / 2 + i * (tw / 3);
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, -th / 2 - mh / 2 + 2), width: mw, height: mh),
        paint,
      );
    }

    // Gate archway.
    final gatePaint = Paint()..color = const Color(0xFFF5E6C8);
    final gateRect = Rect.fromCenter(center: const Offset(0, 5), width: 5.0, height: 6.0);
    canvas.drawArc(gateRect, pi, pi, true, gatePaint);
    canvas.drawRect(
      Rect.fromLTWH(gateRect.left, gateRect.center.dy, gateRect.width, gateRect.height / 2),
      gatePaint,
    );

    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, 2), width: tw, height: th),
      strokePaint,
    );
  }

  void _drawDragon(Canvas canvas) {
    final paint = Paint()
      ..color = landmarkColor
      ..style = PaintingStyle.fill;

    // Background circle.
    canvas.drawCircle(Offset.zero, 12.0, Paint()..color = landmarkColor.withValues(alpha: 0.12));

    // Dragon body (simplified silhouette with paths).
    final body = Path()
      ..moveTo(-8, 4)
      ..cubicTo(-6, -2, -2, -6, 4, -4)
      ..cubicTo(8, -2, 9, 2, 8, 5)
      ..cubicTo(6, 8, 2, 8, -2, 7)
      ..cubicTo(-5, 6, -8, 6, -8, 4)
      ..close();
    canvas.drawPath(body, paint);

    // Head.
    final head = Path()
      ..moveTo(5, -3)
      ..cubicTo(8, -6, 11, -5, 11, -2)
      ..cubicTo(11, 0, 8, 2, 5, 1)
      ..close();
    canvas.drawPath(head, paint);

    // Wing.
    final wing = Path()
      ..moveTo(-1, -2)
      ..lineTo(-6, -9)
      ..lineTo(-2, -6)
      ..lineTo(0, -9)
      ..lineTo(2, -5)
      ..lineTo(4, -4)
      ..close();
    canvas.drawPath(wing, paint..color = landmarkColor.withValues(alpha: 0.7));

    // Tail curl.
    final tailPaint = Paint()
      ..color = landmarkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final tail = Path()
      ..moveTo(-7, 5)
      ..cubicTo(-10, 7, -11, 9, -9, 10)
      ..cubicTo(-7, 11, -6, 10, -7, 8);
    canvas.drawPath(tail, tailPaint);

    // Eye dot.
    canvas.drawCircle(const Offset(8.5, -3), 1.2,
        Paint()..color = const Color(0xFFF5E6C8));
  }

  void _drawTreasureChest(Canvas canvas) {
    final paint = Paint()
      ..color = landmarkColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = landmarkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final goldPaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.fill;

    // Background circle.
    canvas.drawCircle(Offset.zero, 12.0, Paint()..color = landmarkColor.withValues(alpha: 0.12));

    const w = 16.0;
    const h = 10.0;

    // Chest base.
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, 3), width: w, height: h),
      paint,
    );

    // Chest lid (rounded top).
    final lidRect = Rect.fromCenter(center: const Offset(0, -3), width: w, height: 6.0);
    canvas.drawArc(lidRect, pi, pi, true, paint);
    canvas.drawRect(Rect.fromLTWH(-w / 2, -3, w, 3), paint);

    // Gold band across middle.
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, -0.5), width: w, height: 2.5),
      goldPaint,
    );

    // Lock.
    canvas.drawCircle(const Offset(0, -0.5), 2.5, goldPaint);
    canvas.drawCircle(const Offset(0, -0.5), 2.5, strokePaint..color = landmarkColor.withValues(alpha: 0.5));

    // Outline.
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, 3), width: w, height: h),
      strokePaint..color = landmarkColor,
    );
    canvas.drawArc(lidRect, pi, pi, true, strokePaint..color = landmarkColor);
    canvas.drawLine(const Offset(-w / 2, -3), const Offset(w / 2, -3), strokePaint);
  }

  // ── Ink tip glow ──────────────────────────────────────────────────────────

  void _drawInkTipGlow(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final tip = trailTipOffset(progress, size.width);

    // Soft radial glow.
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          inkColor.withValues(alpha: 0.55),
          inkColor.withValues(alpha: 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCenter(center: tip, width: 24, height: 24))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(tip, 12, glowPaint);

    // Bright centre dot.
    canvas.drawCircle(
      tip,
      3.0,
      Paint()..color = inkColor.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_TreasureMapPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulsePhase != pulsePhase ||
        oldDelegate.landmarkScales != landmarkScales ||
        oldDelegate.burstValues != burstValues;
  }
}

// ---------------------------------------------------------------------------
// Particle painter
// ---------------------------------------------------------------------------

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Color color;
  final double opacity;

  _ParticlePainter({
    required this.particles,
    required this.color,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.life <= 0.0) continue;
      final alpha = (p.life * opacity * 0.8).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(p.pos.dx, p.pos.dy);
      canvas.rotate(p.angle);
      // Small diamond / sparkle shape.
      final s = p.size * p.life;
      final path = Path()
        ..moveTo(0, -s)
        ..lineTo(s * 0.4, 0)
        ..lineTo(0, s)
        ..lineTo(-s * 0.4, 0)
        ..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}

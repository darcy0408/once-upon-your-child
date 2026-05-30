import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/age_band_theme.dart';
import '../../utils/motion_utils.dart';

/// Adventurer (9-11) avatar loading: a richly coloured treasure map where a
/// glowing amber trail draws itself through terrain zones (sea, forest,
/// mountains) as four landmarks appear with burst animations.
class AdventurerTreasureMap extends StatefulWidget {
  final double stageSize;
  final double progress;
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

enum _LandmarkKind { compassRose, castle, dragon, treasureChest }

class _Landmark {
  final _LandmarkKind kind;
  final Offset position;
  final double revealAt;
  const _Landmark({required this.kind, required this.position, required this.revealAt});
}

class _Particle {
  Offset pos;
  Offset vel;
  double life;
  double size;
  double angle;
  Color color;
  _Particle({required this.pos, required this.vel, required this.life, required this.size, required this.angle, required this.color});
}

class _AdventurerTreasureMapState extends State<AdventurerTreasureMap>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _particleCtrl;

  final Map<int, AnimationController> _burstCtrls = {};
  final Map<int, AnimationController> _landmarkScaleCtrls = {};
  final Set<int> _landmarkRevealed = {};

  final List<_Particle> _particles = [];
  final Random _rng = Random();

  static const int _particleCount = 18;
  static const _particleColors = [
    Color(0xFFFFD54F), // gold
    Color(0xFFFFAB40), // amber
    Color(0xFFFF8F00), // deep amber
    Color(0xFFFFECB3), // pale gold
  ];

  static const List<_Landmark> _landmarks = [
    _Landmark(kind: _LandmarkKind.compassRose, position: Offset(0.18, 0.22), revealAt: 0.0),
    _Landmark(kind: _LandmarkKind.castle, position: Offset(0.72, 0.18), revealAt: 0.28),
    _Landmark(kind: _LandmarkKind.dragon, position: Offset(0.62, 0.68), revealAt: 0.56),
    _Landmark(kind: _LandmarkKind.treasureChest, position: Offset(0.22, 0.78), revealAt: 0.85),
  ];

  @override
  void initState() {
    super.initState();

    // Looping controllers; repeats are started in didChangeDependencies so
    // MotionPrefs.reduceMotion is honored at runtime (A11Y-007 sweep). The
    // particle controller's listener is attached here either way so a
    // settings change while alive will start ticking the particles again.
    _pulseCtrl = AnimationController(duration: const Duration(milliseconds: 1600), vsync: this);

    _shimmerCtrl = AnimationController(duration: const Duration(milliseconds: 2400), vsync: this);

    _particleCtrl = AnimationController(duration: const Duration(milliseconds: 80), vsync: this)
      ..addListener(_tickParticles);

    for (int i = 0; i < _landmarks.length; i++) {
      _landmarkScaleCtrls[i] = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );
    }

    for (int i = 0; i < _particleCount; i++) {
      _particles.add(_Particle(
        pos: Offset.zero,
        vel: Offset.zero,
        life: 0.0,
        size: 2.5 + _rng.nextDouble() * 4.0,
        angle: _rng.nextDouble() * 2 * pi,
        color: _particleColors[_rng.nextInt(_particleColors.length)],
      ));
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _particleCtrl.dispose();
    for (final c in _burstCtrls.values) { c.dispose(); }
    for (final c in _landmarkScaleCtrls.values) { c.dispose(); }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPrefs.reduceMotion(context)) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0.5;
      _shimmerCtrl.stop();
      _shimmerCtrl.value = 0.0;
      _particleCtrl.stop();
      _particleCtrl.value = 0.0;
    } else {
      if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
      if (!_shimmerCtrl.isAnimating) _shimmerCtrl.repeat();
      if (!_particleCtrl.isAnimating) _particleCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(AdventurerTreasureMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (int i = 0; i < _landmarks.length; i++) {
      if (!_landmarkRevealed.contains(i) && widget.progress >= _landmarks[i].revealAt) {
        _landmarkRevealed.add(i);
        _landmarkScaleCtrls[i]?.forward(from: 0.0);
        HapticFeedback.lightImpact();
      }
    }
  }

  void _tickParticles() {
    if (!mounted) return;
    final mapSize = widget.stageSize;
    final tipPos = _TreasureMapPainter.trailTipOffset(widget.progress, mapSize);

    setState(() {
      for (final p in _particles) {
        if (p.life <= 0.0) {
          p.pos = tipPos + Offset((_rng.nextDouble() - 0.5) * 10, (_rng.nextDouble() - 0.5) * 10);
          p.vel = Offset((_rng.nextDouble() - 0.5) * 1.6, (_rng.nextDouble() - 0.85) * 1.8);
          p.life = 0.6 + _rng.nextDouble() * 0.4;
          p.size = 2.5 + _rng.nextDouble() * 4.0;
          p.angle = _rng.nextDouble() * 2 * pi;
          p.color = _particleColors[_rng.nextInt(_particleColors.length)];
        } else {
          p.pos += p.vel;
          p.vel = Offset(p.vel.dx * 0.95, p.vel.dy * 0.95 + 0.05);
          p.life -= 0.035;
        }
      }
    });
  }

  void _onLandmarkTap(int index) {
    HapticFeedback.mediumImpact();
    widget.onTap();
    _burstCtrls[index]?.dispose();
    final burst = AnimationController(duration: const Duration(milliseconds: 400), vsync: this)
      ..forward();
    _burstCtrls[index] = burst;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MotionPrefs.reduceMotion(context);
    final bt = Theme.of(context).extension<AgeBandThemeData>() ?? themeForBand(AgeBand.adventurer);
    final size = widget.stageSize;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: reduced
                  ? const AlwaysStoppedAnimation(0.0)
                  : Listenable.merge([_pulseCtrl, _shimmerCtrl]),
              builder: (_, __) {
                return CustomPaint(
                  painter: _TreasureMapPainter(
                    progress: widget.progress,
                    pulsePhase: reduced ? 0.5 : _pulseCtrl.value,
                    shimmerPhase: reduced ? 0.0 : _shimmerCtrl.value,
                    inkColor: const Color(0xFFFFAB40), // glowing amber trail
                    landmarkColor: bt.primary,
                    landmarks: _landmarks,
                    landmarkScales: {
                      for (int i = 0; i < _landmarks.length; i++)
                        i: reduced
                            ? (widget.progress >= _landmarks[i].revealAt ? 1.0 : 0.0)
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

          // Particle trail near ink tip
          if (!reduced)
            Positioned.fill(
              child: CustomPaint(
                painter: _ParticlePainter(particles: _particles),
              ),
            ),

          // Tap targets over each landmark
          for (int i = 0; i < _landmarks.length; i++)
            _buildLandmarkTapTarget(i, size, reduced),
        ],
      ),
    );
  }

  Widget _buildLandmarkTapTarget(int index, double size, bool reduced) {
    final lm = _landmarks[index];
    if (widget.progress < lm.revealAt) return const SizedBox.shrink();
    final cx = lm.position.dx * size;
    final cy = lm.position.dy * size;
    const hitSize = 52.0;
    return Positioned(
      left: cx - hitSize / 2,
      top: cy - hitSize / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _onLandmarkTap(index),
        child: const SizedBox(width: hitSize, height: hitSize),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CustomPainter
// ---------------------------------------------------------------------------

class _TreasureMapPainter extends CustomPainter {
  final double progress;
  final double pulsePhase;
  final double shimmerPhase;
  final Color inkColor;
  final Color landmarkColor;
  final List<_Landmark> landmarks;
  final Map<int, double> landmarkScales;
  final Map<int, double> burstValues;
  final bool reduceMotion;

  _TreasureMapPainter({
    required this.progress,
    required this.pulsePhase,
    required this.shimmerPhase,
    required this.inkColor,
    required this.landmarkColor,
    required this.landmarks,
    required this.landmarkScales,
    required this.burstValues,
    required this.reduceMotion,
  });

  static Path _buildFullPath(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(0.18 * w, 0.22 * h);
    path.cubicTo(0.35 * w, 0.08 * h, 0.55 * w, 0.10 * h, 0.72 * w, 0.18 * h);
    path.cubicTo(0.88 * w, 0.28 * h, 0.90 * w, 0.48 * h, 0.80 * w, 0.58 * h);
    path.cubicTo(0.76 * w, 0.63 * h, 0.70 * w, 0.65 * h, 0.62 * w, 0.68 * h);
    path.cubicTo(0.52 * w, 0.72 * h, 0.40 * w, 0.70 * h, 0.30 * w, 0.76 * h);
    path.cubicTo(0.26 * w, 0.79 * h, 0.23 * w, 0.80 * h, 0.22 * w, 0.78 * h);
    return path;
  }

  static Offset trailTipOffset(double progress, double mapSize) {
    if (progress <= 0.0) return Offset(0.18 * mapSize, 0.22 * mapSize);
    final size = Size(mapSize, mapSize);
    final path = _buildFullPath(size);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return Offset(0.18 * mapSize, 0.22 * mapSize);
    final totalLength = metrics.fold<double>(0, (sum, m) => sum + m.length);
    final target = totalLength * progress.clamp(0.0, 1.0);
    double accumulated = 0;
    for (final metric in metrics) {
      if (accumulated + metric.length >= target) {
        final t = (target - accumulated).clamp(0.0, metric.length);
        final tangent = metric.getTangentForOffset(t);
        return tangent?.position ?? Offset(0.18 * mapSize, 0.22 * mapSize);
      }
      accumulated += metric.length;
    }
    return Offset(0.22 * mapSize, 0.78 * mapSize);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawTerrainZones(canvas, size);
    _drawDecorativeElements(canvas, size);
    _drawTrail(canvas, size);
    _drawLandmarks(canvas, size);
    _drawInkTipGlow(canvas, size);
    _drawVignette(canvas, size);
  }

  // ── Rich parchment background ─────────────────────────────────────────────

  void _drawBackground(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(18),
    );

    // Richly aged parchment — warm amber-brown gradient
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.1, -0.15),
        radius: 1.3,
        colors: const [
          Color(0xFFF5D99A), // warm gold-parchment centre
          Color(0xFFE8C07A), // medium amber
          Color(0xFFD4A055), // deep burnt sienna edges
          Color(0xFFC08840), // dark aged corner
        ],
        stops: const [0.0, 0.45, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(rrect, bgPaint);

    // Aged outer border — double stroke
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFF7A4F1A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
        const Radius.circular(14),
      ),
      Paint()
        ..color = const Color(0xFF9B6D2A).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Horizontal age lines for texture
    final texturePaint = Paint()
      ..color = const Color(0xFF8B5E20).withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (int i = 1; i < 12; i++) {
      final y = size.height * i / 12.0;
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), texturePaint);
    }
  }

  // ── Coloured terrain zones ────────────────────────────────────────────────

  void _drawTerrainZones(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sea / ocean in the top-right and bottom-left — translucent teal-blue
    final seaPaint = Paint()
      ..color = const Color(0xFF1565C0).withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    // Top-right sea blob
    final seaTopRight = Path()
      ..moveTo(w * 0.85, 0.05 * h)
      ..cubicTo(w * 0.95, 0.08 * h, w * 0.97, 0.22 * h, w * 0.92, 0.35 * h)
      ..cubicTo(w * 0.88, 0.42 * h, w * 0.78, 0.38 * h, w * 0.80, 0.28 * h)
      ..cubicTo(w * 0.82, 0.18 * h, w * 0.75, 0.10 * h, w * 0.85, 0.05 * h)
      ..close();
    canvas.drawPath(seaTopRight, seaPaint);

    // Bottom-left sea blob
    final seaBottomLeft = Path()
      ..moveTo(0.03 * w, 0.75 * h)
      ..cubicTo(0.02 * w, 0.85 * h, 0.10 * w, 0.96 * h, 0.22 * w, 0.94 * h)
      ..cubicTo(0.32 * w, 0.92 * h, 0.30 * w, 0.84 * h, 0.20 * w, 0.82 * h)
      ..cubicTo(0.12 * w, 0.80 * h, 0.06 * w, 0.72 * h, 0.03 * w, 0.75 * h)
      ..close();
    canvas.drawPath(seaBottomLeft, seaPaint);

    // Draw wave lines inside sea areas
    final wavePaint = Paint()
      ..color = const Color(0xFF1565C0).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    // Waves top-right
    for (int i = 0; i < 3; i++) {
      final yBase = (0.12 + i * 0.07) * h;
      final waveP = Path()..moveTo(0.82 * w, yBase);
      waveP.cubicTo(0.86 * w, yBase - 3, 0.90 * w, yBase + 3, 0.94 * w, yBase);
      canvas.drawPath(waveP, wavePaint);
    }

    // Forest in the centre-left — translucent green
    final forestPaint = Paint()
      ..color = const Color(0xFF2E7D32).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final forestBlob = Path()
      ..moveTo(0.28 * w, 0.38 * h)
      ..cubicTo(0.20 * w, 0.35 * h, 0.12 * w, 0.42 * h, 0.14 * w, 0.52 * h)
      ..cubicTo(0.16 * w, 0.62 * h, 0.26 * w, 0.66 * h, 0.35 * w, 0.62 * h)
      ..cubicTo(0.44 * w, 0.58 * h, 0.46 * w, 0.48 * h, 0.40 * w, 0.42 * h)
      ..cubicTo(0.36 * w, 0.38 * h, 0.32 * w, 0.36 * h, 0.28 * w, 0.38 * h)
      ..close();
    canvas.drawPath(forestBlob, forestPaint);

    // Draw tiny tree dots in forest
    final treePaint = Paint()
      ..color = const Color(0xFF1B5E20).withValues(alpha: 0.30)
      ..style = PaintingStyle.fill;
    final treeDots = [
      Offset(0.22 * w, 0.46 * h), Offset(0.28 * w, 0.52 * h),
      Offset(0.34 * w, 0.44 * h), Offset(0.38 * w, 0.54 * h),
      Offset(0.25 * w, 0.58 * h), Offset(0.32 * w, 0.60 * h),
    ];
    for (final pt in treeDots) {
      // Small triangle tree
      final tree = Path()
        ..moveTo(pt.dx, pt.dy - 5)
        ..lineTo(pt.dx - 4, pt.dy + 3)
        ..lineTo(pt.dx + 4, pt.dy + 3)
        ..close();
      canvas.drawPath(tree, treePaint);
    }

    // Mountains in the centre-right — translucent brown with hatching
    final mountainPaint = Paint()
      ..color = const Color(0xFF5D4037).withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final mountainPeaks = [
      [Offset(0.46 * w, 0.46 * h), Offset(0.38 * w, 0.62 * h), Offset(0.54 * w, 0.62 * h)],
      [Offset(0.55 * w, 0.40 * h), Offset(0.46 * w, 0.56 * h), Offset(0.64 * w, 0.56 * h)],
      [Offset(0.50 * w, 0.32 * h), Offset(0.44 * w, 0.46 * h), Offset(0.56 * w, 0.46 * h)],
    ];
    for (final pts in mountainPeaks) {
      final mountainPath = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (final pt in pts.skip(1)) {
        mountainPath.lineTo(pt.dx, pt.dy);
      }
      mountainPath.close();
      canvas.drawPath(mountainPath, mountainPaint);
      // Snow cap
      final snowPaint = Paint()..color = Colors.white.withValues(alpha: 0.35);
      final snowPath = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[0].dx - 5, pts[0].dy + 8)
        ..lineTo(pts[0].dx + 5, pts[0].dy + 8)
        ..close();
      canvas.drawPath(snowPath, snowPaint);
    }
  }

  // ── Decorative map elements ───────────────────────────────────────────────

  void _drawDecorativeElements(Canvas canvas, Size size) {
    // Inner dotted border
    final dotPaint = Paint()
      ..color = const Color(0xFF7A4F1A).withValues(alpha: 0.40)
      ..style = PaintingStyle.fill;
    const inset = 9.0;
    const dotR = 1.8;
    const spacing = 10.0;
    double x = inset + spacing;
    while (x < size.width - inset) {
      canvas.drawCircle(Offset(x, inset), dotR, dotPaint);
      canvas.drawCircle(Offset(x, size.height - inset), dotR, dotPaint);
      x += spacing;
    }
    double y = inset + spacing;
    while (y < size.height - inset) {
      canvas.drawCircle(Offset(inset, y), dotR, dotPaint);
      canvas.drawCircle(Offset(size.width - inset, y), dotR, dotPaint);
      y += spacing;
    }

    // "N" cardinal label near top of compass rose
    _drawCardinalLabel(canvas, Offset(0.18 * size.width, 0.07 * size.height), 'N', size);

    // "Here Be Dragons" text label near dragon landmark
    _drawMapLabel(canvas, Offset(0.72 * size.width, 0.56 * size.height), 'Here be\ndragons!', size);
  }

  void _drawCardinalLabel(Canvas canvas, Offset position, String text, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF5D3A0A).withValues(alpha: 0.60),
          fontSize: size.width * 0.055,
          fontWeight: FontWeight.bold,
          fontFamily: 'serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, position - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawMapLabel(Canvas canvas, Offset position, String text, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF5D3A0A).withValues(alpha: 0.35),
          fontSize: size.width * 0.038,
          fontStyle: FontStyle.italic,
          fontFamily: 'serif',
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.25);
    tp.paint(canvas, position - Offset(tp.width / 2, tp.height / 2));
  }

  // ── Glowing amber trail ───────────────────────────────────────────────────

  void _drawTrail(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final fullPath = _buildFullPath(size);
    final metrics = fullPath.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final totalLength = metrics.fold<double>(0, (sum, m) => sum + m.length);
    final drawLength = totalLength * progress.clamp(0.0, 1.0);

    final partialPath = Path();
    double accumulated = 0;
    for (final metric in metrics) {
      final remaining = drawLength - accumulated;
      if (remaining <= 0) break;
      final segLen = remaining.clamp(0.0, metric.length);
      partialPath.addPath(metric.extractPath(0, segLen), Offset.zero);
      accumulated += metric.length;
      if (accumulated >= drawLength) break;
    }

    // Outer soft glow
    canvas.drawPath(
      partialPath,
      Paint()
        ..color = inkColor.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Mid glow
    canvas.drawPath(
      partialPath,
      Paint()
        ..color = inkColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Drop shadow for depth on parchment
    canvas.drawPath(
      partialPath,
      Paint()
        ..color = const Color(0xFF4E2800).withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Main bright stroke
    canvas.drawPath(
      partialPath,
      Paint()
        ..color = inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    // Bright inner highlight streak
    canvas.drawPath(
      partialPath,
      Paint()
        ..color = const Color(0xFFFFECB3).withValues(alpha: 0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
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
          _drawCompassRose(canvas, i);
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

  void _drawCompassRose(Canvas canvas, int index) {
    final burstVal = burstValues[index] ?? 0.0;

    // Outer glowing ring
    if (!reduceMotion) {
      final pulseRadius = 16.0 + pulsePhase * 8.0 + burstVal * 12.0;
      canvas.drawCircle(
        Offset.zero,
        pulseRadius,
        Paint()
          ..color = const Color(0xFFFF8F00).withValues(alpha: (0.25 + pulsePhase * 0.15) * (1 - burstVal * 0.4))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // Burst ring on tap
    if (!reduceMotion && burstVal > 0.0) {
      canvas.drawCircle(
        Offset.zero,
        16.0 + burstVal * 28.0,
        Paint()
          ..color = const Color(0xFFFF8F00).withValues(alpha: (1.0 - burstVal) * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - burstVal),
      );
    }

    // Background disc
    canvas.drawCircle(Offset.zero, 14.0, Paint()..color = const Color(0xFF1A237E).withValues(alpha: 0.20));
    canvas.drawCircle(
      Offset.zero,
      14.0,
      Paint()
        ..color = const Color(0xFF1A237E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Compass rose — 8-point star
    final roseFill = Paint()..color = const Color(0xFF1A237E)..style = PaintingStyle.fill;
    final roseAccent = Paint()..color = const Color(0xFFFF8F00)..style = PaintingStyle.fill;
    const r = 11.0;
    const inner = 4.5;
    const diagR = 8.0;
    const diagInner = 3.0;
    // Cardinal 4 points (N/S/E/W) — larger
    for (int d = 0; d < 4; d++) {
      final angle = d * pi / 2 - pi / 2;
      final tip = Offset(cos(angle) * r, sin(angle) * r);
      final lPt = Offset(cos(angle + pi / 2) * inner, sin(angle + pi / 2) * inner);
      final rPt = Offset(cos(angle - pi / 2) * inner, sin(angle - pi / 2) * inner);
      final arrow = Path()..moveTo(tip.dx, tip.dy)..lineTo(lPt.dx, lPt.dy)..lineTo(rPt.dx, rPt.dy)..close();
      canvas.drawPath(arrow, d == 0 ? roseAccent : roseFill); // North = amber
    }
    // Diagonal 4 points (NE/SE/SW/NW) — smaller
    for (int d = 0; d < 4; d++) {
      final angle = d * pi / 2 - pi / 4;
      final tip = Offset(cos(angle) * diagR, sin(angle) * diagR);
      final lPt = Offset(cos(angle + pi / 2) * diagInner, sin(angle + pi / 2) * diagInner);
      final rPt = Offset(cos(angle - pi / 2) * diagInner, sin(angle - pi / 2) * diagInner);
      final arrow = Path()..moveTo(tip.dx, tip.dy)..lineTo(lPt.dx, lPt.dy)..lineTo(rPt.dx, rPt.dy)..close();
      canvas.drawPath(arrow, roseFill);
    }
    // Centre circle
    canvas.drawCircle(Offset.zero, 3.5, Paint()..color = const Color(0xFFFF8F00));
    canvas.drawCircle(Offset.zero, 3.5, Paint()..color = const Color(0xFF1A237E)..style = PaintingStyle.stroke..strokeWidth = 1.0);
    // N label
    final nTp = TextPainter(
      text: const TextSpan(text: 'N', style: TextStyle(color: Color(0xFF1A237E), fontSize: 5, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    nTp.paint(canvas, Offset(-nTp.width / 2, -r - nTp.height - 1));
  }

  void _drawCastle(Canvas canvas) {
    const tealBase = Color(0xFF1A237E);

    // Glow disc
    canvas.drawCircle(Offset.zero, 16.0, Paint()..color = tealBase.withValues(alpha: 0.15));
    canvas.drawCircle(
      Offset.zero,
      16.0,
      Paint()..color = tealBase.withValues(alpha: 0.50)..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );

    final fill = Paint()..color = tealBase..style = PaintingStyle.fill;
    final stroke = Paint()..color = tealBase..style = PaintingStyle.stroke..strokeWidth = 1.0;
    final gateFill = Paint()..color = const Color(0xFFF5D99A); // parchment inside gate

    // Left tower
    canvas.drawRect(Rect.fromCenter(center: const Offset(-8, 1), width: 8, height: 14), fill);
    // Right tower
    canvas.drawRect(Rect.fromCenter(center: const Offset(8, 1), width: 8, height: 14), fill);
    // Main wall connecting towers
    canvas.drawRect(Rect.fromLTWH(-4, -4, 8, 12), fill);

    // Battlements — 3 per tower
    for (final tx in [-8.0, 8.0]) {
      for (int m = 0; m < 3; m++) {
        final bx = tx - 3.0 + m * 3.0;
        canvas.drawRect(Rect.fromCenter(center: Offset(bx, -7), width: 2.5, height: 3.5), fill);
      }
    }
    // Wall battlements
    for (int m = 0; m < 2; m++) {
      canvas.drawRect(Rect.fromCenter(center: Offset(-2.5 + m * 5.0, -7), width: 2.5, height: 3.5), fill);
    }

    // Gate arch
    final gateRect = Rect.fromCenter(center: const Offset(0, 4), width: 6, height: 7);
    canvas.drawArc(gateRect, pi, pi, true, gateFill);
    canvas.drawRect(Rect.fromLTWH(-3, 4, 6, 4), gateFill);

    // Windows in towers
    canvas.drawRect(Rect.fromCenter(center: const Offset(-8, 0), width: 3, height: 4), gateFill);
    canvas.drawRect(Rect.fromCenter(center: const Offset(8, 0), width: 3, height: 4), gateFill);

    // Outline
    canvas.drawRect(Rect.fromCenter(center: const Offset(-8, 1), width: 8, height: 14), stroke);
    canvas.drawRect(Rect.fromCenter(center: const Offset(8, 1), width: 8, height: 14), stroke);
  }

  void _drawDragon(Canvas canvas) {
    // Glow disc
    canvas.drawCircle(Offset.zero, 16.0, Paint()..color = const Color(0xFF7B1FA2).withValues(alpha: 0.15));
    canvas.drawCircle(
      Offset.zero,
      16.0,
      Paint()..color = const Color(0xFF7B1FA2).withValues(alpha: 0.50)..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );

    final bodyPaint = Paint()..color = const Color(0xFF4A148C)..style = PaintingStyle.fill;
    final scalePaint = Paint()..color = const Color(0xFF7B1FA2).withValues(alpha: 0.6)..style = PaintingStyle.fill;
    final firePaint = Paint()..color = const Color(0xFFFF6D00)..style = PaintingStyle.fill;

    // Body
    final body = Path()
      ..moveTo(-10, 5)
      ..cubicTo(-7, -3, -2, -8, 5, -5)
      ..cubicTo(10, -2, 11, 3, 10, 6)
      ..cubicTo(7, 10, 2, 10, -3, 9)
      ..cubicTo(-6, 8, -10, 7, -10, 5)
      ..close();
    canvas.drawPath(body, bodyPaint);

    // Head
    final head = Path()
      ..moveTo(6, -4)
      ..cubicTo(10, -8, 14, -6, 13, -2)
      ..cubicTo(13, 1, 10, 3, 6, 2)
      ..close();
    canvas.drawPath(head, bodyPaint);

    // Snout / jaw
    final jaw = Path()
      ..moveTo(9, 0)
      ..cubicTo(12, 0, 14, 2, 13, 3)
      ..cubicTo(11, 4, 9, 3, 9, 2)
      ..close();
    canvas.drawPath(jaw, scalePaint);

    // Fire breath
    final fire = Path()
      ..moveTo(13, 1)
      ..cubicTo(17, -2, 18, 3, 16, 4)
      ..cubicTo(14, 5, 13, 3, 13, 1)
      ..close();
    canvas.drawPath(fire, firePaint);

    // Wing
    final wing = Path()
      ..moveTo(-2, -3)
      ..lineTo(-8, -12)
      ..lineTo(-3, -8)
      ..lineTo(-1, -13)
      ..lineTo(3, -7)
      ..lineTo(5, -5)
      ..close();
    canvas.drawPath(wing, scalePaint);

    // Tail
    canvas.drawPath(
      Path()
        ..moveTo(-9, 6)
        ..cubicTo(-13, 9, -15, 11, -12, 13)
        ..cubicTo(-10, 14, -8, 12, -9, 10),
      Paint()..color = const Color(0xFF4A148C)..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round,
    );

    // Eye
    canvas.drawCircle(const Offset(10, -4), 1.8, Paint()..color = const Color(0xFFFF6D00));
    canvas.drawCircle(const Offset(10, -4), 1.8, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 0.7);
  }

  void _drawTreasureChest(Canvas canvas) {
    // Glow disc — gold if near end
    final glowColor = progress >= 0.85 ? const Color(0xFFFFD700) : const Color(0xFF4E342E);
    canvas.drawCircle(Offset.zero, 16.0, Paint()..color = glowColor.withValues(alpha: 0.18));
    canvas.drawCircle(
      Offset.zero,
      16.0,
      Paint()..color = glowColor.withValues(alpha: 0.55)..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );

    // Pulsing gold glow when near complete
    if (!reduceMotion && progress >= 0.85) {
      final glow = 18.0 + pulsePhase * 6.0;
      canvas.drawCircle(
        Offset.zero,
        glow,
        Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: 0.25 + pulsePhase * 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    final woodFill = Paint()..color = const Color(0xFF4E342E)..style = PaintingStyle.fill;
    final woodStroke = Paint()..color = const Color(0xFF3E2723)..style = PaintingStyle.stroke..strokeWidth = 1.0;
    final goldFill = Paint()..color = const Color(0xFFFFD700)..style = PaintingStyle.fill;
    final goldStroke = Paint()..color = const Color(0xFFF57F17)..style = PaintingStyle.stroke..strokeWidth = 0.8;

    const w = 20.0;
    const hBase = 11.0;

    // Chest base
    canvas.drawRect(Rect.fromCenter(center: const Offset(0, 4), width: w, height: hBase), woodFill);
    canvas.drawRect(Rect.fromCenter(center: const Offset(0, 4), width: w, height: hBase), woodStroke);

    // Chest lid (arc)
    final lidRect = Rect.fromCenter(center: const Offset(0, -1.5), width: w, height: 8.0);
    canvas.drawArc(lidRect, pi, pi, true, woodFill);
    canvas.drawRect(Rect.fromLTWH(-w / 2, -1.5, w, 3.5), woodFill);
    canvas.drawArc(lidRect, pi, pi, false, woodStroke);
    canvas.drawLine(Offset(-w / 2, -1.5), Offset(w / 2, -1.5), woodStroke);

    // Gold band across middle
    canvas.drawRect(Rect.fromCenter(center: const Offset(0, 0.5), width: w, height: 3.0), goldFill);
    canvas.drawRect(Rect.fromCenter(center: const Offset(0, 0.5), width: w, height: 3.0), goldStroke);

    // Corner reinforcements
    for (final sx in [-1, 1]) {
      canvas.drawRect(Rect.fromCenter(center: Offset(sx * 8.0, 4), width: 3.5, height: hBase), goldFill..color = const Color(0xFFFFD700));
    }

    // Lock
    canvas.drawCircle(const Offset(0, 0.5), 3.5, goldFill..color = const Color(0xFFFFD700));
    canvas.drawCircle(const Offset(0, 0.5), 3.5, goldStroke);

    // "X" on chest lid — the famous X marks the spot
    final xPaint = Paint()..color = const Color(0xFFFFD700)..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-4, -4), const Offset(-1.5, -1), xPaint);
    canvas.drawLine(const Offset(-1.5, -4), const Offset(-4, -1), xPaint);

    // Coins spilling out when near complete
    if (progress >= 0.85) {
      final coinPaint = Paint()..color = const Color(0xFFFFD700)..style = PaintingStyle.fill;
      final coinPositions = [
        const Offset(-8, 8), const Offset(-5, 10), const Offset(6, 9), const Offset(9, 7),
      ];
      for (final cp in coinPositions) {
        canvas.drawCircle(cp, 2.5, coinPaint);
        canvas.drawCircle(cp, 2.5, goldStroke);
      }
    }
  }

  // ── Ink tip glow ──────────────────────────────────────────────────────────

  void _drawInkTipGlow(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final tip = trailTipOffset(progress, size.width);

    // Outer soft glow
    canvas.drawCircle(
      tip,
      16,
      Paint()
        ..shader = RadialGradient(
          colors: [inkColor.withValues(alpha: 0.60), inkColor.withValues(alpha: 0.15), Colors.transparent],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCenter(center: tip, width: 32, height: 32))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Bright inner dot
    canvas.drawCircle(tip, 4.5, Paint()..color = const Color(0xFFFFECB3).withValues(alpha: 0.95));
    canvas.drawCircle(tip, 3.0, Paint()..color = inkColor);
  }

  // ── Edge vignette for depth ───────────────────────────────────────────────

  void _drawVignette(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(18),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: [
            Colors.transparent,
            const Color(0xFF7A4F1A).withValues(alpha: 0.22),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(_TreasureMapPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulsePhase != pulsePhase ||
        oldDelegate.shimmerPhase != shimmerPhase ||
        oldDelegate.landmarkScales != landmarkScales ||
        oldDelegate.burstValues != burstValues;
  }
}

// ---------------------------------------------------------------------------
// Particle painter
// ---------------------------------------------------------------------------

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;

  _ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.life <= 0.0) continue;
      final alpha = (p.life * 0.85).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: alpha)..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(p.pos.dx, p.pos.dy);
      canvas.rotate(p.angle);
      final s = p.size * p.life;
      // Diamond sparkle
      canvas.drawPath(
        Path()
          ..moveTo(0, -s)
          ..lineTo(s * 0.45, 0)
          ..lineTo(0, s)
          ..lineTo(-s * 0.45, 0)
          ..close(),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}

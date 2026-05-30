import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/age_band_theme.dart';
import '../../utils/motion_utils.dart';

/// Adolescent (15-17) avatar loading animation: a holographic portal with
/// chromatic-aberration rings, teal data-stream rain, and a silhouette that
/// gradually materialises as [progress] approaches 1.0.
///
/// Tapping triggers a brief glitch burst (doubled chromatic offset + ring
/// shake) and calls [onTap].
///
/// Reduced-motion fallback: static concentric rings, opacity-faded silhouette,
/// no stream rain, tap glitch replaced by a border colour flash.
class AdolescentHolographicPortal extends StatefulWidget {
  final double stageSize;

  /// Loading progress from 0.0 to 1.0.
  final double progress;

  final VoidCallback onTap;

  const AdolescentHolographicPortal({
    super.key,
    required this.stageSize,
    required this.progress,
    required this.onTap,
  });

  @override
  State<AdolescentHolographicPortal> createState() =>
      _AdolescentHolographicPortalState();
}

class _AdolescentHolographicPortalState
    extends State<AdolescentHolographicPortal> with TickerProviderStateMixin {
  // ── Animation controllers ─────────────────────────────────────────────────

  /// Drives the continuous data-stream fall cycle (4 s, repeat).
  late final AnimationController _dataStreamCtrl;

  /// Drives the full-stage scan-line scroll (8 s, repeat).
  late final AnimationController _scanCtrl;

  /// One-shot glitch burst triggered by taps (200 ms).
  AnimationController? _glitchCtrl;

  // ── Glitch state ──────────────────────────────────────────────────────────

  bool _glitching = false;
  final Random _rng = Random();

  // Stable random x positions for data-stream lines (generated once).
  late final List<double> _streamX; // normalised 0..1
  late final List<double> _streamSpeeds; // 0.5..2.0 — multiplier
  late final List<double> _streamLengths; // 2..15 px
  late final List<double> _streamAlphas; // 0.1..0.5

  // Reduced-motion flash state
  bool _flashBorder = false;

  @override
  void initState() {
    super.initState();

    // Generate stable per-stream randomness.
    _streamX = List.generate(25, (_) => _rng.nextDouble());
    _streamSpeeds = List.generate(25, (_) => 0.5 + _rng.nextDouble() * 1.5);
    _streamLengths =
        List.generate(25, (_) => 2.0 + _rng.nextDouble() * 13.0);
    _streamAlphas =
        List.generate(25, (_) => 0.1 + _rng.nextDouble() * 0.4);

    // Looping controllers; repeats are started in didChangeDependencies so
    // MotionPrefs.reduceMotion is honored at runtime (A11Y-007 sweep). The
    // reduced-motion build path uses a static painter, but stopping the
    // controllers themselves avoids vsync ticks in the background.
    _dataStreamCtrl = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _scanCtrl = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPrefs.reduceMotion(context)) {
      _dataStreamCtrl.stop();
      _dataStreamCtrl.value = 0.0;
      _scanCtrl.stop();
      _scanCtrl.value = 0.0;
    } else {
      if (!_dataStreamCtrl.isAnimating) _dataStreamCtrl.repeat();
      if (!_scanCtrl.isAnimating) _scanCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _dataStreamCtrl.dispose();
    _scanCtrl.dispose();
    _glitchCtrl?.dispose();
    super.dispose();
  }

  // ── Interaction ───────────────────────────────────────────────────────────

  void _onTap() {
    HapticFeedback.lightImpact();
    widget.onTap();

    final reduced = MotionPrefs.reduceMotion(context);
    if (reduced) {
      // Reduced-motion: flash the border instead of animating.
      setState(() => _flashBorder = true);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _flashBorder = false);
      });
      return;
    }

    _glitchCtrl?.dispose();
    _glitchCtrl = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) setState(() => _glitching = false);
        }
      })
      ..forward();
    setState(() => _glitching = true);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final reduced = MotionPrefs.reduceMotion(context);
    final bt = Theme.of(context).extension<AgeBandThemeData>() ??
        themeForBand(AgeBand.adolescent);

    if (reduced) {
      return _buildReducedMotion(bt);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _onTap(),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _dataStreamCtrl,
          _scanCtrl,
          if (_glitchCtrl != null) _glitchCtrl!,
        ]),
        builder: (context, _) {
          final glitchProgress =
              (_glitching && _glitchCtrl != null) ? _glitchCtrl!.value : 0.0;
          // Glitch offset: 0→2 px normally, 0→4 px while glitching.
          final chromaticOffset = glitchProgress > 0
              ? 2.0 + glitchProgress * 2.0
              : 1.5;
          // Ring shake: ±3 px random while glitching.
          final ringShake = _glitching
              ? Offset(
                  (_rng.nextDouble() - 0.5) * 6,
                  (_rng.nextDouble() - 0.5) * 6,
                )
              : Offset.zero;

          return Transform.translate(
            offset: ringShake,
            child: CustomPaint(
              size: Size(widget.stageSize, widget.stageSize),
              painter: _HolographicPortalPainter(
                progress: widget.progress,
                dataPhase: _dataStreamCtrl.value,
                scanPhase: _scanCtrl.value,
                chromaticOffset: chromaticOffset,
                accent: bt.accent,
                streamX: _streamX,
                streamSpeeds: _streamSpeeds,
                streamLengths: _streamLengths,
                streamAlphas: _streamAlphas,
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Reduced-motion fallback ───────────────────────────────────────────────

  Widget _buildReducedMotion(AgeBandThemeData bt) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _onTap(),
      child: CustomPaint(
        size: Size(widget.stageSize, widget.stageSize),
        painter: _StaticPortalPainter(
          progress: widget.progress,
          accent: bt.accent,
          flashBorder: _flashBorder,
        ),
      ),
    );
  }
}

// ── Full painter ──────────────────────────────────────────────────────────────

class _HolographicPortalPainter extends CustomPainter {
  final double progress;
  final double dataPhase; // 0..1
  final double scanPhase; // 0..1
  final double chromaticOffset;
  final Color accent;

  // Per-stream stable randomness
  final List<double> streamX;
  final List<double> streamSpeeds;
  final List<double> streamLengths;
  final List<double> streamAlphas;

  _HolographicPortalPainter({
    required this.progress,
    required this.dataPhase,
    required this.scanPhase,
    required this.chromaticOffset,
    required this.accent,
    required this.streamX,
    required this.streamSpeeds,
    required this.streamLengths,
    required this.streamAlphas,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // ── 1. Background (near-black) ────────────────────────────────────────
    final bgPaint = Paint()
      ..color = const Color(0xFF070B14);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // ── 2. Chromatic aberration rings ─────────────────────────────────────
    _drawChromaticRings(canvas, size, cx, cy);

    // ── 3. Data stream rain ───────────────────────────────────────────────
    _drawDataStream(canvas, size);

    // ── 4. Silhouette / scan-line phase ───────────────────────────────────
    _drawSilhouette(canvas, size, cx, cy);

    // ── 5. Full-stage scan lines ──────────────────────────────────────────
    _drawScanLines(canvas, size);
  }

  // ── Chromatic rings ───────────────────────────────────────────────────────

  void _drawChromaticRings(
      Canvas canvas, Size size, double cx, double cy) {
    final radii = [0.30, 0.50, 0.70];
    // Each radius gets three strokes offset in R, G, B.
    const channels = [
      Color(0xFFFF0000), // R
      Color(0xFF00FF00), // G
      Color(0xFF00FFFF), // B/cyan
    ];
    const offsets = [
      Offset(-1, 0),
      Offset(0, -1),
      Offset(1, 1),
    ];

    for (final frac in radii) {
      final r = frac * size.width / 2;
      for (int i = 0; i < 3; i++) {
        final paint = Paint()
          ..color = channels[i].withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..blendMode = BlendMode.plus;
        final dx = offsets[i].dx * chromaticOffset;
        final dy = offsets[i].dy * chromaticOffset;
        canvas.drawCircle(Offset(cx + dx, cy + dy), r, paint);
      }
    }
  }

  // ── Data stream rain ──────────────────────────────────────────────────────

  void _drawDataStream(Canvas canvas, Size size) {
    for (int i = 0; i < streamX.length; i++) {
      // Each line has its own speed.  The "y head" wraps 0..1 over time.
      final yHead =
          ((dataPhase * streamSpeeds[i]) % 1.0) * (size.height + 20);
      final lineLen = streamLengths[i];
      final x = streamX[i] * size.width;

      final paint = Paint()
        ..color = accent.withValues(alpha: streamAlphas[i])
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x, yHead - lineLen),
        Offset(x, yHead),
        paint,
      );
    }
  }

  // ── Silhouette ────────────────────────────────────────────────────────────

  void _drawSilhouette(
      Canvas canvas, Size size, double cx, double cy) {
    final headR = size.width * 0.11;
    final headCy = cy - size.height * 0.08;

    // Shoulder trapezoid: wide at bottom, narrow at top.
    final shoulderTop = headCy + headR * 1.1;
    final shoulderBottom = cy + size.height * 0.22;
    final shoulderHalfTop = size.width * 0.10;
    final shoulderHalfBottom = size.width * 0.20;

    final silPath = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(cx, headCy), radius: headR))
      ..moveTo(cx - shoulderHalfTop, shoulderTop)
      ..lineTo(cx + shoulderHalfTop, shoulderTop)
      ..lineTo(cx + shoulderHalfBottom, shoulderBottom)
      ..lineTo(cx - shoulderHalfBottom, shoulderBottom)
      ..close();

    if (progress < 0.3) {
      // Low progress: only show horizontal scan glitches across the silhouette
      // area — don't fill the silhouette at all yet.
      _drawSilhouetteGlitch(canvas, silPath, cx, cy, headCy, shoulderBottom);
    } else {
      // Fill silhouette with increasing opacity.
      final alpha = ((progress - 0.3) / 0.7).clamp(0.0, 1.0) * 0.5;
      final silPaint = Paint()
        ..color = accent.withValues(alpha: alpha)
        ..blendMode = BlendMode.plus;
      canvas.drawPath(silPath, silPaint);

      // At high progress, also add a soft glow edge.
      if (progress > 0.6) {
        final glowAlpha = ((progress - 0.6) / 0.4).clamp(0.0, 1.0) * 0.2;
        final glowPaint = Paint()
          ..color = accent.withValues(alpha: glowAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..blendMode = BlendMode.plus;
        canvas.drawPath(silPath, glowPaint);
      }
    }
  }

  void _drawSilhouetteGlitch(
    Canvas canvas,
    Path silPath,
    double cx,
    double cy,
    double headCy,
    double shoulderBottom,
  ) {
    // Clip to silhouette bounding area and draw a few random horizontal lines.
    canvas.save();
    canvas.clipPath(silPath);
    final scanPaint = Paint()
      ..color = accent.withValues(alpha: 0.25)
      ..strokeWidth = 1.0;
    final topY = headCy - 20;
    final totalH = shoulderBottom - topY;
    // ~8 glitchy scan stripes spaced pseudo-randomly using scanPhase.
    for (int i = 0; i < 8; i++) {
      final frac = (i / 8.0 + scanPhase * 0.6) % 1.0;
      final y = topY + frac * totalH;
      canvas.drawLine(
        Offset(cx - 80, y),
        Offset(cx + 80, y),
        scanPaint,
      );
    }
    canvas.restore();
  }

  // ── Full-stage scan lines ─────────────────────────────────────────────────

  void _drawScanLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;
    const spacing = 4.0;
    final offset = scanPhase * spacing * 2; // scroll downward
    var y = -spacing + offset % (spacing * 2);
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += spacing;
    }
  }

  @override
  bool shouldRepaint(_HolographicPortalPainter old) =>
      old.progress != progress ||
      old.dataPhase != dataPhase ||
      old.scanPhase != scanPhase ||
      old.chromaticOffset != chromaticOffset;
}

// ── Reduced-motion static painter ─────────────────────────────────────────────

class _StaticPortalPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final bool flashBorder;

  const _StaticPortalPainter({
    required this.progress,
    required this.accent,
    required this.flashBorder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF070B14),
    );

    // Static concentric rings (no chromatic shift)
    for (final frac in [0.30, 0.50, 0.70]) {
      final r = frac * size.width / 2;
      final alpha = flashBorder ? 0.7 : 0.3;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = accent.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Silhouette fades in by progress (simple opacity, no streams).
    if (progress > 0.0) {
      final headR = size.width * 0.11;
      final headCy = cy - size.height * 0.08;
      final shoulderTop = headCy + headR * 1.1;
      final shoulderBottom = cy + size.height * 0.22;
      final shoulderHalfTop = size.width * 0.10;
      final shoulderHalfBottom = size.width * 0.20;

      final silPath = Path()
        ..addOval(
            Rect.fromCircle(center: Offset(cx, headCy), radius: headR))
        ..moveTo(cx - shoulderHalfTop, shoulderTop)
        ..lineTo(cx + shoulderHalfTop, shoulderTop)
        ..lineTo(cx + shoulderHalfBottom, shoulderBottom)
        ..lineTo(cx - shoulderHalfBottom, shoulderBottom)
        ..close();

      final alpha = progress.clamp(0.0, 1.0) * 0.5;
      canvas.drawPath(
        silPath,
        Paint()..color = accent.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_StaticPortalPainter old) =>
      old.progress != progress || old.flashBorder != flashBorder;
}

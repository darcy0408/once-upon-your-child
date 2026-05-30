import 'package:flutter/material.dart';

import '../../theme/age_band_theme.dart';
import '../../utils/motion_utils.dart';

/// Adult (18+) avatar loading animation: minimalist ink-wash brush strokes
/// that flow and bloom like ink in water. Elegant and meditative.
///
/// Four bezier brush strokes reveal progressively as [progress] advances
/// from 0.0 to 1.0. Each stroke blooms gently via a breathing oscillation
/// and bleeds slightly at the edges with an ink-diffusion blur.
class AdultInkWash extends StatefulWidget {
  final double stageSize;

  /// Loading progress from 0.0 to 1.0.
  final double progress;

  const AdultInkWash({
    super.key,
    required this.stageSize,
    required this.progress,
  });

  @override
  State<AdultInkWash> createState() => _AdultInkWashState();
}

class _AdultInkWashState extends State<AdultInkWash>
    with SingleTickerProviderStateMixin {
  /// Drives the gentle width oscillation (bloom effect) on each stroke.
  late final AnimationController _breathCtrl;

  @override
  void initState() {
    super.initState();
    // Looping controller; repeat started in didChangeDependencies so
    // MotionPrefs.reduceMotion is honored at runtime (A11Y-007 sweep).
    _breathCtrl = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPrefs.reduceMotion(context)) {
      _breathCtrl.stop();
      _breathCtrl.value = 0.5; // mid breath — neutral stroke width
    } else if (!_breathCtrl.isAnimating) {
      _breathCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MotionPrefs.reduceMotion(context);
    final bt = Theme.of(context).extension<AgeBandThemeData>() ??
        themeForBand(AgeBand.adult);

    return SizedBox(
      width: widget.stageSize,
      height: widget.stageSize,
      child: AnimatedBuilder(
        animation: reduced
            ? const AlwaysStoppedAnimation(0.0)
            : _breathCtrl,
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.stageSize, widget.stageSize),
            painter: _InkWashPainter(
              progress: widget.progress,
              breathPhase: reduced ? 0.5 : _breathCtrl.value,
              accentColor: bt.accent,
              glowColor: bt.primary,
              reduced: reduced,
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stroke definitions
// ---------------------------------------------------------------------------

/// Describes a single brush stroke as a cubic bezier curve with control
/// points expressed as fractions of the canvas size ([0.0, 1.0]).
class _StrokeDef {
  /// Bezier control points: [p0, cp1, cp2, p3] as fractional offsets.
  final List<Offset> points;

  /// Progress window [start, end] in which this stroke is revealed.
  final double revealStart;
  final double revealEnd;

  /// Base stroke width in logical pixels.
  final double baseWidth;

  const _StrokeDef({
    required this.points,
    required this.revealStart,
    required this.revealEnd,
    required this.baseWidth,
  });
}

/// The four brush stroke definitions.
///
/// Coordinates are fractional (0.0-1.0) relative to the canvas square.
/// Arranged diagonally for a calligraphic, meditative composition:
///   1. Top-left sweeping down-right
///   2. Bottom-left curving upward
///   3. Horizontal sweep across the middle
///   4. Center curving to bottom-right
const List<_StrokeDef> _kStrokes = [
  // Stroke 1 — top-left sweeping down-right
  _StrokeDef(
    points: [
      Offset(0.08, 0.12),
      Offset(0.25, 0.20),
      Offset(0.50, 0.38),
      Offset(0.68, 0.55),
    ],
    revealStart: 0.00,
    revealEnd: 0.25,
    baseWidth: 12.0,
  ),
  // Stroke 2 — bottom-left curving upward to center
  _StrokeDef(
    points: [
      Offset(0.10, 0.82),
      Offset(0.22, 0.60),
      Offset(0.42, 0.48),
      Offset(0.60, 0.42),
    ],
    revealStart: 0.20,
    revealEnd: 0.50,
    baseWidth: 14.0,
  ),
  // Stroke 3 — horizontal sweep across the middle
  _StrokeDef(
    points: [
      Offset(0.15, 0.50),
      Offset(0.38, 0.44),
      Offset(0.62, 0.56),
      Offset(0.85, 0.50),
    ],
    revealStart: 0.45,
    revealEnd: 0.75,
    baseWidth: 9.0,
  ),
  // Stroke 4 — center to bottom-right with a downward curve
  _StrokeDef(
    points: [
      Offset(0.45, 0.45),
      Offset(0.58, 0.58),
      Offset(0.70, 0.72),
      Offset(0.88, 0.84),
    ],
    revealStart: 0.70,
    revealEnd: 1.00,
    baseWidth: 11.0,
  ),
];

// ---------------------------------------------------------------------------
// CustomPainter
// ---------------------------------------------------------------------------

class _InkWashPainter extends CustomPainter {
  final double progress;
  final double breathPhase; // 0.0-1.0 from _breathCtrl
  final Color accentColor;  // bt.accent — warm amber
  final Color glowColor;    // bt.primary — amber-gold
  final bool reduced;

  const _InkWashPainter({
    required this.progress,
    required this.breathPhase,
    required this.accentColor,
    required this.glowColor,
    required this.reduced,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── 1. Soft center background glow ────────────────────────────────────
    _drawCenterGlow(canvas, size);

    // ── 2. Brush strokes ──────────────────────────────────────────────────
    for (final stroke in _kStrokes) {
      _drawStroke(canvas, size, stroke);
    }
  }

  void _drawCenterGlow(Canvas canvas, Size size) {
    // Fades in proportional to overall progress.
    final alpha = (progress * 0.08).clamp(0.0, 0.08);
    if (alpha <= 0.001) return;

    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = size.width * 0.45;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          glowColor.withValues(alpha: alpha),
          glowColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  void _drawStroke(Canvas canvas, Size size, _StrokeDef stroke) {
    // Determine how much of this stroke is revealed.
    final localProgress = _strokeLocalProgress(stroke);
    if (localProgress <= 0.0) return;

    // Convert fractional control points to canvas coordinates.
    final pts = stroke.points
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();

    // Build the full bezier path.
    final fullPath = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..cubicTo(
        pts[1].dx, pts[1].dy,
        pts[2].dx, pts[2].dy,
        pts[3].dx, pts[3].dy,
      );

    // Extract a partial path based on localProgress (0.0-1.0).
    final drawnPath = reduced
        ? fullPath
        : _partialBezierPath(pts, localProgress);

    // ── Stroke width with breath oscillation ──────────────────────────────
    // Oscillates ±1.5px around baseWidth. No oscillation in reduced mode.
    final breathOffset = reduced ? 0.0 : (breathPhase - 0.5) * 3.0; // ±1.5
    final strokeWidth = (stroke.baseWidth + breathOffset).clamp(
      stroke.baseWidth - 1.5,
      stroke.baseWidth + 1.5,
    );

    // ── Ink diffusion blur ────────────────────────────────────────────────
    // Sigma grows from 0 (just appeared) to 3.0 (fully revealed).
    final blurSigma = reduced ? 0.0 : localProgress * 3.0;

    // ── Gradient paint (accent → transparent) ─────────────────────────────
    final startPt = pts[0];
    final endPt = pts[3];

    // Glow / blur pass first (softer, wider).
    if (!reduced && blurSigma > 0.1) {
      final blurPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma)
        ..shader = LinearGradient(
          begin: Alignment(
            (startPt.dx / size.width) * 2 - 1,
            (startPt.dy / size.height) * 2 - 1,
          ),
          end: Alignment(
            (endPt.dx / size.width) * 2 - 1,
            (endPt.dy / size.height) * 2 - 1,
          ),
          colors: [
            accentColor.withValues(alpha: 0.25),
            accentColor.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromPoints(startPt, endPt),
        );
      canvas.drawPath(drawnPath, blurPaint);
    }

    // Crisp ink pass on top.
    final inkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        begin: Alignment(
          (startPt.dx / size.width) * 2 - 1,
          (startPt.dy / size.height) * 2 - 1,
        ),
        end: Alignment(
          (endPt.dx / size.width) * 2 - 1,
          (endPt.dy / size.height) * 2 - 1,
        ),
        colors: [
          accentColor.withValues(alpha: 0.85),
          accentColor.withValues(alpha: 0.15),
        ],
      ).createShader(
        Rect.fromPoints(startPt, endPt),
      );
    canvas.drawPath(drawnPath, inkPaint);
  }

  /// Maps the global [progress] value onto [0.0, 1.0] for the given stroke's
  /// reveal window.  Returns 0.0 if the stroke hasn't started yet, 1.0 if
  /// it's fully revealed.
  double _strokeLocalProgress(_StrokeDef stroke) {
    if (progress <= stroke.revealStart) return 0.0;
    if (progress >= stroke.revealEnd) return 1.0;
    return (progress - stroke.revealStart) /
        (stroke.revealEnd - stroke.revealStart);
  }

  /// Returns a Path that traces only the first [t] fraction of the cubic
  /// bezier defined by [pts] (p0, cp1, cp2, p3), using de Casteljau
  /// subdivision.
  Path _partialBezierPath(List<Offset> pts, double t) {
    // De Casteljau: split at t → take the "left" segment.
    final p0 = pts[0];
    final p1 = pts[1];
    final p2 = pts[2];
    final p3 = pts[3];

    final q0 = _lerp(p0, p1, t);
    final q1 = _lerp(p1, p2, t);
    final q2 = _lerp(p2, p3, t);

    final r0 = _lerp(q0, q1, t);
    final r1 = _lerp(q1, q2, t);

    final s0 = _lerp(r0, r1, t);

    // The partial bezier: p0 → q0 → r0 → s0
    return Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(q0.dx, q0.dy, r0.dx, r0.dy, s0.dx, s0.dy);
  }

  static Offset _lerp(Offset a, Offset b, double t) =>
      Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);

  @override
  bool shouldRepaint(_InkWashPainter old) =>
      old.progress != progress ||
      old.breathPhase != breathPhase ||
      old.accentColor != accentColor ||
      old.glowColor != glowColor ||
      old.reduced != reduced;
}

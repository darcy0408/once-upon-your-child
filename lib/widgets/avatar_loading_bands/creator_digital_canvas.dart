import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/age_band_theme.dart';
import '../../utils/motion_utils.dart';

/// Creator (12-14) avatar loading animation.
///
/// Geometric shapes and paint strokes compose themselves on a near-black canvas
/// as [progress] advances from 0.0 to 1.0. No particles — clean editorial
/// aesthetic with wireframe-first shape reveals and diagonal sweep lines.
class CreatorDigitalCanvas extends StatefulWidget {
  final double stageSize;

  /// Loading progress, 0.0–1.0.
  final double progress;

  final VoidCallback onTap;

  const CreatorDigitalCanvas({
    super.key,
    required this.stageSize,
    required this.progress,
    required this.onTap,
  });

  @override
  State<CreatorDigitalCanvas> createState() => _CreatorDigitalCanvasState();
}

class _CreatorDigitalCanvasState extends State<CreatorDigitalCanvas>
    with TickerProviderStateMixin {
  // Glow pulse on the latest visible shape.
  late final AnimationController _pulseCtrl;

  // Active tap ripples.
  final List<_TapRipple> _ripples = [];

  // Reduced-motion flash overlay.
  AnimationController? _flashCtrl;

  final Random _rng = Random(42); // seeded for deterministic shape positions

  // Pre-generated shape definitions (generated once in initState).
  late final List<_ShapeDef> _shapes;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _shapes = _buildShapes();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    for (final r in _ripples) {
      r.ctrl.dispose();
    }
    _flashCtrl?.dispose();
    super.dispose();
  }

  // ── Shape generation ────────────────────────────────────────────────────────

  List<_ShapeDef> _buildShapes() {
    const count = 12;
    final shapes = <_ShapeDef>[];
    final types = _ShapeType.values;

    for (int i = 0; i < count; i++) {
      final type = types[i % types.length];
      shapes.add(_ShapeDef(
        type: type,
        // Distribute normalized positions avoiding the exact center
        x: 0.1 + _rng.nextDouble() * 0.8,
        y: 0.1 + _rng.nextDouble() * 0.8,
        // Size: 5%–15% of stage
        sizeFraction: 0.05 + _rng.nextDouble() * 0.10,
        // Rotation 0–360°
        rotation: _rng.nextDouble() * 2 * pi,
        // Alpha 0.2–0.7
        alpha: 0.2 + _rng.nextDouble() * 0.5,
        // Alternate between primary and primaryLight
        usePrimaryLight: i.isOdd,
        // Each shape appears at evenly spaced progress intervals
        appearAt: i / count,
        // Fill solidifies 0.07 of progress after outline appears
        fillAt: (i / count) + 0.07,
      ));
    }

    return shapes;
  }

  // ── Interaction ─────────────────────────────────────────────────────────────

  void _onTapDown(TapDownDetails details) {
    final reduced = MotionPrefs.reduceMotion(context);
    HapticFeedback.selectionClick();
    widget.onTap();

    if (reduced) {
      // Brief opacity flash instead of ripple.
      _flashCtrl?.dispose();
      _flashCtrl = AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      )
        ..addListener(() => setState(() {}))
        ..forward();
      setState(() {});
      return;
    }

    final ctrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    final ripple = _TapRipple(
      position: details.localPosition,
      ctrl: ctrl,
    );
    ctrl.addListener(() => setState(() {}));
    ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _ripples.remove(ripple));
        ctrl.dispose();
      }
    });
    setState(() => _ripples.add(ripple));
    ctrl.forward();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final reduced = MotionPrefs.reduceMotion(context);
    final bt = Theme.of(context).extension<AgeBandThemeData>() ??
        themeForBand(AgeBand.creator);

    // Index of the latest shape that has started appearing.
    int latestVisibleIndex = -1;
    for (int i = _shapes.length - 1; i >= 0; i--) {
      if (widget.progress >= _shapes[i].appearAt) {
        latestVisibleIndex = i;
        break;
      }
    }

    // Flash overlay alpha for reduced-motion tap response.
    double flashAlpha = 0.0;
    if (reduced && _flashCtrl != null) {
      final t = _flashCtrl!.value;
      // Rise then fall: peaks at 0.5
      flashAlpha = (t < 0.5 ? t * 2 : (1 - t) * 2) * 0.18;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      child: SizedBox(
        width: widget.stageSize,
        height: widget.stageSize,
        child: Stack(
          children: [
            // Main canvas painter
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                return CustomPaint(
                  size: Size(widget.stageSize, widget.stageSize),
                  painter: _DigitalCanvasPainter(
                    progress: widget.progress,
                    shapes: _shapes,
                    latestVisibleIndex: latestVisibleIndex,
                    pulseValue: reduced ? 0.5 : _pulseCtrl.value,
                    ripples: reduced ? const [] : _ripples,
                    primaryColor: bt.primary,
                    primaryLightColor: bt.primaryLight,
                    accentColor: bt.accent,
                    reduced: reduced,
                  ),
                );
              },
            ),

            // Reduced-motion flash overlay
            if (reduced && flashAlpha > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: bt.primaryLight.withValues(alpha: flashAlpha),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Data classes ─────────────────────────────────────────────────────────────

enum _ShapeType { circle, triangle, rectangle }

class _ShapeDef {
  final _ShapeType type;

  /// Normalized position (0–1) within the stage.
  final double x;
  final double y;

  /// Size as a fraction of the stage dimension.
  final double sizeFraction;

  final double rotation;

  /// Fill alpha when fully opaque (0.2–0.7).
  final double alpha;

  final bool usePrimaryLight;

  /// Progress value at which the wireframe outline first appears.
  final double appearAt;

  /// Progress value at which the fill is fully opaque.
  final double fillAt;

  const _ShapeDef({
    required this.type,
    required this.x,
    required this.y,
    required this.sizeFraction,
    required this.rotation,
    required this.alpha,
    required this.usePrimaryLight,
    required this.appearAt,
    required this.fillAt,
  });
}

class _TapRipple {
  final Offset position;
  final AnimationController ctrl;

  _TapRipple({required this.position, required this.ctrl});

  /// Ripple radius: 0 → 80 px.
  double get radius => ctrl.value * 80.0;

  /// Alpha: full at start, zero at end.
  double get alpha => (1.0 - ctrl.value) * 0.55;
}

// ── CustomPainter ─────────────────────────────────────────────────────────────

class _DigitalCanvasPainter extends CustomPainter {
  final double progress;
  final List<_ShapeDef> shapes;
  final int latestVisibleIndex;
  final double pulseValue; // 0–1 from _pulseCtrl
  final List<_TapRipple> ripples;
  final Color primaryColor;
  final Color primaryLightColor;
  final Color accentColor;
  final bool reduced;

  const _DigitalCanvasPainter({
    required this.progress,
    required this.shapes,
    required this.latestVisibleIndex,
    required this.pulseValue,
    required this.ripples,
    required this.primaryColor,
    required this.primaryLightColor,
    required this.accentColor,
    required this.reduced,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background
    _drawBackground(canvas, size);

    // 2. Grid
    _drawGrid(canvas, size);

    // 3. Paint sweeps
    _drawSweeps(canvas, size);

    // 4. Geometric shapes
    _drawShapes(canvas, size);

    // 5. Tap ripples
    _drawRipples(canvas, size);
  }

  // ── Background ────────────────────────────────────────────────────────────

  void _drawBackground(Canvas canvas, Size size) {
    // Near-black with purple undertone gradient matching creatorTheme.
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0A0A14), // gradientStart
          Color(0xFF121228), // gradientMid
          Color(0xFF0E0E1E), // gradientEnd
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  // ── Grid ──────────────────────────────────────────────────────────────────

  void _drawGrid(Canvas canvas, Size size) {
    // In reduced mode: grid is always visible at a slightly stronger alpha.
    // In normal mode: grid flashes very briefly in the first 15% of progress,
    // then fades to near-invisible as shapes arrive.
    double gridAlpha;
    if (reduced) {
      gridAlpha = 0.12;
    } else {
      // Flash 0→0.08 progress: fade in quickly
      // 0.08→0.15: hold briefly
      // 0.15→0.30: fade out to 0.06
      if (progress < 0.08) {
        gridAlpha = (progress / 0.08) * 0.18;
      } else if (progress < 0.15) {
        gridAlpha = 0.18;
      } else if (progress < 0.30) {
        gridAlpha = 0.18 - ((progress - 0.15) / 0.15) * 0.12;
      } else {
        gridAlpha = 0.06;
      }
    }

    final paint = Paint()
      ..color = primaryColor.withValues(alpha: gridAlpha)
      ..strokeWidth = 0.5;

    const divisions = 6;
    for (int i = 0; i <= divisions; i++) {
      final x = size.width * i / divisions;
      final y = size.height * i / divisions;
      // Vertical line
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      // Horizontal line
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  // ── Paint sweeps ──────────────────────────────────────────────────────────

  void _drawSweeps(Canvas canvas, Size size) {
    // Three diagonal sweep lines, each active over a progress window.
    // They draw from one corner toward the opposite, using a gradient that
    // fades to transparent at the tail.
    const sweepDefs = [
      // (progressStart, progressEnd, fromAlignment, toAlignment)
      (0.20, 0.45, Alignment.topLeft, Alignment.bottomRight),
      (0.40, 0.65, Alignment.topRight, Alignment.bottomLeft),
      (0.60, 0.85, Alignment.centerLeft, Alignment.centerRight),
    ];

    for (final sweep in sweepDefs) {
      final pStart = sweep.$1;
      final pEnd = sweep.$2;
      final fromAlign = sweep.$3;
      final toAlign = sweep.$4;

      if (progress < pStart) continue;

      // t: how far along this sweep we are (0→1)
      final t = ((progress - pStart) / (pEnd - pStart)).clamp(0.0, 1.0);

      final from = Offset(
        (fromAlign.x + 1) / 2 * size.width,
        (fromAlign.y + 1) / 2 * size.height,
      );
      final to = Offset(
        (toAlign.x + 1) / 2 * size.width,
        (toAlign.y + 1) / 2 * size.height,
      );

      // Current tip position along the line
      final tip = Offset.lerp(from, to, t)!;

      // Gradient: primary at tip, transparent at origin
      final paint = Paint()
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.0),
            primaryColor.withValues(alpha: 0.55),
          ],
        ).createShader(Rect.fromPoints(from, tip));

      canvas.drawLine(from, tip, paint);
    }
  }

  // ── Geometric shapes ──────────────────────────────────────────────────────

  void _drawShapes(Canvas canvas, Size size) {
    for (int i = 0; i < shapes.length; i++) {
      final shape = shapes[i];

      if (progress < shape.appearAt) continue;

      final color =
          shape.usePrimaryLight ? primaryLightColor : primaryColor;

      // Compute fill alpha: 0 at appearAt, full at fillAt
      double fillAlpha;
      if (reduced) {
        // Snap to full alpha immediately
        fillAlpha = shape.alpha;
      } else {
        final fillProgress =
            ((progress - shape.appearAt) / (shape.fillAt - shape.appearAt))
                .clamp(0.0, 1.0);
        fillAlpha = fillProgress * shape.alpha;
      }

      // Outline alpha: fully visible as soon as shape appears, fades out
      // once fill is complete.
      double outlineAlpha;
      if (reduced) {
        outlineAlpha = 0.0; // no wireframe in reduced mode
      } else {
        final fillProgress =
            ((progress - shape.appearAt) / (shape.fillAt - shape.appearAt))
                .clamp(0.0, 1.0);
        // Outline fades from 0.8 down to 0 as fill comes in
        outlineAlpha = (1.0 - fillProgress) * 0.8;
      }

      final cx = shape.x * size.width;
      final cy = shape.y * size.height;
      final shapeSize = shape.sizeFraction * size.width;

      // Glow on the latest appearing shape
      if (i == latestVisibleIndex && !reduced) {
        _drawShapeGlow(canvas, size, shape, cx, cy, shapeSize, color);
      }

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(shape.rotation);

      switch (shape.type) {
        case _ShapeType.circle:
          _drawCircle(canvas, shapeSize, color, fillAlpha, outlineAlpha);
        case _ShapeType.triangle:
          _drawTriangle(canvas, shapeSize, color, fillAlpha, outlineAlpha);
        case _ShapeType.rectangle:
          _drawRectangle(canvas, shapeSize, color, fillAlpha, outlineAlpha);
      }

      canvas.restore();
    }
  }

  void _drawShapeGlow(Canvas canvas, Size size, _ShapeDef shape, double cx,
      double cy, double shapeSize, Color color) {
    final glowRadius = shapeSize * (1.8 + pulseValue * 0.6);
    final glowAlpha = 0.12 + pulseValue * 0.18;

    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: glowAlpha),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(cx, cy),
        radius: glowRadius,
      ));

    canvas.drawCircle(Offset(cx, cy), glowRadius, paint);
  }

  void _drawCircle(Canvas canvas, double shapeSize, Color color,
      double fillAlpha, double outlineAlpha) {
    final r = shapeSize * 0.5;

    if (fillAlpha > 0) {
      final fill = Paint()
        ..color = color.withValues(alpha: fillAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset.zero, r, fill);
    }

    if (outlineAlpha > 0) {
      final stroke = Paint()
        ..color = color.withValues(alpha: outlineAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(Offset.zero, r, stroke);
    }
  }

  void _drawTriangle(Canvas canvas, double shapeSize, Color color,
      double fillAlpha, double outlineAlpha) {
    final h = shapeSize;
    final path = Path()
      ..moveTo(0, -h * 0.5)
      ..lineTo(h * 0.433, h * 0.25)
      ..lineTo(-h * 0.433, h * 0.25)
      ..close();

    if (fillAlpha > 0) {
      final fill = Paint()
        ..color = color.withValues(alpha: fillAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fill);
    }

    if (outlineAlpha > 0) {
      final stroke = Paint()
        ..color = color.withValues(alpha: outlineAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, stroke);
    }
  }

  void _drawRectangle(Canvas canvas, double shapeSize, Color color,
      double fillAlpha, double outlineAlpha) {
    // Aspect ratio varies — some squares, some wider rectangles.
    final w = shapeSize;
    final h = shapeSize * 0.6;
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);

    if (fillAlpha > 0) {
      final fill = Paint()
        ..color = color.withValues(alpha: fillAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fill);
    }

    if (outlineAlpha > 0) {
      final stroke = Paint()
        ..color = color.withValues(alpha: outlineAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRect(rect, stroke);
    }
  }

  // ── Tap ripples ───────────────────────────────────────────────────────────

  void _drawRipples(Canvas canvas, Size size) {
    for (final ripple in ripples) {
      // Concentric ripple ring
      final ringPaint = Paint()
        ..color = accentColor.withValues(alpha: ripple.alpha * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(ripple.position, ripple.radius, ringPaint);

      // Slightly smaller inner ring for depth
      if (ripple.radius > 10) {
        final innerPaint = Paint()
          ..color = accentColor.withValues(alpha: ripple.alpha * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
        canvas.drawCircle(ripple.position, ripple.radius * 0.6, innerPaint);
      }

      // Small geometric shape at tap point (small rectangle, rotated 45°)
      final shapeAlpha = (1.0 - ripple.ctrl.value) * 0.6;
      if (shapeAlpha > 0) {
        canvas.save();
        canvas.translate(ripple.position.dx, ripple.position.dy);
        canvas.rotate(pi / 4 + ripple.ctrl.value * pi * 0.25);
        final accentSize = 6.0 + ripple.ctrl.value * 4.0;
        final accentRect = Rect.fromCenter(
          center: Offset.zero,
          width: accentSize,
          height: accentSize,
        );
        final accentPaint = Paint()
          ..color = accentColor.withValues(alpha: shapeAlpha)
          ..style = PaintingStyle.fill;
        canvas.drawRect(accentRect, accentPaint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_DigitalCanvasPainter old) {
    return old.progress != progress ||
        old.pulseValue != pulseValue ||
        old.ripples.length != ripples.length ||
        old.latestVisibleIndex != latestVisibleIndex;
  }
}

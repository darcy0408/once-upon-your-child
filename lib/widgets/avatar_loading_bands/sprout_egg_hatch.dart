import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/age_band_theme.dart';
import '../../utils/motion_utils.dart';
import '../safe_asset_image.dart';

/// Sprout (2-5) avatar loading: a glowing egg that wobbles and cracks on tap.
///
/// Each tap cracks the egg exactly where the child touched. After several
/// taps, golden light peeks through the cracks. A companion image bounces
/// gently beside the egg when provided.
class SproutEggHatch extends StatefulWidget {
  final double stageSize;
  final double progress;
  final VoidCallback onTap;
  final String? companionImagePath;

  const SproutEggHatch({
    super.key,
    required this.stageSize,
    required this.progress,
    required this.onTap,
    this.companionImagePath,
  });

  @override
  State<SproutEggHatch> createState() => _SproutEggHatchState();
}

class _SproutEggHatchState extends State<SproutEggHatch>
    with TickerProviderStateMixin {
  late final AnimationController _wobbleCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _bounceCtrl;
  AnimationController? _crackBurstCtrl;

  final List<_CrackLine> _cracks = [];
  final Random _rng = Random();
  int _tapCount = 0;

  double get _eggSize => widget.stageSize * 0.65;

  @override
  void initState() {
    super.initState();
    _wobbleCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    _glowCtrl = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _bounceCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _wobbleCtrl.dispose();
    _glowCtrl.dispose();
    _bounceCtrl.dispose();
    _crackBurstCtrl?.dispose();
    super.dispose();
  }

  /// Maps a tap on the [widget.stageSize]-square gesture area onto a point
  /// inside the egg's painter coordinate space, clamped to stay on the shell.
  Offset _crackOriginForTap(Offset tapInStage) {
    final eggW = _eggSize;
    final eggH = _eggSize * 1.2;
    // Painter is centred inside the square stage.
    final px = tapInStage.dx - (widget.stageSize - eggW) / 2;
    final py = tapInStage.dy - (widget.stageSize - eggH) / 2;

    // Egg ellipse in painter space (mirrors _EggCrackPainter).
    final cx = eggW / 2;
    final cy = eggH / 2;
    final rx = eggW * 0.42;
    final ry = eggH * 0.48;

    // Clamp the point inside the shell so the crack always lands on the egg
    // even if the child taps just outside it.
    final nx = (px - cx) / rx;
    final ny = (py - cy) / ry;
    final dist = sqrt(nx * nx + ny * ny);
    const maxDist = 0.78;
    if (dist > maxDist && dist > 0) {
      final scale = maxDist / dist;
      return Offset(cx + nx * rx * scale, cy + ny * ry * scale);
    }
    return Offset(px, py);
  }

  void _onTapEgg(TapDownDetails details) {
    HapticFeedback.lightImpact();
    widget.onTap();
    setState(() {
      _tapCount++;
      _cracks.add(_CrackLine(
        origin: _crackOriginForTap(details.localPosition),
        angle: _rng.nextDouble() * 2 * pi,
        length: 0.10 + _rng.nextDouble() * 0.16,
        jaggedness: 0.3 + _rng.nextDouble() * 0.4,
      ));
    });

    // Burst animation on each tap
    _crackBurstCtrl?.dispose();
    _crackBurstCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MotionPrefs.reduceMotion(context);
    final bt = Theme.of(context).extension<AgeBandThemeData>() ??
        themeForBand(AgeBand.sprout);
    final eggSize = _eggSize;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapEgg,
      child: SizedBox(
        width: widget.stageSize,
        height: widget.stageSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glow behind egg (intensifies with cracks)
            if (!reduced)
              AnimatedBuilder(
                animation: _glowCtrl,
                builder: (_, __) {
                  final glowIntensity =
                      (_tapCount / 12.0).clamp(0.0, 1.0) * 0.6 +
                          _glowCtrl.value * 0.15;
                  return Container(
                    width: eggSize * 1.6,
                    height: eggSize * 1.6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          bt.accent.withValues(alpha: glowIntensity),
                          bt.accent.withValues(alpha: glowIntensity * 0.3),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  );
                },
              ),

            // Egg with wobble
            AnimatedBuilder(
              animation: reduced
                  ? const AlwaysStoppedAnimation(0.0)
                  : _wobbleCtrl,
              builder: (_, child) {
                final wobbleAngle = reduced
                    ? 0.0
                    : sin(_wobbleCtrl.value * pi) *
                        0.04 *
                        (1 + _tapCount * 0.15).clamp(1.0, 2.5);
                return Transform.rotate(
                  angle: wobbleAngle,
                  child: child,
                );
              },
              child: _crackBurstCtrl != null && !reduced
                  ? AnimatedBuilder(
                      animation: _crackBurstCtrl!,
                      builder: (_, __) {
                        final burst = _crackBurstCtrl!.value;
                        final scale = 1.0 + burst * 0.08 * (1 - burst);
                        return Transform.scale(
                          scale: scale,
                          child: _buildEgg(bt, eggSize),
                        );
                      },
                    )
                  : _buildEgg(bt, eggSize),
            ),

            // Companion bouncing (top-right)
            if (widget.companionImagePath != null)
              Positioned(
                right: widget.stageSize * 0.02,
                top: widget.stageSize * 0.05,
                child: AnimatedBuilder(
                  animation: reduced
                      ? const AlwaysStoppedAnimation(0.0)
                      : _bounceCtrl,
                  builder: (_, __) {
                    final offset = reduced ? 0.0 : -10.0 * _bounceCtrl.value;
                    return Transform.translate(
                      offset: Offset(0, offset),
                      child: ClipOval(
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: _buildCompanionImage(),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // "Tap me" hint — shown until the child cracks the egg the first
            // time, so it's discoverable even with the sound off.
            if (_tapCount == 0)
              Positioned(
                bottom: 0,
                child: _buildTapHint(bt, reduced),
              ),

            // Progress-based hatching hint
            if (_tapCount >= 8)
              Positioned(
                bottom: 0,
                child: Text(
                  'Almost hatched!',
                  style: TextStyle(
                    color: bt.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTapHint(AgeBandThemeData bt, bool reduced) {
    final hint = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: bt.accent.withValues(alpha: 0.35),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app, color: bt.accent, size: 20),
          const SizedBox(width: 6),
          Text(
            'Tap the egg to crack it!',
            style: TextStyle(
              color: bt.accent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    if (reduced) return hint;

    return AnimatedBuilder(
      animation: _bounceCtrl,
      builder: (_, child) {
        final scale = 0.96 + 0.08 * _bounceCtrl.value;
        return Transform.scale(scale: scale, child: child);
      },
      child: hint,
    );
  }

  Widget _buildEgg(AgeBandThemeData bt, double eggSize) {
    return CustomPaint(
      size: Size(eggSize, eggSize * 1.2),
      painter: _EggCrackPainter(
        cracks: _cracks,
        tapCount: _tapCount,
        glowPhase: _glowCtrl.value,
        eggColor: const Color(0xFFFFF8E1), // warm cream
        glowColor: bt.accent,
        crackColor: const Color(0xFF8D6E63), // brown cracks
      ),
    );
  }

  Widget _buildCompanionImage() {
    final path = widget.companionImagePath!;
    if (path.startsWith('assets/')) {
      return SafeAssetImage(
        path,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
      );
    }
    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.auto_awesome,
          color: Colors.purple,
          size: 28,
        ),
      );
    }
    return const Icon(Icons.auto_awesome, color: Colors.purple, size: 28);
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _CrackLine {
  /// Impact point in painter coordinate space — where the child tapped.
  final Offset origin;
  final double angle;
  final double length;
  final double jaggedness;

  const _CrackLine({
    required this.origin,
    required this.angle,
    required this.length,
    required this.jaggedness,
  });
}

// ── CustomPainter ────────────────────────────────────────────────────────────

class _EggCrackPainter extends CustomPainter {
  final List<_CrackLine> cracks;
  final int tapCount;
  final double glowPhase;
  final Color eggColor;
  final Color glowColor;
  final Color crackColor;

  _EggCrackPainter({
    required this.cracks,
    required this.tapCount,
    required this.glowPhase,
    required this.eggColor,
    required this.glowColor,
    required this.crackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width * 0.42; // horizontal radius
    final ry = size.height * 0.48; // vertical radius (taller)

    // Egg shape path (oval, slightly pointy at top)
    final eggPath = Path();
    for (double t = 0; t <= 2 * pi; t += 0.02) {
      // Modify the top to be slightly narrower
      final topFactor = 1.0 - 0.15 * max(0, -sin(t));
      final x = cx + rx * cos(t) * topFactor;
      final y = cy + ry * sin(t);
      if (t == 0) {
        eggPath.moveTo(x, y);
      } else {
        eggPath.lineTo(x, y);
      }
    }
    eggPath.close();

    // Glow through cracks (behind egg)
    if (tapCount > 3) {
      final glowIntensity = ((tapCount - 3) / 10.0).clamp(0.0, 1.0);
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            glowColor.withValues(alpha: 0.6 * glowIntensity * (0.7 + 0.3 * glowPhase)),
            glowColor.withValues(alpha: 0.1 * glowIntensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width,
          height: size.height,
        ))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 1.8, height: ry * 1.8),
        glowPaint,
      );
    }

    // Egg body
    final eggPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.3),
        colors: [
          eggColor,
          Color.lerp(eggColor, const Color(0xFFFFE0B2), 0.5)!,
          Color.lerp(eggColor, const Color(0xFFD7CCC8), 0.3)!,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.width,
        height: size.height,
      ));
    canvas.drawPath(eggPath, eggPaint);

    // Egg outline
    final outlinePaint = Paint()
      ..color = crackColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(eggPath, outlinePaint);

    // Highlight (top-left gloss)
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.5),
        radius: 0.6,
        colors: [
          Colors.white.withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCenter(
        center: Offset(cx - rx * 0.25, cy - ry * 0.3),
        width: rx * 1.2,
        height: ry * 1.2,
      ));
    canvas.save();
    canvas.clipPath(eggPath);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - rx * 0.25, cy - ry * 0.3),
        width: rx * 1.0,
        height: ry * 0.8,
      ),
      highlightPaint,
    );
    canvas.restore();

    // Cracks — each tap produces a small jagged star centred on the impact
    // point, so the crack appears wherever the child actually touched.
    if (cracks.isNotEmpty) {
      final crackPaint = Paint()
        ..color = crackColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      final crackGlowPaint = tapCount > 5
          ? (Paint()
            ..color = glowColor.withValues(
                alpha: 0.4 *
                    ((tapCount - 5) / 8.0).clamp(0.0, 1.0) *
                    (0.6 + 0.4 * glowPhase))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4))
          : null;

      final maxRadius = (rx + ry) / 2;

      canvas.save();
      canvas.clipPath(eggPath);
      for (final crack in cracks) {
        // Three jagged spokes radiating from the tap point.
        for (int spoke = 0; spoke < 3; spoke++) {
          final spokeAngle = crack.angle + spoke * (2 * pi / 3);
          final crackPath = Path()
            ..moveTo(crack.origin.dx, crack.origin.dy);

          const segments = 4;
          final maxDist = crack.length * maxRadius;
          for (int i = 1; i <= segments; i++) {
            final frac = i / segments;
            final dist = maxDist * frac;
            // Jitter tapers toward the tip so the crack looks like it grows
            // out of the impact point.
            final jitter = (i % 2 == 0 ? 1 : -1) *
                crack.jaggedness *
                6 *
                (1 - frac * 0.6);
            final perpAngle = spokeAngle + pi / 2;
            final x = crack.origin.dx +
                cos(spokeAngle) * dist +
                cos(perpAngle) * jitter;
            final y = crack.origin.dy +
                sin(spokeAngle) * dist +
                sin(perpAngle) * jitter;
            crackPath.lineTo(x, y);
          }

          if (crackGlowPaint != null) {
            canvas.drawPath(crackPath, crackGlowPaint);
          }
          canvas.drawPath(crackPath, crackPaint);
        }
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_EggCrackPainter oldDelegate) =>
      oldDelegate.cracks.length != cracks.length ||
      oldDelegate.tapCount != tapCount ||
      oldDelegate.glowPhase != glowPhase;
}

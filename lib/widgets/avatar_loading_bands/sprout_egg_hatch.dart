import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/age_band_theme.dart';
import '../../utils/motion_utils.dart';
import '../safe_asset_image.dart';

/// Sprout (2-5) avatar loading: a glowing egg that wobbles and cracks on tap.
///
/// After several taps, golden light peeks through the cracks. A companion
/// image bounces gently beside the egg when provided.
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

  void _onTapEgg() {
    HapticFeedback.lightImpact();
    widget.onTap();
    setState(() {
      _tapCount++;
      // Add a crack line at a random angle from center
      final angle = _rng.nextDouble() * 2 * pi;
      final length = 0.15 + _rng.nextDouble() * 0.25;
      _cracks.add(_CrackLine(
        angle: angle,
        length: length,
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
    final eggSize = widget.stageSize * 0.65;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _onTapEgg(),
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
  final double angle;
  final double length;
  final double jaggedness;

  const _CrackLine({
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

    // Cracks
    if (cracks.isNotEmpty) {
      final crackPaint = Paint()
        ..color = crackColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      for (final crack in cracks) {
        final crackPath = Path();
        final startX = cx;
        final startY = cy;
        crackPath.moveTo(startX, startY);

        // Draw jagged crack line from center outward
        const segments = 5;
        for (int i = 1; i <= segments; i++) {
          final frac = i / segments;
          final dist = crack.length * frac * (rx + ry) / 2;
          final jitter = (i % 2 == 0 ? 1 : -1) * crack.jaggedness * 8;
          final perpAngle = crack.angle + pi / 2;
          final x = cx + cos(crack.angle) * dist + cos(perpAngle) * jitter;
          final y = cy + sin(crack.angle) * dist + sin(perpAngle) * jitter;
          crackPath.lineTo(x, y);
        }

        canvas.save();
        canvas.clipPath(eggPath);
        canvas.drawPath(crackPath, crackPaint);

        // Glow along crack for later taps
        if (tapCount > 5) {
          final crackGlowPaint = Paint()
            ..color = glowColor.withValues(
                alpha: 0.4 * ((tapCount - 5) / 8.0).clamp(0.0, 1.0) *
                    (0.6 + 0.4 * glowPhase))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
          canvas.drawPath(crackPath, crackGlowPaint);
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_EggCrackPainter oldDelegate) =>
      oldDelegate.cracks.length != cracks.length ||
      oldDelegate.tapCount != tapCount ||
      oldDelegate.glowPhase != glowPhase;
}

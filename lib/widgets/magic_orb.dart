import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A magical orb widget that displays a scenario image with pulsing glow and sparkles.
/// 
/// Used in the "Magic Review" step to visualize the story being created.
class MagicOrbWidget extends StatefulWidget {
  final String imagePath;
  final Color glowColor;
  final double size;
  final String? topLabel; // NEW: Scenario title overlay (top)
  final String? label; // NEW: Label overlay
  final Widget? child; // Optional overlay content
  final double childScale; // If child is present, optionally scale it so background stays visible.

  const MagicOrbWidget({
    super.key,
    required this.imagePath,
    this.glowColor = AppColors.gold,
    this.size = 200.0,
    this.topLabel,
    this.label,
    this.child,
    this.childScale = 1.0,
  });

  @override
  State<MagicOrbWidget> createState() => _MagicOrbWidgetState();
}

class _MagicOrbWidgetState extends State<MagicOrbWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _sparkleController;
  late Animation<double> _pulseAnimation;
  
  final List<_SparkleParticle> _sparkles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    // Pulse animation (breathing glow)
    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Sparkle animation (rotation/shimmer)
    _sparkleController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    // Initialize sparkles
    _generateSparkles();
  }

  void _generateSparkles() {
    for (int i = 0; i < 22; i++) { // Denser sparkle field
      _sparkles.add(_SparkleParticle(
        angle: _random.nextDouble() * 2 * math.pi,
        distance: 0.4 + _random.nextDouble() * 0.6, 
        size: 2.0 + _random.nextDouble() * 5.0,
        speed: 0.3 + _random.nextDouble() * 0.7,
        twinklePhase: _random.nextDouble() * 2 * math.pi,
        twinkleSpeed: 0.8 + _random.nextDouble() * 2.2,
        driftPhase: _random.nextDouble() * 2 * math.pi,
        driftSpeed: 0.2 + _random.nextDouble() * 0.8,
        whiteness: _random.nextDouble() * 0.85,
      ));
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.5,
      height: widget.size * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Magical Aura (3-layer gradient halo)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final t = _pulseAnimation.value; // 0.8..1.2
              final glow = widget.glowColor;
              final soft = Color.lerp(glow, Colors.white, 0.55)!;
              final deep = Color.lerp(glow, Colors.black, 0.15)!;

              return Container(
                width: widget.size * 1.35,
                height: widget.size * 1.35,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Layer 1 (outer, soft)
                    Transform.rotate(
                      angle: _sparkleController.value * 2 * math.pi * 0.03,
                      child: Container(
                        width: widget.size * (1.32 * t),
                        height: widget.size * (1.32 * t),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              soft.withValues(alpha: 0.0),
                              glow.withValues(alpha: 0.18 * t),
                              deep.withValues(alpha: 0.08 * t),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.45, 0.75, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Layer 2 (mid, bright)
                    Transform.rotate(
                      angle: -_sparkleController.value * 2 * math.pi * 0.05,
                      child: Container(
                        width: widget.size * (1.18 * (0.95 + 0.1 * t)),
                        height: widget.size * (1.18 * (0.95 + 0.1 * t)),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.22 * t),
                              glow.withValues(alpha: 0.22 * t),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Layer 3 (inner, tight energy ring)
                    Container(
                      width: widget.size * (1.06 * (1.0 + 0.04 * t)),
                      height: widget.size * (1.06 * (1.0 + 0.04 * t)),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            glow.withValues(alpha: 0.28 * t),
                            Colors.white.withValues(alpha: 0.10 * t),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.65, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // 2. Swirling Sparkles (twinkle + drift)
          AnimatedBuilder(
            animation: _sparkleController,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size * 1.5, widget.size * 1.5),
                painter: _SparklePainter(
                  sparkles: _sparkles,
                  color: widget.glowColor,
                  rotation: _sparkleController.value * 2 * math.pi,
                ),
              );
            },
          ),

          // 3. The Orb Body
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Removed white border for cleaner look
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: widget.glowColor.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Scenario Background (Only if path provided)
                  if (widget.imagePath.isNotEmpty)
                    Image.asset(
                      widget.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 64),
                      ),
                    )
                  else if (widget.child == null)
                    Container(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 64),
                    ),
                  
                  // Atmosphere Tint
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.transparent,
                          widget.glowColor.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.35),
                        ],
                        stops: const [0.6, 0.85, 1.0],
                      ),
                    ),
                  ),

                  // Optional Overlay Content (e.g., Hero Avatar)
                  if (widget.child != null)
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: widget.childScale.clamp(0.25, 1.0),
                        heightFactor: widget.childScale.clamp(0.25, 1.0),
                        child: ClipOval(child: widget.child!),
                      ),
                    ),

                  // Optional Label Overlay
                  if (widget.label != null)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                        child: Text(
                          widget.label!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Quicksand',
                            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  // Optional Top Title Overlay
                  if (widget.topLabel != null)
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.topLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // 4. Glass Reflection & Gloss
          IgnorePointer(
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.4),
                    Colors.white.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.1),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // High-light highlight
          Positioned(
            top: widget.size * 0.1,
            left: widget.size * 0.2,
            child: Container(
              width: widget.size * 0.3,
              height: widget.size * 0.15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.6),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparkleParticle {
  final double angle;
  final double distance;
  final double size;
  final double speed;
  final double twinklePhase;
  final double twinkleSpeed;
  final double driftPhase;
  final double driftSpeed;
  final double whiteness; // 0..1: how much this sparkle trends toward white

  _SparkleParticle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.speed,
    required this.twinklePhase,
    required this.twinkleSpeed,
    required this.driftPhase,
    required this.driftSpeed,
    required this.whiteness,
  });
}

class _SparklePainter extends CustomPainter {
  final List<_SparkleParticle> sparkles;
  final Color color;
  final double rotation;

  _SparklePainter({
    required this.sparkles,
    required this.color,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (final sparkle in sparkles) {
      // Calculate current position with rotation
      final currentAngle = sparkle.angle + (rotation * sparkle.speed);
      final drift = 1.0 + (0.06 * math.sin((rotation * sparkle.driftSpeed) + sparkle.driftPhase));
      final dist = radius * sparkle.distance * drift;
      
      final dx = center.dx + dist * math.cos(currentAngle);
      final dy = center.dy + dist * math.sin(currentAngle);

      // Twinkle (opacity + subtle size change)
      final tw = 0.5 + 0.5 * math.sin((rotation * sparkle.twinkleSpeed) + sparkle.twinklePhase);
      final alpha = (0.20 + 0.80 * tw).clamp(0.0, 1.0);
      final s = sparkle.size * (0.85 + 0.35 * tw);

      final sparkleColor = Color.lerp(Colors.white, color, (1.0 - sparkle.whiteness).clamp(0.0, 1.0))!;

      final glowPaint = Paint()
        ..color = sparkleColor.withValues(alpha: (0.20 * alpha).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, (s * 1.2).clamp(1.0, 8.0));

      final starPaint = Paint()
        ..color = sparkleColor.withValues(alpha: alpha)
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.plus;

      // Small glow core + star
      canvas.drawCircle(Offset(dx, dy), (s * 0.75).clamp(0.8, 6.0), glowPaint);
      _drawStar(canvas, Offset(dx, dy), s, starPaint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy - size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => true;
}

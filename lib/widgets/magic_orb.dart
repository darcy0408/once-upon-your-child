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
  final String? label; // NEW: Label overlay
  final Widget? child; // Optional overlay content

  const MagicOrbWidget({
    super.key,
    required this.imagePath,
    this.glowColor = AppColors.gold,
    this.size = 200.0,
    this.label,
    this.child,
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
    for (int i = 0; i < 15; i++) { // Increased sparkle count
      _sparkles.add(_SparkleParticle(
        angle: _random.nextDouble() * 2 * math.pi,
        distance: 0.4 + _random.nextDouble() * 0.6, 
        size: 2.0 + _random.nextDouble() * 5.0,
        speed: 0.3 + _random.nextDouble() * 0.7,
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
          // 1. Magical Aura (Outer Glow)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: widget.size * 1.1,
                height: widget.size * 1.1,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.glowColor.withValues(alpha: 0.3 * _pulseAnimation.value),
                      blurRadius: 40 * _pulseAnimation.value,
                      spreadRadius: 15 * _pulseAnimation.value,
                    ),
                  ],
                ),
              );
            },
          ),

          // 2. Swirling Sparkles
          AnimatedBuilder(
            animation: _sparkleController,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size * 1.4, widget.size * 1.4),
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
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Scenario Background
                  Image.asset(
                    widget.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 64),
                    ),
                  ),
                  
                  // Atmosphere Tint
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.transparent,
                          widget.glowColor.withValues(alpha: 0.2),
                          Colors.black.withValues(alpha: 0.4),
                        ],
                        stops: const [0.5, 0.8, 1.0],
                      ),
                    ),
                  ),

                  // Optional Label Overlay
                  if (widget.label != null)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                        child: Text(
                          widget.label!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Quicksand',
                            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  if (widget.child != null)
                    Center(child: widget.child),
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

  _SparkleParticle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.speed,
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
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final sparkle in sparkles) {
      // Calculate current position with rotation
      final currentAngle = sparkle.angle + (rotation * sparkle.speed);
      final dist = radius * sparkle.distance;
      
      final dx = center.dx + dist * math.cos(currentAngle);
      final dy = center.dy + dist * math.sin(currentAngle);

      // Draw star shape (simplified cross)
      _drawStar(canvas, Offset(dx, dy), sparkle.size, paint);
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

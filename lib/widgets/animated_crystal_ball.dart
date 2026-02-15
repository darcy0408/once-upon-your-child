import 'dart:math';
import 'package:flutter/material.dart';

/// Animated Crystal Ball with swirling magical energy inside
/// Based on reference design: glowing orb with rotating galaxy effect
class AnimatedCrystalBall extends StatefulWidget {
  final IconData icon;
  final double size;
  final bool showStand;

  const AnimatedCrystalBall({
    super.key,
    required this.icon,
    this.size = 48.0,
    this.showStand = true,
  });

  @override
  State<AnimatedCrystalBall> createState() => _AnimatedCrystalBallState();
}

class _AnimatedCrystalBallState extends State<AnimatedCrystalBall>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final standWidth = widget.size * 0.79;
    final standHeight = widget.size * 0.17;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Enhanced outer magical aura with gold accent
            Container(
              width: widget.size * 1.42,
              height: widget.size * 1.42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFA65BFF).withValues(alpha: 0.75),
                    const Color(0xFFE8A4FF).withValues(alpha: 0.4),
                    const Color(0xFFFFD878).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.65, 1.0],
                ),
              ),
            ),

            // Animated swirling energy layer
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Container(
                  width: widget.size * 0.9,
                  height: widget.size * 0.9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      transform: GradientRotation(_rotationController.value * 2 * pi),
                      colors: const [
                        Color(0xBBCCFFFF), // Brighter Cyan swirl
                        Color(0xBBAA88FF), // Brighter Purple swirl
                        Color(0xBBFFB3E6), // Brighter Pink swirl
                        Color(0xBBCCFFFF), // Back to cyan
                      ],
                      stops: const [0.0, 0.33, 0.66, 1.0],
                    ),
                  ),
                );
              },
            ),

            // Crystal ball with glass effect
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.35, -0.45),
                  colors: [
                    Color(0xFFFFFFFF), // Brighter highlight
                    Color(0xFFF8EFFF), // Very light lavender
                    Color(0xFFE2D1FF), // Light purple
                    Color(0xFFA678E8), // Medium purple
                    Color(0xFF7B45C0), // Deep purple
                    Color(0xFF532885), // Dark purple edge
                  ],
                  stops: [0.0, 0.1, 0.3, 0.6, 0.85, 1.0],
                ),
                border: Border.all(
                  color: const Color(0xFFFFE8F0).withValues(alpha: 0.6),
                  width: 2.2,
                ),
                boxShadow: const [
                  // Bright highlight (glass reflection)
                  BoxShadow(
                    color: Color(0xEEFFFFFF),
                    blurRadius: 14,
                    spreadRadius: -5,
                    offset: Offset(-3, -5),
                  ),
                  // Deep Purple glow
                  BoxShadow(
                    color: Color(0xBBA65BFF),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                  // Intense gold shimmer
                  BoxShadow(
                    color: Color(0xAAFFD878),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                  // Outer soft gold aura
                  BoxShadow(
                    color: Color(0x66FFEBA5),
                    blurRadius: 36,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                size: widget.size * 0.55,
                color: Colors.white,
                shadows: const [
                  Shadow(color: Color(0x99000000), blurRadius: 6),
                  Shadow(color: Colors.white, blurRadius: 12),
                ],
              ),
            ),
          ],
        ),

        if (widget.showStand) ...[
          // Crystal ball stand/base
          const SizedBox(height: 2),
          Container(
            width: standWidth,
            height: standHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF8B7BA8),
                  Color(0xFF5D4A7A),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

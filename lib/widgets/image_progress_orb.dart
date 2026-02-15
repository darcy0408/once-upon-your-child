import 'package:flutter/material.dart';

/// Image-based Progress Orb using transparent PNG assets
/// Shows crystal ball progress indicators with icons
class ImageProgressOrb extends StatefulWidget {
  final IconData icon;
  final bool showStand;
  final double? size; // Responsive sizing override

  const ImageProgressOrb({
    super.key,
    required this.icon,
    this.showStand = false,
    this.size,
  });

  @override
  State<ImageProgressOrb> createState() => _ImageProgressOrbState();
}

class _ImageProgressOrbState extends State<ImageProgressOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final base = widget.size ?? (screenWidth / 8.0).clamp(48.0, 66.0);
    final glowSize = base + (base * 0.18);
    return SizedBox(
      width: base,
      height: base,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing glow
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              return Container(
                width: glowSize + ((base * 0.18) * _shimmerController.value),
                height: glowSize + ((base * 0.18) * _shimmerController.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFB388FF).withValues(alpha: 0.4 * (1 - _shimmerController.value * 0.3)),
                      const Color(0xFF9E6CFF).withValues(alpha: 0.2 * (1 - _shimmerController.value * 0.3)),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),

          // Crystal ball image
          Container(
            width: base,
            height: base,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9E6CFF).withValues(alpha: 0.5),
                  blurRadius: (base * 0.33).clamp(12.0, 24.0),
                  spreadRadius: (base * 0.05).clamp(2.0, 4.0),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.3),
                  blurRadius: (base * 0.16).clamp(6.0, 12.0),
                  offset: Offset(-(base * 0.03), -(base * 0.03)),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/ui/Progress Indicator.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0xFFE5DAFF),
                          Color(0xFF9E6CFF),
                          Color(0xFF7C4DFF),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Icon overlay
          Icon(
            widget.icon,
            size: (base * 0.40).clamp(18.0, 28.0),
            color: Colors.white,
            shadows: const [
              Shadow(
                color: Color(0x88000000),
                blurRadius: 4,
              ),
              Shadow(
                color: Colors.white,
                blurRadius: 8,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

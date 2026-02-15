import 'package:flutter/material.dart';

/// 3D Crystal Formation - Faceted crystal cluster with multiple shards
/// Based on reference design: Ice/Amber/Amethyst crystal clusters
class CrystalFormation extends StatefulWidget {
  final String type; // 'quick', 'classic', 'epic'
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const CrystalFormation({
    super.key,
    required this.type,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<CrystalFormation> createState() => _CrystalFormationState();
}

class _CrystalFormationState extends State<CrystalFormation>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  CrystalColors _getColorsForType(String type) {
    switch (type) {
      case 'quick':
        return CrystalColors(
          light: const Color(0xFFE8FEFF), // Icy white
          primary: const Color(0xFF8EEDFF), // Cyan
          mid: const Color(0xFF4DD9F5), // Bright cyan
          dark: const Color(0xFF00B8D4), // Deep cyan
          glow: const Color(0xFF80DEEA), // Cyan glow
        );
      case 'classic':
        return CrystalColors(
          light: const Color(0xFFFFF7D6), // Pale gold
          primary: const Color(0xFFFFD65C), // Gold
          mid: const Color(0xFFFFC107), // Amber
          dark: const Color(0xFFFF8F00), // Deep orange
          glow: const Color(0xFFFFEB3B), // Golden glow
        );
      case 'epic':
        return CrystalColors(
          light: const Color(0xFFE5DAFF), // Pale purple
          primary: const Color(0xFF9E6CFF), // Amethyst
          mid: const Color(0xFF7C4DFF), // Deep purple
          dark: const Color(0xFF6A1B9A), // Royal purple
          glow: const Color(0xFFB388FF), // Purple glow
        );
      default:
        return CrystalColors(
          light: Colors.white,
          primary: Colors.purple,
          mid: Colors.deepPurple,
          dark: Colors.deepPurple.shade900,
          glow: Colors.purpleAccent,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getColorsForType(widget.type);
    final screenWidth = MediaQuery.of(context).size.width;
    final crystalWidth = (screenWidth / 3.5).clamp(85.0, 110.0);
    final crystalHeight = (crystalWidth * 1.2).clamp(100.0, 130.0);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 250),
        scale: widget.isSelected ? 1.15 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: crystalWidth + 30,
              height: crystalHeight,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Ambient glow aura
                  if (widget.isSelected)
                    Positioned(
                      bottom: crystalHeight * 0.25,
                      child: Container(
                        width: crystalWidth + 40,
                        height: crystalWidth + 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              colors.primary.withValues(alpha: 0.6),
                              colors.glow.withValues(alpha: 0.3),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),

                  // 3D Crystal formation
                  Positioned(
                    bottom: 0,
                    child: SizedBox(
                      width: crystalWidth,
                      height: crystalHeight,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return CustomPaint(
                            size: Size(crystalWidth, crystalHeight),
                            painter: _CrystalFormationPainter(
                              colors: colors,
                              pulse: _pulseController.value,
                              isSelected: widget.isSelected,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Crystal base platform
            const SizedBox(height: 4),
            Container(
              width: crystalWidth * 0.8,
              height: 8,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF4A4A5A),
                    Color(0xFF2A2A3A),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Label text
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF2A2040),
                fontWeight: widget.isSelected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 18,
                shadows: widget.isSelected
                    ? [
                        Shadow(
                          color: colors.glow.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CrystalColors {
  final Color light;
  final Color primary;
  final Color mid;
  final Color dark;
  final Color glow;

  CrystalColors({
    required this.light,
    required this.primary,
    required this.mid,
    required this.dark,
    required this.glow,
  });
}

class _CrystalFormationPainter extends CustomPainter {
  final CrystalColors colors;
  final double pulse; // 0.0 to 1.0
  final bool isSelected;

  _CrystalFormationPainter({
    required this.colors,
    required this.pulse,
    required this.isSelected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final glowIntensity = isSelected ? 0.8 + (pulse * 0.2) : 0.4;

    // Draw multiple crystal shards forming a cluster

    // Center large shard (tallest)
    _drawCrystalShard(
      canvas,
      size,
      offset: Offset(size.width * 0.5, size.height * 0.85),
      width: size.width * 0.35,
      height: size.height * 0.7,
      angle: 0,
      glowIntensity: glowIntensity,
    );

    // Left shard (medium)
    _drawCrystalShard(
      canvas,
      size,
      offset: Offset(size.width * 0.25, size.height * 0.9),
      width: size.width * 0.25,
      height: size.height * 0.5,
      angle: -0.3,
      glowIntensity: glowIntensity * 0.8,
    );

    // Right shard (medium)
    _drawCrystalShard(
      canvas,
      size,
      offset: Offset(size.width * 0.75, size.height * 0.9),
      width: size.width * 0.25,
      height: size.height * 0.5,
      angle: 0.3,
      glowIntensity: glowIntensity * 0.8,
    );

    // Left small shard
    _drawCrystalShard(
      canvas,
      size,
      offset: Offset(size.width * 0.15, size.height * 0.95),
      width: size.width * 0.18,
      height: size.height * 0.35,
      angle: -0.5,
      glowIntensity: glowIntensity * 0.6,
    );

    // Right small shard
    _drawCrystalShard(
      canvas,
      size,
      offset: Offset(size.width * 0.85, size.height * 0.95),
      width: size.width * 0.18,
      height: size.height * 0.35,
      angle: 0.5,
      glowIntensity: glowIntensity * 0.6,
    );
  }

  void _drawCrystalShard(
    Canvas canvas,
    Size size, {
    required Offset offset,
    required double width,
    required double height,
    required double angle,
    required double glowIntensity,
  }) {
    final path = Path();

    // Create more sharp irregular hexagonal crystal shape
    path.moveTo(0, -height);
    path.lineTo(width * 0.4, -height * 0.75);
    path.lineTo(width * 0.6, -height * 0.4);
    path.lineTo(width * 0.4, 0);
    path.lineTo(0, height * 0.2);
    path.lineTo(-width * 0.4, 0);
    path.lineTo(-width * 0.6, -height * 0.4);
    path.lineTo(-width * 0.4, -height * 0.75);
    path.close();

    // Apply rotation and translation
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.rotate(angle);

    // Fill with deeper, more vibrant gradient
    final rect = path.getBounds();
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        colors.light,
        colors.primary,
        colors.mid,
        colors.dark,
        colors.dark.withValues(alpha: 0.8),
      ],
      stops: const [0.0, 0.25, 0.55, 0.85, 1.0],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);

    // Add multiple facet highlights for "shimmer"
    _drawFacetHighlight(
      canvas,
      Offset(-width * 0.2, -height * 0.7),
      width * 0.35,
      height * 0.4,
      glowIntensity,
    );

    _drawFacetHighlight(
      canvas,
      Offset(width * 0.2, -height * 0.3),
      width * 0.25,
      height * 0.25,
      glowIntensity * 0.8,
    );
    
    // Top tip highlight
    _drawFacetHighlight(
      canvas,
      Offset(0, -height * 0.9),
      width * 0.2,
      height * 0.1,
      glowIntensity * 1.2,
    );

    // Edge highlight for glass/crystal effect
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6 * glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 1.5);

    canvas.drawPath(path, edgePaint);

    // Secondary inner glow
    final glowPaint = Paint()
      ..color = colors.glow.withValues(alpha: 0.4 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawPath(path, glowPaint);

    canvas.restore();
  }

  void _drawFacetHighlight(
    Canvas canvas,
    Offset position,
    double width,
    double height,
    double intensity,
  ) {
    final highlightPath = Path();
    highlightPath.addOval(
      Rect.fromCenter(
        center: position,
        width: width,
        height: height,
      ),
    );

    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.8 * intensity),
          Colors.white.withValues(alpha: 0.3 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(highlightPath.getBounds());

    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(_CrystalFormationPainter oldDelegate) {
    return oldDelegate.pulse != pulse || oldDelegate.isSelected != isSelected;
  }
}

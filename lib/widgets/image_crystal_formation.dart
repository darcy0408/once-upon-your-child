import 'package:flutter/material.dart';
import 'magical_float.dart';

/// Code-rendered crystal formation toggle with transparent-friendly visuals.
class ImageCrystalFormation extends StatefulWidget {
  final String type; // 'quick', 'classic', 'epic'
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const ImageCrystalFormation({
    super.key,
    required this.type,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<ImageCrystalFormation> createState() => _ImageCrystalFormationState();
}

class _ImageCrystalFormationState extends State<ImageCrystalFormation>
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

  String _getImagePath(String type) {
    switch (type) {
      case 'quick':
        return 'assets/images/ui/clean/quick_orb.png';
      case 'classic':
        return 'assets/images/ui/clean/classic_orb.png';
      case 'epic':
        return 'assets/images/ui/clean/epic_orb.png';
      default:
        return 'assets/images/ui/clean/classic_orb.png';
    }
  }

  Color _getGlowColor(String type) {
    switch (type) {
      case 'quick':
        return const Color(0xFF80DEEA); // Cyan glow
      case 'classic':
        return const Color(0xFFFFEB3B); // Golden glow
      case 'epic':
        return const Color(0xFFB388FF); // Purple glow
      default:
        return const Color(0xFFFFEB3B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = _getGlowColor(widget.type);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the actual available width (e.g. inside Flexible/Row) for responsive sizing.
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final maxCrystalByWidth = (availableWidth - 26).clamp(56.0, 132.0);
        final crystalSize = (availableWidth * 0.72)
            .clamp(56.0, 132.0)
            .clamp(56.0, maxCrystalByWidth);

        return MagicalFloat(
          distance: 6.0,
          duration: const Duration(seconds: 4),
          delay: (widget.type.length * 300).toDouble(),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 250),
              scale: widget.isSelected ? 1.12 : 1.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: crystalSize + 26,
                    height: crystalSize + 18,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ambient glow aura (pulsing)
                        if (widget.isSelected)
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final pulseValue = _pulseController.value;
                              final auraSpread = (crystalSize * 0.34);
                              return Container(
                                width: crystalSize + (auraSpread * pulseValue),
                                height: crystalSize + (auraSpread * pulseValue),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      glowColor.withValues(
                                          alpha: 0.62 * (1 - pulseValue * 0.3)),
                                      glowColor.withValues(
                                          alpha: 0.30 * (1 - pulseValue * 0.3)),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.55, 1.0],
                                  ),
                                ),
                              );
                            },
                          ),

                        // Crystal orb artwork (transparent PNG)
                        Container(
                          width: crystalSize,
                          height: crystalSize,
                          decoration: BoxDecoration(
                            boxShadow: widget.isSelected
                                ? [
                                    BoxShadow(
                                      color: glowColor.withValues(alpha: 0.8),
                                      blurRadius: (crystalSize * 0.28)
                                          .clamp(18.0, 40.0),
                                      spreadRadius:
                                          (crystalSize * 0.06).clamp(4.0, 10.0),
                                    ),
                                    BoxShadow(
                                      color:
                                          Colors.white.withValues(alpha: 0.5),
                                      blurRadius: (crystalSize * 0.14)
                                          .clamp(10.0, 20.0),
                                      spreadRadius:
                                          (crystalSize * 0.02).clamp(1.0, 4.0),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: glowColor.withValues(alpha: 0.3),
                                      blurRadius:
                                          (crystalSize * 0.10).clamp(8.0, 14.0),
                                      spreadRadius:
                                          (crystalSize * 0.02).clamp(1.0, 4.0),
                                    ),
                                  ],
                          ),
                          child: Image.asset(
                            _getImagePath(widget.type),
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
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
                      fontWeight:
                          widget.isSelected ? FontWeight.w900 : FontWeight.w700,
                      fontSize: (crystalSize * 0.18).clamp(14.0, 18.0),
                      shadows: widget.isSelected
                          ? [
                              Shadow(
                                color: glowColor.withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                              const Shadow(
                                color: Colors.white,
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

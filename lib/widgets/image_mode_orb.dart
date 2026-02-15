import 'dart:math';
import 'package:flutter/material.dart';

/// Image-based Mode Orb using transparent PNG assets
/// Displays Tales, Rhyme, Spellbound Reading, or Pick Your Path mode icons
class ImageModeOrb extends StatefulWidget {
  final String modeType; // 'tales', 'rhyme', 'reading', 'pickpath'
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color primaryColor;
  final Color secondaryColor;

  const ImageModeOrb({
    super.key,
    required this.modeType,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.primaryColor = const Color(0xFFAA88FF),
    this.secondaryColor = const Color(0xFFFF88CC),
  });

  @override
  State<ImageModeOrb> createState() => _ImageModeOrbState();
}

class _ImageModeOrbState extends State<ImageModeOrb>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late AnimationController _galaxyController;
  late AnimationController _floatController;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _galaxyController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();

    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _syncShimmerState();
  }

  @override
  void didUpdateWidget(covariant ImageModeOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncShimmerState();
    }
  }

  void _syncShimmerState() {
    if (widget.isActive || _isHovering) {
      if (!_shimmerController.isAnimating) {
        _shimmerController.repeat();
      }
    } else {
      _shimmerController.stop();
    }
  }

  void _handleTap() {
    _shimmerController
      ..stop()
      ..forward(from: 0);
    widget.onTap();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _galaxyController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  String _getImagePath(String modeType) {
    switch (modeType) {
      case 'tales':
        return 'assets/images/ui/Tales.jpg';
      case 'rhyme':
        return 'assets/images/ui/RhymeTime.jpg';
      case 'reading':
        return 'assets/images/ui/easyRead.jpg';
      case 'pickpath':
        return 'assets/images/ui/PickAPath.jpg';
      default:
        return 'assets/images/ui/Tales.jpg';
    }
  }

  @override
  Widget build(BuildContext context) {
    const inactiveText = Color(0xFF2F2748);
    final activeGlow = widget.primaryColor;

    return MouseRegion(
      onEnter: (_) {
        _isHovering = true;
        _syncShimmerState();
      },
      onExit: (_) {
        _isHovering = false;
        _syncShimmerState();
      },
      child: GestureDetector(
        onTap: _handleTap,
        child: SizedBox(
          width: 90,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 220),
                scale: widget.isActive ? 1.12 : 1.0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outermost radiant halo
                    if (widget.isActive)
                      Container(
                        width: 124,
                        height: 124,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              activeGlow.withValues(alpha: 0.3),
                              activeGlow.withValues(alpha: 0.12),
                              const Color(0xFFFFD478).withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.4, 0.7, 1.0],
                          ),
                        ),
                      ),

                    // Middle radiant halo
                    if (widget.isActive)
                      Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              activeGlow.withValues(alpha: 0.5),
                              activeGlow.withValues(alpha: 0.25),
                              activeGlow.withValues(alpha: 0.1),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.4, 0.7, 1.0],
                          ),
                        ),
                      ),

                    // Animated galaxy swirl background
                    AnimatedBuilder(
                      animation: _galaxyController,
                      builder: (context, child) {
                        return Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              transform: GradientRotation(
                                _galaxyController.value * 2 * pi,
                              ),
                              colors: [
                                widget.primaryColor.withValues(alpha: 0.6),
                                widget.secondaryColor.withValues(alpha: 0.5),
                                widget.primaryColor.withValues(alpha: 0.4),
                                widget.secondaryColor.withValues(alpha: 0.5),
                              ],
                              stops: const [0.0, 0.25, 0.5, 1.0],
                            ),
                          ),
                        );
                      },
                    ),

                    // Mode icon image (transparent PNG)
                    AnimatedBuilder(
                      animation: _floatController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _floatController.value * 3),
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                // Glass highlight
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: widget.isActive ? 0.6 : 0.3),
                                  blurRadius: widget.isActive ? 12 : 6,
                                  spreadRadius: widget.isActive ? -3 : -5,
                                  offset: const Offset(-1, -3),
                                ),
                                // Primary glow
                                BoxShadow(
                                  color: widget.primaryColor.withValues(alpha: widget.isActive ? 0.8 : 0.3),
                                  blurRadius: widget.isActive ? 35 : 10,
                                  spreadRadius: widget.isActive ? 5 : 0,
                                ),
                                // Secondary glow
                                if (widget.isActive)
                                  BoxShadow(
                                    color: widget.secondaryColor.withValues(alpha: 0.5),
                                    blurRadius: 25,
                                    spreadRadius: 3,
                                  ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                _getImagePath(widget.modeType),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          widget.primaryColor.withValues(alpha: 0.7),
                                          widget.secondaryColor.withValues(alpha: 0.5),
                                        ],
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.auto_awesome,
                                      size: 34,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
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
                  color: widget.isActive ? const Color(0xFF2F2748) : inactiveText,
                  fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

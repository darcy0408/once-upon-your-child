import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/motion_utils.dart';

/// Glass Sphere Orb with animated galaxy/swirl energy inside
/// Based on reference design: crystal clear sphere with magical swirling colors
class GlassSphereOrb extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color primaryColor;
  final Color secondaryColor;

  const GlassSphereOrb({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.primaryColor = const Color(0xFFAA88FF), // Purple
    this.secondaryColor = const Color(0xFFFF88CC), // Pink
  });

  @override
  State<GlassSphereOrb> createState() => _GlassSphereOrbState();
}

class _GlassSphereOrbState extends State<GlassSphereOrb>
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
    );

    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    // Looping galaxy/float/shimmer animations started in didChangeDependencies
    // so MotionPrefs.reduceMotion is honored (WCAG 2.2 AA SC 2.2.2 Pause, Stop,
    // Hide).
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MotionPrefs.reduceMotion(context)) {
      if (!_galaxyController.isAnimating) _galaxyController.repeat();
      if (!_floatController.isAnimating) {
        _floatController.repeat(reverse: true);
      }
    }
    _syncShimmerState();
  }

  @override
  void didUpdateWidget(covariant GlassSphereOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncShimmerState();
    }
  }

  void _syncShimmerState() {
    // Skip the looping shimmer under reduce-motion (WCAG 2.2 AA SC 2.2.2).
    if ((widget.isActive || _isHovering) &&
        !MotionPrefs.reduceMotion(context)) {
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

                    // Animated galaxy swirl inside sphere
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

                    // Main 3D glass sphere with depth
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 76,
                      height: 76,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Base glass sphere
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: const Alignment(-0.2, -0.3),
                                colors: widget.isActive
                                    ? [
                                        const Color(0xFFFFFFFF),
                                        const Color(0xFFFFF8FF),
                                        const Color(0xFFE8DAFF),
                                        const Color(0xFFC8ADFF),
                                        const Color(0xFFA884FF),
                                        const Color(0xFF7A5CC8),
                                      ]
                                    : [
                                        const Color(0xFFF5F5FA),
                                        const Color(0xFFE8E8F0),
                                        const Color(0xFFC8C8D8),
                                        const Color(0xFFA8A8C0),
                                        const Color(0xFF8888A8),
                                        const Color(0xFF6A6A88),
                                      ],
                                stops: const [0.0, 0.12, 0.28, 0.5, 0.75, 1.0],
                              ),
                              border: Border.all(
                                color: widget.isActive
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : const Color(0x33CCCCDD),
                                width: widget.isActive ? 2.0 : 1.2,
                              ),
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
                                // Depth shadow
                                BoxShadow(
                                  color: const Color(0x30000000),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),

                          // Floating icon with up/down animation
                          AnimatedBuilder(
                            animation: _floatController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _floatController.value * 3),
                                child: Icon(
                                  widget.icon,
                                  size: 34,
                                  color: widget.isActive
                                      ? Colors.white
                                      : const Color(0xFF5A5A7A),
                                  shadows: widget.isActive ? [
                                    const Shadow(
                                      color: Colors.white,
                                      blurRadius: 10,
                                    ),
                                    const Shadow(
                                      color: Color(0x66000000),
                                      blurRadius: 4,
                                    ),
                                  ] : const [
                                    Shadow(
                                      color: Color(0x44000000),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
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

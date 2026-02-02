// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;

/// Magical avatar widget with glow effects and optional particles
///
/// Wraps a DiceBear SVG avatar with theatrical Story Weaver styling:
/// - Radial gradient aura/glow
/// - Decorative frame border
/// - Optional floating particles (lightweight placeholder)
class MagicalAvatar extends StatefulWidget {
  /// SVG string from DiceBear API
  final String? svgString;

  /// Size of the avatar (diameter)
  final double size;

  /// Glow color (defaults to purple-blue gradient)
  final Color glowColor;

  /// Enable floating particle effect
  final bool enableParticles;

  /// Placeholder shown when SVG is loading or failed
  final Widget? placeholder;

  /// Border width for decorative frame
  final double borderWidth;

  const MagicalAvatar({
    super.key,
    required this.svgString,
    this.size = 120,
    this.glowColor = const Color(0xFF7C3AED),
    this.enableParticles = false,
    this.placeholder,
    this.borderWidth = 3,
  });

  @override
  State<MagicalAvatar> createState() => _MagicalAvatarState();
}

class _MagicalAvatarState extends State<MagicalAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Subtle pulsing glow animation
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radial glow background
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.glowColor.withValues(alpha: 0.4 * _glowAnimation.value),
                      widget.glowColor.withValues(alpha: 0.1 * _glowAnimation.value),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              );
            },
          ),

          // Main avatar with frame
          Container(
            width: widget.size * 0.85,
            height: widget.size * 0.85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.glowColor.withValues(alpha: 0.8),
                width: widget.borderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.glowColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: _buildAvatarContent(),
            ),
          ),

          // Optional particles
          if (widget.enableParticles) _buildParticles(),
        ],
      ),
    );
  }

  /// Build avatar content (SVG or placeholder)
  Widget _buildAvatarContent() {
    if (widget.svgString == null || widget.svgString!.isEmpty) {
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }

    try {
      return SvgPicture.string(
        widget.svgString!,
        fit: BoxFit.cover,
        placeholderBuilder: (context) => _buildDefaultPlaceholder(),
      );
    } catch (e) {
      debugPrint('MagicalAvatar: Failed to render SVG: $e');
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }
  }

  /// Default placeholder when avatar is unavailable
  Widget _buildDefaultPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.person,
          size: widget.size * 0.4,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  /// Lightweight particle effect (simple rotating sparkles)
  Widget _buildParticles() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _ParticlePainter(
              progress: _controller.value,
              color: widget.glowColor,
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for magical particles
class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw 4 rotating sparkles
    for (int i = 0; i < 4; i++) {
      final angle = (progress * 2 * math.pi) + (i * math.pi / 2);
      final x = center.dx + radius * 0.6 * math.cos(angle);
      final y = center.dy + radius * 0.6 * math.sin(angle);

      // Small sparkle circle
      canvas.drawCircle(
        Offset(x, y),
        2.0,
        paint..color = color.withValues(alpha: 0.8 * (1 - progress)),
      );

      // Sparkle trail
      canvas.drawCircle(
        Offset(x, y),
        4.0,
        paint..color = color.withValues(alpha: 0.3 * (1 - progress)),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Loading variant of MagicalAvatar with shimmer effect
class MagicalAvatarLoading extends StatefulWidget {
  final double size;
  final Color glowColor;
  final double borderWidth;

  const MagicalAvatarLoading({
    super.key,
    this.size = 120,
    this.glowColor = const Color(0xFF7C3AED),
    this.borderWidth = 3,
  });

  @override
  State<MagicalAvatarLoading> createState() => _MagicalAvatarLoadingState();
}

class _MagicalAvatarLoadingState extends State<MagicalAvatarLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Container(
        width: widget.size * 0.85,
        height: widget.size * 0.85,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.glowColor.withValues(alpha: 0.5),
            width: widget.borderWidth,
          ),
        ),
        child: ClipOval(
          child: AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.grey[300]!,
                      Colors.grey[100]!,
                      Colors.grey[300]!,
                    ],
                    stops: [
                      math.max(0.0, _shimmerAnimation.value - 0.3),
                      _shimmerAnimation.value,
                      math.min(1.0, _shimmerAnimation.value + 0.3),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.refresh,
                    size: widget.size * 0.3,
                    color: Colors.grey[400],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

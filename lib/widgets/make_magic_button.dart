import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

/// MakeMagicButton - The primary CTA button with magical animations
///
/// Features:
/// - Large pill-shaped button (60% screen width)
/// - Continuous pulse animation (1-second interval)
/// - Sparkle effects
/// - Haptic feedback on tap
/// - Gold border with purple gradient background
/// - WCAG AAA accessible (88px height)
class MakeMagicButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isEnabled;
  final bool showSparkles;

  const MakeMagicButton({
    super.key,
    this.label = 'Make Magic ✨',
    required this.onTap,
    this.isEnabled = true,
    this.showSparkles = true,
  });

  @override
  State<MakeMagicButton> createState() => _MakeMagicButtonState();
}

class _MakeMagicButtonState extends State<MakeMagicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupPulseAnimation();
  }

  void _setupPulseAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    if (widget.isEnabled) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(MakeMagicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnabled && !oldWidget.isEnabled) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isEnabled && oldWidget.isEnabled) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.isEnabled) return;

    // Haptic feedback (light tap)
    HapticFeedback.lightImpact();

    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth * 0.6; // 60% of screen width

    return Semantics(
      button: true,
      enabled: widget.isEnabled,
      label: widget.label,
      hint: 'Start creating your magical story',
      child: ScaleTransition(
        scale: widget.isEnabled ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            width: buttonWidth,
            height: AppTouchTargets.large, // 88px for primary action
            decoration: BoxDecoration(
              gradient: widget.isEnabled
                  ? AppGradients.purpleGlow
                  : LinearGradient(
                      colors: [
                        AppColors.textDisabled,
                        AppColors.textDisabled.withAlpha(204), // 80% opacity
                      ],
                    ),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: widget.isEnabled ? AppColors.gold : AppColors.textDisabled,
                width: 3,
              ),
              boxShadow: widget.isEnabled
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(102), // 40% opacity
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Sparkles (if enabled)
                if (widget.showSparkles && widget.isEnabled) ...[
                  const Positioned(
                    left: 20,
                    top: 15,
                    child: _SparkleIcon(size: 16),
                  ),
                  const Positioned(
                    right: 25,
                    top: 20,
                    child: _SparkleIcon(size: 12),
                  ),
                  const Positioned(
                    left: 30,
                    bottom: 18,
                    child: _SparkleIcon(size: 14),
                  ),
                  const Positioned(
                    right: 20,
                    bottom: 15,
                    child: _SparkleIcon(size: 16),
                  ),
                ],
                // Button label
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sparkle icon with rotation animation
class _SparkleIcon extends StatefulWidget {
  final double size;

  const _SparkleIcon({required this.size});

  @override
  State<_SparkleIcon> createState() => _SparkleIconState();
}

class _SparkleIconState extends State<_SparkleIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationController.value * 2 * math.pi,
          child: Icon(
            Icons.auto_awesome,
            color: AppColors.goldLight,
            size: widget.size,
          ),
        );
      },
    );
  }
}

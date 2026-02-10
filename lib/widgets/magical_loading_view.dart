import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A magical loading view with sparkling animations and phase messages.
class MagicalLoadingView extends StatefulWidget {
  final String status;
  final VoidCallback? onCancel;

  const MagicalLoadingView({
    super.key,
    required this.status,
    this.onCancel,
  });

  @override
  State<MagicalLoadingView> createState() => _MagicalLoadingViewState();
}

class _MagicalLoadingViewState extends State<MagicalLoadingView>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  final List<_Sparkle> _sparkles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // Pulse animation for the central icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Rotation for the outer ring
    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    // Generate random sparkles
    for (int i = 0; i < 12; i++) {
      _sparkles.add(_Sparkle(
        angle: _random.nextDouble() * 2 * pi,
        distance: 40.0 + _random.nextDouble() * 40.0,
        size: 4.0 + _random.nextDouble() * 6.0,
        speed: 0.5 + _random.nextDouble() * 1.5,
      ));
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 150,
            width: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Rotating magical ring
                AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationController.value * 2 * pi,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.3),
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                          gradient: SweepGradient(
                            colors: [
                              AppColors.gold.withValues(alpha: 0.0),
                              AppColors.gold.withValues(alpha: 0.5),
                              AppColors.gold.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Pulsing central book/wand icon
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_pulseController.value * 0.1),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3 * _pulseController.value),
                              blurRadius: 20 * _pulseController.value,
                              spreadRadius: 5 * _pulseController.value,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  },
                ),
                // Orbiting Sparkles
                ..._sparkles.map((sparkle) {
                  return _AnimatedSparkle(
                    controller: _rotationController,
                    sparkle: sparkle,
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            widget.status,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Quicksand', // Ensure we use the magical font
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Weaving your adventure...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
          ),
          if (widget.onCancel != null) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: widget.onCancel,
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Sparkle {
  final double angle;
  final double distance;
  final double size;
  final double speed;

  _Sparkle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.speed,
  });
}

class _AnimatedSparkle extends StatelessWidget {
  final AnimationController controller;
  final _Sparkle sparkle;

  const _AnimatedSparkle({
    required this.controller,
    required this.sparkle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final currentAngle = sparkle.angle + (controller.value * 2 * pi * sparkle.speed);
        final dx = cos(currentAngle) * sparkle.distance;
        final dy = sin(currentAngle) * sparkle.distance;
        
        // Twinkle effect based on rotation
        final opacity = (sin(currentAngle * 3) + 1) / 2;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Opacity(
            opacity: 0.3 + (opacity * 0.7),
            child: Icon(
              Icons.star,
              color: AppColors.gold,
              size: sparkle.size,
            ),
          ),
        );
      },
    );
  }
}

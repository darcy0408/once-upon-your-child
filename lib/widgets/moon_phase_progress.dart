import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// MoonPhaseProgress - Visual wizard step indicator
///
/// Design specs:
/// - Shows 4 steps as moon phase icons
/// - Active step glows
/// - No text labels (icon-only)
/// - Accessible with screen reader support
class MoonPhaseProgress extends StatelessWidget {
  final int currentStep; // 0-2
  final int totalSteps; // Should be 3
  final List<String> stepLabels; // For screen readers

  const MoonPhaseProgress({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
    this.stepLabels = const [
      'Step 1: Create your hero',
      'Step 2: Pick a companion',
      'Step 3: Make magic',
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Progress: ${stepLabels[currentStep]}, step ${currentStep + 1} of $totalSteps',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalSteps, (index) {
          final isActive = index == currentStep;
          final isCompleted = index < currentStep;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: _MoonPhaseIcon(
              isActive: isActive,
              isCompleted: isCompleted,
              label: stepLabels[index],
            ),
          );
        }),
      ),
    );
  }
}

class _MoonPhaseIcon extends StatefulWidget {
  final bool isActive;
  final bool isCompleted;
  final String label;

  const _MoonPhaseIcon({
    required this.isActive,
    required this.isCompleted,
    required this.label,
  });

  @override
  State<_MoonPhaseIcon> createState() => _MoonPhaseIconState();
}

class _MoonPhaseIconState extends State<_MoonPhaseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _setupGlowAnimation();
  }

  void _setupGlowAnimation() {
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _glowAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    if (widget.isActive) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_MoonPhaseIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _glowController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _glowController.stop();
      _glowController.value = 0;
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withAlpha((255 * _glowAnimation.value).toInt()),
                        blurRadius: 12 * _glowAnimation.value,
                        spreadRadius: 4 * _glowAnimation.value,
                      ),
                    ]
                  : null,
            ),
            child: _buildMoonIcon(),
          );
        },
      ),
    );
  }

  Widget _buildMoonIcon() {
    if (widget.isCompleted) {
      // Completed step: Full moon (filled circle)
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.gold,
          border: Border.all(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.check,
          color: AppColors.textLight,
          size: 24,
        ),
      );
    } else if (widget.isActive) {
      // Active step: Glowing moon
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.goldLight,
              AppColors.gold,
            ],
          ),
          border: Border.all(
            color: AppColors.primary,
            width: 3,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.auto_awesome,
            color: AppColors.textLight,
            size: 24,
          ),
        ),
      );
    } else {
      // Inactive step: Empty circle (new moon)
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(
            color: Colors.grey.shade400,
            width: 2,
          ),
        ),
      );
    }
  }
}

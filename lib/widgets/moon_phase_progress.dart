import 'package:flutter/material.dart';

/// Crystal-orb wizard progress indicator.
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
      label:
          'Progress: ${stepLabels[currentStep]}, step ${currentStep + 1} of $totalSteps',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalSteps, (index) {
          final isActive = index == currentStep;
          final isCompleted = index < currentStep;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _CrystalStepOrb(
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

class _CrystalStepOrb extends StatefulWidget {
  final bool isActive;
  final bool isCompleted;
  final String label;

  const _CrystalStepOrb({
    required this.isActive,
    required this.isCompleted,
    required this.label,
  });

  @override
  State<_CrystalStepOrb> createState() => _CrystalStepOrbState();
}

class _CrystalStepOrbState extends State<_CrystalStepOrb>
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
  void didUpdateWidget(_CrystalStepOrb oldWidget) {
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

  String get _orbAssetPath => widget.isCompleted
      ? 'assets/images/ui/clean/progress_done_orb.png'
      : 'assets/images/ui/clean/progress_active_orb.png';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          final orbSize = 56.0;
          final glowFactor = widget.isActive ? _glowAnimation.value : 0.42;

          return SizedBox(
            width: orbSize,
            height: orbSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.isActive)
                  Container(
                    width: orbSize + (orbSize * 0.30 * glowFactor),
                    height: orbSize + (orbSize * 0.30 * glowFactor),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFB388FF)
                              .withValues(alpha: 0.38 * glowFactor),
                          const Color(0xFF9E6CFF)
                              .withValues(alpha: 0.20 * glowFactor),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                Opacity(
                  opacity: widget.isActive || widget.isCompleted ? 1.0 : 0.45,
                  child: ClipOval(
                    child: Image.asset(
                      _orbAssetPath,
                      width: orbSize,
                      height: orbSize,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => Container(
                        width: orbSize,
                        height: orbSize,
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
                      ),
                    ),
                  ),
                ),
                if (widget.isCompleted)
                  const Icon(
                    Icons.check_rounded,
                    size: 24,
                    color: Color(0xFFFFD478),
                    shadows: [
                      Shadow(color: Color(0xCC000000), blurRadius: 4),
                    ],
                  )
                else if (widget.isActive)
                  const Icon(
                    Icons.auto_awesome,
                    size: 21,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Color(0xCC000000), blurRadius: 4),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

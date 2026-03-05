import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/age_band_theme.dart';

/// Crystal-orb wizard progress indicator.
///
/// Shows step orbs with optional visible labels beneath each orb.
class MoonPhaseProgress extends StatelessWidget {
  final int currentStep; // 0-2
  final int totalSteps; // Should be 3
  final List<String> stepLabels; // For screen readers & visible display
  final bool showLabels; // Whether to show text labels beneath orbs

  const MoonPhaseProgress({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
    this.stepLabels = const [
      'Step 1: Create your hero',
      'Step 2: Pick a companion',
      'Step 3: Make magic',
    ],
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final band = Theme.of(context).extension<AgeBandThemeData>();
    // Short labels for the visible text beneath each orb.
    final shortLabels = stepLabels
        .map((l) => l.replaceFirst(RegExp(r'^Step \d+:\s*'), ''))
        .toList();

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CrystalStepOrb(
                  isActive: isActive,
                  isCompleted: isCompleted,
                  label: stepLabels[index],
                  orbIndex: index % 2, // alternates between orb style 1 and 2
                ),
                if (showLabels) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 64,
                    child: Text(
                      shortLabels[index],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _moonLabelStyle(
                        band,
                        isActive: isActive,
                        isCompleted: isCompleted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

TextStyle _moonLabelStyle(
  AgeBandThemeData? band, {
  required bool isActive,
  required bool isCompleted,
}) {
  final color = (isActive || isCompleted) ? Colors.white : Colors.white38;
  final weight = isActive ? FontWeight.bold : FontWeight.normal;
  const size = 10.0;
  switch (band?.uiFontFamily) {
    case 'Nunito':
      return GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color);
    case 'Bitter':
      return GoogleFonts.bitter(fontSize: size, fontWeight: weight, color: color);
    case 'SourceSansPro':
      return GoogleFonts.sourceSans3(fontSize: size, fontWeight: weight, color: color);
    default:
      return GoogleFonts.quicksand(fontSize: size, fontWeight: weight, color: color);
  }
}

class _CrystalStepOrb extends StatefulWidget {
  final bool isActive;
  final bool isCompleted;
  final String label;
  final int orbIndex; // 0 = orb-style-1, 1+ = orb-style-2

  const _CrystalStepOrb({
    required this.isActive,
    required this.isCompleted,
    required this.label,
    this.orbIndex = 0,
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
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
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

  String get _orbAssetPath {
    final variant = widget.orbIndex == 0 ? 'orb1' : 'orb2';
    if (widget.isCompleted) return 'assets/images/ui/clean/progress_${variant}_done.png';
    if (widget.isActive) return 'assets/images/ui/clean/progress_${variant}_active.png';
    return 'assets/images/ui/clean/progress_${variant}_idle.png';
  }

  @override
  Widget build(BuildContext context) {
    const orbSize = 56.0;

    return Semantics(
      label: widget.label,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          final glowFactor = widget.isActive ? _glowAnimation.value : 0.0;

          return SizedBox(
            width: orbSize + 8,
            height: orbSize + 8,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing glow behind active orb
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
                // Orb image (background removed via ImageMagick)
                Opacity(
                  opacity: widget.isActive || widget.isCompleted ? 1.0 : 0.35,
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
                // Gold checkmark badge when completed
                if (widget.isCompleted)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF2ECC71),
                        boxShadow: [BoxShadow(color: Color(0xFF27AE60), blurRadius: 4)],
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

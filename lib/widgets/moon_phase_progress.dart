import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/age_band_theme.dart';

/// Gold step wizard progress indicator.
///
/// Renders numbered gold circles connected by thin gold lines,
/// with labels beneath each step. Fully coded — no image assets.
class MoonPhaseProgress extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepLabels;
  /// Optional illustrated icons (emoji strings) shown instead of text labels.
  /// When provided, each step shows a large emoji rather than the text label.
  /// Intended for Sprout band where children cannot read the labels.
  final List<String>? stepIcons;
  final bool showLabels;
  final ValueChanged<int>? onStepTap;

  const MoonPhaseProgress({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
    this.stepLabels = const [
      'Step 1: Create your hero',
      'Step 2: Pick a companion',
      'Step 3: Begin',
    ],
    this.stepIcons,
    this.showLabels = true,
    this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    final band = Theme.of(context).extension<AgeBandThemeData>();
    final shortLabels = stepLabels
        .map((l) => l.replaceFirst(RegExp(r'^Step \d+:\s*'), ''))
        .toList();

    return Semantics(
      label:
          'Progress: ${stepLabels[currentStep]}, step ${currentStep + 1} of $totalSteps',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(totalSteps * 2 - 1, (i) {
          // Even indices = step circles, odd indices = connector lines
          if (i.isOdd) {
            final stepIndex = i ~/ 2;
            final isDone = stepIndex < currentStep;
            return _StepConnector(isCompleted: isDone);
          }

          final index = i ~/ 2;
          final isActive = index == currentStep;
          final isCompleted = index < currentStep;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onStepTap == null ? null : () => onStepTap!(index),
                behavior: HitTestBehavior.opaque,
                child: _GoldStepCircle(
                  stepNumber: index + 1,
                  isActive: isActive,
                  isCompleted: isCompleted,
                  label: stepLabels[index],
                ),
              ),
              if (showLabels) ...[
                const SizedBox(height: 5),
                if (stepIcons != null && index < stepIcons!.length)
                  // Illustrated icon mode (Sprout band): big emoji, no text
                  SizedBox(
                    width: 40,
                    child: Text(
                      stepIcons![index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isActive ? 22 : 17,
                        // Fade non-active icons for non-done steps
                        color: isCompleted || isActive
                            ? null
                            : Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: 76,
                    child: Text(
                      shortLabels[index],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _stepLabelStyle(
                        band,
                        isActive: isActive,
                        isCompleted: isCompleted,
                      ),
                    ),
                  ),
              ],
            ],
          );
        }),
      ),
    );
  }
}

class _StepConnector extends StatelessWidget {
  final bool isCompleted;
  const _StepConnector({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Vertically centre the line with the 44px circles
      padding: const EdgeInsets.only(top: 22),
      child: Container(
        width: 28,
        height: 1.5,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isCompleted
                ? [const Color(0xFFFFD54F), const Color(0xFFFFE082)]
                : [
                    const Color(0xFFFFD54F).withAlpha(60),
                    const Color(0xFFFFD54F).withAlpha(60),
                  ],
          ),
        ),
      ),
    );
  }
}

TextStyle _stepLabelStyle(
  AgeBandThemeData? band, {
  required bool isActive,
  required bool isCompleted,
}) {
  final color = isActive
      ? const Color(0xFFFFE082)
      : isCompleted
          ? Colors.white70
          : Colors.white38;
  final weight = isActive ? FontWeight.bold : FontWeight.normal;
  const size = 11.0;
  switch (band?.uiFontFamily) {
    case 'Nunito':
      return GoogleFonts.nunito(
          fontSize: size, fontWeight: weight, color: color);
    case 'Bitter':
      return GoogleFonts.bitter(
          fontSize: size, fontWeight: weight, color: color);
    case 'SourceSansPro':
      return GoogleFonts.sourceSans3(
          fontSize: size, fontWeight: weight, color: color);
    default:
      return GoogleFonts.quicksand(
          fontSize: size, fontWeight: weight, color: color);
  }
}

class _GoldStepCircle extends StatefulWidget {
  final int stepNumber;
  final bool isActive;
  final bool isCompleted;
  final String label;

  const _GoldStepCircle({
    required this.stepNumber,
    required this.isActive,
    required this.isCompleted,
    required this.label,
  });

  @override
  State<_GoldStepCircle> createState() => _GoldStepCircleState();
}

class _GoldStepCircleState extends State<_GoldStepCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
    if (widget.isActive) _glowCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_GoldStepCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _glowCtrl.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _glowCtrl.stop();
      _glowCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 44.0;

    return Semantics(
      label: widget.label,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _glowAnim,
        builder: (context, _) {
          final g = widget.isActive ? _glowAnim.value : 0.0;

          return SizedBox(
            width: size + 12,
            height: size + 12,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing outer glow for active step
                if (widget.isActive)
                  Container(
                    width: size + 8 + (10 * g),
                    height: size + 8 + (10 * g),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFD54F).withAlpha((80 * g).round()),
                          const Color(0xFFFFD54F).withAlpha((30 * g).round()),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                // Main circle
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.isActive
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.lerp(const Color(0xFFFFE082),
                                  const Color(0xFFFFD54F), g)!,
                              const Color(0xFFFFAB00),
                            ],
                          )
                        : widget.isCompleted
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                              )
                            : null,
                    color: (!widget.isActive && !widget.isCompleted)
                        ? const Color(0xFF2A0A4E).withAlpha(180)
                        : null,
                    border: Border.all(
                      color: widget.isActive || widget.isCompleted
                          ? const Color(0xFFFFD54F)
                          : const Color(0xFFFFD54F).withAlpha(70),
                      width: widget.isActive ? 2.0 : 1.5,
                    ),
                    boxShadow: widget.isActive
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFD54F)
                                  .withAlpha((100 * g).round()),
                              blurRadius: 12 * g,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: widget.isCompleted
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 20)
                        : Text(
                            '${widget.stepNumber}',
                            style: TextStyle(
                              color: widget.isActive
                                  ? const Color(0xFF3E2000)
                                  : const Color(0xFFFFD54F).withAlpha(160),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

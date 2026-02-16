import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

/// Image-based Make Magic Button using transparent PNG asset
/// Features pulsing animation and sparkle effects
class ImageMakeMagicButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isEnabled;

  const ImageMakeMagicButton({
    super.key,
    this.label = 'Make Magic',
    required this.onTap,
    this.isEnabled = true,
  });

  @override
  State<ImageMakeMagicButton> createState() => _ImageMakeMagicButtonState();
}

class _ImageMakeMagicButtonState extends State<ImageMakeMagicButton>
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
  void didUpdateWidget(ImageMakeMagicButton oldWidget) {
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

    // Haptic feedback
    HapticFeedback.lightImpact();

    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = math.min(screenWidth * 0.86, 360.0);
    final borderColor =
        widget.isEnabled ? const Color(0xFFFFD478) : const Color(0xFF9A93AB);

    return Semantics(
      button: true,
      enabled: widget.isEnabled,
      label: widget.label,
      hint: 'Start creating your magical story',
      child: ScaleTransition(
        scale: widget.isEnabled
            ? _pulseAnimation
            : const AlwaysStoppedAnimation(1.0),
        child: GestureDetector(
          onTap: _handleTap,
          child: SizedBox(
            width: buttonWidth,
            height: 88, // Standard large touch target
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow effect
                if (widget.isEnabled)
                  Container(
                    width: buttonWidth + 20,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9E6CFF).withValues(alpha: 0.6),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: const Color(0xFFFFD478).withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),

                // Code-rendered magical button avoids checkerboard artifacts from legacy JPG assets.
                Container(
                  width: buttonWidth,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: widget.isEnabled
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFBE73FF),
                              Color(0xFF7E3FC6),
                              Color(0xFF57238B),
                            ],
                            stops: [0.0, 0.45, 1.0],
                          )
                        : const LinearGradient(
                            colors: [
                              Color(0xFF8A8297),
                              Color(0xFF666072),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(44),
                    border: Border.all(color: borderColor, width: 3.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 10,
                        left: 24,
                        child: Icon(
                          Icons.auto_awesome,
                          color: const Color(0xFFFFE6A1)
                              .withValues(alpha: widget.isEnabled ? 0.85 : 0.4),
                          size: 17,
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        right: 26,
                        child: Icon(
                          Icons.auto_awesome,
                          color: const Color(0xFFFFE6A1)
                              .withValues(alpha: widget.isEnabled ? 0.85 : 0.4),
                          size: 15,
                        ),
                      ),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: Color(0xAAFFFFFF),
                              blurRadius: 10,
                            ),
                            Shadow(
                              color: Color(0x88000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
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

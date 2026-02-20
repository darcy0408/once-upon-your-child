import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

/// Image-based Continue Button using the Codex-generated PNG asset.
/// Mirrors the pulsing/glow behaviour of [ImageMakeMagicButton].
class ImageContinueButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isEnabled;

  const ImageContinueButton({
    super.key,
    required this.onTap,
    this.isEnabled = true,
  });

  @override
  State<ImageContinueButton> createState() => _ImageContinueButtonState();
}

class _ImageContinueButtonState extends State<ImageContinueButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isEnabled) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ImageContinueButton oldWidget) {
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
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = math.min(screenWidth * 0.72, 300.0);

    return Semantics(
      button: true,
      enabled: widget.isEnabled,
      label: 'Continue',
      hint: 'Proceed to the next step',
      child: ScaleTransition(
        scale: widget.isEnabled
            ? _pulseAnimation
            : const AlwaysStoppedAnimation(1.0),
        child: GestureDetector(
          onTap: _handleTap,
          child: SizedBox(
            width: buttonWidth,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow
                if (widget.isEnabled)
                  Container(
                    width: buttonWidth + 16,
                    height: 84,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(42),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9E6CFF).withValues(alpha: 0.5),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: const Color(0xFFFFD478).withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                // Button image
                Opacity(
                  opacity: widget.isEnabled ? 1.0 : 0.45,
                  child: Image.asset(
                    'assets/images/ui/continue_btn_codex.png',
                    width: buttonWidth,
                    height: 72,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => _FallbackContinueButton(
                      width: buttonWidth,
                      isEnabled: widget.isEnabled,
                    ),
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

class _FallbackContinueButton extends StatelessWidget {
  final double width;
  final bool isEnabled;
  const _FallbackContinueButton(
      {required this.width, required this.isEnabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 72,
      decoration: BoxDecoration(
        gradient: isEnabled
            ? const LinearGradient(
                colors: [Color(0xFF5B1BAA), Color(0xFF9B3FD8), Color(0xFF5B1BAA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF8A8297), Color(0xFF666072)],
              ),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFFFFD700), width: 2),
      ),
      child: const Center(
        child: Text(
          'CONTINUE',
          style: TextStyle(
            color: Color(0xFFFFE066),
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

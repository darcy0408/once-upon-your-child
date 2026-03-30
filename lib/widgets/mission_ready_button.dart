import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Adventurer-band (9–11) launch button for the Magic Review step.
/// Rectangular with a pulsing teal border — replaces the orb-shaped
/// ImageMakeMagicButton for this band.
class MissionReadyButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isEnabled;

  const MissionReadyButton({
    super.key,
    required this.onTap,
    this.isEnabled = true,
  });

  @override
  State<MissionReadyButton> createState() => _MissionReadyButtonState();
}

class _MissionReadyButtonState extends State<MissionReadyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
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
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF80CBC4).withValues(alpha: _pulse.value),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF80CBC4)
                    .withValues(alpha: _pulse.value * 0.35),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isEnabled ? widget.onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D2B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
              child: Text(
                'MISSION READY',
                style: GoogleFonts.bitter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.isEnabled
                      ? const Color(0xFF80CBC4)
                      : const Color(0xFF80CBC4).withValues(alpha: 0.4),
                  letterSpacing: 3.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

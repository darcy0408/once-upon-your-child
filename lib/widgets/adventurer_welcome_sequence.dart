import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Animated "loading your adventure profile" splash for the Adventurer band
/// (ages 9–11) shown on the welcome screen title step.
///
/// Runs a 3-stage staggered text reveal, then calls [onComplete] to advance.
class AdventurerWelcomeSequence extends StatefulWidget {
  final String? userName;
  final VoidCallback onComplete;

  const AdventurerWelcomeSequence({
    super.key,
    this.userName,
    required this.onComplete,
  });

  @override
  State<AdventurerWelcomeSequence> createState() =>
      _AdventurerWelcomeSequenceState();
}

class _AdventurerWelcomeSequenceState extends State<AdventurerWelcomeSequence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Stage intervals
  static const _s1Start = 0.0;
  static const _s1End = 0.28;
  static const _s2Start = 0.30;
  static const _s2End = 0.62;
  static const _s3Start = 0.64;
  static const _s3End = 0.92;

  late final Animation<double> _stage1;
  late final Animation<double> _stage2;
  late final Animation<double> _stage3;
  late final Animation<double> _iconRotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _stage1 = _fadeFor(_s1Start, _s1End);
    _stage2 = _fadeFor(_s2Start, _s2End);
    _stage3 = _fadeFor(_s3Start, _s3End);
    _iconRotation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _ctrl.forward().whenComplete(() {
      if (mounted) widget.onComplete();
    });
  }

  Animation<double> _fadeFor(double start, double end) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, end),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final greeting = widget.userName?.isNotEmpty == true
        ? 'Welcome back, ${widget.userName}.'
        : 'Adventure awaits.';

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 48),

            // Rotating compass/shield icon
            RotationTransition(
              turns: _iconRotation,
              child: const Icon(
                Icons.explore_rounded,
                size: 56,
                color: Color(0xFF80CBC4),
              ),
            ),
            const SizedBox(height: 28),

            // Stage 1: Initializing...
            Opacity(
              opacity: _stage1.value,
              child: Text(
                'Initializing...',
                textAlign: TextAlign.center,
                style: GoogleFonts.bitter(
                  fontSize: 16,
                  color: const Color(0xFF80CBC4),
                  letterSpacing: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

            // Stage 2: Loading your adventure profile...
            Opacity(
              opacity: _stage2.value,
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF80CBC4), Color(0xFFFFD700), Color(0xFF80CBC4)],
                ).createShader(bounds),
                child: Text(
                  'Loading your adventure profile...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bitter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // Stage 3: Personalised greeting
            Opacity(
              opacity: _stage3.value,
              child: Text(
                greeting,
                textAlign: TextAlign.center,
                style: GoogleFonts.bitter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFD700),
                ),
              ),
            ),

            const SizedBox(height: 48),
          ],
        );
      },
    );
  }
}

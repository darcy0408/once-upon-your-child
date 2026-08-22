import 'package:flutter/material.dart';
import '../utils/motion_utils.dart';
import '../widgets/safe_asset_image.dart';

/// Full-screen splash that fades in the "Once Upon YOUR Child" logo,
/// holds it briefly, then fades out and calls [onComplete].
///
/// MT-387: the 4-second hold is skippable. Tapping anywhere completes
/// immediately, and a hint fades in partway through so the affordance is
/// discoverable — an unskippable splash is four seconds of nothing on every
/// single launch. Reduced-motion users skip the animation entirely.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _fadeOut;
  late final Animation<double> _hintFade;

  /// Guards [onComplete] against firing from both the tap and the controller.
  bool _finished = false;
  bool _reduceMotionHandled = false;

  @override
  void initState() {
    super.initState();

    // Total duration: 0.6s fade-in + 2.8s hold + 0.6s fade-out = 4.0s
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    // Fade in during 0–15% (≈0.6s)
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.15, curve: Curves.easeIn),
      ),
    );

    // Fade out during 85–100% (≈0.6s)
    _fadeOut = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 1.0, curve: Curves.easeOut),
      ),
    );

    // Hint fades in between 1.6s and 2.4s — after the logo has landed, with
    // enough of the hold left for the cue to be worth acting on.
    _hintFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.6, curve: Curves.easeIn),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _complete();
      }
    });

    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: don't hold the user through a fade they can't perceive
    // the point of. Finish immediately rather than animating to the same end.
    if (!_reduceMotionHandled && MotionPrefs.reduceMotion(context)) {
      _reduceMotionHandled = true;
      _controller.stop();
      // Post-frame: onComplete swaps the root route, and doing that
      // synchronously from didChangeDependencies markNeedsBuild()s an
      // ancestor mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _complete();
      });
    }
  }

  /// Completes exactly once. Both the tap and the animation's status listener
  /// can reach here, and firing [onComplete] twice would push the next route
  /// twice.
  void _complete() {
    if (_finished) return;
    _finished = true;
    widget.onComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Matches the averaged corner color of the logo art's starfield, so the
      // square image dissolves into the page instead of sitting in a box.
      backgroundColor: const Color(0xFF05020F),
      body: GestureDetector(
        onTap: _complete,
        // Opaque so the whole screen is the tap target, including the
        // letterbox bands above and below the square art.
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          button: true,
          label: 'Skip intro',
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Combine fade-in and fade-out: during the hold both are 1.0
                  final opacity = _fadeIn.value * _fadeOut.value;
                  return Opacity(
                    opacity: opacity,
                    child: child,
                  );
                },
                // Fill the screen: on a portrait phone the square art spans the
                // full width, centered vertically, with the letterbox bands
                // blending into the matching background color above.
                child: SizedBox.expand(
                  child: SafeAssetImage(
                    'assets/images/splash_logo.webp',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 32,
                child: SafeArea(
                  child: FadeTransition(
                    key: const ValueKey('splash-skip-hint'),
                    opacity: _hintFade,
                    child: const Text(
                      'Tap to skip',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        // white54 is the lowest white opacity that clears
                        // 4.5:1 on a dark background — white38 and below fail.
                        color: Colors.white54,
                        fontSize: 13,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

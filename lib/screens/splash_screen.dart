import 'package:flutter/material.dart';
import '../widgets/safe_asset_image.dart';

/// Full-screen splash that fades in the "Once Upon YOUR Child" logo,
/// holds it briefly, then fades out and calls [onComplete].
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

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
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
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Combine fade-in and fade-out: during the hold period both are 1.0
          final opacity = _fadeIn.value * _fadeOut.value;
          return Opacity(
            opacity: opacity,
            child: child,
          );
        },
        // Fill the screen: on a portrait phone the square art spans the full
        // width, centered vertically, with the letterbox bands blending into
        // the matching background color above.
        child: SizedBox.expand(
          child: SafeAssetImage(
            'assets/images/splash_logo.webp',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

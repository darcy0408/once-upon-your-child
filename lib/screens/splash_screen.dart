import 'package:flutter/material.dart';

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

    // Total duration: 0.4s fade-in + 1.6s hold + 0.4s fade-out = 2.4s
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // Fade in during 0–17% (≈0.4s)
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.17, curve: Curves.easeIn),
      ),
    );

    // Fade out during 83–100% (≈0.4s)
    _fadeOut = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.83, 1.0, curve: Curves.easeOut),
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
      backgroundColor: const Color(0xFF3A1078), // deep purple from the logo
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
        child: Center(
          child: Image.asset(
            'assets/images/splash_logo.png',
            width: 320,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

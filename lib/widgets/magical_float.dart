import 'package:flutter/material.dart';
import '../utils/motion_utils.dart';

/// A reusable widget that adds a "breathing" / "alive" floating animation.
/// Moves the child up and down smoothly.
class MagicalFloat extends StatefulWidget {
  final Widget child;
  final double distance;
  final Duration duration;
  final double delay;

  const MagicalFloat({
    super.key,
    required this.child,
    this.distance = 5.0,
    this.duration = const Duration(seconds: 3),
    this.delay = 0.0,
  });

  @override
  State<MagicalFloat> createState() => _MagicalFloatState();
}

class _MagicalFloatState extends State<MagicalFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Apply phase offset by starting at a random or fixed point in the animation
    if (widget.delay > 0) {
      _controller.value = (widget.delay % widget.duration.inMilliseconds) /
          widget.duration.inMilliseconds;
    }

    // Repeat is started in didChangeDependencies so MotionPrefs.reduceMotion
    // is honored at runtime (A11Y-007 sweep).

    _animation = Tween<double>(begin: -widget.distance, end: widget.distance)
        .animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPrefs.reduceMotion(context)) {
      _controller.stop();
      // Settle to the midpoint so the offset is 0 — child renders centred.
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MotionPrefs.reduceMotion(context)) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../utils/motion_utils.dart';

/// Wraps [child] with a subtle 3-D parallax tilt that responds to horizontal
/// (and optionally vertical) drag gestures — movie-poster effect.
///
/// On pan end the card springs back to flat using [Curves.easeOutCubic].
/// Respects [MotionPrefs.reduceMotion]: passes through child unmodified when
/// reduced motion is requested.
class ParallaxTiltCard extends StatefulWidget {
  final Widget child;

  /// Maximum tilt in degrees on each axis. Default 8°.
  final double maxTiltDegrees;

  /// Perspective depth value for the Matrix4. Default 0.002.
  final double perspective;

  /// Whether to also tilt on the Y axis (vertical drag). Default true.
  final bool tiltVertical;

  /// Duration of the spring-back animation. Default 350ms.
  final Duration springDuration;

  const ParallaxTiltCard({
    super.key,
    required this.child,
    this.maxTiltDegrees = 8.0,
    this.perspective = 0.002,
    this.tiltVertical = true,
    this.springDuration = const Duration(milliseconds: 350),
  });

  @override
  State<ParallaxTiltCard> createState() => _ParallaxTiltCardState();
}

class _ParallaxTiltCardState extends State<ParallaxTiltCard>
    with SingleTickerProviderStateMixin {
  // Current tilt: x = horizontal, y = vertical (in -1…1 normalised range)
  double _nx = 0.0;
  double _ny = 0.0;

  // Spring-back animation
  late AnimationController _springController;
  late Animation<double> _springX;
  late Animation<double> _springY;
  double _springStartX = 0.0;
  double _springStartY = 0.0;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      duration: widget.springDuration,
      vsync: this,
    )..addListener(() {
        setState(() {
          _nx = _springX.value;
          _ny = _springY.value;
        });
      });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails d, BoxConstraints constraints) {
    _springController.stop();
    setState(() {
      _nx = (_nx + d.delta.dx / (constraints.maxWidth / 2)).clamp(-1.0, 1.0);
      if (widget.tiltVertical) {
        _ny =
            (_ny + d.delta.dy / (constraints.maxHeight / 2)).clamp(-1.0, 1.0);
      }
    });
  }

  void _onPanEnd(DragEndDetails _) {
    _springStartX = _nx;
    _springStartY = _ny;
    _springX = Tween<double>(begin: _springStartX, end: 0.0).animate(
      CurvedAnimation(
          parent: _springController, curve: Curves.easeOutCubic),
    );
    _springY = Tween<double>(begin: _springStartY, end: 0.0).animate(
      CurvedAnimation(
          parent: _springController, curve: Curves.easeOutCubic),
    );
    _springController
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    if (MotionPrefs.reduceMotion(context)) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxRad = widget.maxTiltDegrees * math.pi / 180;
        final rotX = _ny * maxRad; // tilt around X axis → vertical lean
        final rotY = _nx * maxRad; // tilt around Y axis → horizontal lean

        return GestureDetector(
          onPanUpdate: (d) => _onPanUpdate(d, constraints),
          onPanEnd: _onPanEnd,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, widget.perspective)
              ..rotateX(-rotX)
              ..rotateY(rotY),
            child: widget.child,
          ),
        );
      },
    );
  }
}

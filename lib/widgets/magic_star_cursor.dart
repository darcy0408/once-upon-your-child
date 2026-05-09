import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Wraps any widget with a magical star cursor overlay on web.
/// On non-web platforms the child is returned unchanged.
class MagicStarCursor extends StatefulWidget {
  const MagicStarCursor({super.key, required this.child});

  final Widget child;

  /// Global kill-switch. Tests/headless runs flip this to `false` to skip the
  /// overlay entirely. The auto-detect in [_runtimeDisabled] also catches
  /// `flutter test` automatically — without that, dartdevc + headless Chrome
  /// asserts during paint and floods Sentry (~1000 events/run).
  static bool enabled = true;

  static bool get _runtimeDisabled =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  State<MagicStarCursor> createState() => _MagicStarCursorState();
}

class _MagicStarCursorState extends State<MagicStarCursor>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<_OverlayFrame> _frame =
      ValueNotifier(const _OverlayFrame.empty());
  final List<_Sparkle> _sparkles = [];
  final _rand = Random();
  Offset _cursor = Offset.zero;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onHover(PointerEvent event) {
    _cursor = event.localPosition;
    final now = _lastTick;
    final n = 2 + _rand.nextInt(2);
    for (var i = 0; i < n; i++) {
      _sparkles.add(_Sparkle(
        position: _cursor +
            Offset(
              (_rand.nextDouble() - 0.5) * 18,
              (_rand.nextDouble() - 0.5) * 18,
            ),
        bornAt: now,
        color: _sparkleColor(),
        size: 4 + _rand.nextDouble() * 7,
        angle: _rand.nextDouble() * pi * 2,
      ));
    }
  }

  void _onTick(Duration elapsed) {
    _lastTick = elapsed;
    // Drop sparkles older than 600ms.
    final cutoff = elapsed - const Duration(milliseconds: 600);
    _sparkles.removeWhere((s) => s.bornAt < cutoff);

    // 0.85..1.15 pulse on a 700ms triangle wave.
    final phase = (elapsed.inMicroseconds % 1400000) / 1400000.0;
    final tri = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    final eased = Curves.easeInOut.transform(tri);
    final pulse = 0.85 + eased * 0.30;

    _frame.value = _OverlayFrame(
      cursor: _cursor,
      pulse: pulse,
      sparkles: List.of(_sparkles),
      now: elapsed,
    );
  }

  Color _sparkleColor() {
    const colors = [
      Color(0xFFFFD700),
      Color(0xFFFFE066),
      Color(0xFFB87FFF),
      Color(0xFFFFFFFF),
      Color(0xFFFF88FF),
    ];
    return colors[_rand.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb ||
        !MagicStarCursor.enabled ||
        MagicStarCursor._runtimeDisabled) {
      return widget.child;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.none,
      onHover: _onHover,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: ValueListenableBuilder<_OverlayFrame>(
                  valueListenable: _frame,
                  builder: (_, frame, __) => CustomPaint(
                    painter: _OverlayPainter(frame),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sparkle {
  final Offset position;
  final Duration bornAt;
  final Color color;
  final double size;
  final double angle;

  const _Sparkle({
    required this.position,
    required this.bornAt,
    required this.color,
    required this.size,
    required this.angle,
  });
}

@immutable
class _OverlayFrame {
  final Offset cursor;
  final double pulse;
  final List<_Sparkle> sparkles;
  final Duration now;

  const _OverlayFrame({
    required this.cursor,
    required this.pulse,
    required this.sparkles,
    required this.now,
  });

  const _OverlayFrame.empty()
      : cursor = Offset.zero,
        pulse = 1.0,
        sparkles = const [],
        now = Duration.zero;
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter(this.frame);
  final _OverlayFrame frame;

  static const _cursorColor = Color(0xFFFFE066);
  static const _glowColor = Color(0x66FFE066);

  @override
  void paint(Canvas canvas, Size size) {
    // Sparkles
    for (final s in frame.sparkles) {
      final age = (frame.now - s.bornAt).inMilliseconds;
      final opacity = (1.0 - age / 600.0).clamp(0.0, 1.0);
      if (opacity <= 0) continue;
      canvas.save();
      canvas.translate(s.position.dx, s.position.dy);
      canvas.rotate(s.angle);
      _drawStar(
        canvas,
        radius: s.size / 2,
        color: s.color.withValues(alpha: opacity),
        glow: false,
      );
      canvas.restore();
    }

    // Main cursor star
    final r = 16.0 * frame.pulse;
    canvas.save();
    canvas.translate(frame.cursor.dx, frame.cursor.dy);
    _drawStar(canvas, radius: r, color: _cursorColor, glow: true);
    canvas.restore();
  }

  void _drawStar(Canvas canvas,
      {required double radius, required Color color, required bool glow}) {
    final outer = radius;
    final inner = outer * 0.25;
    const points = 4;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final angle = (i * pi / points) - pi / 2;
      final x = r * cos(angle);
      final y = r * sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();

    if (glow) {
      // Cheap glow: radial gradient circle behind the solid star. Avoids
      // MaskFilter.blur, which destabilizes CanvasKit when redrawn every frame.
      final glowPaint = Paint()
        ..shader = const RadialGradient(
          colors: [_glowColor, Color(0x00FFE066)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: outer * 1.6));
      canvas.drawCircle(Offset.zero, outer * 1.6, glowPaint);
    }

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => !identical(old.frame, frame);
}

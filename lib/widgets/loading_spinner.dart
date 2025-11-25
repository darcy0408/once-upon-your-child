import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LoadingSpinner extends StatefulWidget {
  final String? message;
  final double size;

  const LoadingSpinner({
    super.key,
    this.message,
    this.size = 56,
  });

  @override
  State<LoadingSpinner> createState() => _LoadingSpinnerState();
}

class _LoadingSpinnerState extends State<LoadingSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return CustomPaint(
                painter: _SpinnerPainter(progress: _controller.value),
              );
            },
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.message!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  final double progress;

  _SpinnerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.08;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: const [AppColors.primary, AppColors.accent],
        startAngle: 0,
        endAngle: 3.14 * 2,
      ).createShader(rect);
    final startAngle = progress * 6.283;
    const sweepAngle = 6.283 * 0.6;
    canvas.drawArc(
      Rect.fromLTWH(stroke, stroke, size.width - stroke * 2, size.height - stroke * 2),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

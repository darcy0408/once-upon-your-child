import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:story_weaver_app/theme/app_theme.dart';

/// A magical storybook page widget that wraps content with decorative book aesthetics.
///
/// Features:
/// - Parchment-colored background (#FFF8E7)
/// - Decorative corner ornaments with gold accents
/// - Gold border with glow effect
/// - Elegant shadows for depth
/// - Configurable padding and decorations
class StoryBookPage extends StatelessWidget {
  const StoryBookPage({
    super.key,
    required this.child,
    this.showDecorations = true,
    this.contentPadding,
    this.backgroundColor = const Color(0xFFFFF8E7), // Parchment
  });

  final Widget child;
  final bool showDecorations;
  final EdgeInsets? contentPadding;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.1),
            blurRadius: 0,
            spreadRadius: 4,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Spine shadow (Inner shadow on the left/right depending on page side)
          // For simplicity, we add a subtle spine shadow on the left
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 30,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Edge highlight (Top/Right edge highlight)
          Positioned(
            right: 2,
            top: 2,
            bottom: 2,
            width: 4,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.2),
                  ],
                ),
              ),
            ),
          ),

          // Paper Texture Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: PaperTexturePainter(
                  opacity: 0.05,
                ),
              ),
            ),
          ),

          // Main content
          Padding(
            padding: contentPadding ??
                const EdgeInsets.fromLTRB(40, 50, 40, 40),
            child: child,
          ),

          // Paper texture overlay
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: PaperTexturePainter(
                  opacity: 0.04,
                ),
              ),
            ),
          ),

          // Corner ornaments
          if (showDecorations) ...[
            // Top-left corner
            Positioned(
              top: 0,
              left: 0,
              child: CustomPaint(
                size: const Size(40, 40),
                painter: BookCornerPainter(
                  cornerPosition: CornerPosition.topLeft,
                ),
              ),
            ),

            // Top-right corner
            Positioned(
              top: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(40, 40),
                painter: BookCornerPainter(
                  cornerPosition: CornerPosition.topRight,
                ),
              ),
            ),

            // Bottom-left corner
            Positioned(
              bottom: 0,
              left: 0,
              child: CustomPaint(
                size: const Size(40, 40),
                painter: BookCornerPainter(
                  cornerPosition: CornerPosition.bottomLeft,
                ),
              ),
            ),

            // Bottom-right corner
            Positioned(
              bottom: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(40, 40),
                painter: BookCornerPainter(
                  cornerPosition: CornerPosition.bottomRight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Subtle paper speckle overlay used by [StoryBookPage].
class PaperTexturePainter extends CustomPainter {
  const PaperTexturePainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: opacity)
      ..strokeWidth = 1;

    // Deterministic speckle pattern (no randomness) to keep goldens stable.
    const step = 14.0;
    for (double y = 4; y < size.height; y += step) {
      for (double x = 3; x < size.width; x += step) {
        canvas.drawPoints(ui.PointMode.points, [Offset(x, y)], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PaperTexturePainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}

/// Position of the corner ornament
enum CornerPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// Custom painter for drawing elegant corner ornaments
class BookCornerPainter extends CustomPainter {
  BookCornerPainter({
    required this.cornerPosition,
  });

  final CornerPosition cornerPosition;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Create gradient shader
    final shader = LinearGradient(
      colors: [
        AppColors.gold,
        AppColors.goldLight,
        AppColors.gold,
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    paint.shader = shader;

    // Draw ornament based on corner position
    _drawOrnament(canvas, size, paint);
  }

  void _drawOrnament(Canvas canvas, Size size, Paint paint) {
    final path = Path();

    switch (cornerPosition) {
      case CornerPosition.topLeft:
        // Main curved flourish from (0, 30) to (30, 0)
        path.moveTo(0, 30);
        path.quadraticBezierTo(0, 15, 15, 0);
        path.lineTo(30, 0);

        // Inner accent curve
        path.moveTo(5, 25);
        path.quadraticBezierTo(5, 15, 15, 5);
        path.lineTo(25, 5);

        canvas.drawPath(path, paint);

        // Decorative dots
        final dotPaint = Paint()
          ..color = AppColors.gold
          ..style = PaintingStyle.fill;

        canvas.drawCircle(const Offset(8, 22), 2, dotPaint);
        canvas.drawCircle(const Offset(15, 15), 2, dotPaint);
        canvas.drawCircle(const Offset(22, 8), 2, dotPaint);
        break;

      case CornerPosition.topRight:
        // Mirror of top-left
        path.moveTo(size.width, 30);
        path.quadraticBezierTo(size.width, 15, size.width - 15, 0);
        path.lineTo(size.width - 30, 0);

        path.moveTo(size.width - 5, 25);
        path.quadraticBezierTo(size.width - 5, 15, size.width - 15, 5);
        path.lineTo(size.width - 25, 5);

        canvas.drawPath(path, paint);

        final dotPaint = Paint()
          ..color = AppColors.gold
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(size.width - 8, 22), 2, dotPaint);
        canvas.drawCircle(Offset(size.width - 15, 15), 2, dotPaint);
        canvas.drawCircle(Offset(size.width - 22, 8), 2, dotPaint);
        break;

      case CornerPosition.bottomLeft:
        // Flip of top-left
        path.moveTo(0, size.height - 30);
        path.quadraticBezierTo(0, size.height - 15, 15, size.height);
        path.lineTo(30, size.height);

        path.moveTo(5, size.height - 25);
        path.quadraticBezierTo(5, size.height - 15, 15, size.height - 5);
        path.lineTo(25, size.height - 5);

        canvas.drawPath(path, paint);

        final dotPaint = Paint()
          ..color = AppColors.gold
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(8, size.height - 22), 2, dotPaint);
        canvas.drawCircle(Offset(15, size.height - 15), 2, dotPaint);
        canvas.drawCircle(Offset(22, size.height - 8), 2, dotPaint);
        break;

      case CornerPosition.bottomRight:
        // Mirror and flip of top-left
        path.moveTo(size.width, size.height - 30);
        path.quadraticBezierTo(
          size.width,
          size.height - 15,
          size.width - 15,
          size.height,
        );
        path.lineTo(size.width - 30, size.height);

        path.moveTo(size.width - 5, size.height - 25);
        path.quadraticBezierTo(
          size.width - 5,
          size.height - 15,
          size.width - 15,
          size.height - 5,
        );
        path.lineTo(size.width - 25, size.height - 5);

        canvas.drawPath(path, paint);

        final dotPaint = Paint()
          ..color = AppColors.gold
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(size.width - 8, size.height - 22), 2, dotPaint);
        canvas.drawCircle(Offset(size.width - 15, size.height - 15), 2, dotPaint);
        canvas.drawCircle(Offset(size.width - 22, size.height - 8), 2, dotPaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

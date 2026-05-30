import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:story_weaver_app/theme/app_theme.dart';

/// Which side of a [StoryBookPage] carries the book binding.
///
/// Drives where the spine shadow sits and which corners curl: a left-hand
/// (even) page binds on the right toward the centre of an open book, a
/// right-hand page binds on the left, and a stand-alone single page binds
/// on the left like the front of a closed book.
enum BookBindingSide { left, right }

/// A magical storybook page widget that wraps content with decorative book aesthetics.
///
/// Features:
/// - Parchment-colored background (#FFF8E7)
/// - Decorative corner ornaments with gold accents
/// - Gold border with glow effect
/// - Elegant shadows for depth
/// - A stacked page-edge fan on the outer side so the page reads as one
///   leaf of a thick book rather than a floating card
/// - An optional "Page N of M" badge tucked into the outer bottom corner
/// - Configurable padding and decorations
class StoryBookPage extends StatelessWidget {
  const StoryBookPage({
    super.key,
    required this.child,
    this.showDecorations = true,
    this.contentPadding,
    this.backgroundColor = const Color(0xFFFFF8E7), // Parchment
    this.bindingSide = BookBindingSide.left,
    this.showPageEdges = true,
    this.pageLabel,
    this.darkPage = false,
    this.framed = false,
  });

  final Widget child;
  final bool showDecorations;
  final EdgeInsets? contentPadding;
  final Color backgroundColor;

  /// Side the book spine sits on. The opposite side gets the stacked
  /// page-edge fan and the page-number badge.
  final BookBindingSide bindingSide;

  /// When true, draws a thin fan of page edges along the outer side so the
  /// reader feels they're holding one leaf of many.
  final bool showPageEdges;

  /// Optional "Page N of M" text tucked into the outer bottom corner of the
  /// page itself (replaces the separate pill below the book).
  final String? pageLabel;

  /// True when the page background is dark (mature bands / high contrast) so
  /// the paper edges and badge invert to stay legible.
  final bool darkPage;

  /// True when this leaf sits inside an [OpenBookFrame]. The frame supplies the
  /// cover border and grounding shadow, so the leaf drops its own gold border,
  /// outer glow, and filigree corners (which read "diploma", not "storybook")
  /// and insets its spine to sit just off the frame's gutter (MT-099).
  final bool framed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale chrome to viewport so text actually fits on small phones.
        // Below ~340dp the fixed 40px side padding swallowed half the page.
        final width = constraints.maxWidth;
        final isTiny = width < 340;
        final isCompact = width < 480;
        final spineWidth = isTiny ? 12.0 : (isCompact ? 20.0 : 30.0);
        final ornamentSize = isTiny ? 24.0 : (isCompact ? 32.0 : 40.0);
        final defaultPadding = isTiny
            ? const EdgeInsets.fromLTRB(18, 26, 18, 22)
            : (isCompact
                ? const EdgeInsets.fromLTRB(26, 34, 26, 30)
                : const EdgeInsets.fromLTRB(40, 50, 40, 40));
        // Inside an OpenBookFrame the leather rim is the border, so the leaf
        // sheds its own gold filigree corners.
        final effectiveShowDecorations = showDecorations && !isTiny && !framed;
        final bindLeft = bindingSide == BookBindingSide.left;
        // The binding side gets a deeper spine shadow; the outer side gets
        // the stacked page-edge fan and (optionally) the page-number badge.
        final radius = isCompact ? 16.0 : 20.0;
        // Asymmetric corner rounding: corners on the binding side stay
        // crisp (held by the spine) while the outer corners curl softly.
        final pageRadius = BorderRadius.horizontal(
          left: Radius.circular(bindLeft ? 3 : radius),
          right: Radius.circular(bindLeft ? radius : 3),
        );

        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: pageRadius,
            // Framed leaves drop the gold border + outer glow (the leather
            // cover supplies them); they keep only a soft drop shadow so the
            // leaf still lifts off the book body.
            border: framed
                ? null
                : Border.all(
                    color: AppColors.gold.withValues(alpha: 0.3),
                    width: 2,
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: framed ? 0.18 : 0.15),
                blurRadius: framed ? 10 : 20,
                offset: Offset(0, framed ? 4 : 8),
              ),
              if (!framed)
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  blurRadius: 0,
                  spreadRadius: 4,
                  offset: const Offset(0, 0),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: pageRadius,
            child: Stack(
            children: [
              // Stacked page-edge fan on the OUTER side — three hairline
              // strokes that read as the cut edges of the leaves beneath
              // this one, so the page feels like part of a thick book.
              if (showPageEdges && !isTiny)
                Positioned(
                  top: 6,
                  bottom: 6,
                  left: bindLeft ? null : 0,
                  right: bindLeft ? 0 : null,
                  width: 6,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _PageEdgeStackPainter(
                        onLeft: bindLeft,
                        dark: darkPage,
                      ),
                    ),
                  ),
                ),

              // Spine shadow on the binding edge — deeper than before so a
              // two-page spread reads as a real gutter, not a seam. Inset 2px
              // when framed so it sits just off the OpenBookFrame's gutter.
              Positioned(
                left: bindLeft ? (framed ? 2 : 0) : null,
                right: bindLeft ? null : (framed ? 2 : 0),
                top: 0,
                bottom: 0,
                width: spineWidth,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: bindLeft
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      end: bindLeft
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      colors: [
                        Colors.black.withValues(alpha: 0.22),
                        Colors.black.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // Edge highlight on the OUTER side — a faint catch of light
              // along the page's free edge.
              Positioned(
                left: bindLeft ? null : 2,
                right: bindLeft ? 2 : null,
                top: 2,
                bottom: 2,
                width: 4,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: bindLeft
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      end: bindLeft
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                ),
              ),

              // Paper texture overlay.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: const PaperTexturePainter(
                      opacity: 0.05,
                    ),
                  ),
                ),
              ),

              // Main content.
              Padding(
                padding: contentPadding ?? defaultPadding,
                child: child,
              ),

              // Second pass paper texture for warmth.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: const PaperTexturePainter(
                      opacity: 0.04,
                    ),
                  ),
                ),
              ),

              // Corner ornaments — sized to viewport, hidden on the tiniest phones.
              if (effectiveShowDecorations) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  child: CustomPaint(
                    size: Size(ornamentSize, ornamentSize),
                    painter: BookCornerPainter(
                      cornerPosition: CornerPosition.topLeft,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: CustomPaint(
                    size: Size(ornamentSize, ornamentSize),
                    painter: BookCornerPainter(
                      cornerPosition: CornerPosition.topRight,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: CustomPaint(
                    size: Size(ornamentSize, ornamentSize),
                    painter: BookCornerPainter(
                      cornerPosition: CornerPosition.bottomLeft,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CustomPaint(
                    size: Size(ornamentSize, ornamentSize),
                    painter: BookCornerPainter(
                      cornerPosition: CornerPosition.bottomRight,
                    ),
                  ),
                ),
              ],

              // "Page N of M" badge tucked into the OUTER bottom corner of
              // the page itself — replaces the separate pill that used to
              // float below the book and broke the "this is a page" feel.
              if (pageLabel != null)
                Positioned(
                  bottom: isTiny ? 6 : 10,
                  left: bindLeft ? null : (isTiny ? 14 : 20),
                  right: bindLeft ? (isTiny ? 14 : 20) : null,
                  child: IgnorePointer(
                    child: Text(
                      pageLabel!,
                      style: TextStyle(
                        fontSize: isTiny ? 10 : 11,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: darkPage
                            ? Colors.white.withValues(alpha: 0.45)
                            : const Color(0xFF8C7240)
                                .withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          ),
        );
      },
    );
  }
}

/// Paints a thin fan of page edges along one side of a [StoryBookPage] so a
/// single leaf reads as the top of a thick stack of pages.
class _PageEdgeStackPainter extends CustomPainter {
  const _PageEdgeStackPainter({required this.onLeft, required this.dark});

  /// True to draw the stack flush against the left side of the paint box.
  final bool onLeft;

  /// Dark-page mode flips the edge strokes light so they stay visible.
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final edgeColor = dark
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFF8C7240).withValues(alpha: 0.28);
    // Three hairlines progressively further from the page so they read as
    // receding leaves underneath the current one.
    for (var i = 0; i < 3; i++) {
      paint.color = edgeColor.withValues(
        alpha: edgeColor.a * (1.0 - i * 0.25),
      );
      final x = onLeft ? size.width - 1.0 - i * 2.0 : 1.0 + i * 2.0;
      // A gentle inward bow so the stack curls rather than sitting ruler-straight.
      final bow = (i + 1) * 1.5;
      final path = Path()
        ..moveTo(x, 0)
        ..quadraticBezierTo(
          onLeft ? x - bow : x + bow,
          size.height / 2,
          x,
          size.height,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PageEdgeStackPainter oldDelegate) =>
      oldDelegate.onLeft != onLeft || oldDelegate.dark != dark;
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

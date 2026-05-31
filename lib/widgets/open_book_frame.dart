import 'package:flutter/material.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/theme/app_theme.dart';

/// The leather + body tones that surround a [StoryBookPage] leaf inside an
/// [OpenBookFrame]. Resolved per age band so each band's book has a subtly
/// different cover personality (MT-099, Direction B — "per-band leather").
@immutable
class BookLeatherPalette {
  const BookLeatherPalette({
    required this.leather,
    required this.leatherLight,
    required this.body,
  });

  /// Deep tone of the hardback cover rim.
  final Color leather;

  /// Lit edge of the cover — the highlight along the top of the rim.
  final Color leatherLight;

  /// The matte book "body" colour shown between the leather rim and the
  /// parchment leaf, and in the stacked-leaves footer.
  final Color body;

  /// Resolves the cover tones for a band. Warm reds for the youngest readers,
  /// classic brown for Explorer, deeper walnut for Adventurer, and a midnight
  /// leather for the dark-mode mature bands so the cover never glares against
  /// their near-black backgrounds.
  factory BookLeatherPalette.forBand(AgeBandThemeData band) {
    if (band.preferDarkMode) {
      // Creator / Adolescent / Adult — near-black scaffold, so the cover stays
      // dim and the body is walnut rather than cream.
      return const BookLeatherPalette(
        leather: Color(0xFF241A14),
        leatherLight: Color(0xFF3A2A1E),
        body: AppColors.bookBodyWalnut,
      );
    }
    switch (band.band) {
      case AgeBand.sprout:
        // Warm chestnut — friendliest, most "picture book" of the covers.
        return const BookLeatherPalette(
          leather: Color(0xFF6B3A2A),
          leatherLight: Color(0xFF8A5238),
          body: AppColors.bookBodyCream,
        );
      case AgeBand.adventurer:
        // Deeper walnut for the "cool" older-kid book.
        return const BookLeatherPalette(
          leather: Color(0xFF43301E),
          leatherLight: Color(0xFF5E472F),
          body: AppColors.bookBodyCream,
        );
      case AgeBand.explorer:
      default:
        // Classic brown hardback (the design-doc default).
        return const BookLeatherPalette(
          leather: AppColors.bookCoverLeather,
          leatherLight: AppColors.bookCoverLeatherLight,
          body: AppColors.bookBodyCream,
        );
    }
  }
}

/// Wraps a [StoryBookPage] leaf (or a two-leaf spread) in a decorative open
/// hardback: a leather cover rim, a warm book body behind the leaf, and a
/// stacked-leaves cross-section footer. This is what finally places the
/// parchment leaf *inside a visible book* rather than floating on the purple
/// background (MT-099, Direction B).
///
/// The frame is purely decorative: it adds no gesture handlers and is wrapped
/// in [ExcludeSemantics] so screen readers traverse the leaf content unchanged.
/// In high-contrast mode pass `enabled: false` to fall back to the flat leaf
/// rendering so the textured leather never undercuts legibility.
class OpenBookFrame extends StatelessWidget {
  const OpenBookFrame({
    super.key,
    required this.child,
    required this.palette,
    this.enabled = true,
    this.showFooter = true,
  });

  final Widget child;
  final BookLeatherPalette palette;

  /// When false the frame is a no-op passthrough (high-contrast mode).
  final bool enabled;

  /// The stacked-leaves footer is the first thing to drop on short viewports.
  final bool showFooter;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Scale the chrome down on small phones so the leaf keeps its room.
          final isTiny = constraints.maxWidth < 360;
          final isShort = constraints.maxHeight < 520;
          final coverEdge = isTiny ? 6.0 : 10.0;
          final footerHeight = isTiny ? 10.0 : 14.0;
          final outerRadius = isTiny ? 14.0 : 18.0;
          final innerRadius = outerRadius - coverEdge / 2;
          final renderFooter = showFooter && !isShort;

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(outerRadius),
              // Leather grain: lit top edge fading to the deep cover tone.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [palette.leatherLight, palette.leather],
                stops: const [0.0, 0.6],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            padding: EdgeInsets.all(coverEdge),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(innerRadius),
              child: ColoredBox(
                color: palette.body,
                child: Column(
                  children: [
                    // The leaf (or spread) sits on the warm body, with a small
                    // breathing gap so the flip's 3D shadow can overhang the
                    // leaf edge without being clipped against the leather.
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(isTiny ? 4.0 : 7.0),
                        child: child,
                      ),
                    ),
                    if (renderFooter)
                      SizedBox(
                        height: footerHeight,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _StackedLeavesPainter(body: palette.body),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Paints the cut edges of the page stack as a horizontal cross-section under
/// the active leaf — a few paper-tone hairlines on a faint gradient so the
/// book reads as a thick block of leaves, not a single sheet.
class _StackedLeavesPainter extends CustomPainter {
  const _StackedLeavesPainter({required this.body});

  /// The book body colour; the leaves are tinted darker than it.
  final Color body;

  @override
  void paint(Canvas canvas, Size size) {
    // A soft vertical gradient from the body colour into a slightly deeper
    // tone gives the stack a touch of depth at its base.
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        body,
        Color.lerp(body, Colors.black, 0.18) ?? body,
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // Deterministic hairlines (no randomness) to keep goldens stable.
    final linePaint = Paint()
      ..color = Color.lerp(body, Colors.black, 0.32)!.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final count = (size.height / 4).floor().clamp(2, 4);
    for (var i = 1; i <= count; i++) {
      final y = size.height * i / (count + 1);
      canvas.drawLine(Offset(2, y), Offset(size.width - 2, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StackedLeavesPainter oldDelegate) =>
      oldDelegate.body != body;
}

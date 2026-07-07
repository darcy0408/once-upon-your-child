// lib/widgets/per_page_illustration.dart

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/per_page_illustration_prefetcher.dart';
import 'ai_generated_badge.dart';

/// Renders the prefetcher's state for a single page: the image when ready,
/// a soft skeleton when the reader arrived before generation finished, an
/// upsell card when the free-tier monthly cap is hit, or nothing otherwise.
class PerPageIllustration extends StatelessWidget {
  const PerPageIllustration({
    super.key,
    required this.listenable,
    this.borderRadius = 16,
    this.aspectRatio = 4 / 3,
    this.onTapUpgrade,
  });

  final ValueListenable<PageIllustrationState> listenable;
  final double borderRadius;
  final double aspectRatio;

  /// When provided, [PageIllustrationStatus.quotaExceeded] renders a soft
  /// per-page upsell card and tapping it runs this callback. When null, the
  /// quota-exceeded state is invisible (the screen is expected to surface
  /// the upsell elsewhere, e.g. a single top-of-story banner).
  final VoidCallback? onTapUpgrade;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PageIllustrationState>(
      valueListenable: listenable,
      builder: (context, state, _) {
        switch (state.status) {
          case PageIllustrationStatus.ready:
            final bytes = state.bytes;
            if (bytes == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  // STORE-6/PP-6: freshly-prefetched illustrations are not yet
                  // persisted, so they bypass the story-result badge — label
                  // them here too with the corner "AI" badge.
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                      const Positioned(
                        right: 6,
                        bottom: 6,
                        child: AiGeneratedBadge.corner(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          case PageIllustrationStatus.queued:
          case PageIllustrationStatus.loading:
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _IllustrationSkeleton(
                borderRadius: borderRadius,
                aspectRatio: aspectRatio,
              ),
            );
          case PageIllustrationStatus.quotaExceeded:
            final onTap = onTapUpgrade;
            if (onTap == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _IllustrationUpsellCard(
                borderRadius: borderRadius,
                aspectRatio: aspectRatio,
                onTap: onTap,
              ),
            );
          case PageIllustrationStatus.idle:
          case PageIllustrationStatus.failed:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

/// Looks like "an illustration is here, but locked" — a decorative painted
/// scene (never real AI art; we never generate art just to hide it) behind a
/// frosted-glass blur, with a clear CTA chip on top.
///
/// Deliberately pure Flutter painting + no network image: see task notes in
/// the funnel PR — an upsell card must never cost us a paid generation.
class _IllustrationUpsellCard extends StatelessWidget {
  const _IllustrationUpsellCard({
    required this.borderRadius,
    required this.aspectRatio,
    required this.onTap,
  });

  final double borderRadius;
  final double aspectRatio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Lavender matches the existing premium-hook convention used in
    // story_result_screen.dart::_showIllustrationUnlockSheet (0xFF7E57C2).
    const lavender = Color(0xFF7E57C2);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Material(
          color: const Color(0xFFF3EEFB),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The "hidden" scene — a decorative painted placeholder, not
                // a real illustration. Gives the card the silhouette of art
                // worth unlocking without us paying to generate + hide one.
                const _DecorativeSceneBackdrop(),
                // Frosted-glass blur over the painted scene.
                BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                // Bottom scrim so the CTA text stays readable over any part
                // of the painted scene.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.32),
                      ],
                    ),
                  ),
                ),
                // Sharp CTA content — unblurred, sits above the frosted glass.
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Text(
                            'See this scene come alive ✨',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: lavender,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to unlock illustrations',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.92),
                            shadows: const [
                              Shadow(blurRadius: 4, color: Colors.black38),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Decorative dusk-storybook scene painted with plain shapes and gradients —
/// a moon glow, a rolling hill silhouette, and a scatter of sparkles. Never
/// meant to resemble any specific story's real illustration; it exists only
/// to give the frosted-glass card above something scene-shaped to blur.
class _DecorativeSceneBackdrop extends StatelessWidget {
  const _DecorativeSceneBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(painter: _ScenePainter()),
    );
  }
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Dusk sky gradient.
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF4A3B8C),
          Color(0xFF9B7FD4),
          Color(0xFFF5C77E),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, skyPaint);

    // Soft glowing moon.
    final moonCenter = Offset(size.width * 0.74, size.height * 0.26);
    final moonRadius = size.shortestSide * 0.14;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: moonCenter, radius: moonRadius * 2.6),
      );
    canvas.drawCircle(moonCenter, moonRadius * 2.6, glowPaint);
    canvas.drawCircle(
      moonCenter,
      moonRadius,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );

    // Rolling hill silhouette.
    final hillPaint = Paint()
      ..color = const Color(0xFF2F235E).withValues(alpha: 0.85);
    final hillPath = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.56,
        size.width * 0.55,
        size.height * 0.74,
      )
      ..quadraticBezierTo(
        size.width * 0.8,
        size.height * 0.9,
        size.width,
        size.height * 0.66,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hillPath, hillPaint);

    // Scattered sparkles.
    final sparklePaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    const sparkleSpots = [
      Offset(0.14, 0.18),
      Offset(0.34, 0.4),
      Offset(0.5, 0.14),
      Offset(0.64, 0.46),
      Offset(0.86, 0.58),
    ];
    for (final spot in sparkleSpots) {
      _drawSparkle(
        canvas,
        Offset(size.width * spot.dx, size.height * spot.dy),
        size.shortestSide * 0.028,
        sparklePaint,
      );
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - r)
      ..lineTo(center.dx + r * 0.28, center.dy - r * 0.28)
      ..lineTo(center.dx + r, center.dy)
      ..lineTo(center.dx + r * 0.28, center.dy + r * 0.28)
      ..lineTo(center.dx, center.dy + r)
      ..lineTo(center.dx - r * 0.28, center.dy + r * 0.28)
      ..lineTo(center.dx - r, center.dy)
      ..lineTo(center.dx - r * 0.28, center.dy - r * 0.28)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) => false;
}

class _IllustrationSkeleton extends StatefulWidget {
  const _IllustrationSkeleton({
    required this.borderRadius,
    required this.aspectRatio,
  });

  final double borderRadius;
  final double aspectRatio;

  @override
  State<_IllustrationSkeleton> createState() => _IllustrationSkeletonState();
}

class _IllustrationSkeletonState extends State<_IllustrationSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(
                      const Color(0xFFE6E0F8),
                      const Color(0xFFD6CBF0),
                      t,
                    )!,
                    Color.lerp(
                      const Color(0xFFD6CBF0),
                      const Color(0xFFEFE7FF),
                      t,
                    )!,
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white70,
                size: 36,
              ),
            );
          },
        ),
      ),
    );
  }
}

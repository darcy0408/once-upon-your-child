// lib/widgets/per_page_illustration.dart

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
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEFE7FF), Color(0xFFE6E0F8)],
                ),
                border: Border.all(
                  color: lavender.withValues(alpha: 0.35),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎨', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  const Text(
                    'Out of free illustrations',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: lavender,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to upgrade and see this scene come alive.',
                    style: TextStyle(
                      fontSize: 12,
                      color: lavender.withValues(alpha: 0.85),
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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

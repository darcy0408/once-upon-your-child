// lib/widgets/per_page_illustration.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/per_page_illustration_prefetcher.dart';

/// Renders the prefetcher's state for a single page: the image when ready,
/// a soft skeleton when the reader arrived before generation finished, or
/// nothing when the page isn't being prefetched.
class PerPageIllustration extends StatelessWidget {
  const PerPageIllustration({
    super.key,
    required this.listenable,
    this.borderRadius = 16,
    this.aspectRatio = 4 / 3,
  });

  final ValueListenable<PageIllustrationState> listenable;
  final double borderRadius;
  final double aspectRatio;

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
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
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
          case PageIllustrationStatus.idle:
          case PageIllustrationStatus.failed:
            return const SizedBox.shrink();
        }
      },
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

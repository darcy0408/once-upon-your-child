import 'package:flutter/material.dart';
import '../utils/motion_utils.dart';

/// How each child enters during the staggered deal.
enum CardDealType {
  /// Slides up from below while fading in. Good for grid layouts.
  slideUp,

  /// Slight rotation + scale from near-zero, like a card being flipped off a deck.
  flipIn,

  /// Scales from 0.6 with a spring — "pop" sticker feel.
  fadeScale,
}

/// Animates a list of children entering one-by-one, like cards being dealt.
///
/// Each child is animated with a staggered [staggerDelay]. The full animation
/// plays once when the widget first builds (or when [key] changes).
///
/// Reduced-motion: all children are shown immediately with no animation.
class StaggeredCardDealer extends StatefulWidget {
  final List<Widget> children;

  /// Delay between each child starting its entrance. Default 120ms.
  final Duration staggerDelay;

  /// Duration of each individual card's entrance animation. Default 400ms.
  final Duration dealDuration;

  /// The entrance style. Default [CardDealType.slideUp].
  final CardDealType dealType;

  /// Curve applied to each card's entrance. Default [Curves.easeOutBack].
  final Curve curve;

  /// Wraps children in a [Wrap]. If false, children are returned as-is
  /// (useful when the parent is already a Row/Column/GridView).
  final bool wrapChildren;

  /// [Wrap] spacing when [wrapChildren] is true.
  final double wrapSpacing;
  final double wrapRunSpacing;
  final WrapAlignment wrapAlignment;

  const StaggeredCardDealer({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 120),
    this.dealDuration = const Duration(milliseconds: 400),
    this.dealType = CardDealType.slideUp,
    this.curve = Curves.easeOutBack,
    this.wrapChildren = false,
    this.wrapSpacing = 8,
    this.wrapRunSpacing = 8,
    this.wrapAlignment = WrapAlignment.start,
  });

  @override
  State<StaggeredCardDealer> createState() => _StaggeredCardDealerState();
}

class _StaggeredCardDealerState extends State<StaggeredCardDealer>
    with SingleTickerProviderStateMixin {
  late AnimationController _master;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _buildAnimations();
    _master.forward();
  }

  void _buildAnimations() {
    final count = widget.children.length;
    if (count == 0) {
      _master = AnimationController(duration: Duration.zero, vsync: this);
      _animations = [];
      return;
    }

    final totalMs = widget.staggerDelay.inMilliseconds * (count - 1) +
        widget.dealDuration.inMilliseconds;
    _master = AnimationController(
      duration: Duration(milliseconds: totalMs),
      vsync: this,
    );

    _animations = List.generate(count, (i) {
      final startMs = widget.staggerDelay.inMilliseconds * i;
      final endMs = startMs + widget.dealDuration.inMilliseconds;
      final start = startMs / totalMs;
      final end = endMs / totalMs;
      return CurvedAnimation(
        parent: _master,
        curve: Interval(start, end, curve: widget.curve),
      );
    });
  }

  @override
  void didUpdateWidget(StaggeredCardDealer old) {
    super.didUpdateWidget(old);
    if (old.children.length != widget.children.length ||
        old.staggerDelay != widget.staggerDelay ||
        old.dealDuration != widget.dealDuration) {
      _master.dispose();
      _buildAnimations();
      _master.forward();
    }
  }

  @override
  void dispose() {
    _master.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced-motion: show all children immediately
    if (MotionPrefs.reduceMotion(context)) {
      if (widget.wrapChildren) {
        return Wrap(
          spacing: widget.wrapSpacing,
          runSpacing: widget.wrapRunSpacing,
          alignment: widget.wrapAlignment,
          children: widget.children,
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.children,
      );
    }

    final animated = List.generate(widget.children.length, (i) {
      return AnimatedBuilder(
        animation: _animations[i],
        builder: (_, child) =>
            _buildEntry(widget.dealType, _animations[i].value, child!),
        child: widget.children[i],
      );
    });

    if (widget.wrapChildren) {
      return Wrap(
        spacing: widget.wrapSpacing,
        runSpacing: widget.wrapRunSpacing,
        alignment: widget.wrapAlignment,
        children: animated,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: animated,
    );
  }

  Widget _buildEntry(CardDealType type, double t, Widget child) {
    switch (type) {
      case CardDealType.slideUp:
        final offset = Offset(0, 0.25 * (1 - t));
        return FractionalTranslation(
          translation: offset,
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        );

      case CardDealType.flipIn:
        // Rotate slightly from the left edge (like a card flicked off a deck)
        final angle = (1 - t) * 0.35; // max ~20°
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.bottomLeft,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateZ(-angle),
            child: child,
          ),
        );

      case CardDealType.fadeScale:
        final scale = 0.6 + 0.4 * t;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        );
    }
  }
}

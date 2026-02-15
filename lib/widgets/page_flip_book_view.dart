import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:page_flip_builder/page_flip_builder.dart';
import 'package:story_weaver_app/widgets/storybook_page.dart';

/// A magical book-style page viewer with 3D flip animations.
///
/// Wraps the page_flip_builder package and automatically applies StoryBookPage
/// decorations to each page. Provides tap zones for navigation and optional
/// page numbers.
class PageFlipBookView extends StatefulWidget {
  const PageFlipBookView({
    super.key,
    required this.pages,
    this.controller,
    this.onPageChanged,
    this.showPageNumbers = true,
    this.showNavigationArrows = false,
  });

  /// List of widgets to display as pages (will be wrapped in StoryBookPage)
  final List<Widget> pages;

  /// Optional PageController for programmatic control
  final PageController? controller;

  /// Callback when page changes
  final Function(int)? onPageChanged;

  /// Whether to show page numbers at the bottom
  final bool showPageNumbers;

  /// Whether to show navigation arrows
  final bool showNavigationArrows;

  @override
  State<PageFlipBookView> createState() => _PageFlipBookViewState();
}

class _PageFlipBookViewState extends State<PageFlipBookView> with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final GlobalKey<PageFlipBuilderState> _pageFlipKey;
  late final AnimationController _turnFxController;
  late final Animation<double> _turnFx;
  int _currentPage = 0;
  int _turnDirection = 1;

  @override
  void initState() {
    super.initState();
    _pageController = widget.controller ?? PageController();
    _pageFlipKey = GlobalKey<PageFlipBuilderState>();
    _turnFxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _turnFx = CurvedAnimation(
      parent: _turnFxController,
      curve: Curves.easeInOutCubic,
    );

    // Listen to page controller changes
    _pageController.addListener(_onPageControllerChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _pageController.dispose();
    } else {
      _pageController.removeListener(_onPageControllerChanged);
    }
    _turnFxController.dispose();
    super.dispose();
  }

  void _playTurnFx({required bool forward}) {
    _turnDirection = forward ? 1 : -1;
    _turnFxController
      ..stop()
      ..reset()
      ..forward();
  }

  void _onPageControllerChanged() {
    if (_pageController.hasClients) {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage && mounted) {
        setState(() {
          _currentPage = page;
        });
        widget.onPageChanged?.call(_currentPage);
      }
    }
  }

  void _handlePageFlip(bool isForward) {
    if (mounted) {
      setState(() {
        if (isForward) {
          _currentPage = (_currentPage + 1) % widget.pages.length;
        } else {
          _currentPage = (_currentPage - 1 + widget.pages.length) % widget.pages.length;
        }
      });
      widget.onPageChanged?.call(_currentPage);
    }
  }

  void _goToNextPage() {
    if (_currentPage < widget.pages.length - 1) {
      _playTurnFx(forward: true);
      _pageFlipKey.currentState?.flip();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      _playTurnFx(forward: false);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      if (mounted) {
        setState(() {
          _currentPage = _currentPage - 1;
        });
      }
      widget.onPageChanged?.call(_currentPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final basePage = PageFlipBuilder(
      key: _pageFlipKey,
      frontBuilder: (context) => _buildPage(_currentPage),
      backBuilder: (context) => _currentPage < widget.pages.length - 1
          ? _buildPage(_currentPage + 1)
          : _buildPage(_currentPage),
      flipAxis: Axis.horizontal,
      maxTilt: 0.003,
      maxScale: 0.2,
      nonInteractiveAnimationDuration: const Duration(milliseconds: 500),
      interactiveFlipEnabled: true,
      onFlipComplete: _handlePageFlip,
    );

    return Stack(
      children: [
        // Page flip view
        GestureDetector(
          onTapUp: (details) {
            // Tap zones: left 1/3 = previous, right 1/3 = next
            final width = MediaQuery.of(context).size.width;
            final tapX = details.globalPosition.dx;

            if (tapX < width / 3) {
              _goToPreviousPage();
            } else if (tapX > (2 * width / 3)) {
              _goToNextPage();
            }
          },
          child: AnimatedBuilder(
            animation: _turnFx,
            builder: (context, child) {
              final t = _turnFx.value;
              final wave = math.sin(t * math.pi);
              final angle = (_turnDirection * -0.13) * wave;
              final shadow = 0.22 * wave;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Transform(
                    alignment: _turnDirection > 0
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0014)
                      ..rotateY(angle),
                    child: child,
                  ),
                  if (shadow > 0)
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: _turnDirection > 0
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            end: _turnDirection > 0
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: shadow),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _PaperTexturePainter(
                        opacity: 0.032,
                      ),
                    ),
                  ),
                ],
              );
            },
            child: basePage,
          ),
        ),

        // Page number indicator
        if (widget.showPageNumbers)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentPage + 1} / ${widget.pages.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

        // Navigation arrows (optional)
        if (widget.showNavigationArrows) ...[
          // Previous arrow
          if (_currentPage > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, size: 36),
                  onPressed: _goToPreviousPage,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),

          // Next arrow
          if (_currentPage < widget.pages.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_right, size: 36),
                  onPressed: _goToNextPage,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildPage(int index) {
    if (index < 0 || index >= widget.pages.length) {
      return const StoryBookPage(
        child: Center(child: Text('Page not found')),
      );
    }

    return StoryBookPage(
      child: widget.pages[index],
    );
  }
}

class _PaperTexturePainter extends CustomPainter {
  const _PaperTexturePainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: opacity)
      ..strokeWidth = 1;
    const step = 14.0;
    for (double y = 4; y < size.height; y += step) {
      for (double x = 3; x < size.width; x += step) {
        canvas.drawPoints(
          PointMode.points,
          [Offset(x, y)],
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PaperTexturePainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}

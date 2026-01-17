import 'package:flutter/material.dart';
import 'package:story_weaver_app/theme/app_theme.dart';

/// Storybook-style progress indicator showing "pages" in a book with kid-friendly labels
///
/// Uses Wizard theme colors (purple primary, gold accent) and displays progress
/// as visual "pages" rather than numbers, making it more engaging for children.
///
/// Example:
/// ```dart
/// StorybookProgressIndicator(
///   currentPage: 2,
///   totalPages: 6,
///   stageLabel: 'Play Time!',
/// )
/// ```
class StorybookProgressIndicator extends StatelessWidget {
  const StorybookProgressIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.stageLabel,
    this.isCompleted = false,
  });

  /// Current page number (1-indexed)
  final int currentPage;

  /// Total number of pages in the story
  final int totalPages;

  /// Optional kid-friendly label for this stage (e.g., "Play Time!", "Find the Star!")
  final String? stageLabel;

  /// Whether the story is completed
  final bool isCompleted;

  /// Get default stage label based on page number
  String get _defaultLabel {
    if (isCompleted) return 'The End!';

    // Default fallback labels by page number
    final labels = [
      'Wake Up!',
      'Play Time!',
      'Pick a Path!',
      'Follow the Glow!',
      'Find the Star!',
      'Big Choice!',
    ];

    if (currentPage > 0 && currentPage <= labels.length) {
      return labels[currentPage - 1];
    }

    return 'Page $currentPage!';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = stageLabel ?? _defaultLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page icons
          ...List.generate(totalPages, (index) {
            final pageNumber = index + 1;
            final isCurrent = pageNumber == currentPage;
            final isPast = pageNumber < currentPage;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _PageIcon(
                isCurrent: isCurrent,
                isPast: isPast,
                isLast: pageNumber == totalPages,
              ),
            );
          }),

          const SizedBox(width: 8),

          // Stage label
          if (!isCompleted) ...[
            Text(
              effectiveLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ] else ...[
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: AppColors.gold,
                ),
                SizedBox(width: 4),
                Text(
                  'The End!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Individual page icon showing a book page with folded corner
class _PageIcon extends StatelessWidget {
  const _PageIcon({
    required this.isCurrent,
    required this.isPast,
    required this.isLast,
  });

  final bool isCurrent;
  final bool isPast;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    Color fillColor;
    Color borderColor;

    if (isPast) {
      // Completed pages: gold fill
      fillColor = AppColors.gold;
      borderColor = AppColors.gold;
    } else if (isCurrent) {
      // Current page: purple fill
      fillColor = AppColors.primary;
      borderColor = AppColors.primary;
    } else {
      // Future pages: light/empty
      fillColor = Colors.white;
      borderColor = AppColors.primary.withValues(alpha: 0.3);
    }

    return Container(
      width: 16,
      height: 18,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(2),
          topRight: Radius.circular(6),
          bottomLeft: Radius.circular(2),
          bottomRight: Radius.circular(2),
        ),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          // Folded corner effect
          Positioned(
            top: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(5, 5),
              painter: _FoldedCornerPainter(
                fillColor: fillColor,
                borderColor: borderColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the folded corner effect on the page icon
class _FoldedCornerPainter extends CustomPainter {
  const _FoldedCornerPainter({
    required this.fillColor,
    required this.borderColor,
  });

  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = fillColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - size.width * 0.7, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FoldedCornerPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor ||
      oldDelegate.borderColor != borderColor;
}

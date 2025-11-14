import 'dart:math';

import 'package:flutter/material.dart';

class TutorialOverlay extends StatelessWidget {
  final Rect highlightRect;
  final String title;
  final String description;
  final VoidCallback onNext;
  final VoidCallback? onSkip;

  const TutorialOverlay({
    super.key,
    required this.highlightRect,
    required this.title,
    required this.description,
    required this.onNext,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bubbleWidth = min(screenSize.width * 0.8, 320.0);
    final bubblePosition = highlightRect.center.dy < screenSize.height / 2
        ? highlightRect.bottom + 16
        : highlightRect.top - 16 - 180;

    return Material(
      color: Colors.black54,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onNext,
              child: CustomPaint(
                painter: _HolePainter(rect: highlightRect.inflate(12)),
              ),
            ),
          ),
          Positioned(
            left: highlightRect.left,
            top: highlightRect.top,
            width: highlightRect.width,
            height: highlightRect.height,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white70, width: 2),
                ),
              ),
            ),
          ),
          Positioned(
            left: (screenSize.width - bubbleWidth) / 2,
            top: bubblePosition,
            child: Container(
              width: bubbleWidth,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (onSkip != null)
                        TextButton(
                          onPressed: onSkip,
                          child: const Text('Skip'),
                        ),
                      ElevatedButton(
                        onPressed: onNext,
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HolePainter extends CustomPainter {
  final Rect rect;

  _HolePainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..blendMode = BlendMode.clear;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black.withOpacity(0.7));
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

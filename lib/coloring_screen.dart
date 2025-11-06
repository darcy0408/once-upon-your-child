// lib/coloring_screen.dart

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'coloring_book_service.dart';

class ColoringScreen extends StatefulWidget {
  final ColoringPage coloringPage;

  const ColoringScreen({
    super.key,
    required this.coloringPage,
  });

  @override
  State<ColoringScreen> createState() => _ColoringScreenState();
}

class _ColoringScreenState extends State<ColoringScreen> {
  final _userColoringService = UserColoringService();
  final GlobalKey _paintKey = GlobalKey();

  Color _selectedColor = Colors.red;
  final List<DrawingPoint> _drawingPoints = [];
  bool _isLoading = true;

  static const List<Color> _colorPalette = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.pink,
    Colors.brown,
    Colors.black,
    Colors.grey,
    Color(0xFFFFB6C1), // Light pink
    Color(0xFF87CEEB), // Sky blue
    Color(0xFFFFD700), // Gold
    Color(0xFF90EE90), // Light green
    Color(0xFFFFA07A), // Light salmon
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedColoring();
  }

  Future<void> _loadSavedColoring() async {
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveColoring() async {
    // Convert drawing points to a simplified format for storage
    final coloredAreas = <String, String>{};
    for (int i = 0; i < _drawingPoints.length; i++) {
      final point = _drawingPoints[i];
      if (point.offset != null) {
        coloredAreas['point_$i'] =
            '#${point.color.value.toRadixString(16).padLeft(8, '0')}';
      }
    }

    final coloring = UserColoring(
      coloringPageId: widget.coloringPage.id,
      coloredAreas: coloredAreas,
      lastModified: DateTime.now(),
      isCompleted: false, // User can mark as completed
    );

    await _userColoringService.saveColoring(coloring);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Coloring saved!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearDrawing() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Coloring?'),
        content: const Text('This will erase all your coloring. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _drawingPoints.clear();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportImage() async {
    try {
      final boundary = _paintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      // In a real app, you would save this to the device or share it
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎨 Image ready! (Print functionality coming soon)'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: Colors.purple,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.coloringPage.pageTitle),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save',
            onPressed: _saveColoring,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print/Export',
            onPressed: _exportImage,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear All',
            onPressed: _clearDrawing,
          ),
        ],
      ),
      body: Column(
        children: [
          // Color palette
          Container(
            height: 80,
            color: Colors.grey.shade200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              itemCount: _colorPalette.length,
              itemBuilder: (context, index) {
                final color = _colorPalette[index];
                final isSelected = _selectedColor == color;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey.shade400,
                        width: isSelected ? 4 : 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),

          // Drawing canvas
          Expanded(
            child: RepaintBoundary(
              key: _paintKey,
              child: Container(
                color: Colors.white,
                child: Stack(
                  children: [
                    // Background image (coloring page)
                    Positioned.fill(
                      child: Image.network(
                        widget.coloringPage.imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error,
                                    size: 60, color: Colors.red),
                                const SizedBox(height: 16),
                                Text('Failed to load image',
                                    style:
                                        TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Drawing layer
                    Positioned.fill(
                      child: GestureDetector(
                        onPanStart: (details) {
                          setState(() {
                            _drawingPoints.add(
                              DrawingPoint(
                                offset: details.localPosition,
                                color: _selectedColor,
                              ),
                            );
                          });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            _drawingPoints.add(
                              DrawingPoint(
                                offset: details.localPosition,
                                color: _selectedColor,
                              ),
                            );
                          });
                        },
                        onPanEnd: (details) {
                          setState(() {
                            _drawingPoints.add(
                              DrawingPoint(offset: null, color: _selectedColor),
                            );
                          });
                        },
                        child: CustomPaint(
                          painter:
                              DrawingPainter(drawingPoints: _drawingPoints),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.touch_app, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap a color above, then draw with your finger to color!',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Drawing point model
class DrawingPoint {
  final Offset? offset;
  final Color color;

  DrawingPoint({
    this.offset,
    required this.color,
  });
}

/// Custom painter for drawing
class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;

  DrawingPainter({required this.drawingPoints});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < drawingPoints.length - 1; i++) {
      if (drawingPoints[i].offset != null &&
          drawingPoints[i + 1].offset != null) {
        final paint = Paint()
          ..color = drawingPoints[i].color
          ..strokeWidth = 15.0
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          drawingPoints[i].offset!,
          drawingPoints[i + 1].offset!,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

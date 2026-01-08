import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../feelings_wheel_data.dart';

/// Interactive expanding feelings wheel - like Simon Says!
/// Tap to light up and expand: core -> secondary -> tertiary
class ExpandingFeelingsWheel extends StatefulWidget {
  final ValueChanged<SelectedFeeling>? onFeelingSelected;
  final Color backgroundColor;
  // 0 = core only, 1 = secondary, 2 = tertiary
  final int maxDepth;

  const ExpandingFeelingsWheel({
    super.key,
    this.onFeelingSelected,
    this.backgroundColor = const Color(0xFFF5E6D3),
    this.maxDepth = 2,
  });

  @override
  State<ExpandingFeelingsWheel> createState() => _ExpandingFeelingsWheelState();
}

class _ExpandingFeelingsWheelState extends State<ExpandingFeelingsWheel>
    with SingleTickerProviderStateMixin {
  CoreEmotion? _selectedCore;
  SecondaryFeeling? _selectedSecondary;
  String? _selectedTertiary;

  final Map<String, ui.Image> _faceImages = {};
  final Set<String> _availableFaces = {
    // Core emotions
    'angry', 'happy', 'surprised', 'bad', 'fearful', 'sad', 'disgusted',
    // Happy family
    'accepted', 'respected', 'valued', 'powerful', 'courageous', 'creative',
    'peaceful', 'loving', 'thankful', 'trusting', 'sensitive', 'intimate',
    'optimistic', 'hopeful', 'inspired',
    // Surprised family
    'excited', 'energetic', 'eager', 'amazed', 'awe', 'astonished',
    'confused', 'perplexed', 'disillusioned', 'startled', 'dismayed', 'shocked',
    // Bad family
    'bored', 'apathetic', 'indifferent', 'tired', 'unfocused', 'sleepy',
    'stressed', 'out_of_control', 'overwhelmed', 'busy', 'rushed', 'pressured',
    // Fearful family
    'anxious', 'worried', 'insecure', 'inadequate', 'inferior', 'weak',
    'worthless', 'insignificant', 'rejected', 'excluded', 'persecuted',
    'threatened', 'nervous', 'exposed', 'let_down', 'betrayed', 'resentful',
    // Sad family
    'depressed', 'empty', 'guilty', 'remorseful', 'ashamed', 'despair',
    'powerless', 'grief', 'vulnerable', 'fragile', 'victimized',
    'disappointed', 'appalled', 'revolted', 'awful', 'nauseated', 'detestable', 'snawed',
    // Angry family
    'mad', 'furious', 'jealous', 'aggressive', 'provoked', 'hostile', 'auctiole',
    'humiliated', 'disrespected', 'ridiculed', 'bitter', 'indignant', 'violated',
    'frustrated', 'infuriated', 'annoyed', 'distant', 'withdrawn', 'numb',
    'critical', 'skeptical', 'dismissive', 'disapproving', 'judgmental', 'embarrassed',
    // Original faces
    'playful', 'aroused', 'cheeky', 'content', 'free', 'joyful',
    'interested', 'curious', 'inquisitive', 'confident', 'proud', 'successful',
  };

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Wheel order clockwise from top (12 o'clock)
  // Matching the actual visual layout on screen - 7 emotions total
  final List<String> _wheelOrder = const [
    'happy',
    'surprised',
    'bad',
    'fearful',
    'sad',
    'disgusted',
    'angry',
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _loadFaceImages();
  }

  Future<void> _loadFaceImages() async {
    for (final key in _availableFaces) {
      try {
        final data = await rootBundle.load('assets/feelings_faces/$key.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        _faceImages[key] = frame.image;
      } catch (_) {
        // Skip missing assets; fallback to drawn faces.
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _handleTap(TapDownDetails details, double size) {
    final center = Offset(size / 2, size / 2);
    final dx = details.localPosition.dx - center.dx;
    final dy = details.localPosition.dy - center.dy;
    final radius = math.sqrt(dx * dx + dy * dy);
    final maxRadius = size / 2;

    if (radius > maxRadius * 0.95) return;

    const startAngle = -math.pi / 2;
    final rawAngle = math.atan2(dy, dx);
    final angle = (rawAngle - startAngle + 2 * math.pi) % (2 * math.pi);
    final ringRatio = radius / maxRadius;

    if (ringRatio < 0.22) {
      _pickSelection();
      return;
    }

    if (_selectedCore == null || widget.maxDepth == 0) {
      _tapCore(angle);
      return;
    }

    if (ringRatio < 0.50) {
      _tapCore(angle);
      return;
    }

    if (widget.maxDepth >= 1 && ringRatio < 0.75) {
      _tapSecondary(angle);
      return;
    }

    if (widget.maxDepth >= 2 && ringRatio < 0.92) {
      _tapTertiary(angle);
    }
  }

  void _tapCore(double angle) {
    final sectorIndex = _getSectorIndex(angle);
    final coreId = _wheelOrder[sectorIndex];
    final core = FeelingsWheelData.coreEmotions.firstWhere((c) => c.id == coreId);

    setState(() {
      if (_selectedCore?.id == core.id) {
        _selectedCore = null;
        _selectedSecondary = null;
        _selectedTertiary = null;
      } else {
        _selectedCore = core;
        _selectedSecondary = null;
        _selectedTertiary = null;
      }
    });

    if (widget.maxDepth == 0 && _selectedCore != null) {
      _pickCore();
    }
  }

  void _tapSecondary(double angle) {
    if (_selectedCore == null) return;

    final secondaryList = _selectedCore!.secondary;
    if (secondaryList.isEmpty) return;

    final coreSectorIndex = _wheelOrder.indexOf(_selectedCore!.id);
    if (coreSectorIndex == -1) return;

    final sectorAngle = (2 * math.pi) / _wheelOrder.length;
    final coreSectorStart = coreSectorIndex * sectorAngle;

    double localAngle = (angle - coreSectorStart + 2 * math.pi) % (2 * math.pi);
    if (localAngle > sectorAngle) {
      localAngle = localAngle - 2 * math.pi;
    }

    if (localAngle < 0 || localAngle >= sectorAngle) {
      return;
    }

    final secondaryAngle = sectorAngle / secondaryList.length;
    final secondaryIndex = (localAngle / secondaryAngle).floor().clamp(0, secondaryList.length - 1);
    final secondary = secondaryList[secondaryIndex];

    setState(() {
      if (_selectedSecondary?.id == secondary.id) {
        _selectedSecondary = null;
        _selectedTertiary = null;
      } else {
        _selectedSecondary = secondary;
        _selectedTertiary = null;
      }
    });

    if (widget.maxDepth == 1 && _selectedSecondary != null) {
      _pickSecondary();
    } else if (widget.maxDepth >= 2 && secondary.tertiary.isEmpty) {
      _pickSecondary();
    }
  }

  void _tapTertiary(double angle) {
    if (_selectedCore == null || _selectedSecondary == null) return;

    final secondaryList = _selectedCore!.secondary;
    if (secondaryList.isEmpty) return;

    final coreSectorIndex = _wheelOrder.indexOf(_selectedCore!.id);
    if (coreSectorIndex == -1) return;

    final secondaryIndex = secondaryList.indexWhere((s) => s.id == _selectedSecondary!.id);
    if (secondaryIndex == -1) return;

    final sectorAngle = (2 * math.pi) / _wheelOrder.length;
    final coreSectorStart = coreSectorIndex * sectorAngle;
    final secondaryAngle = sectorAngle / secondaryList.length;
    final secondaryStart = coreSectorStart + secondaryIndex * secondaryAngle;

    final tertiaryList = _selectedSecondary!.tertiary;
    if (tertiaryList.isEmpty) return;

    double localAngle = (angle - secondaryStart + 2 * math.pi) % (2 * math.pi);
    if (localAngle > secondaryAngle) {
      localAngle = localAngle - 2 * math.pi;
    }

    if (localAngle < 0 || localAngle >= secondaryAngle) {
      return;
    }

    final tertiaryAngle = secondaryAngle / tertiaryList.length;
    final tertiaryIndex = (localAngle / tertiaryAngle).floor().clamp(0, tertiaryList.length - 1);
    final tertiary = tertiaryList[tertiaryIndex];

    setState(() {
      if (_selectedTertiary == tertiary) {
        _selectedTertiary = null;
      } else {
        _selectedTertiary = tertiary;
      }
    });

    if (_selectedTertiary != null) {
      _pickTertiary(_selectedTertiary!);
    }
  }

  int _getSectorIndex(double angle) {
    final sectorAngle = (2 * math.pi) / _wheelOrder.length;
    return (angle / sectorAngle).floor() % _wheelOrder.length;
  }

  void _pickSelection() {
    if (widget.maxDepth >= 2 && _selectedTertiary != null) {
      _pickTertiary(_selectedTertiary!);
      return;
    }
    if (_selectedSecondary != null) {
      _pickSecondary();
      return;
    }
    if (_selectedCore != null) {
      _pickCore();
    }
  }

  void _pickCore() {
    if (_selectedCore == null) return;
    widget.onFeelingSelected?.call(
      SelectedFeeling(
        core: _selectedCore!.name,
        secondary: '',
        tertiary: _selectedCore!.name,
        emoji: _selectedCore!.emoji,
        eyeType: _selectedCore!.eyeType,
        mouthType: _selectedCore!.mouthType,
        color: _selectedCore!.color ?? const Color(0xFFFFD93D),
      ),
    );
  }

  void _pickSecondary() {
    if (_selectedCore == null || _selectedSecondary == null) return;
    widget.onFeelingSelected?.call(
      SelectedFeeling(
        core: _selectedCore!.name,
        secondary: _selectedSecondary!.name,
        tertiary: _selectedSecondary!.name,
        emoji: _selectedSecondary!.emoji,
        eyeType: _selectedSecondary!.eyeType,
        mouthType: _selectedSecondary!.mouthType,
        color: _selectedCore!.color ?? const Color(0xFFFFD93D),
      ),
    );
  }

  void _pickTertiary(String tertiary) {
    if (_selectedCore == null || _selectedSecondary == null) return;
    final emoji = FeelingsEmojiLookup.emojiFor(tertiary) ?? _selectedSecondary!.emoji;
    widget.onFeelingSelected?.call(
      SelectedFeeling(
        core: _selectedCore!.name,
        secondary: _selectedSecondary!.name,
        tertiary: tertiary,
        emoji: emoji,
        eyeType: _selectedSecondary!.eyeType,
        mouthType: _selectedSecondary!.mouthType,
        color: _selectedCore!.color ?? const Color(0xFFFFD93D),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth;
          return AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(size, size),
                    painter: _WheelPainter(
                      wheelOrder: _wheelOrder,
                      coreEmotions: FeelingsWheelData.coreEmotions,
                      selectedCore: _selectedCore,
                      selectedSecondary: _selectedSecondary,
                      selectedTertiary: _selectedTertiary,
                      glowIntensity: _glowAnimation.value,
                      backgroundColor: widget.backgroundColor,
                      maxDepth: widget.maxDepth,
                      faceImages: _faceImages,
                    ),
                  ),
                  GestureDetector(
                    onTapDown: (details) => _handleTap(details, size),
                    child: Container(
                      width: size,
                      height: size,
                      color: Colors.transparent,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Layout constants for the feelings wheel
class _WheelLayout {
  _WheelLayout._(); // Prevent instantiation

  // Ring radii (% of total radius)
  static const double centerRadius = 0.22;
  static const double coreInner = 0.25;
  static const double coreOuter_collapsed = 0.94;
  static const double coreOuter_expanded = 0.54;

  static const double secondaryInner = 0.54;
  static const double secondaryOuter_collapsed = 0.94;
  static const double secondaryOuter_expanded = 0.80;

  static const double tertiaryInner = 0.80;
  static const double tertiaryOuter = 0.94;

  // Face positions (radial distance from center)
  static const double coreFaceRadial = 0.88;
  static const double secondaryFaceRadial = 0.87;
  static const double tertiaryFaceRadial = 0.87;

  // Face sizes
  static const double coreFaceSize = 0.045;
  static const double secondaryFaceSize = 0.032;
  static const double tertiaryFaceSize = 0.025;

  // Text label positions
  static const double coreLabelRadial = 0.68;
  static const double secondaryLabelRadial = 0.67;
  static const double tertiaryLabelRadial = 0.67;

  // Gaps between slices
  static const double coreGap = 0.04;
  static const double secondaryGap = 0.02;
  static const double tertiaryGap = 0.01;
}

/// Custom painter for the wheel
class _WheelPainter extends CustomPainter {
  final List<String> wheelOrder;
  final List<CoreEmotion> coreEmotions;
  final CoreEmotion? selectedCore;
  final SecondaryFeeling? selectedSecondary;
  final String? selectedTertiary;
  final double glowIntensity;
  final Color backgroundColor;
  final int maxDepth;
  final Map<String, ui.Image> faceImages;

  _WheelPainter({
    required this.wheelOrder,
    required this.coreEmotions,
    this.selectedCore,
    this.selectedSecondary,
    this.selectedTertiary,
    required this.glowIntensity,
    required this.backgroundColor,
    required this.maxDepth,
    required this.faceImages,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Progressive disclosure: Show only relevant rings based on selection
    if (selectedCore == null) {
      // Show only core emotions
      _drawCoreRing(canvas, center, radius);
    } else if (selectedSecondary == null) {
      // Show core + selected core's secondary emotions
      _drawCoreRing(canvas, center, radius);
      _drawSecondaryRing(canvas, center, radius);
    } else {
      // Show core + secondary + selected secondary's tertiary emotions
      _drawCoreRing(canvas, center, radius);
      _drawSecondaryRing(canvas, center, radius);
      _drawTertiaryRing(canvas, center, radius);
    }

    // Draw center hub with selected emotion (if any)
    _drawCenterHub(canvas, center, radius);
  }

  void _drawCoreRing(Canvas canvas, Offset center, double radius) {
    const startAngle = -math.pi / 2; // Start at 12 o'clock
    const gapAngle = 0.02; // Small white gap between segments
    const coreInner = 0.35; // Larger core segments
    const coreOuter = 0.85; // Extend to outer edge

    final coreSectorAngle = (2 * math.pi) / wheelOrder.length;

    for (int i = 0; i < wheelOrder.length; i++) {
      final coreId = wheelOrder[i];
      final core = coreEmotions.firstWhere((c) => c.id == coreId);
      final coreColor = core.color ?? Colors.grey;

      final sectorStart = startAngle + i * coreSectorAngle + gapAngle / 2;
      final sectorAngle = coreSectorAngle - gapAngle;

      final isSelected = selectedCore?.id == core.id;

      // Draw the core segment
      _drawCoreSegment(canvas, center, radius, sectorStart, sectorAngle,
          coreInner, coreOuter, coreColor, isSelected, core.name, core.id);
    }
  }

  void _drawSecondaryRing(Canvas canvas, Offset center, double radius) {
    if (selectedCore == null) return;

    const startAngle = -math.pi / 2;
    const gapAngle = 0.02;
    const secondaryInner = 0.35;
    const secondaryOuter = 0.85;

    final secondaryList = selectedCore!.secondary;
    if (secondaryList.isEmpty) return;

    final secondarySectorAngle = (2 * math.pi) / secondaryList.length;

    for (int i = 0; i < secondaryList.length; i++) {
      final secondary = secondaryList[i];
      final secondaryColor = selectedCore!.secondaryColor ?? selectedCore!.color ?? Colors.grey;

      final sectorStart = startAngle + i * secondarySectorAngle + gapAngle / 2;
      final sectorAngle = secondarySectorAngle - gapAngle;

      final isSelected = selectedSecondary?.id == secondary.id;

      _drawSecondarySegment(canvas, center, radius, sectorStart, sectorAngle,
          secondaryInner, secondaryOuter, secondaryColor, isSelected, secondary.name, secondary.id);
    }
  }

  void _drawTertiaryRing(Canvas canvas, Offset center, double radius) {
    if (selectedCore == null || selectedSecondary == null) return;

    const startAngle = -math.pi / 2;
    const gapAngle = 0.02;
    const tertiaryInner = 0.35;
    const tertiaryOuter = 0.85;

    final tertiaryList = selectedSecondary!.tertiary;
    if (tertiaryList.isEmpty) return;

    final tertiarySectorAngle = (2 * math.pi) / tertiaryList.length;

    for (int i = 0; i < tertiaryList.length; i++) {
      final tertiary = tertiaryList[i];
      final tertiaryColor = selectedCore!.tertiaryColor ?? selectedCore!.color ?? Colors.grey;

      final sectorStart = startAngle + i * tertiarySectorAngle + gapAngle / 2;
      final sectorAngle = tertiarySectorAngle - gapAngle;

      final isSelected = selectedTertiary == tertiary;

      _drawTertiarySegment(canvas, center, radius, sectorStart, sectorAngle,
          tertiaryInner, tertiaryOuter, tertiaryColor, isSelected, tertiary);
    }
  }

  void _drawRingSegment(Canvas canvas, Offset center, double radius, double startAngle,
      double sweepAngle, double innerRatio, double outerRatio, Color color,
      bool isSelected, String label, String level) {

    final innerRadius = radius * innerRatio;
    final outerRadius = radius * outerRatio;

    // Draw glow if selected
    if (isSelected) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.4 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)
        ..style = PaintingStyle.fill;
      _drawSector(canvas, center, innerRadius * 0.98, outerRadius * 1.02,
          startAngle, sweepAngle, glowPaint);
    }

    // Draw main segment
    final segmentPaint = Paint()
      ..color = isSelected ? color : color.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    _drawSector(canvas, center, innerRadius, outerRadius, startAngle, sweepAngle, segmentPaint);

    // Draw label ONLY if provided and segment is wide enough
    if (label.isNotEmpty) {
      final labelRadius = (innerRadius + outerRadius) / 2;
      final labelAngle = startAngle + sweepAngle / 2;

      double fontSize = 7.0;
      double minAngle = 0.03;

      if (level == 'core') {
        fontSize = 10.0;
        minAngle = 0.15; // Core labels for wider segments
      } else if (level == 'secondary') {
        fontSize = 8.0;
        minAngle = 0.05; // Secondary labels show more often
      } else if (level == 'tertiary') {
        fontSize = 7.0;
        minAngle = 0.03; // Tertiary labels show for most segments
      }

      if (sweepAngle > minAngle) {
        // Rotate text to follow the arc orientation
        _drawRotatedText(
          canvas,
          label,
          center.dx + labelRadius * math.cos(labelAngle),
          center.dy + labelRadius * math.sin(labelAngle),
          fontSize,
          Colors.white,
          labelAngle, // Rotation angle
          fontWeight: FontWeight.bold,
          shadow: true,
        );
      }
    }
  }

  void _drawSingleSegment(Canvas canvas, Offset center, double radius, double startAngle,
      double sweepAngle, double innerRatio, double outerRatio, Color color,
      bool isSelected, String label, String level, String faceKey) {

    final innerRadius = radius * innerRatio;
    final outerRadius = radius * outerRatio;

    if (isSelected) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.4 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      _drawSector(canvas, center, innerRadius * 0.98, outerRadius * 1.02,
          startAngle, sweepAngle, glowPaint);
    }

    final segmentPaint = Paint()
      ..color = isSelected ? color : color.withOpacity(0.85);
    _drawSector(canvas, center, innerRadius, outerRadius, startAngle, sweepAngle, segmentPaint);

    if (label.isNotEmpty && sweepAngle > 0.05) {
      final labelRadius = (innerRadius + outerRadius) / 2;
      final labelAngle = startAngle + sweepAngle / 2;
      _drawRotatedText(canvas, label, center.dx + labelRadius * math.cos(labelAngle),
          center.dy + labelRadius * math.sin(labelAngle), 9.0, Colors.white, labelAngle,
          fontWeight: FontWeight.bold, shadow: true);
    }

    _drawFaceAtTip(canvas, center, radius, startAngle, sweepAngle, outerRatio, faceKey);
  }

  void _drawCoreSegment(Canvas canvas, Offset center, double radius, double startAngle,
      double sweepAngle, double innerRatio, double outerRatio, Color color,
      bool isSelected, String label, String emotionId) {

    final innerRadius = radius * innerRatio;
    final outerRadius = radius * outerRatio;

    // Draw glow if selected
    if (isSelected) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.6 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
        ..style = PaintingStyle.fill;
      _drawSector(canvas, center, innerRadius * 0.95, outerRadius * 1.02,
          startAngle, sweepAngle, glowPaint);
    }

    // Draw main segment
    final segmentPaint = Paint()
      ..color = color.withOpacity(0.95)
      ..style = PaintingStyle.fill;

    _drawSector(canvas, center, innerRadius, outerRadius, startAngle, sweepAngle, segmentPaint);

    // Draw label in center of segment
    final labelRadius = (innerRadius + outerRadius) / 2;
    final labelAngle = startAngle + sweepAngle / 2;
    final labelX = center.dx + labelRadius * math.cos(labelAngle);
    final labelY = center.dy + labelRadius * math.sin(labelAngle);

    _drawText(canvas, label, labelX, labelY, 14.0, Colors.white,
        fontWeight: FontWeight.bold, shadow: true);

    // Draw face icon in segment
    _drawFaceInSegment(canvas, center, radius, startAngle, sweepAngle,
        labelRadius * 0.7 / radius, emotionId, color);
  }

  void _drawSecondarySegment(Canvas canvas, Offset center, double radius, double startAngle,
      double sweepAngle, double innerRatio, double outerRatio, Color color,
      bool isSelected, String label, String emotionId) {

    final innerRadius = radius * innerRatio;
    final outerRadius = radius * outerRatio;

    if (isSelected) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.6 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
        ..style = PaintingStyle.fill;
      _drawSector(canvas, center, innerRadius * 0.95, outerRadius * 1.02,
          startAngle, sweepAngle, glowPaint);
    }

    final segmentPaint = Paint()
      ..color = color.withOpacity(0.95)
      ..style = PaintingStyle.fill;

    _drawSector(canvas, center, innerRadius, outerRadius, startAngle, sweepAngle, segmentPaint);

    final labelRadius = (innerRadius + outerRadius) / 2;
    final labelAngle = startAngle + sweepAngle / 2;
    final labelX = center.dx + labelRadius * math.cos(labelAngle);
    final labelY = center.dy + labelRadius * math.sin(labelAngle);

    _drawText(canvas, label, labelX, labelY, 12.0, Colors.white,
        fontWeight: FontWeight.bold, shadow: true);

    _drawFaceInSegment(canvas, center, radius, startAngle, sweepAngle,
        labelRadius * 0.7 / radius, emotionId, color);
  }

  void _drawTertiarySegment(Canvas canvas, Offset center, double radius, double startAngle,
      double sweepAngle, double innerRatio, double outerRatio, Color color,
      bool isSelected, String label) {

    final innerRadius = radius * innerRatio;
    final outerRadius = radius * outerRatio;

    if (isSelected) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.6 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
        ..style = PaintingStyle.fill;
      _drawSector(canvas, center, innerRadius * 0.95, outerRadius * 1.02,
          startAngle, sweepAngle, glowPaint);
    }

    final segmentPaint = Paint()
      ..color = color.withOpacity(0.95)
      ..style = PaintingStyle.fill;

    _drawSector(canvas, center, innerRadius, outerRadius, startAngle, sweepAngle, segmentPaint);

    final labelRadius = (innerRadius + outerRadius) / 2;
    final labelAngle = startAngle + sweepAngle / 2;
    final labelX = center.dx + labelRadius * math.cos(labelAngle);
    final labelY = center.dy + labelRadius * math.sin(labelAngle);

    _drawText(canvas, label, labelX, labelY, 11.0, Colors.white,
        fontWeight: FontWeight.bold, shadow: true);

    _drawFaceInSegment(canvas, center, radius, startAngle, sweepAngle,
        labelRadius * 0.7 / radius, label, color);
  }

  void _drawFaceInSegment(Canvas canvas, Offset center, double radius, double startAngle,
      double sweepAngle, double facePositionRatio, String emotionName, Color bgColor) {

    final faceRadius = radius * facePositionRatio;
    final faceAngle = startAngle + sweepAngle / 2;
    final faceCenter = Offset(
      center.dx + faceRadius * math.cos(faceAngle),
      center.dy + faceRadius * math.sin(faceAngle),
    );

    // Face size based on segment width
    final arcWidth = faceRadius * sweepAngle;
    final faceDiameter = (arcWidth * 0.6).clamp(radius * 0.08, radius * 0.15);

    // Draw circular background matching segment color
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(faceCenter, faceDiameter, bgPaint);

    // Draw face image
    final faceImage = _imageForName(emotionName);
    if (faceImage != null) {
      _drawImageFace(canvas, faceImage, faceCenter, faceDiameter * 0.85);
    }
  }

  void _drawFaceAtTip(Canvas canvas, Offset center, double radius, double startAngle,
      double sweepAngle, double tipRatio, String emotionName) {

    // Position faces slightly inside the wheel boundary (at 92% instead of edge)
    final facePositionRatio = (tipRatio - 0.03).clamp(0.70, 0.92);
    final tipRadius = radius * facePositionRatio;
    final faceAngle = startAngle + sweepAngle / 2;
    final faceCenter = Offset(
      center.dx + tipRadius * math.cos(faceAngle),
      center.dy + tipRadius * math.sin(faceAngle),
    );

    // Face size based on segment width - larger and more visible
    final arcWidth = tipRadius * sweepAngle;
    final faceRadius = (arcWidth * 0.9).clamp(radius * 0.025, radius * 0.065);

    final faceImage = _imageForName(emotionName);
    if (faceImage != null) {
      _drawImageFace(canvas, faceImage, faceCenter, faceRadius);
    }
  }

  void _drawCenterHub(Canvas canvas, Offset center, double radius) {
    final hubRadius = radius * 0.15;

    if (selectedCore == null) {
      // Empty state - subtle background
      final hintPaint = Paint()
        ..color = backgroundColor.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, hubRadius, hintPaint);

      _drawText(
        canvas,
        'Tap a\nFeeling',
        center.dx,
        center.dy,
        11,
        Colors.black45,
        fontWeight: FontWeight.w500,
      );
      return;
    }

    // Determine selected emotion and appropriate color
    String name = selectedCore!.name;
    Color baseColor = selectedCore!.color ?? const Color(0xFFFFD93D);
    String eyeType = selectedCore!.eyeType;
    String mouthType = selectedCore!.mouthType;

    if (selectedTertiary != null) {
      name = selectedTertiary!;
      baseColor = selectedCore!.tertiaryColor ?? baseColor;
      // Keep eye/mouth from secondary
      if (selectedSecondary != null) {
        eyeType = selectedSecondary!.eyeType;
        mouthType = selectedSecondary!.mouthType;
      }
    } else if (selectedSecondary != null) {
      name = selectedSecondary!.name;
      baseColor = selectedCore!.secondaryColor ?? baseColor;
      eyeType = selectedSecondary!.eyeType;
      mouthType = selectedSecondary!.mouthType;
    }

    // Pulsing glow effect
    final outerGlow = Paint()
      ..color = baseColor.withOpacity(0.3 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, hubRadius * 1.3, outerGlow);

    final innerGlow = Paint()
      ..color = baseColor.withOpacity(0.5 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, hubRadius * 1.1, innerGlow);

    // Colored background circle (not white!)
    final bgPaint = Paint()
      ..color = baseColor.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, hubRadius, bgPaint);

    // LARGE face icon
    final faceRadius = radius * 0.08;
    final faceImage = _imageForName(name);

    if (faceImage != null) {
      _drawImageFace(canvas, faceImage, center, faceRadius);
    } else {
      // Fallback to procedural drawing
      final featureColor = _contrastColor(baseColor);
      _drawFace(
        canvas,
        center,
        faceRadius * 0.85,
        Colors.white.withOpacity(0.9),
        featureColor,
        eyeType,
        mouthType,
      );
    }

    // Text label below face
    final textY = center.dy + hubRadius * 1.2;
    _drawText(
      canvas,
      name,
      center.dx,
      textY,
      12,
      Colors.white,
      fontWeight: FontWeight.bold,
      shadow: true,
    );
  }

  ui.Image? _imageForName(String name) {
    final key = _sanitizeKey(name);
    return faceImages[key];
  }

  String _sanitizeKey(String name) {
    final lower = name.toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return replaced.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  }

  void _drawImageFace(Canvas canvas, ui.Image image, Offset center, double radius) {
    final size = radius * 2;
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromCenter(center: center, width: size, height: size);
    canvas.drawImageRect(image, src, dst, Paint());
  }

  void _drawSector(Canvas canvas, Offset center, double innerRadius,
      double outerRadius, double startAngle, double sweepAngle, Paint paint) {
    final path = Path();
    path.moveTo(
      center.dx + innerRadius * math.cos(startAngle),
      center.dy + innerRadius * math.sin(startAngle),
    );
    path.arcTo(
      Rect.fromCircle(center: center, radius: innerRadius),
      startAngle,
      sweepAngle,
      false,
    );
    path.lineTo(
      center.dx + outerRadius * math.cos(startAngle + sweepAngle),
      center.dy + outerRadius * math.sin(startAngle + sweepAngle),
    );
    path.arcTo(
      Rect.fromCircle(center: center, radius: outerRadius),
      startAngle + sweepAngle,
      -sweepAngle,
      false,
    );
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawText(Canvas canvas, String text, double x, double y, double fontSize,
      Color color, {FontWeight? fontWeight, bool shadow = false}) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight ?? FontWeight.normal,
          color: color,
          shadows: shadow
              ? [
                  const Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 3,
                    color: Colors.black54,
                  ),
                ]
              : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height / 2),
    );
  }

  void _drawRotatedText(Canvas canvas, String text, double x, double y, double fontSize,
      Color color, double rotationAngle, {FontWeight? fontWeight, bool shadow = false}) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight ?? FontWeight.normal,
          color: color,
          shadows: shadow
              ? [
                  const Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 3,
                    color: Colors.black54,
                  ),
                ]
              : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Save canvas state
    canvas.save();

    // Move to text position
    canvas.translate(x, y);

    // Rotate the canvas
    // Adjust angle so text reads correctly (perpendicular to radius, reading outward)
    double textRotation = rotationAngle + math.pi / 2;

    // If text would be upside down, flip it
    if (textRotation > math.pi / 2 && textRotation < 3 * math.pi / 2) {
      textRotation += math.pi;
    }

    canvas.rotate(textRotation);

    // Draw text centered at origin
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );

    // Restore canvas state
    canvas.restore();
  }

  void _drawFace(
    Canvas canvas,
    Offset center,
    double radius,
    Color faceColor,
    Color featureColor,
    String eyeType,
    String mouthType,
  ) {
    final facePaint = Paint()
      ..color = faceColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, facePaint);

    final eyeOffsetX = radius * 0.35;
    final eyeOffsetY = radius * -0.15;
    final eyeRadius = radius * 0.12;
    final eyePaint = Paint()
      ..color = featureColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = featureColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.12
      ..strokeCap = StrokeCap.round;

    if (eyeType == 'Surprised') {
      canvas.drawCircle(center.translate(-eyeOffsetX, eyeOffsetY), eyeRadius * 1.4, eyePaint);
      canvas.drawCircle(center.translate(eyeOffsetX, eyeOffsetY), eyeRadius * 1.4, eyePaint);
    } else if (eyeType == 'Dizzy') {
      _drawX(canvas, center.translate(-eyeOffsetX, eyeOffsetY), eyeRadius * 1.2, strokePaint);
      _drawX(canvas, center.translate(eyeOffsetX, eyeOffsetY), eyeRadius * 1.2, strokePaint);
    } else if (eyeType == 'EyeRoll') {
      _drawArc(canvas, center.translate(-eyeOffsetX, eyeOffsetY), eyeRadius * 1.5, math.pi, strokePaint);
      _drawArc(canvas, center.translate(eyeOffsetX, eyeOffsetY), eyeRadius * 1.5, math.pi, strokePaint);
    } else {
      canvas.drawCircle(center.translate(-eyeOffsetX, eyeOffsetY), eyeRadius, eyePaint);
      canvas.drawCircle(center.translate(eyeOffsetX, eyeOffsetY), eyeRadius, eyePaint);
    }

    final mouthCenter = center.translate(0, radius * 0.3);
    if (mouthType == 'Smile' || mouthType == 'Twinkle') {
      _drawArc(canvas, mouthCenter, radius * 0.45, 0, strokePaint, sweep: math.pi);
    } else if (mouthType == 'Concerned') {
      _drawArc(canvas, mouthCenter.translate(0, radius * 0.2), radius * 0.45, math.pi, strokePaint, sweep: math.pi);
    } else if (mouthType == 'Serious' || mouthType == 'Default') {
      canvas.drawLine(
        mouthCenter.translate(-radius * 0.35, 0),
        mouthCenter.translate(radius * 0.35, 0),
        strokePaint,
      );
    } else {
      canvas.drawLine(
        mouthCenter.translate(-radius * 0.25, 0),
        mouthCenter.translate(radius * 0.25, 0),
        strokePaint,
      );
    }
  }

  void _drawX(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawLine(
      center.translate(-radius, -radius),
      center.translate(radius, radius),
      paint,
    );
    canvas.drawLine(
      center.translate(-radius, radius),
      center.translate(radius, -radius),
      paint,
    );
  }

  void _drawArc(Canvas canvas, Offset center, double radius, double startAngle,
      Paint paint, {double sweep = 0}) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweep == 0 ? math.pi : sweep, false, paint);
  }

  Color _contrastColor(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) {
    return oldDelegate.selectedCore != selectedCore ||
        oldDelegate.selectedSecondary != selectedSecondary ||
        oldDelegate.selectedTertiary != selectedTertiary ||
        oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.maxDepth != maxDepth ||
        oldDelegate.faceImages.length != faceImages.length;
  }
}

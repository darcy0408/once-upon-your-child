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

    // Center hub: tap to confirm selection
    if (ringRatio < 0.22) {
      _pickSelection();
      return;
    }

    // No selection yet - tap anywhere to select core
    if (_selectedCore == null || widget.maxDepth == 0) {
      if (ringRatio >= 0.50 && ringRatio <= 0.90) {
        _tapCore(angle);
      }
      return;
    }

    // Core selected - determine if tapping core, secondary, or tertiary
    if (ringRatio >= 0.50 && ringRatio <= 0.90) {
      // Tapping core ring
      _tapCore(angle);
      return;
    }

    if (_selectedSecondary == null) {
      // Core selected but no secondary - tap secondary expansion area
      if (widget.maxDepth >= 1 && ringRatio >= 0.10 && ringRatio < 0.48) {
        _tapSecondary(angle);
        return;
      }
    } else {
      // Secondary selected - can tap tertiary expansion area
      if (widget.maxDepth >= 2 && ringRatio >= 0.10 && ringRatio < 0.35) {
        _tapTertiary(angle);
        return;
      } else if (ringRatio >= 0.10 && ringRatio < 0.48) {
        _tapSecondary(angle);
        return;
      }
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

    // Always draw core emotions in outer ring
    _drawCoreRing(canvas, center, radius);

    // Draw secondary emotions expanding below if core is selected
    if (selectedCore != null) {
      _drawSecondaryExpansion(canvas, center, radius);
    }

    // Draw tertiary emotions expanding below if secondary is selected
    if (selectedCore != null && selectedSecondary != null) {
      _drawTertiaryExpansion(canvas, center, radius);
    }

    // Draw center hub with selected emotion
    _drawCenterHub(canvas, center, radius);
  }

  void _drawCoreRing(Canvas canvas, Offset center, double radius) {
    const startAngle = -math.pi / 2;
    const gapAngle = 0.02;
    const coreInner = 0.50; // Core ring inner edge
    const coreOuter = 0.90; // Core ring outer edge

    final coreSectorAngle = (2 * math.pi) / wheelOrder.length;

    for (int i = 0; i < wheelOrder.length; i++) {
      final coreId = wheelOrder[i];
      final core = coreEmotions.firstWhere((c) => c.id == coreId);
      final coreColor = core.color ?? Colors.grey;

      final sectorStart = startAngle + i * coreSectorAngle + gapAngle / 2;
      final sectorAngle = coreSectorAngle - gapAngle;

      final isSelected = selectedCore?.id == core.id;

      _drawCoreSegment(canvas, center, radius, sectorStart, sectorAngle,
          coreInner, coreOuter, coreColor, isSelected, core.name, core.id);
    }
  }

  void _drawSecondaryExpansion(Canvas canvas, Offset center, double radius) {
    if (selectedCore == null) return;

    final secondaryList = selectedCore!.secondary;
    if (secondaryList.isEmpty) return;

    // Find the selected core emotion's angular position
    final coreIndex = wheelOrder.indexOf(selectedCore!.id);
    if (coreIndex == -1) return;

    const startAngle = -math.pi / 2;
    final coreSectorAngle = (2 * math.pi) / wheelOrder.length;
    final coreStart = startAngle + coreIndex * coreSectorAngle;

    // Secondary emotions expand as small tabs below the core wedge
    const secondaryInner = 0.10; // Start near center
    const secondaryOuter = 0.48; // End below core ring

    final secondarySectorAngle = coreSectorAngle / secondaryList.length;

    for (int i = 0; i < secondaryList.length; i++) {
      final secondary = secondaryList[i];
      final secondaryColor = selectedCore!.secondaryColor ?? selectedCore!.color ?? Colors.grey;

      final sectorStart = coreStart + i * secondarySectorAngle + 0.01;
      final sectorAngle = secondarySectorAngle - 0.02;

      final isSelected = selectedSecondary?.id == secondary.id;

      _drawSecondarySegment(canvas, center, radius, sectorStart, sectorAngle,
          secondaryInner, secondaryOuter, secondaryColor, isSelected, secondary.name, secondary.id);
    }
  }

  void _drawTertiaryExpansion(Canvas canvas, Offset center, double radius) {
    if (selectedCore == null || selectedSecondary == null) return;

    final tertiaryList = selectedSecondary!.tertiary;
    if (tertiaryList.isEmpty) return;

    // Find angular positions
    final coreIndex = wheelOrder.indexOf(selectedCore!.id);
    final secondaryList = selectedCore!.secondary;
    final secondaryIndex = secondaryList.indexWhere((s) => s.id == selectedSecondary!.id);

    if (coreIndex == -1 || secondaryIndex == -1) return;

    const startAngle = -math.pi / 2;
    final coreSectorAngle = (2 * math.pi) / wheelOrder.length;
    final coreStart = startAngle + coreIndex * coreSectorAngle;
    final secondarySectorAngle = coreSectorAngle / secondaryList.length;
    final secondaryStart = coreStart + secondaryIndex * secondarySectorAngle;

    // Tertiary emotions expand as tiny tabs at the very bottom
    const tertiaryInner = 0.10;
    const tertiaryOuter = 0.35;

    final tertiarySectorAngle = secondarySectorAngle / tertiaryList.length;

    for (int i = 0; i < tertiaryList.length; i++) {
      final tertiary = tertiaryList[i];
      final tertiaryColor = selectedCore!.tertiaryColor ?? selectedCore!.color ?? Colors.grey;

      final sectorStart = secondaryStart + i * tertiarySectorAngle + 0.005;
      final sectorAngle = tertiarySectorAngle - 0.01;

      final isSelected = selectedTertiary == tertiary;

      _drawTertiarySegment(canvas, center, radius, sectorStart, sectorAngle,
          tertiaryInner, tertiaryOuter, tertiaryColor, isSelected, tertiary);
    }
  }



  void _drawCoreSegment(Canvas canvas, Offset center, double radius, double startAngle,
      double sweepAngle, double innerRatio, double outerRatio, Color color,
      bool isSelected, String label, String emotionId) {

    final innerRadius = radius * innerRatio;
    final outerRadius = radius * outerRatio;

    // Draw STRONG glow if selected - make it magical!
    if (isSelected) {
      // Outer glow layer
      final outerGlowPaint = Paint()
        ..color = color.withValues(alpha: 0.5 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35)
        ..style = PaintingStyle.fill;
      _drawSector(canvas, center, innerRadius * 0.90, outerRadius * 1.08,
          startAngle, sweepAngle, outerGlowPaint);

      // Inner glow layer for extra brightness
      final innerGlowPaint = Paint()
        ..color = color.withValues(alpha: 0.7 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)
        ..style = PaintingStyle.fill;
      _drawSector(canvas, center, innerRadius * 0.95, outerRadius * 1.03,
          startAngle, sweepAngle, innerGlowPaint);
    }

    // Draw main segment - brighter when selected
    final segmentPaint = Paint()
      ..color = isSelected ? color : color.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    _drawSector(canvas, center, innerRadius, outerRadius, startAngle, sweepAngle, segmentPaint);

    // Calculate positions - face in INNER area, label in OUTER area (no overlap!)
    final midRadius = (innerRadius + outerRadius) / 2;
    final faceRadius = innerRadius * 1.15; // Face closer to inner edge
    final labelRadius = outerRadius * 0.78; // Label near outer edge

    final centerAngle = startAngle + sweepAngle / 2;

    // Draw face image DIRECTLY on segment (no circular background!)
    final faceImage = _imageForName(emotionId);
    if (faceImage != null) {
      final faceCenter = Offset(
        center.dx + faceRadius * math.cos(centerAngle),
        center.dy + faceRadius * math.sin(centerAngle),
      );

      // Calculate face size based on segment dimensions
      final arcLength = midRadius * sweepAngle;
      final radialDepth = outerRadius - innerRadius;
      final maxFaceSize = math.min(arcLength * 0.5, radialDepth * 0.35);
      final faceSize = maxFaceSize.clamp(radius * 0.04, radius * 0.12);

      // Draw face WITHOUT circular clipping or background
      _drawImageFaceFlat(canvas, faceImage, faceCenter, faceSize);
    }

    // Draw label in outer area - will not overlap with face
    final labelX = center.dx + labelRadius * math.cos(centerAngle);
    final labelY = center.dy + labelRadius * math.sin(centerAngle);

    _drawText(canvas, label, labelX, labelY, 14.0, Colors.white,
        fontWeight: FontWeight.bold, shadow: true);
  }

  void _drawSecondarySegment(Canvas canvas, Offset center, double radius, double startAngle,
      double sweepAngle, double innerRatio, double outerRatio, Color color,
      bool isSelected, String label, String emotionId) {

    final innerRadius = radius * innerRatio;
    final outerRadius = radius * outerRatio;

    // Strong glow for selected secondary emotions
    if (isSelected) {
      // Outer glow
      final outerGlowPaint = Paint()
        ..color = color.withValues(alpha: 0.5 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30)
        ..style = PaintingStyle.fill;
      _drawSector(canvas, center, innerRadius * 0.90, outerRadius * 1.06,
          startAngle, sweepAngle, outerGlowPaint);

      // Inner glow
      final innerGlowPaint = Paint()
        ..color = color.withValues(alpha: 0.7 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
        ..style = PaintingStyle.fill;
      _drawSector(canvas, center, innerRadius * 0.95, outerRadius * 1.03,
          startAngle, sweepAngle, innerGlowPaint);
    }

    final segmentPaint = Paint()
      ..color = isSelected ? color : color.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    _drawSector(canvas, center, innerRadius, outerRadius, startAngle, sweepAngle, segmentPaint);

    // Position label at outer edge
    final labelRadius = outerRadius * 0.85;
    final labelAngle = startAngle + sweepAngle / 2;
    final labelX = center.dx + labelRadius * math.cos(labelAngle);
    final labelY = center.dy + labelRadius * math.sin(labelAngle);

    _drawText(canvas, label, labelX, labelY, 9.0, Colors.white,
        fontWeight: FontWeight.w600, shadow: true);

    // No face icons for secondary emotions - labels only
  }

  void _drawTertiarySegment(Canvas canvas, Offset center, double radius, double startAngle,
      double sweepAngle, double innerRatio, double outerRatio, Color color,
      bool isSelected, String label) {

    final innerRadius = radius * innerRatio;
    final outerRadius = radius * outerRatio;

    // Strong glow for selected tertiary emotions
    if (isSelected) {
      // Outer glow
      final outerGlowPaint = Paint()
        ..color = color.withValues(alpha: 0.5 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25)
        ..style = PaintingStyle.fill;
      _drawSector(canvas, center, innerRadius * 0.90, outerRadius * 1.06,
          startAngle, sweepAngle, outerGlowPaint);

      // Inner glow
      final innerGlowPaint = Paint()
        ..color = color.withValues(alpha: 0.7 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..style = PaintingStyle.fill;
      _drawSector(canvas, center, innerRadius * 0.95, outerRadius * 1.03,
          startAngle, sweepAngle, innerGlowPaint);
    }

    final segmentPaint = Paint()
      ..color = isSelected ? color : color.withValues(alpha: 0.80)
      ..style = PaintingStyle.fill;

    _drawSector(canvas, center, innerRadius, outerRadius, startAngle, sweepAngle, segmentPaint);

    // Position label at outer edge
    final labelRadius = outerRadius * 0.80;
    final labelAngle = startAngle + sweepAngle / 2;
    final labelX = center.dx + labelRadius * math.cos(labelAngle);
    final labelY = center.dy + labelRadius * math.sin(labelAngle);

    _drawText(canvas, label, labelX, labelY, 8.0, Colors.white,
        fontWeight: FontWeight.w600, shadow: true);

    // No face icons for tertiary emotions - labels only
  }



  void _drawCenterHub(Canvas canvas, Offset center, double radius) {
    final hubRadius = radius * 0.18; // Slightly larger hub

    if (selectedCore == null) {
      // Empty state - subtle background
      final hintPaint = Paint()
        ..color = backgroundColor.withValues(alpha: 0.3)
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

    // MAGICAL pulsing glow effect - stronger and more visible
    final outerGlow = Paint()
      ..color = baseColor.withValues(alpha: 0.4 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(center, hubRadius * 1.5, outerGlow);

    final innerGlow = Paint()
      ..color = baseColor.withValues(alpha: 0.6 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, hubRadius * 1.2, innerGlow);

    // Colored background circle (not white!)
    final bgPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, hubRadius, bgPaint);

    // LARGE face icon positioned higher to avoid overlap with text
    final faceSize = radius * 0.15; // Larger flat face
    final faceCenter = Offset(center.dx, center.dy - hubRadius * 0.15); // Move face up
    final faceImage = _imageForName(name);

    if (faceImage != null) {
      _drawImageFaceFlat(canvas, faceImage, faceCenter, faceSize);
    } else {
      // Fallback to procedural drawing
      final featureColor = _contrastColor(baseColor);
      _drawFace(
        canvas,
        faceCenter,
        faceSize * 0.5,
        Colors.white.withValues(alpha: 0.9),
        featureColor,
        eyeType,
        mouthType,
      );
    }

    // Text label below face - positioned lower to avoid overlap
    final textY = center.dy + hubRadius * 1.4; // Moved further down
    _drawText(
      canvas,
      name,
      center.dx,
      textY,
      13, // Slightly larger text
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

  void _drawImageFaceFlat(Canvas canvas, ui.Image image, Offset center, double size) {
    // Draw face image FLAT on segment without any circular clipping or backgrounds
    // This preserves all face details and text won't be overlapped
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromCenter(center: center, width: size, height: size);

    // Draw directly without clipping - let the face be part of the segment
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

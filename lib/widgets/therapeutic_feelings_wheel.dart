import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../feelings_wheel_data.dart';

/// Professional therapeutic feelings wheel for children ages 5-8
/// Traditional layout: Core emotions in center ring, secondary in middle, tertiary in outer
/// Progressive illumination: Tap to light up emotional paths
class TherapeuticFeelingsWheel extends StatefulWidget {
  final ValueChanged<SelectedFeeling>? onFeelingSelected;
  final Color backgroundColor;

  const TherapeuticFeelingsWheel({
    super.key,
    this.onFeelingSelected,
    this.backgroundColor = const Color(0xFFF5E6D3),
  });

  @override
  State<TherapeuticFeelingsWheel> createState() => _TherapeuticFeelingsWheelState();
}

class _TherapeuticFeelingsWheelState extends State<TherapeuticFeelingsWheel>
    with SingleTickerProviderStateMixin {
  CoreEmotion? _selectedCore;
  SecondaryFeeling? _selectedSecondary;
  String? _selectedTertiary;

  final Map<String, ui.Image> _faceImages = {};
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Wheel order clockwise from top
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

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _loadFaceImages() async {
    // Load all 122 emotion face images
    for (final core in FeelingsWheelData.coreEmotions) {
      await _loadFaceImage(core.id);
      for (final secondary in core.secondary) {
        await _loadFaceImage(secondary.id);
        for (final tertiary in secondary.tertiary) {
          await _loadFaceImage(tertiary);
        }
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadFaceImage(String emotionName) async {
    final key = _sanitizeKey(emotionName);
    try {
      final data = await rootBundle.load('assets/feelings_faces/$key.webp');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _faceImages[key] = frame.image;
    } catch (_) {
      // Image not found, will draw without face
    }
  }

  String _sanitizeKey(String name) {
    final lower = name.toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return replaced.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  }

  void _handleTap(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final ringRatio = distance / radius;

    // Convert tap to angle (0 = top, clockwise)
    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    // Core ring: 20%-40% of radius
    if (ringRatio >= 0.20 && ringRatio <= 0.40) {
      _tapCore(angle);
      return;
    }

    // Secondary ring: 40%-70% of radius
    if (ringRatio >= 0.40 && ringRatio <= 0.70) {
      if (_selectedCore != null) {
        _tapSecondary(angle);
      }
      return;
    }

    // Tertiary ring: 70%-95% of radius
    if (ringRatio >= 0.70 && ringRatio <= 0.95) {
      if (_selectedCore != null && _selectedSecondary != null) {
        _tapTertiary(angle);
      }
      return;
    }
  }

  void _tapCore(double angle) {
    final coreIndex = _getSegmentIndex(angle, _wheelOrder.length);
    final coreId = _wheelOrder[coreIndex];
    final core = FeelingsWheelData.coreEmotions.firstWhere((c) => c.id == coreId);

    setState(() {
      if (_selectedCore?.id == core.id) {
        // Deselect
        _selectedCore = null;
        _selectedSecondary = null;
        _selectedTertiary = null;
      } else {
        // Select new core
        _selectedCore = core;
        _selectedSecondary = null;
        _selectedTertiary = null;
      }
    });

    _notifySelection();
  }

  void _tapSecondary(double angle) {
    if (_selectedCore == null) return;

    final coreIndex = _wheelOrder.indexOf(_selectedCore!.id);
    final coreSectorAngle = (2 * math.pi) / _wheelOrder.length;
    final coreStart = -math.pi / 2 + coreIndex * coreSectorAngle;

    // Check if tap is within selected core's sector
    var relativeAngle = angle - coreStart;
    if (relativeAngle < 0) relativeAngle += 2 * math.pi;

    if (relativeAngle >= 0 && relativeAngle <= coreSectorAngle) {
      final secondaryList = _selectedCore!.secondary;
      if (secondaryList.isEmpty) return;

      final secondaryIndex = _getSegmentIndex(relativeAngle, secondaryList.length);
      if (secondaryIndex < secondaryList.length) {
        setState(() {
          final secondary = secondaryList[secondaryIndex];
          if (_selectedSecondary?.id == secondary.id) {
            _selectedSecondary = null;
            _selectedTertiary = null;
          } else {
            _selectedSecondary = secondary;
            _selectedTertiary = null;
          }
        });
        _notifySelection();
      }
    }
  }

  void _tapTertiary(double angle) {
    if (_selectedCore == null || _selectedSecondary == null) return;

    final coreIndex = _wheelOrder.indexOf(_selectedCore!.id);
    final coreSectorAngle = (2 * math.pi) / _wheelOrder.length;
    final coreStart = -math.pi / 2 + coreIndex * coreSectorAngle;

    final secondaryList = _selectedCore!.secondary;
    final secondaryIndex = secondaryList.indexOf(_selectedSecondary!);
    final secondarySectorAngle = coreSectorAngle / secondaryList.length;
    final secondaryStart = coreStart + secondaryIndex * secondarySectorAngle;

    var relativeAngle = angle - secondaryStart;
    if (relativeAngle < 0) relativeAngle += 2 * math.pi;

    if (relativeAngle >= 0 && relativeAngle <= secondarySectorAngle) {
      final tertiaryList = _selectedSecondary!.tertiary;
      if (tertiaryList.isEmpty) return;

      final tertiaryIndex = _getSegmentIndex(relativeAngle, tertiaryList.length);
      if (tertiaryIndex < tertiaryList.length) {
        setState(() {
          final tertiary = tertiaryList[tertiaryIndex];
          if (_selectedTertiary == tertiary) {
            _selectedTertiary = null;
          } else {
            _selectedTertiary = tertiary;
          }
        });
        _notifySelection();
      }
    }
  }

  int _getSegmentIndex(double angle, int segmentCount) {
    final normalizedAngle = angle % (2 * math.pi);
    final segmentAngle = (2 * math.pi) / segmentCount;
    return (normalizedAngle / segmentAngle).floor() % segmentCount;
  }

  void _notifySelection() {
    if (widget.onFeelingSelected == null) return;

    // Determine the selected emotion and its properties
    String coreName = _selectedCore?.name ?? '';
    String secondaryName = _selectedSecondary?.name ?? '';
    String tertiaryName = _selectedTertiary ?? '';
    String emoji = _selectedCore?.emoji ?? '😊';
    String eyeType = _selectedSecondary?.eyeType ?? _selectedCore?.eyeType ?? 'normal';
    String mouthType = _selectedSecondary?.mouthType ?? _selectedCore?.mouthType ?? 'smile';
    Color color = _selectedCore?.color ?? Colors.grey;

    widget.onFeelingSelected!(SelectedFeeling(
      core: coreName,
      secondary: secondaryName,
      tertiary: tertiaryName,
      emoji: emoji,
      eyeType: eyeType,
      mouthType: mouthType,
      color: color,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTapDown: (details) => _handleTap(details.localPosition, context.size!),
          child: CustomPaint(
            painter: _TherapeuticWheelPainter(
              coreEmotions: FeelingsWheelData.coreEmotions,
              wheelOrder: _wheelOrder,
              selectedCore: _selectedCore,
              selectedSecondary: _selectedSecondary,
              selectedTertiary: _selectedTertiary,
              faceImages: _faceImages,
              glowIntensity: _glowAnimation.value,
              backgroundColor: widget.backgroundColor,
            ),
            child: Container(),
          ),
        );
      },
    );
  }
}

class _TherapeuticWheelPainter extends CustomPainter {
  final List<CoreEmotion> coreEmotions;
  final List<String> wheelOrder;
  final CoreEmotion? selectedCore;
  final SecondaryFeeling? selectedSecondary;
  final String? selectedTertiary;
  final Map<String, ui.Image> faceImages;
  final double glowIntensity;
  final Color backgroundColor;

  _TherapeuticWheelPainter({
    required this.coreEmotions,
    required this.wheelOrder,
    required this.selectedCore,
    required this.selectedSecondary,
    required this.selectedTertiary,
    required this.faceImages,
    required this.glowIntensity,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw all three rings - always visible for teaching full emotional vocabulary
    _drawTertiaryRing(canvas, center, radius);
    _drawSecondaryRing(canvas, center, radius);
    _drawCoreRing(canvas, center, radius);

    // Draw center hub
    _drawCenterHub(canvas, center, radius);
  }

  void _drawCoreRing(Canvas canvas, Offset center, double radius) {
    const innerRatio = 0.20;
    const outerRatio = 0.40;
    const startAngle = -math.pi / 2;
    const gapAngle = 0.02;

    final sectorAngle = (2 * math.pi) / wheelOrder.length;

    for (int i = 0; i < wheelOrder.length; i++) {
      final coreId = wheelOrder[i];
      final core = coreEmotions.firstWhere((c) => c.id == coreId);
      final color = core.color ?? Colors.grey;

      final segmentStart = startAngle + i * sectorAngle + gapAngle / 2;
      final segmentAngle = sectorAngle - gapAngle;

      final isSelected = selectedCore?.id == core.id;
      final opacity = isSelected ? 1.0 : 0.30; // Progressive illumination!

      _drawSegment(
        canvas,
        center,
        radius,
        segmentStart,
        segmentAngle,
        innerRatio,
        outerRatio,
        color,
        opacity,
        isSelected,
        core.name,
        core.id,
        'core',
      );
    }
  }

  void _drawSecondaryRing(Canvas canvas, Offset center, double radius) {
    const innerRatio = 0.40;
    const outerRatio = 0.70;
    const startAngle = -math.pi / 2;

    final coreSectorAngle = (2 * math.pi) / wheelOrder.length;

    for (int i = 0; i < wheelOrder.length; i++) {
      final coreId = wheelOrder[i];
      final core = coreEmotions.firstWhere((c) => c.id == coreId);
      final coreStart = startAngle + i * coreSectorAngle;

      final secondaryList = core.secondary;
      if (secondaryList.isEmpty) continue;

      final secondarySectorAngle = coreSectorAngle / secondaryList.length;

      for (int j = 0; j < secondaryList.length; j++) {
        final secondary = secondaryList[j];
        final color = core.secondaryColor ?? core.color ?? Colors.grey;

        final segmentStart = coreStart + j * secondarySectorAngle + 0.01;
        final segmentAngle = secondarySectorAngle - 0.02;

        // Only illuminate if this core is selected
        final isThisCoreSelected = selectedCore?.id == core.id;
        final isThisSecondarySelected = isThisCoreSelected && selectedSecondary?.id == secondary.id;
        final opacity = isThisCoreSelected ? (isThisSecondarySelected ? 1.0 : 0.60) : 0.30;

        _drawSegment(
          canvas,
          center,
          radius,
          segmentStart,
          segmentAngle,
          innerRatio,
          outerRatio,
          color,
          opacity,
          isThisSecondarySelected,
          secondary.name,
          secondary.id,
          'secondary',
        );
      }
    }
  }

  void _drawTertiaryRing(Canvas canvas, Offset center, double radius) {
    const innerRatio = 0.70;
    const outerRatio = 0.95;
    const startAngle = -math.pi / 2;

    final coreSectorAngle = (2 * math.pi) / wheelOrder.length;

    for (int i = 0; i < wheelOrder.length; i++) {
      final coreId = wheelOrder[i];
      final core = coreEmotions.firstWhere((c) => c.id == coreId);
      final coreStart = startAngle + i * coreSectorAngle;

      final secondaryList = core.secondary;
      if (secondaryList.isEmpty) continue;

      final secondarySectorAngle = coreSectorAngle / secondaryList.length;

      for (int j = 0; j < secondaryList.length; j++) {
        final secondary = secondaryList[j];
        final secondaryStart = coreStart + j * secondarySectorAngle;

        final tertiaryList = secondary.tertiary;
        if (tertiaryList.isEmpty) continue;

        final tertiarySectorAngle = secondarySectorAngle / tertiaryList.length;

        for (int k = 0; k < tertiaryList.length; k++) {
          final tertiary = tertiaryList[k];
          final color = core.tertiaryColor ?? core.color ?? Colors.grey;

          final segmentStart = secondaryStart + k * tertiarySectorAngle + 0.005;
          final segmentAngle = tertiarySectorAngle - 0.01;

          // Only illuminate if both core and secondary are selected
          final isPathSelected = selectedCore?.id == core.id && selectedSecondary?.id == secondary.id;
          final isThisTertiarySelected = isPathSelected && selectedTertiary == tertiary;
          final opacity = isPathSelected ? (isThisTertiarySelected ? 1.0 : 0.60) : 0.30;

          _drawSegment(
            canvas,
            center,
            radius,
            segmentStart,
            segmentAngle,
            innerRatio,
            outerRatio,
            color,
            opacity,
            isThisTertiarySelected,
            tertiary,
            tertiary,
            'tertiary',
          );
        }
      }
    }
  }

  void _drawSegment(
    Canvas canvas,
    Offset center,
    double radius,
    double startAngle,
    double sweepAngle,
    double innerRatio,
    double outerRatio,
    Color color,
    double opacity,
    bool isSelected,
    String label,
    String emotionId,
    String level,
  ) {
    final innerRadius = radius * innerRatio;
    final outerRadius = radius * outerRatio;

    // Draw magical glow if selected
    if (isSelected) {
      final glowPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.4 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
        ..style = PaintingStyle.fill;
      _drawSector(canvas, center, innerRadius * 0.95, outerRadius * 1.05,
          startAngle, sweepAngle, glowPaint);
    }

    // Draw main segment with progressive illumination
    final segmentPaint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    _drawSector(canvas, center, innerRadius, outerRadius, startAngle, sweepAngle, segmentPaint);

    // Draw face if available (using blend mode to remove white)
    final faceImage = _getFaceImage(emotionId);
    if (faceImage != null) {
      _drawFaceOnSegment(canvas, center, radius, startAngle, sweepAngle,
          innerRatio, outerRatio, faceImage, level);
    }

    // Draw label
    _drawLabel(canvas, center, radius, startAngle, sweepAngle,
        innerRatio, outerRatio, label, level);
  }

  void _drawFaceOnSegment(
    Canvas canvas,
    Offset center,
    double radius,
    double startAngle,
    double sweepAngle,
    double innerRatio,
    double outerRatio,
    ui.Image faceImage,
    String level,
  ) {
    final midRadius = radius * ((innerRatio + outerRatio) / 2);
    final midAngle = startAngle + sweepAngle / 2;

    final faceCenter = Offset(
      center.dx + midRadius * math.cos(midAngle),
      center.dy + midRadius * math.sin(midAngle),
    );

    // Size based on level and segment size
    double faceSize;
    if (level == 'core') {
      faceSize = radius * 0.12; // Large faces for core
    } else if (level == 'secondary') {
      faceSize = radius * 0.06; // Medium for secondary
    } else {
      faceSize = radius * 0.03; // Small for tertiary
    }

    // Draw face with blend mode to remove white backgrounds
    final src = Rect.fromLTWH(0, 0, faceImage.width.toDouble(), faceImage.height.toDouble());
    final dst = Rect.fromCenter(center: faceCenter, width: faceSize, height: faceSize);

    final paint = Paint()
      ..colorFilter = const ColorFilter.mode(Colors.black, BlendMode.multiply);

    canvas.drawImageRect(faceImage, src, dst, paint);
  }

  void _drawLabel(
    Canvas canvas,
    Offset center,
    double radius,
    double startAngle,
    double sweepAngle,
    double innerRatio,
    double outerRatio,
    String label,
    String level,
  ) {
    // Position label at edge of segment
    double labelRatio = outerRatio * 0.92;
    double fontSize;

    if (level == 'core') {
      fontSize = 14.0;
    } else if (level == 'secondary') {
      fontSize = 10.0;
    } else {
      fontSize = 8.0;
      // For tertiary, only show if segment is wide enough
      if (sweepAngle < 0.05) return;
    }

    final labelAngle = startAngle + sweepAngle / 2;
    final labelX = center.dx + radius * labelRatio * math.cos(labelAngle);
    final labelY = center.dy + radius * labelRatio * math.sin(labelAngle);

    _drawText(canvas, label, labelX, labelY, fontSize, Colors.white);
  }

  void _drawCenterHub(Canvas canvas, Offset center, double radius) {
    final hubRadius = radius * 0.15;

    if (selectedCore == null) {
      // Empty state
      final hintPaint = Paint()
        ..color = backgroundColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, hubRadius, hintPaint);

      _drawText(canvas, 'Tap a\nfeeling', center.dx, center.dy, 11, Colors.black54);
      return;
    }

    // Show selected emotion in center
    String name = selectedCore!.name;
    Color color = selectedCore!.color ?? Colors.grey;

    if (selectedTertiary != null) {
      name = selectedTertiary!;
      color = selectedCore!.tertiaryColor ?? color;
    } else if (selectedSecondary != null) {
      name = selectedSecondary!.name;
      color = selectedCore!.secondaryColor ?? color;
    }

    // Magical glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
    canvas.drawCircle(center, hubRadius * 1.4, glowPaint);

    // Colored background
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, hubRadius, bgPaint);

    // Face image
    final faceImage = _getFaceImage(name);
    if (faceImage != null) {
      final src = Rect.fromLTWH(0, 0, faceImage.width.toDouble(), faceImage.height.toDouble());
      final faceSize = hubRadius * 1.2;
      final dst = Rect.fromCenter(
        center: Offset(center.dx, center.dy - hubRadius * 0.2),
        width: faceSize,
        height: faceSize,
      );

      final paint = Paint()
        ..colorFilter = const ColorFilter.mode(Colors.black, BlendMode.multiply);
      canvas.drawImageRect(faceImage, src, dst, paint);
    }

    // Label below
    _drawText(canvas, name, center.dx, center.dy + hubRadius * 1.5, 13, Colors.white);
  }

  ui.Image? _getFaceImage(String name) {
    final key = _sanitizeKey(name);
    return faceImages[key];
  }

  String _sanitizeKey(String name) {
    final lower = name.toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return replaced.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
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

  void _drawText(Canvas canvas, String text, double x, double y, double fontSize, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(
              color: Colors.black45,
              offset: Offset(1, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_TherapeuticWheelPainter oldDelegate) {
    return oldDelegate.selectedCore != selectedCore ||
        oldDelegate.selectedSecondary != selectedSecondary ||
        oldDelegate.selectedTertiary != selectedTertiary ||
        oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.faceImages != faceImages;
  }
}

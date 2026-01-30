import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../feelings_wheel_data.dart';

/// Wheel navigation level
enum WheelLevel { core, secondary, tertiary }

/// Interactive expanding feelings wheel with progressive replacement UX
/// Shows one level at a time: core -> secondary -> tertiary
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
    with TickerProviderStateMixin {
  WheelLevel _currentLevel = WheelLevel.core;
  CoreEmotion? _selectedCore;
  SecondaryFeeling? _selectedSecondary;

  final Map<String, ui.Image> _faceImages = {};
  final Set<String> _availableFaces = {
    // Core emotions
    'angry', 'happy', 'surprised', 'bad', 'fearful', 'sad', 'disgusted',
    // Happy family
    'accepted', 'respected', 'valued', 'powerful', 'courageous', 'creative',
    'peaceful', 'loving', 'thankful', 'trusting', 'sensitive', 'connected',
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
    'mad', 'furious', 'jealous', 'aggressive', 'provoked', 'hostile',
    'humiliated', 'disrespected', 'ridiculed', 'bitter', 'indignant', 'wronged',
    'frustrated', 'infuriated', 'annoyed', 'distant', 'withdrawn', 'numb',
    'critical', 'skeptical', 'dismissive', 'disapproving', 'judgmental', 'embarrassed',
    // Original faces
    'playful', 'silly', 'cheeky', 'content', 'free', 'joyful',
    'interested', 'curious', 'inquisitive', 'confident', 'proud', 'successful',
  };

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _transitionController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Wheel order clockwise from top (12 o'clock)
  final List<String> _wheelOrder = const [
    'happy',
    'surprised',
    'bad',
    'fearful',
    'sad',
    'disgusted',
    'angry',
  ];

  /// Get current emotions to display based on level
  List<dynamic> get _currentEmotions {
    switch (_currentLevel) {
      case WheelLevel.core:
        return FeelingsWheelData.coreEmotions;
      case WheelLevel.secondary:
        return _selectedCore?.secondary ?? [];
      case WheelLevel.tertiary:
        return _selectedSecondary?.tertiary ?? [];
    }
  }

  /// Get the current color based on selection
  Color get _currentColor {
    if (_selectedCore == null) return const Color(0xFFFFD93D);
    switch (_currentLevel) {
      case WheelLevel.core:
        return _selectedCore!.color ?? const Color(0xFFFFD93D);
      case WheelLevel.secondary:
        return _selectedCore!.secondaryColor ?? _selectedCore!.color ?? const Color(0xFFFFD93D);
      case WheelLevel.tertiary:
        return _selectedCore!.tertiaryColor ?? _selectedCore!.color ?? const Color(0xFFFFD93D);
    }
  }

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

    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _transitionController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _transitionController, curve: Curves.easeOut),
    );
    _transitionController.forward();

    _loadFaceImages();
  }

  Future<void> _loadFaceImages() async {
    int loaded = 0;
    int failed = 0;
    for (final key in _availableFaces) {
      try {
        final data = await rootBundle.load('assets/feelings_faces/$key.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        _faceImages[key] = frame.image;
        loaded++;
      } catch (e) {
        failed++;
        debugPrint('Failed to load face image: $key - $e');
      }
    }
    debugPrint('Feelings wheel: Loaded $loaded faces, failed $failed');
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _transitionController.dispose();
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

    // Center hub: go back or confirm selection
    if (ringRatio < 0.25) {
      if (_currentLevel != WheelLevel.core) {
        _goBack();
      } else {
        // On core level, tapping center does nothing (or could confirm if something selected)
      }
      return;
    }

    // Tap on wheel ring
    if (ringRatio >= 0.30 && ringRatio <= 0.90) {
      _tapSector(angle);
    }
  }

  void _tapSector(double angle) {
    final emotions = _currentEmotions;
    if (emotions.isEmpty) return;

    final sectorAngle = (2 * math.pi) / emotions.length;
    final sectorIndex = (angle / sectorAngle).floor() % emotions.length;

    switch (_currentLevel) {
      case WheelLevel.core:
        _selectCore(sectorIndex);
        break;
      case WheelLevel.secondary:
        _selectSecondary(sectorIndex);
        break;
      case WheelLevel.tertiary:
        _selectTertiary(sectorIndex);
        break;
    }
  }

  void _selectCore(int index) {
    final coreId = _wheelOrder[index];
    final core = FeelingsWheelData.coreEmotions.firstWhere((c) => c.id == coreId);

    if (widget.maxDepth == 0) {
      // Core only mode - select and finish
      widget.onFeelingSelected?.call(
        SelectedFeeling(
          core: core.name,
          secondary: '',
          tertiary: core.name,
          emoji: core.emoji,
          eyeType: core.eyeType,
          mouthType: core.mouthType,
          color: core.color ?? const Color(0xFFFFD93D),
        ),
      );
      return;
    }

    // Navigate to secondary level
    _transitionController.reset();
    setState(() {
      _selectedCore = core;
      _selectedSecondary = null;
      _currentLevel = WheelLevel.secondary;
    });
    _transitionController.forward();
  }

  void _selectSecondary(int index) {
    if (_selectedCore == null) return;
    final secondaryList = _selectedCore!.secondary;
    if (index >= secondaryList.length) return;

    final secondary = secondaryList[index];

    if (widget.maxDepth == 1 || secondary.tertiary.isEmpty) {
      // Secondary only mode or no tertiary - select and finish
      widget.onFeelingSelected?.call(
        SelectedFeeling(
          core: _selectedCore!.name,
          secondary: secondary.name,
          tertiary: secondary.name,
          emoji: secondary.emoji,
          eyeType: secondary.eyeType,
          mouthType: secondary.mouthType,
          color: _selectedCore!.color ?? const Color(0xFFFFD93D),
        ),
      );
      return;
    }

    // Navigate to tertiary level
    _transitionController.reset();
    setState(() {
      _selectedSecondary = secondary;
      _currentLevel = WheelLevel.tertiary;
    });
    _transitionController.forward();
  }

  void _selectTertiary(int index) {
    if (_selectedCore == null || _selectedSecondary == null) return;
    final tertiaryList = _selectedSecondary!.tertiary;
    if (index >= tertiaryList.length) return;

    final tertiary = tertiaryList[index];
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

  void _goBack() {
    _transitionController.reset();
    setState(() {
      if (_currentLevel == WheelLevel.tertiary) {
        _currentLevel = WheelLevel.secondary;
        _selectedSecondary = null;
      } else if (_currentLevel == WheelLevel.secondary) {
        _currentLevel = WheelLevel.core;
        _selectedCore = null;
        _selectedSecondary = null;
      }
    });
    _transitionController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth;
          return AnimatedBuilder(
            animation: Listenable.merge([_glowAnimation, _transitionController]),
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Animated wheel with fade and scale
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: CustomPaint(
                        size: Size(size, size),
                        painter: _SimpleWheelPainter(
                          emotions: _currentEmotions,
                          level: _currentLevel,
                          selectedCore: _selectedCore,
                          selectedSecondary: _selectedSecondary,
                          baseColor: _currentColor,
                          glowIntensity: _glowAnimation.value,
                          backgroundColor: widget.backgroundColor,
                          faceImages: _faceImages,
                          wheelOrder: _wheelOrder,
                        ),
                      ),
                    ),
                  ),
                  // Gesture detector
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

/// Simplified wheel painter - draws only ONE level at a time
class _SimpleWheelPainter extends CustomPainter {
  final List<dynamic> emotions;
  final WheelLevel level;
  final CoreEmotion? selectedCore;
  final SecondaryFeeling? selectedSecondary;
  final Color baseColor;
  final double glowIntensity;
  final Color backgroundColor;
  final Map<String, ui.Image> faceImages;
  final List<String> wheelOrder;

  _SimpleWheelPainter({
    required this.emotions,
    required this.level,
    this.selectedCore,
    this.selectedSecondary,
    required this.baseColor,
    required this.glowIntensity,
    required this.backgroundColor,
    required this.faceImages,
    required this.wheelOrder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw the single ring of emotions
    _drawEmotionsRing(canvas, center, radius);

    // Draw center hub
    _drawCenterHub(canvas, center, radius);
  }

  void _drawEmotionsRing(Canvas canvas, Offset center, double radius) {
    if (emotions.isEmpty) return;

    const startAngle = -math.pi / 2;
    const gapAngle = 0.03;
    const innerRatio = 0.30;
    const outerRatio = 0.90;

    final sectorAngle = (2 * math.pi) / emotions.length;

    for (int i = 0; i < emotions.length; i++) {
      final emotion = emotions[i];
      final sectorStart = startAngle + i * sectorAngle + gapAngle / 2;
      final sweep = sectorAngle - gapAngle;

      Color sectorColor;
      String label;
      String? faceKey;

      if (level == WheelLevel.core) {
        final core = emotion as CoreEmotion;
        sectorColor = core.color ?? Colors.grey;
        label = core.name;
        faceKey = core.id;
      } else if (level == WheelLevel.secondary) {
        final secondary = emotion as SecondaryFeeling;
        sectorColor = selectedCore?.secondaryColor ?? baseColor;
        label = secondary.name;
        faceKey = secondary.id;
      } else {
        final tertiary = emotion as String;
        sectorColor = selectedCore?.tertiaryColor ?? baseColor;
        label = tertiary;
        faceKey = _sanitizeKey(tertiary);
      }

      _drawSector(canvas, center, radius, sectorStart, sweep,
          innerRatio, outerRatio, sectorColor, label, faceKey, level == WheelLevel.core);
    }
  }

  void _drawSector(Canvas canvas, Offset center, double radius,
      double startAngle, double sweepAngle, double innerRatio, double outerRatio,
      Color color, String label, String? faceKey, bool showFace) {

    final innerRadius = radius * innerRatio;
    final outerRadius = radius * outerRatio;

    // Draw main segment
    final segmentPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    _drawSectorPath(canvas, center, innerRadius, outerRadius, startAngle, sweepAngle, segmentPaint);

    // Calculate center of sector for face and label
    final midRadius = (innerRadius + outerRadius) / 2;
    final centerAngle = startAngle + sweepAngle / 2;

    // Show face image for all levels (magical feel)
    final faceImage = faceKey != null ? faceImages[faceKey] : null;

    if (faceImage != null) {
      // Position face in upper portion of sector
      final faceRadius = innerRadius + (outerRadius - innerRadius) * 0.38;
      final faceCenter = Offset(
        center.dx + faceRadius * math.cos(centerAngle),
        center.dy + faceRadius * math.sin(centerAngle),
      );

      // Draw subtle glow behind face for magical effect
      final glowPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(faceCenter, radius * 0.11, glowPaint);

      // Draw face - larger size for better visibility
      final faceSize = radius * 0.18;
      _drawImageFace(canvas, faceImage, faceCenter, faceSize);

      // Label below face
      final labelRadius = innerRadius + (outerRadius - innerRadius) * 0.78;
      final labelX = center.dx + labelRadius * math.cos(centerAngle);
      final labelY = center.dy + labelRadius * math.sin(centerAngle);
      _drawText(canvas, label, labelX, labelY, 12.0, Colors.white, fontWeight: FontWeight.bold, shadow: true);
    } else {
      // Fallback: just show label centered (for emotions without face images)
      final labelX = center.dx + midRadius * math.cos(centerAngle);
      final labelY = center.dy + midRadius * math.sin(centerAngle);
      _drawText(canvas, label, labelX, labelY, 11.0, Colors.white, fontWeight: FontWeight.w600, shadow: true);
    }
  }

  void _drawCenterHub(Canvas canvas, Offset center, double radius) {
    final hubRadius = radius * 0.25;

    if (level == WheelLevel.core) {
      // Empty state - prompt to tap
      final hintPaint = Paint()
        ..color = backgroundColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, hubRadius, hintPaint);

      _drawText(
        canvas,
        'Tap a\nFeeling',
        center.dx,
        center.dy,
        12,
        Colors.black54,
        fontWeight: FontWeight.w500,
      );
      return;
    }

    // Show selected emotion with back button
    String name;
    Color hubColor;
    String? faceKey;

    if (level == WheelLevel.tertiary && selectedSecondary != null) {
      name = selectedSecondary!.name;
      hubColor = selectedCore?.secondaryColor ?? baseColor;
      faceKey = selectedSecondary!.id;
    } else if (selectedCore != null) {
      name = selectedCore!.name;
      hubColor = selectedCore!.color ?? baseColor;
      faceKey = selectedCore!.id;
    } else {
      return;
    }

    // Glow effect
    final outerGlow = Paint()
      ..color = hubColor.withValues(alpha: 0.4 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
    canvas.drawCircle(center, hubRadius * 1.4, outerGlow);

    final innerGlow = Paint()
      ..color = hubColor.withValues(alpha: 0.6 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, hubRadius * 1.15, innerGlow);

    // Background circle
    final bgPaint = Paint()
      ..color = hubColor.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, hubRadius, bgPaint);

    // Face image
    final faceImage = faceImages[faceKey];
    if (faceImage != null) {
      final faceCenter = Offset(center.dx, center.dy - hubRadius * 0.2);
      _drawImageFace(canvas, faceImage, faceCenter, radius * 0.14);
    }

    // Label below face
    _drawText(
      canvas,
      name,
      center.dx,
      center.dy + hubRadius * 0.55,
      11,
      Colors.white,
      fontWeight: FontWeight.bold,
      shadow: true,
    );

    // Back arrow at bottom of hub
    _drawBackArrow(canvas, Offset(center.dx, center.dy + hubRadius * 0.85), radius * 0.03);
  }

  void _drawBackArrow(Canvas canvas, Offset center, double size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(center.dx + size, center.dy - size)
      ..lineTo(center.dx - size, center.dy)
      ..lineTo(center.dx + size, center.dy + size);

    canvas.drawPath(path, paint);
  }

  void _drawImageFace(Canvas canvas, ui.Image image, Offset center, double size) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromCenter(center: center, width: size, height: size);
    canvas.drawImageRect(image, src, dst, Paint());
  }

  void _drawSectorPath(Canvas canvas, Offset center, double innerRadius,
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
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height / 2),
    );
  }

  String _sanitizeKey(String name) {
    final lower = name.toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return replaced.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  }

  @override
  bool shouldRepaint(_SimpleWheelPainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.selectedCore != selectedCore ||
        oldDelegate.selectedSecondary != selectedSecondary ||
        oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.faceImages.length != faceImages.length;
  }
}

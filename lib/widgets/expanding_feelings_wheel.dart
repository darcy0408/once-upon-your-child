import 'dart:math' as math;
import 'package:flutter/material.dart';
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

    const startAngle = 3 * math.pi / 2;
    final rawAngle = math.atan2(dy, dx);
    final angle = (rawAngle - startAngle + 2 * math.pi) % (2 * math.pi);
    final ringRatio = radius / maxRadius;

    if (ringRatio < 0.22) {
      _pickSelection();
      return;
    }

    if (widget.maxDepth == 0 || ringRatio < 0.50) {
      _tapCore(angle);
      return;
    }

    if (widget.maxDepth >= 1 && ringRatio < 0.75) {
      _tapSecondaryAtAngle(angle);
      return;
    }

    if (widget.maxDepth >= 2 && ringRatio < 0.92) {
      _tapTertiaryAtAngle(angle);
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
    _tapSecondaryForCore(_selectedCore!, angle);
  }

  void _tapSecondaryAtAngle(double angle) {
    final core = _coreForAngle(angle);
    if (core == null) return;
    _tapSecondaryForCore(core, angle);
  }

  void _tapSecondaryForCore(CoreEmotion core, double angle) {
    final secondaryList = core.secondary;
    if (secondaryList.isEmpty) return;

    final coreSectorIndex = _wheelOrder.indexOf(core.id);
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
      _selectedCore = core;
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
    _tapTertiaryForCore(_selectedCore!, angle);
  }

  void _tapTertiaryAtAngle(double angle) {
    final core = _coreForAngle(angle);
    if (core == null) return;
    _tapTertiaryForCore(core, angle);
  }

  void _tapTertiaryForCore(CoreEmotion core, double angle) {
    final secondaryList = core.secondary;
    if (secondaryList.isEmpty) return;

    final coreSectorIndex = _wheelOrder.indexOf(core.id);
    if (coreSectorIndex == -1) return;

    final sectorAngle = (2 * math.pi) / _wheelOrder.length;
    final coreSectorStart = coreSectorIndex * sectorAngle;
    final secondaryAngle = sectorAngle / secondaryList.length;

    double localAngle = (angle - coreSectorStart + 2 * math.pi) % (2 * math.pi);
    if (localAngle > sectorAngle) {
      localAngle = localAngle - 2 * math.pi;
    }

    if (localAngle < 0 || localAngle >= sectorAngle) {
      return;
    }

    final secondaryIndex = (localAngle / secondaryAngle).floor().clamp(0, secondaryList.length - 1);
    final secondary = secondaryList[secondaryIndex];
    final secondaryStart = coreSectorStart + secondaryIndex * secondaryAngle;

    final tertiaryList = secondary.tertiary;
    if (tertiaryList.isEmpty) return;

    double secondaryLocalAngle = (angle - secondaryStart + 2 * math.pi) % (2 * math.pi);
    if (secondaryLocalAngle > secondaryAngle) {
      secondaryLocalAngle = secondaryLocalAngle - 2 * math.pi;
    }

    if (secondaryLocalAngle < 0 || secondaryLocalAngle >= secondaryAngle) {
      return;
    }

    final tertiaryAngle = secondaryAngle / tertiaryList.length;
    final tertiaryIndex =
        (secondaryLocalAngle / tertiaryAngle).floor().clamp(0, tertiaryList.length - 1);
    final tertiary = tertiaryList[tertiaryIndex];
    setState(() {
      _selectedCore = core;
      _selectedSecondary = secondary;
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

  CoreEmotion? _coreForAngle(double angle) {
    final sectorIndex = _getSectorIndex(angle);
    final coreId = _wheelOrder[sectorIndex];
    for (final core in FeelingsWheelData.coreEmotions) {
      if (core.id == coreId) return core;
    }
    return null;
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
                    ),
                  ),
                  ..._buildCoreFaceOverlays(size),
                  ..._buildSecondaryFaceOverlays(size),
                  ..._buildTertiaryFaceOverlays(size),
                  _buildCenterConfirm(size),
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

  Widget _buildCenterConfirm(double size) {
    final label = _selectedTertiary ??
        _selectedSecondary?.name ??
        _selectedCore?.name;
    final hasSelection = label != null && label.isNotEmpty;
    final imagePath = _imageForSelection();
    final buttonSize = size * 0.22;

    final glowScale = hasSelection ? (0.98 + (_glowAnimation.value * 0.06)) : 1.0;
    final glowOpacity = hasSelection ? (0.25 + (_glowAnimation.value * 0.25)) : 0.0;

    return Center(
      child: GestureDetector(
        onTap: hasSelection ? _pickSelection : null,
        child: AnimatedScale(
          scale: glowScale,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: hasSelection ? Colors.white : Colors.white.withOpacity(0.85),
              shape: BoxShape.circle,
              boxShadow: [
                if (hasSelection)
                  BoxShadow(
                    color: Colors.white.withOpacity(glowOpacity),
                    blurRadius: 18,
                    spreadRadius: 4,
                  ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: hasSelection ? Colors.white : Colors.white.withOpacity(0.6),
                width: 2,
              ),
            ),
            child: Center(
              child: hasSelection
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (imagePath != null)
                          Image.asset(
                            imagePath,
                            width: buttonSize * 0.55,
                            height: buttonSize * 0.55,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          label!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Tap a\nfeeling',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCoreFaceOverlays(double size) {
    final radius = size / 2;
    final sectorAngle = (2 * math.pi) / _wheelOrder.length;
    const startAngle = 3 * math.pi / 2;
    final isExpanded = _selectedCore != null && widget.maxDepth >= 1;
    final faceOrbit = radius * (isExpanded ? 0.375 : 0.55);
    final faceSize = size * (isExpanded ? 0.16 : 0.20);

    const assetById = {
      'angry': 'assets/images/feelings_faces/core/angry.png',
      'happy': 'assets/images/feelings_faces/core/happy.png',
      'surprised': 'assets/images/feelings_faces/core/surprised.png',
      'bad': 'assets/images/feelings_faces/core/bad.png',
      'fearful': 'assets/images/feelings_faces/core/fearful.png',
      'sad': 'assets/images/feelings_faces/core/sad.png',
      'disgusted': 'assets/images/feelings_faces/core/disgusted.png',
    };

    return List.generate(_wheelOrder.length, (i) {
      final coreId = _wheelOrder[i];
      final assetPath = assetById[coreId];
      if (assetPath == null) return const SizedBox.shrink();

      final angle = startAngle + i * sectorAngle + (sectorAngle / 2);
      final center = Offset(
        radius + faceOrbit * math.cos(angle),
        radius + faceOrbit * math.sin(angle),
      );

      return Positioned(
        left: center.dx - faceSize / 2,
        top: center.dy - faceSize / 2,
        width: faceSize,
        height: faceSize,
        child: IgnorePointer(
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
        ),
      );
    });
  }

  List<Widget> _buildSecondaryFaceOverlays(double size) {
    if (_selectedCore == null || widget.maxDepth < 1) return const [];

    const assetById = {
      'playful': 'assets/images/feelings_faces/secondary/playful.png',
      'content': 'assets/images/feelings_faces/secondary/content.png',
      'interested': 'assets/images/feelings_faces/secondary/interested.png',
      'proud': 'assets/images/feelings_faces/secondary/proud.png',
    };

    final radius = size / 2;
    final sectorAngle = (2 * math.pi) / _wheelOrder.length;
    const startAngle = 3 * math.pi / 2;
    final coreIndex = _wheelOrder.indexOf(_selectedCore!.id);
    if (coreIndex == -1) return const [];

    final secondaryList = _selectedCore!.secondary;
    if (secondaryList.isEmpty) return const [];

    final secondaryAngle = sectorAngle / secondaryList.length;
    final coreStart = startAngle + coreIndex * sectorAngle;
    final faceOrbit = radius * 0.60;
    final faceSize = size * 0.11;

    final overlays = <Widget>[];
    for (int i = 0; i < secondaryList.length; i++) {
      final secondary = secondaryList[i];
      final assetPath = assetById[secondary.id];
      if (assetPath == null) continue;

      final angle = coreStart + i * secondaryAngle + (secondaryAngle / 2);
      final center = Offset(
        radius + faceOrbit * math.cos(angle),
        radius + faceOrbit * math.sin(angle),
      );

      overlays.add(
        Positioned(
          left: center.dx - faceSize / 2,
          top: center.dy - faceSize / 2,
          width: faceSize,
          height: faceSize,
          child: IgnorePointer(
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
          ),
        ),
      );
    }

    return overlays;
  }

  List<Widget> _buildTertiaryFaceOverlays(double size) {
    if (_selectedCore == null || _selectedSecondary == null || widget.maxDepth < 2) {
      return const [];
    }

    const assetByName = {
      'aroused': 'assets/images/feelings_faces/tertiary/aroused.png',
      'cheeky': 'assets/images/feelings_faces/tertiary/cheeky.png',
      'confident': 'assets/images/feelings_faces/tertiary/confident.png',
      'curious': 'assets/images/feelings_faces/tertiary/curious.png',
      'free': 'assets/images/feelings_faces/tertiary/free.png',
      'inquisitive': 'assets/images/feelings_faces/tertiary/inquisitive.png',
      'joyful': 'assets/images/feelings_faces/tertiary/joyful.png',
      'successful': 'assets/images/feelings_faces/tertiary/successful.png',
    };

    final tertiaryList = _selectedSecondary!.tertiary;
    if (tertiaryList.isEmpty) return const [];

    final radius = size / 2;
    final sectorAngle = (2 * math.pi) / _wheelOrder.length;
    const startAngle = 3 * math.pi / 2;
    final coreIndex = _wheelOrder.indexOf(_selectedCore!.id);
    if (coreIndex == -1) return const [];

    final secondaryList = _selectedCore!.secondary;
    final secondaryIndex = secondaryList.indexWhere((s) => s.id == _selectedSecondary!.id);
    if (secondaryIndex == -1) return const [];

    final secondaryAngle = sectorAngle / secondaryList.length;
    final coreStart = startAngle + coreIndex * sectorAngle;
    final secondaryStart = coreStart + secondaryIndex * secondaryAngle;
    final tertiaryAngle = secondaryAngle / tertiaryList.length;
    final faceOrbit = radius * 0.84;
    final faceSize = size * 0.09;

    final overlays = <Widget>[];
    for (int i = 0; i < tertiaryList.length; i++) {
      final name = tertiaryList[i];
      final assetPath = assetByName[name.toLowerCase()];
      if (assetPath == null) continue;

      final angle = secondaryStart + i * tertiaryAngle + (tertiaryAngle / 2);
      final center = Offset(
        radius + faceOrbit * math.cos(angle),
        radius + faceOrbit * math.sin(angle),
      );

      overlays.add(
        Positioned(
          left: center.dx - faceSize / 2,
          top: center.dy - faceSize / 2,
          width: faceSize,
          height: faceSize,
          child: IgnorePointer(
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
          ),
        ),
      );
    }

    return overlays;
  }

  String? _imageForSelection() {
    if (_selectedTertiary != null) {
      final key = _selectedTertiary!.toLowerCase();
      return _tertiaryAsset(key);
    }
    if (_selectedSecondary != null) {
      return _secondaryAsset(_selectedSecondary!.id);
    }
    if (_selectedCore != null) {
      return _coreAsset(_selectedCore!.id);
    }
    return null;
  }

  String? _coreAsset(String id) {
    const assets = {
      'angry': 'assets/images/feelings_faces/core/angry.png',
      'happy': 'assets/images/feelings_faces/core/happy.png',
      'surprised': 'assets/images/feelings_faces/core/surprised.png',
      'bad': 'assets/images/feelings_faces/core/bad.png',
      'fearful': 'assets/images/feelings_faces/core/fearful.png',
      'sad': 'assets/images/feelings_faces/core/sad.png',
      'disgusted': 'assets/images/feelings_faces/core/disgusted.png',
    };
    return assets[id];
  }

  String? _secondaryAsset(String id) {
    const assets = {
      'playful': 'assets/images/feelings_faces/secondary/playful.png',
      'content': 'assets/images/feelings_faces/secondary/content.png',
      'interested': 'assets/images/feelings_faces/secondary/interested.png',
      'proud': 'assets/images/feelings_faces/secondary/proud.png',
    };
    return assets[id];
  }

  String? _tertiaryAsset(String id) {
    const assets = {
      'aroused': 'assets/images/feelings_faces/tertiary/aroused.png',
      'cheeky': 'assets/images/feelings_faces/tertiary/cheeky.png',
      'confident': 'assets/images/feelings_faces/tertiary/confident.png',
      'curious': 'assets/images/feelings_faces/tertiary/curious.png',
      'free': 'assets/images/feelings_faces/tertiary/free.png',
      'inquisitive': 'assets/images/feelings_faces/tertiary/inquisitive.png',
      'joyful': 'assets/images/feelings_faces/tertiary/joyful.png',
      'successful': 'assets/images/feelings_faces/tertiary/successful.png',
    };
    return assets[id];
  }
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
  _WheelPainter({
    required this.wheelOrder,
    required this.coreEmotions,
    this.selectedCore,
    this.selectedSecondary,
    this.selectedTertiary,
    required this.glowIntensity,
    required this.backgroundColor,
    required this.maxDepth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    _drawCoreRing(canvas, center, radius);

    if (selectedCore != null && maxDepth >= 1) {
      _drawSecondaryRing(canvas, center, radius);
    }

    if (selectedCore != null && selectedSecondary != null && maxDepth >= 2) {
      _drawTertiaryRing(canvas, center, radius);
    }

    // No center button; tap segments to choose.
  }

  void _drawCoreRing(Canvas canvas, Offset center, double radius) {
    final sectorAngle = (2 * math.pi) / wheelOrder.length;
    const startAngle = 3 * math.pi / 2;
    const gapAngle = 0.04;
    final coreOuter = (selectedCore != null && maxDepth >= 1) ? radius * 0.50 : radius * 0.92;

    for (int i = 0; i < wheelOrder.length; i++) {
      final coreId = wheelOrder[i];
      final core = coreEmotions.firstWhere((c) => c.id == coreId);
      final isSelected = selectedCore?.id == core.id;
      final baseColor = core.color ?? Colors.grey;

      final actualSectorStart = startAngle + i * sectorAngle + gapAngle / 2;
      final actualSectorAngle = sectorAngle - gapAngle;

      if (isSelected) {
        final outerGlowPaint = Paint()
          ..color = baseColor.withOpacity(0.3 * glowIntensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30)
          ..style = PaintingStyle.fill;
        _drawSector(canvas, center, radius * 0.23, coreOuter + radius * 0.02,
            actualSectorStart, actualSectorAngle, outerGlowPaint);

        final midGlowPaint = Paint()
          ..color = baseColor.withOpacity(0.5 * glowIntensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
          ..style = PaintingStyle.fill;
        _drawSector(canvas, center, radius * 0.24, coreOuter + radius * 0.01,
            actualSectorStart, actualSectorAngle, midGlowPaint);

        final innerGlowPaint = Paint()
          ..color = baseColor.withOpacity(0.7 * glowIntensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
          ..style = PaintingStyle.fill;
        _drawSector(canvas, center, radius * 0.25, coreOuter,
            actualSectorStart, actualSectorAngle, innerGlowPaint);
      }

      final sectorPaint = Paint()
        ..color = isSelected ? baseColor : baseColor.withOpacity(0.4)
        ..style = PaintingStyle.fill;

      _drawSector(canvas, center, radius * 0.25, coreOuter,
          actualSectorStart, actualSectorAngle, sectorPaint);

      final labelRadius = radius * (selectedCore != null ? 0.33 : 0.50);
      final labelAngle = actualSectorStart + actualSectorAngle / 2;
      _drawRotatedText(
        canvas,
        core.name,
        center.dx + labelRadius * math.cos(labelAngle),
        center.dy + labelRadius * math.sin(labelAngle),
        labelAngle,
        isSelected ? 15 : 13,
        Colors.white,
        fontWeight: FontWeight.bold,
        shadow: true,
      );
    }
  }

  void _drawSecondaryRing(Canvas canvas, Offset center, double radius) {
    if (selectedCore == null) return;

    final coreSectorIndex = wheelOrder.indexOf(selectedCore!.id);
    if (coreSectorIndex == -1) return;

    final sectorAngle = (2 * math.pi) / wheelOrder.length;
    const startAngle = 3 * math.pi / 2;
    final coreSectorStart = startAngle + coreSectorIndex * sectorAngle;
    final secondaryList = selectedCore!.secondary;

    if (secondaryList.isEmpty) return;

    final secondaryAngle = sectorAngle / secondaryList.length;
    const gapAngle = 0.02;
    final outerRadius = maxDepth >= 2 ? radius * 0.75 : radius * 0.92;

    for (int i = 0; i < secondaryList.length; i++) {
      final secondary = secondaryList[i];
      final isSelected = selectedSecondary?.id == secondary.id;
      final baseColor = selectedCore!.color ?? Colors.grey;

      final actualSecondaryStart = coreSectorStart + i * secondaryAngle + gapAngle / 2;
      final actualSecondaryAngle = secondaryAngle - gapAngle;

      if (isSelected) {
        final outerGlowPaint = Paint()
          ..color = baseColor.withOpacity(0.4 * glowIntensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25)
          ..style = PaintingStyle.fill;
        _drawSector(canvas, center, radius * 0.48, outerRadius + radius * 0.02,
            actualSecondaryStart, actualSecondaryAngle, outerGlowPaint);

        final midGlowPaint = Paint()
          ..color = baseColor.withOpacity(0.6 * glowIntensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)
          ..style = PaintingStyle.fill;
        _drawSector(canvas, center, radius * 0.49, outerRadius + radius * 0.01,
            actualSecondaryStart, actualSecondaryAngle, midGlowPaint);

        final innerGlowPaint = Paint()
          ..color = baseColor.withOpacity(0.8 * glowIntensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
          ..style = PaintingStyle.fill;
        _drawSector(canvas, center, radius * 0.50, outerRadius,
            actualSecondaryStart, actualSecondaryAngle, innerGlowPaint);
      }

      final sectorPaint = Paint()
        ..color = isSelected ? baseColor : baseColor.withOpacity(0.35)
        ..style = PaintingStyle.fill;

      _drawSector(canvas, center, radius * 0.50, outerRadius,
          actualSecondaryStart, actualSecondaryAngle, sectorPaint);

      final labelRadius = radius * (maxDepth >= 2 ? 0.58 : 0.70);
      final labelAngle = actualSecondaryStart + actualSecondaryAngle / 2;
      _drawRotatedText(
        canvas,
        secondary.name,
        center.dx + labelRadius * math.cos(labelAngle),
        center.dy + labelRadius * math.sin(labelAngle),
        labelAngle,
        isSelected ? 12 : 11,
        Colors.white,
        fontWeight: FontWeight.bold,
        shadow: true,
      );
    }
  }

  void _drawTertiaryRing(Canvas canvas, Offset center, double radius) {
    if (selectedCore == null || selectedSecondary == null) return;

    final coreSectorIndex = wheelOrder.indexOf(selectedCore!.id);
    if (coreSectorIndex == -1) return;

    final secondaryList = selectedCore!.secondary;
    if (secondaryList.isEmpty) return;

    final secondaryIndex = secondaryList.indexWhere((s) => s.id == selectedSecondary!.id);
    if (secondaryIndex == -1) return;

    final tertiaryList = selectedSecondary!.tertiary;
    if (tertiaryList.isEmpty) return;

    final sectorAngle = (2 * math.pi) / wheelOrder.length;
    const startAngle = 3 * math.pi / 2;
    final coreSectorStart = startAngle + coreSectorIndex * sectorAngle;
    final secondaryAngle = sectorAngle / secondaryList.length;
    final secondaryStart = coreSectorStart + secondaryIndex * secondaryAngle;
    final tertiaryAngle = secondaryAngle / tertiaryList.length;
    const gapAngle = 0.01;

    for (int i = 0; i < tertiaryList.length; i++) {
      final tertiary = tertiaryList[i];
      final isSelected = selectedTertiary == tertiary;
      final baseColor = selectedCore!.color ?? Colors.grey;

      final actualStart = secondaryStart + i * tertiaryAngle + gapAngle / 2;
      final actualAngle = tertiaryAngle - gapAngle;

      if (isSelected) {
        final glowPaint = Paint()
          ..color = baseColor.withOpacity(0.55 * glowIntensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
          ..style = PaintingStyle.fill;
        _drawSector(canvas, center, radius * 0.74, radius * 0.92,
            actualStart, actualAngle, glowPaint);
      }

      final sectorPaint = Paint()
        ..color = isSelected ? baseColor : baseColor.withOpacity(0.35)
        ..style = PaintingStyle.fill;

      _drawSector(canvas, center, radius * 0.75, radius * 0.92,
          actualStart, actualAngle, sectorPaint);

      final labelRadius = radius * 0.74;
      final labelAngle = actualStart + actualAngle / 2;
      _drawRotatedText(
        canvas,
        tertiary,
        center.dx + labelRadius * math.cos(labelAngle),
        center.dy + labelRadius * math.sin(labelAngle),
        labelAngle,
        isSelected ? 9 : 8,
        Colors.white,
        fontWeight: FontWeight.bold,
        shadow: true,
      );
    }
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

  void _drawRotatedText(
    Canvas canvas,
    String text,
    double x,
    double y,
    double angle,
    double fontSize,
    Color color, {
    FontWeight? fontWeight,
    bool shadow = false,
  }) {
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
    double rotation = angle + math.pi / 2;
    final normalized = (rotation + 2 * math.pi) % (2 * math.pi);
    if (normalized > math.pi / 2 && normalized < (3 * math.pi / 2)) {
      rotation += math.pi;
    }
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rotation);
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
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
      _drawArc(canvas, center.translate(-eyeOffsetX, eyeOffsetY), eyeRadius * 1.4, math.pi, strokePaint);
      _drawArc(canvas, center.translate(eyeOffsetX, eyeOffsetY), eyeRadius * 1.4, math.pi, strokePaint);
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
        oldDelegate.maxDepth != maxDepth;
  }
}

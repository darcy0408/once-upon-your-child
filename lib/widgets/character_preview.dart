import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../models/generated_avatar.dart';

/// CharacterPreview - Large character display with magical sparkle circle
///
/// Design specs:
/// - Takes up top 50% of screen
/// - Dotted circle frame around character
/// - Floating sparkles that rotate
/// - Supports AI-generated avatars, network images, or emoji placeholders
/// - Scales and animates on character change
class CharacterPreview extends StatefulWidget {
  final String? characterImageUrl;
  final GeneratedAvatar? generatedAvatar;
  final String placeholderEmoji;
  final Color backgroundColor;
  final bool showSparkles;

  const CharacterPreview({
    super.key,
    this.characterImageUrl,
    this.generatedAvatar,
    this.placeholderEmoji = '👧',
    this.backgroundColor = AppColors.gradientMid,
    this.showSparkles = true,
  });

  @override
  State<CharacterPreview> createState() => _CharacterPreviewState();
}

class _CharacterPreviewState extends State<CharacterPreview>
    with TickerProviderStateMixin {
  late AnimationController _sparkleController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    // Sparkle rotation animation
    _sparkleController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Scale animation for character changes
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _scaleController.forward();
  }

  @override
  void didUpdateWidget(CharacterPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeholderEmoji != widget.placeholderEmoji ||
        oldWidget.characterImageUrl != widget.characterImageUrl ||
        oldWidget.generatedAvatar?.id != widget.generatedAvatar?.id) {
      // Trigger scale animation on character change
      _scaleController.reset();
      _scaleController.forward();
    }
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final previewSize = math.min(size.width * 0.7, 300.0);

    return Semantics(
      image: true,
      label: 'Character preview',
      child: Container(
        height: size.height * 0.5, // Top 50% of screen
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.backgroundColor.withAlpha(128), // 50% opacity
              widget.backgroundColor.withAlpha(25), // 10% opacity
            ],
          ),
        ),
        child: Center(
          child: SizedBox(
            width: previewSize,
            height: previewSize,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Rotating sparkles circle (if enabled)
                if (widget.showSparkles)
                  AnimatedBuilder(
                    animation: _sparkleController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _sparkleController.value * 2 * math.pi,
                        child: child,
                      );
                    },
                    child: _buildSparkleCircle(previewSize),
                  ),

                // Character image/placeholder
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildCharacter(previewSize),
                ),

                // Dotted circle frame (on top)
                _buildDottedCircle(previewSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSparkleCircle(double size) {
    const sparkleCount = 8;
    final sparkleRadius = size / 2 + 10;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: List.generate(sparkleCount, (index) {
          final angle = (index * 2 * math.pi) / sparkleCount;
          final x = sparkleRadius * math.cos(angle);
          final y = sparkleRadius * math.sin(angle);

          return Transform.translate(
            offset: Offset(x, y),
            child: const Icon(
              Icons.auto_awesome,
              color: AppColors.goldLight,
              size: 20,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDottedCircle(double size) {
    return CustomPaint(
      size: Size(size, size),
      painter: _DottedCirclePainter(
        color: AppColors.gold,
        strokeWidth: 3,
        dashLength: 10,
        dashGap: 8,
      ),
    );
  }

  Widget _buildCharacter(double size) {
    // Character should be slightly smaller than the dotted circle (which is 'size')
    final characterSize = size * 0.90;

    // Priority: Generated Avatar > Network Image > Emoji Placeholder
    if (widget.generatedAvatar != null) {
      // AI-generated avatar
      return _buildGeneratedAvatar(characterSize);
    } else if (widget.characterImageUrl != null) {
      // Network image (future use)
      return Container(
        width: characterSize,
        height: characterSize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.network(
            widget.characterImageUrl!,
            width: characterSize,
            height: characterSize,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholder(characterSize);
            },
          ),
        ),
      );
    } else {
      return _buildPlaceholder(characterSize);
    }
  }

  Widget _buildGeneratedAvatar(double size) {
    try {
      final imageData = widget.generatedAvatar!.imageBase64;

      // Check if it's a URL (from avatar gallery) or base64 data
      final isUrl = imageData.startsWith('http://') || imageData.startsWith('https://');

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(102), // 40% opacity - stronger for generated avatars
              blurRadius: 25,
              spreadRadius: 8,
            ),
          ],
        ),
        child: ClipOval(
          child: isUrl
              ? Image.network(
                  imageData,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Error loading avatar from URL: $error');
                    return _buildEmojiPlaceholder(size);
                  },
                )
              : Image.memory(
                  base64Decode(imageData.split(',').last),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Error displaying generated avatar: $error');
                    return _buildEmojiPlaceholder(size);
                  },
                ),
        ),
      );
    } catch (e) {
      debugPrint('Error decoding generated avatar: $e');
      return _buildEmojiPlaceholder(size);
    }
  }

  Widget _buildPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(77), // 30% opacity
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/character_placeholder.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.3), // Show head and upper body
          errorBuilder: (context, error, stackTrace) {
            return _buildEmojiPlaceholder(size);
          },
        ),
      ),
    );
  }

  Widget _buildEmojiPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.surface,
            AppColors.cream,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(77), // 30% opacity
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Text(
          widget.placeholderEmoji,
          style: TextStyle(
            fontSize: size * 0.5,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for dotted circle
class _DottedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;

  _DottedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.dashGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Reduce radius by half stroke width to stay within bounds
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashLength + dashGap)).floor();

    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i * (dashLength + dashGap) / radius);
      final sweepAngle = dashLength / radius;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DottedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.dashGap != dashGap;
  }
}

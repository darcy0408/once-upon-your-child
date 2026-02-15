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
  late AnimationController _breathingController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _breathingAnimation;

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

    // Breathing animation (subtle scale up/down 2% every 2 seconds)
    _breathingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
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
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final previewSize = math.min(size.width * 0.8, 380.0);

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

                // Character image/placeholder (no dotted circle frame)
                AnimatedBuilder(
                  animation: _breathingAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value * _breathingAnimation.value,
                      child: child,
                    );
                  },
                  child: _buildCharacter(previewSize),
                ),
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

  Widget _buildCharacter(double size) {
    // Character fills the full preview area (no dotted circle border)
    final characterSize = size;

    debugPrint('📺 CharacterPreview._buildCharacter:');
    debugPrint('   - Has generatedAvatar: ${widget.generatedAvatar != null}');
    debugPrint('   - Has characterImageUrl: ${widget.characterImageUrl != null}');
    debugPrint('   - Placeholder emoji: ${widget.placeholderEmoji}');

    // Priority: Generated Avatar > Network Image > Placeholder Image
    if (widget.generatedAvatar != null) {
      debugPrint('   ✅ Using generated avatar');
      return _buildGeneratedAvatar(characterSize);
    } else if (widget.characterImageUrl != null) {
      debugPrint('   ✅ Using network image');
      return Container(
        width: characterSize,
        height: characterSize,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: ClipOval(
          child: Image.network(
            widget.characterImageUrl!,
            width: characterSize,
            height: characterSize,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('   ⚠️ Network image failed, falling back to placeholder');
              return _buildPlaceholder(characterSize);
            },
          ),
        ),
      );
    } else {
      debugPrint('   ✅ Using default image placeholder');
      return _buildPlaceholder(characterSize);
    }
  }

  Widget _buildGeneratedAvatar(double size) {
    try {
      final imageData = widget.generatedAvatar!.imageBase64;
      debugPrint('   🎨 Avatar data: ${imageData.substring(0, math.min(imageData.length, 50))}...');

      // Check if it's a URL, Asset, or base64 data
      final isUrl = imageData.startsWith('http://') || imageData.startsWith('https://');
      final isAsset = imageData.startsWith('assets/');

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(102),
              blurRadius: 25,
              spreadRadius: 8,
            ),
          ],
        ),
        child: ClipOval(
          child: isAsset
              ? Image.asset(
                  imageData,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('   ❌ Error loading avatar from Asset ($imageData): $error');
                    return _buildPlaceholder(size);
                  },
                )
              : isUrl
                  ? Image.network(
                      imageData,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('   ❌ Error loading avatar from URL: $error');
                        return _buildPlaceholder(size);
                      },
                    )
                  : Image.memory(
                      base64Decode(imageData.split(',').last),
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('   ❌ Error decoding base64 avatar: $error');
                        return _buildPlaceholder(size);
                      },
                    ),
        ),
      );
    } catch (e) {
      debugPrint('   ❌ Critical error in _buildGeneratedAvatar: $e');
      return _buildPlaceholder(size);
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
            color: AppColors.primary.withAlpha(77),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          children: [
            // The placeholder image
            Image.asset(
              'assets/images/character_placeholder.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (context, error, stackTrace) {
                // Final fallback if even the placeholder asset is missing
                return Image.asset(
                  'thePlaceholderImageBeforeCharacterGeneration.jpeg',
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => _buildEmojiPlaceholder(size),
                );
              },
            ),
            // Soft gradient vignette
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    widget.backgroundColor.withAlpha(40),
                  ],
                  stops: const [0.0, 0.85, 1.0],
                ),
              ),
            ),
          ],
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


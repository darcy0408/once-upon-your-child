import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../utils/motion_utils.dart';
import '../theme/age_band_theme.dart';
import 'safe_asset_image.dart';

/// Image-based Make Magic Button using transparent PNG asset.
///
/// Animations:
///   - Gentle hop (bounce up/down)
///   - Pulse (scale breathe)
///   - Glow (shadow intensity oscillates)
///   - Press: swaps to _pressed asset, scales down, shadow shrinks
class ImageMakeMagicButton extends StatefulWidget {
  final String? label;
  final VoidCallback onTap;
  final bool isEnabled;
  final AgeBand? ageBand;

  const ImageMakeMagicButton({
    super.key,
    this.label,
    required this.onTap,
    this.isEnabled = true,
    this.ageBand,
  });

  @override
  State<ImageMakeMagicButton> createState() => _ImageMakeMagicButtonState();
}

class _ImageMakeMagicButtonState extends State<ImageMakeMagicButton>
    with TickerProviderStateMixin {
  // Hop + pulse: continuous idle animation
  late AnimationController _idleController;
  // Glow: slightly different period for organic feel
  late AnimationController _glowController;
  // Star burst on long-press
  late AnimationController _burstController;
  // Ring-pulse: expanding/fading ring emitted every 2s
  late AnimationController _ringController;
  // Press feedback
  bool _isPressed = false;

  // One shared button art for every band. (A per-band variant path existed
  // here but could never load — it asked uiPath for .png names while the band
  // folders held .webp — so the band assets were dead weight and got purged
  // in the 2026-07-15 asset audit; ageBand still drives the label below.)
  String get _assetNormal => 'assets/images/ui/clean/make_magic_button.webp';

  String get _assetPressed =>
      'assets/images/ui/clean/make_magic_button_pressed.webp';

  @override
  void initState() {
    super.initState();

    // Hop + pulse cycle: 1.6s feels excited but not frantic
    _idleController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );

    // Glow on a slightly offset period so animations don't lock-step
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );

    // Star burst: fires once on long-press, 600ms
    _burstController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Ring-pulse: 2s full cycle — ring expands (scale 1→1.3) and fades out
    _ringController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    // Looping idle/glow/ring animations started in didChangeDependencies so
    // MotionPrefs.reduceMotion is honored (WCAG 2.2 AA SC 2.2.2 Pause, Stop,
    // Hide).
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.isEnabled) _startIdleAnimations();
  }

  @override
  void didUpdateWidget(ImageMakeMagicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnabled && !oldWidget.isEnabled) {
      _startIdleAnimations();
    } else if (!widget.isEnabled && oldWidget.isEnabled) {
      _idleController.stop();
      _glowController.stop();
      _ringController.stop();
    }
  }

  /// Starts the looping idle/glow/ring animations only when motion is allowed.
  void _startIdleAnimations() {
    if (MotionPrefs.reduceMotion(context)) return;
    if (!_idleController.isAnimating) _idleController.repeat(reverse: true);
    if (!_glowController.isAnimating) _glowController.repeat(reverse: true);
    if (!_ringController.isAnimating) _ringController.repeat();
  }

  @override
  void dispose() {
    _idleController.dispose();
    _glowController.dispose();
    _burstController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!widget.isEnabled) return;
    setState(() => _isPressed = true);
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails _) {
    if (!widget.isEnabled) return;
    setState(() => _isPressed = false);
    HapticFeedback.mediumImpact();
    widget.onTap();
  }

  void _onTapCancel() {
    if (_isPressed) setState(() => _isPressed = false);
  }

  void _onLongPressStart(LongPressStartDetails _) {
    if (!widget.isEnabled) return;
    HapticFeedback.heavyImpact();
    _burstController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = math.min(screenWidth * 0.86, 380.0);
    const buttonHeight = 96.0;

    return Semantics(
      button: true,
      enabled: widget.isEnabled,
      label: widget.label ??
          (widget.ageBand == AgeBand.adventurer
              ? 'START ADVENTURE'
              : widget.ageBand == AgeBand.creator
                  ? 'CREATE STORY'
                  : 'MAKE MAGIC'),
      hint: 'Start creating your magical story',
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onLongPressStart: _onLongPressStart,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _idleController,
            _glowController,
            _burstController,
            _ringController,
          ]),
          builder: (context, child) {
            // Hop: translate Y using a bounce curve
            final hopT = _idleController.value;
            final hopY = widget.isEnabled && !_isPressed
                ? -6.0 * math.sin(hopT * math.pi) // Bounce up 6px
                : 0.0;

            // Pulse: subtle scale breathe
            final pulseScale = widget.isEnabled && !_isPressed
                ? 1.0 + 0.035 * math.sin(hopT * math.pi)
                : 1.0;

            // Press: scale down + shift down
            final pressScale = _isPressed ? 0.93 : 1.0;
            final pressY = _isPressed ? 3.0 : 0.0;

            // Glow intensity
            final glowT = _glowController.value;
            final bool showParticles = MotionPrefs.showParticles(context);
            final glowIntensity = (widget.isEnabled && showParticles)
                ? 0.5 + 0.4 * math.sin(glowT * math.pi)
                : 0.0;

            // Ring-pulse: scale 1.0→1.3, opacity 0.4→0.0 over 2s
            final ringT = _ringController.value;
            final ringScale = 1.0 + 0.3 * ringT;
            final ringOpacity = (widget.isEnabled && showParticles && !_isPressed)
                ? (0.4 * (1.0 - ringT)).clamp(0.0, 1.0)
                : 0.0;

            final totalScale = pulseScale * pressScale;
            final totalY = hopY + pressY;

            return Transform.translate(
              offset: Offset(0, totalY),
              child: Transform.scale(
                scale: totalScale,
                child: SizedBox(
                  width: buttonWidth + 30, // Extra room for glow
                  height: buttonHeight + 30,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Expanding ring-pulse layer
                      if (ringOpacity > 0.0)
                        Transform.scale(
                          scale: ringScale,
                          child: Container(
                            width: buttonWidth + 10,
                            height: buttonHeight + 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                color: Color.fromRGBO(188, 138, 255, ringOpacity),
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),

                      // Glow layer
                      if (widget.isEnabled)
                        Container(
                          width: buttonWidth + 10,
                          height: buttonHeight + 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: Color.fromRGBO(
                                    158, 108, 255, _isPressed ? 0.3 : glowIntensity * 0.7),
                                blurRadius: _isPressed ? 14 : 16 + glowIntensity * 16,
                                spreadRadius: _isPressed ? 1 : 3 + glowIntensity * 4,
                              ),
                              BoxShadow(
                                color: Color.fromRGBO(
                                    255, 212, 120, _isPressed ? 0.15 : glowIntensity * 0.45),
                                blurRadius: _isPressed ? 8 : 18 + glowIntensity * 8,
                                spreadRadius: _isPressed ? 0 : 1 + glowIntensity * 3,
                              ),
                            ],
                          ),
                        ),

                      // Button image
                      Opacity(
                        opacity: widget.isEnabled ? 1.0 : 0.4,
                        child: SafeAssetImage(
                          _isPressed ? _assetPressed : _assetNormal,
                          width: buttonWidth,
                          height: buttonHeight,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          placeholder: _FallbackButton(
                            label: widget.label ??
                                (widget.ageBand == AgeBand.adventurer
                                    ? 'START ADVENTURE'
                                    : widget.ageBand == AgeBand.creator
                                        ? 'CREATE STORY'
                                        : 'MAKE MAGIC'),
                            width: buttonWidth,
                            isEnabled: widget.isEnabled,
                            isPressed: _isPressed,
                          ),
                        ),
                      ),

                      // Star burst overlay on long-press
                      if (_burstController.value > 0)
                        IgnorePointer(
                          child: CustomPaint(
                            size: Size(buttonWidth + 30, buttonHeight + 30),
                            painter: _StarBurstPainter(
                              progress: _burstController.value,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Paints 12 stars bursting outward from center on long-press.
class _StarBurstPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0

  const _StarBurstPainter({required this.progress});

  static const _colors = [
    Color(0xFFFFD700),
    Color(0xFFFF8CFF),
    Color(0xFF7FFFCF),
    Color(0xFFFFAA44),
    Color(0xFFB388FF),
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.55;
    // Fade: bright from 0→0.6, fade out 0.6→1.0
    final opacity = progress < 0.6
        ? (progress / 0.6)
        : (1.0 - (progress - 0.6) / 0.4);

    const starCount = 12;
    for (int i = 0; i < starCount; i++) {
      final angle = (i / starCount) * 2 * math.pi;
      final dist = maxRadius * progress;
      final cx = center.dx + dist * math.cos(angle);
      final cy = center.dy + dist * math.sin(angle);
      final color = _colors[i % _colors.length].withValues(alpha: opacity.clamp(0.0, 1.0));
      final size4 = (4.0 + 4.0 * math.sin(progress * math.pi)) * (1 - progress * 0.3);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      // Draw a tiny 4-pointed star
      _drawStar(canvas, Offset(cx, cy), size4, 4, paint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double r, int points, Paint paint) {
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final radius = i.isEven ? r : r * 0.4;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StarBurstPainter old) => old.progress != progress;
}

/// Code-rendered fallback if the PNG assets are missing.
class _FallbackButton extends StatelessWidget {
  final String label;
  final double width;
  final bool isEnabled;
  final bool isPressed;

  const _FallbackButton({
    required this.label,
    required this.width,
    required this.isEnabled,
    required this.isPressed,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isEnabled ? const Color(0xFFFFD478) : const Color(0xFF9A93AB);

    return Container(
      width: width,
      height: 88,
      decoration: BoxDecoration(
        gradient: isEnabled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isPressed
                    ? const [Color(0xFF9A55DD), Color(0xFF6530A0), Color(0xFF431C6E)]
                    : const [Color(0xFFBE73FF), Color(0xFF7E3FC6), Color(0xFF57238B)],
                stops: const [0.0, 0.45, 1.0],
              )
            : const LinearGradient(
                colors: [Color(0xFF8A8297), Color(0xFF666072)],
              ),
        borderRadius: BorderRadius.circular(44),
        border: Border.all(color: borderColor, width: 3.2),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

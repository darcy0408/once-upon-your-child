import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../utils/motion_utils.dart';
import '../theme/age_band_theme.dart';
import '../theme/age_band_asset_resolver.dart';

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
  // Press feedback
  bool _isPressed = false;

  String get _assetNormal {
    final band = widget.ageBand;
    if (band != null) return AgeBandAssetResolver.uiPath(band, 'make_magic_normal.png');
    return 'assets/images/ui/clean/make_magic_button.png';
  }

  String get _assetPressed {
    final band = widget.ageBand;
    if (band != null) return AgeBandAssetResolver.uiPath(band, 'make_magic_normal_clicked.png');
    return 'assets/images/ui/clean/make_magic_button_pressed.png';
  }

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

    if (widget.isEnabled) {
      _idleController.repeat(reverse: true);
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ImageMakeMagicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnabled && !oldWidget.isEnabled) {
      _idleController.repeat(reverse: true);
      _glowController.repeat(reverse: true);
    } else if (!widget.isEnabled && oldWidget.isEnabled) {
      _idleController.stop();
      _glowController.stop();
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    _glowController.dispose();
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
        child: AnimatedBuilder(
          animation: Listenable.merge([_idleController, _glowController]),
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
                                blurRadius: _isPressed ? 14 : 28 + glowIntensity * 12,
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
                        child: Image.asset(
                          _isPressed ? _assetPressed : _assetNormal,
                          width: buttonWidth,
                          height: buttonHeight,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stackTrace) {
                            return _FallbackButton(
                              label: widget.label ??
                                  (widget.ageBand == AgeBand.adventurer
                                      ? 'START ADVENTURE'
                                      : widget.ageBand == AgeBand.creator
                                          ? 'CREATE STORY'
                                          : 'MAKE MAGIC'),
                              width: buttonWidth,
                              isEnabled: widget.isEnabled,
                              isPressed: _isPressed,
                            );
                          },
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

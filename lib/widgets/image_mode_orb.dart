import 'package:flutter/material.dart';
import 'magical_float.dart';

/// Illustrated rectangular scene-thumbnail card for story mode selection.
/// Each card shows the mode illustration over a per-mode gradient, with the
/// mode label (and optional subtitle) overlaid at the bottom.
class ImageModeOrb extends StatefulWidget {
  final String modeType; // 'tales', 'rhyme', 'reading', 'pickpath'
  final String label;
  final String? subtitle;
  final bool isActive;
  final VoidCallback onTap;
  final Color primaryColor;
  final Color secondaryColor;

  const ImageModeOrb({
    super.key,
    required this.modeType,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.subtitle,
    this.primaryColor = const Color(0xFFAA88FF),
    this.secondaryColor = const Color(0xFFFF88CC),
  });

  @override
  State<ImageModeOrb> createState() => _ImageModeOrbState();
}

class _ImageModeOrbState extends State<ImageModeOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant ImageModeOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getAssetPath() {
    // Always use the same asset regardless of active state — the active
    // state is communicated via border/glow rather than a different image.
    switch (widget.modeType) {
      case 'tales':
        return 'assets/images/ui/clean/tales_orb.png';
      case 'rhyme':
        return 'assets/images/ui/clean/rhyme_time_orb.png';
      case 'reading':
        return 'assets/images/ui/clean/easy_read_orb.png';
      case 'pickpath':
        return 'assets/images/ui/clean/pick_path_orb.png';
      default:
        return 'assets/images/ui/clean/tales_orb.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor;
    final secondaryColor = widget.secondaryColor;

    return MagicalFloat(
      distance: 3.0,
      duration: const Duration(seconds: 4),
      delay: (widget.modeType.length * 100).toDouble(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final t = _pulseController.value;
              final borderWidth = widget.isActive ? 2.5 + t * 1.0 : 0.0;
              final borderAlpha = widget.isActive ? 0.85 + t * 0.15 : 0.0;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 136,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: borderAlpha),
                    width: borderWidth,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(
                        alpha: widget.isActive ? 0.55 + t * 0.15 : 0.25,
                      ),
                      blurRadius: widget.isActive ? 18 + t * 8 : 10,
                      spreadRadius: widget.isActive ? 3 + t * 2 : 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    widget.isActive ? 16.5 : 18,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Gradient background
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              secondaryColor.withValues(
                                alpha: widget.isActive ? 0.55 : 0.35,
                              ),
                              primaryColor.withValues(
                                alpha: widget.isActive ? 0.75 : 0.5,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Illustration — centred in the upper 75% of the card
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        height: 82,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 200),
                          scale: widget.isActive ? 1.05 : 1.0,
                          child: Image.asset(
                            _getAssetPath(),
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                      // Bottom label strip with scrim
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.0),
                                Colors.black.withValues(alpha: 0.72),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(8, 10, 8, 7),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: widget.isActive
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  fontSize: 13,
                                  height: 1.2,
                                  shadows: [
                                    Shadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.8),
                                      blurRadius: 4,
                                    ),
                                    if (widget.isActive)
                                      Shadow(
                                        color: primaryColor.withValues(
                                            alpha: 0.6),
                                        blurRadius: 8,
                                      ),
                                  ],
                                ),
                              ),
                              if (widget.subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.subtitle!,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 10,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Selected checkmark badge
                      if (widget.isActive)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryColor.withValues(alpha: 0.9),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
  }
}

import 'package:flutter/material.dart';
import 'magical_float.dart';

/// Image-backed mode orb using cleaned transparent assets.
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
    final suffix = widget.isActive ? '_pressed' : '';
    switch (widget.modeType) {
      case 'tales':
        return 'assets/images/ui/clean/tales_orb$suffix.png';
      case 'rhyme':
        return 'assets/images/ui/clean/rhyme_time_orb$suffix.png';
      case 'reading':
        return 'assets/images/ui/clean/easy_read_orb$suffix.png';
      case 'pickpath':
        return 'assets/images/ui/clean/pick_path_orb$suffix.png';
      default:
        return 'assets/images/ui/clean/tales_orb$suffix.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.primaryColor;

    // GestureDetector is outside MagicalFloat so the hit area stays fixed
    // while only the visual content floats. This prevents "element not stable"
    // tap failures caused by the animation constantly moving the touch target.
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 104,
        child: MagicalFloat(
          distance: 4.0,
          duration: const Duration(seconds: 4),
          delay: (widget.modeType.length * 100).toDouble(), // Pseudo-random offset
          child: IgnorePointer(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.isActive)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final t = _pulseController.value;
                          return Container(
                            width: 96 + (12 * t),
                            height: 96 + (12 * t),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  glowColor.withValues(
                                      alpha: 0.45 * (1 - t * 0.3)),
                                  glowColor.withValues(
                                      alpha: 0.16 * (1 - t * 0.3)),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    AnimatedScale(
                      duration: const Duration(milliseconds: 180),
                      scale: widget.isActive ? 1.03 : 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: glowColor.withValues(
                                alpha: widget.isActive ? 0.75 : 0.45,
                              ),
                              blurRadius: widget.isActive ? 20 : 14,
                              spreadRadius: widget.isActive ? 5 : 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            _getAssetPath(),
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: widget.subtitle != null ? 52 : 34,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            widget.isActive ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 14,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.7),
                            blurRadius: 4,
                          ),
                          if (widget.isActive)
                            Shadow(
                              color: glowColor.withValues(alpha: 0.55),
                              blurRadius: 8,
                            ),
                        ],
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

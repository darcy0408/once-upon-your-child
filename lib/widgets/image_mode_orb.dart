import 'package:flutter/material.dart';

/// Image-backed mode orb using cleaned transparent assets.
class ImageModeOrb extends StatefulWidget {
  final String modeType; // 'tales', 'rhyme', 'reading', 'pickpath'
  final String label;
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
    switch (widget.modeType) {
      case 'tales':
        return 'assets/images/ui/glassy/tales_orb.png';
      case 'rhyme':
        return 'assets/images/ui/glassy/rhyme_time_orb.png';
      case 'reading':
        return 'assets/images/ui/glassy/easy_read_orb.png';
      case 'pickpath':
        return 'assets/images/ui/glassy/pick_path_orb.png';
      default:
        return 'assets/images/ui/glassy/tales_orb.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.primaryColor;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 104,
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
                                glowColor.withValues(alpha: 0.45 * (1 - t * 0.3)),
                                glowColor.withValues(alpha: 0.16 * (1 - t * 0.3)),
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
                    child: Image.asset(
                      _getAssetPath(),
                      width: 84,
                      height: 84,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: Center(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF2F2748),
                    fontWeight:
                        widget.isActive ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13,
                    height: 1.2,
                    shadows: widget.isActive
                        ? [
                            Shadow(
                              color: glowColor.withValues(alpha: 0.55),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/age_band_theme.dart';
import '../utils/motion_utils.dart';

/// A tappable body-outline widget for the Big Feelings body-signal step.
///
/// Zones are defined as [Path] objects. Tapping a zone calls [onZoneSelected]
/// with the zone's string ID. The selected zone glows with [highlightColor].
///
/// Complexity scales with age band:
///  • Sprout  (3-5)  : 5 large blob zones
///  • Explorer/Adventurer : 8 zones
///  • Creator+       : 12 zones with text labels
class BodyOutlineWidget extends StatefulWidget {
  final AgeBand ageBand;
  final String? selectedZone;
  final ValueChanged<String> onZoneSelected;
  final Color highlightColor;

  const BodyOutlineWidget({
    super.key,
    required this.ageBand,
    required this.onZoneSelected,
    required this.highlightColor,
    this.selectedZone,
  });

  @override
  State<BodyOutlineWidget> createState() => _BodyOutlineWidgetState();
}

class _BodyOutlineWidgetState extends State<BodyOutlineWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  _BodyTier get _tier {
    switch (widget.ageBand) {
      case AgeBand.sprout:
        return _BodyTier.sprout;
      case AgeBand.explorer:
      case AgeBand.adventurer:
        return _BodyTier.explorer;
      default:
        return _BodyTier.creator;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MotionPrefs.reduceMotion(context);
    return GestureDetector(
      onTapDown: (d) => _handleTap(d.localPosition),
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (_, __) => CustomPaint(
          painter: _BodyPainter(
            tier: _tier,
            selectedZone: widget.selectedZone,
            highlightColor: widget.highlightColor,
            glowProgress: reduce ? 1.0 : _glowController.value,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  void _handleTap(Offset pos) {
    // We need the render-box size to scale the normalised paths.
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final zones = _zonesFor(_tier);
    for (final zone in zones) {
      final scaledPath = _scalePath(zone.path, size);
      if (scaledPath.contains(pos)) {
        widget.onZoneSelected(zone.id);
        return;
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Zone definitions (normalised 0..1 coordinates, scaled to actual size)
// ---------------------------------------------------------------------------

enum _BodyTier { sprout, explorer, creator }

class _Zone {
  final String id;
  final String label;
  /// Path in normalised space (0..1 on both axes, origin top-left).
  final Path path;

  const _Zone({required this.id, required this.label, required this.path});
}

/// Scale a normalised path to [size].
Path _scalePath(Path normalized, Size size) {
  final m = Matrix4.identity()
    ..scale(size.width, size.height);
  return normalized.transform(m.storage);
}

List<_Zone> _zonesFor(_BodyTier tier) {
  switch (tier) {
    case _BodyTier.sprout:
      return _sproutZones();
    case _BodyTier.explorer:
      return _explorerZones();
    case _BodyTier.creator:
      return _creatorZones();
  }
}

// ---- Sprout: 5 large blobs -----------------------------------------------

List<_Zone> _sproutZones() {
  return [
    _Zone(
      id: 'head',
      label: 'Head',
      path: _ellipsePath(0.36, 0.05, 0.28, 0.16),
    ),
    _Zone(
      id: 'heart',
      label: 'Heart',
      path: _ellipsePath(0.36, 0.26, 0.28, 0.13),
    ),
    _Zone(
      id: 'tummy',
      label: 'Tummy',
      path: _ellipsePath(0.36, 0.43, 0.28, 0.13),
    ),
    _Zone(
      id: 'hands',
      label: 'Hands',
      path: _combinedEllipses(
        0.10, 0.38, 0.14, 0.12,
        0.76, 0.38, 0.14, 0.12,
      ),
    ),
    _Zone(
      id: 'feet',
      label: 'Feet',
      path: _combinedEllipses(
        0.27, 0.82, 0.16, 0.11,
        0.57, 0.82, 0.16, 0.11,
      ),
    ),
  ];
}

// ---- Explorer: 8 zones ---------------------------------------------------

List<_Zone> _explorerZones() {
  return [
    _Zone(id: 'head',    label: 'Head',    path: _ellipsePath(0.38, 0.04, 0.24, 0.13)),
    _Zone(id: 'neck',    label: 'Neck',    path: _rectPath(0.43, 0.17, 0.14, 0.06)),
    _Zone(id: 'chest',   label: 'Chest',   path: _ellipsePath(0.37, 0.25, 0.26, 0.11)),
    _Zone(id: 'stomach', label: 'Stomach', path: _ellipsePath(0.37, 0.38, 0.26, 0.11)),
    _Zone(id: 'arms',    label: 'Arms',    path: _combinedEllipses(
      0.13, 0.27, 0.13, 0.20,
      0.74, 0.27, 0.13, 0.20,
    )),
    _Zone(id: 'hands',   label: 'Hands',   path: _combinedEllipses(
      0.10, 0.48, 0.13, 0.10,
      0.77, 0.48, 0.13, 0.10,
    )),
    _Zone(id: 'legs',    label: 'Legs',    path: _combinedEllipses(
      0.33, 0.60, 0.14, 0.22,
      0.53, 0.60, 0.14, 0.22,
    )),
    _Zone(id: 'feet',    label: 'Feet',    path: _combinedEllipses(
      0.27, 0.83, 0.16, 0.10,
      0.57, 0.83, 0.16, 0.10,
    )),
  ];
}

// ---- Creator: 12 zones ---------------------------------------------------

List<_Zone> _creatorZones() {
  return [
    _Zone(id: 'head',       label: 'Head',       path: _ellipsePath(0.39, 0.03, 0.22, 0.12)),
    _Zone(id: 'face',       label: 'Face/Jaw',   path: _ellipsePath(0.39, 0.09, 0.22, 0.08)),
    _Zone(id: 'throat',     label: 'Throat',     path: _rectPath(0.44, 0.17, 0.12, 0.05)),
    _Zone(id: 'shoulders',  label: 'Shoulders',  path: _combinedEllipses(
      0.22, 0.22, 0.16, 0.07,
      0.62, 0.22, 0.16, 0.07,
    )),
    _Zone(id: 'chest',      label: 'Chest',      path: _ellipsePath(0.38, 0.26, 0.24, 0.09)),
    _Zone(id: 'stomach',    label: 'Stomach',    path: _ellipsePath(0.38, 0.37, 0.24, 0.09)),
    _Zone(id: 'lower_back', label: 'Lower back', path: _ellipsePath(0.38, 0.47, 0.24, 0.08)),
    _Zone(id: 'arms',       label: 'Arms',       path: _combinedEllipses(
      0.13, 0.25, 0.12, 0.22,
      0.75, 0.25, 0.12, 0.22,
    )),
    _Zone(id: 'hands',      label: 'Hands',      path: _combinedEllipses(
      0.11, 0.48, 0.12, 0.09,
      0.77, 0.48, 0.12, 0.09,
    )),
    _Zone(id: 'upper_legs', label: 'Upper legs', path: _combinedEllipses(
      0.34, 0.57, 0.13, 0.16,
      0.53, 0.57, 0.13, 0.16,
    )),
    _Zone(id: 'lower_legs', label: 'Lower legs', path: _combinedEllipses(
      0.34, 0.74, 0.13, 0.13,
      0.53, 0.74, 0.13, 0.13,
    )),
    _Zone(id: 'feet',       label: 'Feet',       path: _combinedEllipses(
      0.28, 0.86, 0.15, 0.09,
      0.57, 0.86, 0.15, 0.09,
    )),
  ];
}

// ---------------------------------------------------------------------------
// Path helpers (all coords normalised 0..1)
// ---------------------------------------------------------------------------

/// Oval centred at (cx, cy) with half-widths (rx, ry).
Path _ellipsePath(double cx, double cy, double rx, double ry) {
  return Path()
    ..addOval(Rect.fromCenter(
      center: Offset(cx, cy),
      width: rx,
      height: ry,
    ));
}

/// Rectangle at (left, top) with (width, height).
Path _rectPath(double left, double top, double w, double h) {
  return Path()
    ..addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, w, h),
      const Radius.circular(0.03),
    ));
}

/// Two separate ellipses merged into one Path (for symmetric pairs like arms/feet).
Path _combinedEllipses(
  double cx1, double cy1, double rx1, double ry1,
  double cx2, double cy2, double rx2, double ry2,
) {
  final p = Path()
    ..addOval(Rect.fromCenter(
        center: Offset(cx1, cy1), width: rx1, height: ry1))
    ..addOval(Rect.fromCenter(
        center: Offset(cx2, cy2), width: rx2, height: ry2));
  return p;
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _BodyPainter extends CustomPainter {
  final _BodyTier tier;
  final String? selectedZone;
  final Color highlightColor;
  final double glowProgress; // 0..1 for pulsing

  const _BodyPainter({
    required this.tier,
    required this.selectedZone,
    required this.highlightColor,
    required this.glowProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final zones = _zonesFor(tier);

    // Silhouette fill pass
    final bodyFill = Paint()
      ..color = const Color(0xFF3A2D55).withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    final bodyStroke = Paint()
      ..color = const Color(0xFF9E8FCC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.008;

    for (final zone in zones) {
      final path = _scalePath(zone.path, size);
      canvas.drawPath(path, bodyFill);
      canvas.drawPath(path, bodyStroke);
    }

    // Highlight selected zone
    if (selectedZone != null) {
      final selected = zones.firstWhere(
        (z) => z.id == selectedZone,
        orElse: () => zones.first,
      );
      final path = _scalePath(selected.path, size);
      final glowAlpha = 0.35 + 0.25 * glowProgress;

      // Glow fill
      canvas.drawPath(
        path,
        Paint()
          ..color = highlightColor.withValues(alpha: glowAlpha)
          ..style = PaintingStyle.fill,
      );
      // Bright stroke
      canvas.drawPath(
        path,
        Paint()
          ..color = highlightColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.012,
      );
    }

    // Labels for creator tier
    if (tier == _BodyTier.creator) {
      for (final zone in zones) {
        final path = _scalePath(zone.path, size);
        final bounds = path.getBounds();
        final tp = TextPainter(
          text: TextSpan(
            text: zone.label,
            style: TextStyle(
              color: zone.id == selectedZone
                  ? highlightColor
                  : const Color(0xCCFFFFFF),
              fontSize: size.width * 0.028,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            bounds.center.dx - tp.width / 2,
            bounds.center.dy - tp.height / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.selectedZone != selectedZone ||
      old.glowProgress != glowProgress ||
      old.tier != tier;
}

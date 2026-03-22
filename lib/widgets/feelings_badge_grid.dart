// lib/widgets/feelings_badge_grid.dart
//
// Scout-badge / RPG-skill style emotion picker for the Adventurer band (ages 9-11).
// Shows a 2×4 grid of illustrated emotion badges. Single-tap selects and confirms.
// Falls back to asset image when present; otherwise renders icon + emoji.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────────────────────────────────────

class _BadgeEmotion {
  final String id;
  final String label;
  final String emoji;
  final IconData icon;
  final Color color;
  final String assetPath; // optional — silently falls back to icon

  const _BadgeEmotion({
    required this.id,
    required this.label,
    required this.emoji,
    required this.icon,
    required this.color,
    required this.assetPath,
  });
}

const _badges = [
  _BadgeEmotion(
    id: 'happy',
    label: 'Happy',
    emoji: '😄',
    icon: Icons.sentiment_very_satisfied_rounded,
    color: Color(0xFFFFC107),
    assetPath: 'assets/images/feelings/adventurer/happy.png',
  ),
  _BadgeEmotion(
    id: 'excited',
    label: 'Excited',
    emoji: '🤩',
    icon: Icons.star_rounded,
    color: Color(0xFFAB47BC),
    assetPath: 'assets/images/feelings/adventurer/excited.png',
  ),
  _BadgeEmotion(
    id: 'calm',
    label: 'Calm',
    emoji: '😌',
    icon: Icons.spa_rounded,
    color: Color(0xFF26A69A),
    assetPath: 'assets/images/feelings/adventurer/calm.png',
  ),
  _BadgeEmotion(
    id: 'sad',
    label: 'Sad',
    emoji: '😢',
    icon: Icons.sentiment_dissatisfied_rounded,
    color: Color(0xFF42A5F5),
    assetPath: 'assets/images/feelings/adventurer/sad.png',
  ),
  _BadgeEmotion(
    id: 'worried',
    label: 'Worried',
    emoji: '😟',
    icon: Icons.psychology_alt_rounded,
    color: Color(0xFFFF7043),
    assetPath: 'assets/images/feelings/adventurer/worried.png',
  ),
  _BadgeEmotion(
    id: 'frustrated',
    label: 'Frustrated',
    emoji: '😤',
    icon: Icons.bolt_rounded,
    color: Color(0xFFEF5350),
    assetPath: 'assets/images/feelings/adventurer/frustrated.png',
  ),
  _BadgeEmotion(
    id: 'angry',
    label: 'Angry',
    emoji: '😠',
    icon: Icons.mood_bad_rounded,
    color: Color(0xFFD32F2F),
    assetPath: 'assets/images/feelings/adventurer/angry.png',
  ),
  _BadgeEmotion(
    id: 'embarrassed',
    label: 'Embarrassed',
    emoji: '😳',
    icon: Icons.face_retouching_natural_rounded,
    color: Color(0xFFEC407A),
    assetPath: 'assets/images/feelings/adventurer/embarrassed.png',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

/// Scout-badge emotion grid for the Adventurer band.
/// Calls [onSelected] with a list containing the chosen emotion id.
class FeelingsBadgeGrid extends StatefulWidget {
  final ValueChanged<List<String>> onSelected;

  const FeelingsBadgeGrid({super.key, required this.onSelected});

  @override
  State<FeelingsBadgeGrid> createState() => _FeelingsBadgeGridState();
}

class _FeelingsBadgeGridState extends State<FeelingsBadgeGrid> {
  String? _hoveredId;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.05,
      ),
      itemCount: _badges.length,
      itemBuilder: (context, i) {
        final badge = _badges[i];
        final isHovered = _hoveredId == badge.id;
        return _BadgeTile(
          badge: badge,
          isHighlighted: isHovered,
          onTap: () => widget.onSelected([badge.id]),
          onHoverChanged: (v) =>
              setState(() => _hoveredId = v ? badge.id : null),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge tile
// ─────────────────────────────────────────────────────────────────────────────

class _BadgeTile extends StatelessWidget {
  final _BadgeEmotion badge;
  final bool isHighlighted;
  final VoidCallback onTap;
  final ValueChanged<bool> onHoverChanged;

  const _BadgeTile({
    required this.badge,
    required this.isHighlighted,
    required this.onTap,
    required this.onHoverChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${badge.label} — tap to select',
      child: MouseRegion(
        onEnter: (_) => onHoverChanged(true),
        onExit: (_) => onHoverChanged(false),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            decoration: BoxDecoration(
              color: isHighlighted
                  ? badge.color.withAlpha(50)
                  : Colors.white.withAlpha(12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isHighlighted
                    ? badge.color
                    : badge.color.withAlpha(100),
                width: isHighlighted ? 2.5 : 1.5,
              ),
              boxShadow: isHighlighted
                  ? [
                      BoxShadow(
                        color: badge.color.withAlpha(90),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BadgeIcon(badge: badge, highlighted: isHighlighted),
                const SizedBox(height: 10),
                Text(
                  badge.label,
                  style: GoogleFonts.fredoka(
                    color: isHighlighted ? badge.color : Colors.white,
                    fontSize: 16,
                    fontWeight: isHighlighted
                        ? FontWeight.w700
                        : FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge icon — asset with icon fallback
// ─────────────────────────────────────────────────────────────────────────────

class _BadgeIcon extends StatelessWidget {
  final _BadgeEmotion badge;
  final bool highlighted;

  const _BadgeIcon({required this.badge, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return _HexClip(
      size: 64,
      color: badge.color.withAlpha(highlighted ? 80 : 40),
      borderColor: badge.color,
      child: Image.asset(
        badge.assetPath,
        width: 44,
        height: 44,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          badge.icon,
          color: badge.color,
          size: 36,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hexagonal clip shape
// ─────────────────────────────────────────────────────────────────────────────

class _HexClip extends StatelessWidget {
  final double size;
  final Color color;
  final Color borderColor;
  final Widget child;

  const _HexClip({
    required this.size,
    required this.color,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HexPainter(fill: color, border: borderColor),
        child: Center(child: child),
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  final Color fill;
  final Color border;
  const _HexPainter({required this.fill, required this.border});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _hexPath(size);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  Path _hexPath(Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final r = s.width / 2;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * 3.14159 / 180;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  double cos(double rad) => _cos(rad);
  double sin(double rad) => _sin(rad);

  // Pure Dart trig — no dart:math import needed in painter
  static double _cos(double x) {
    // Taylor series: accurate enough for hex vertices
    x = x % (2 * 3.14159265358979);
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 8; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  static double _sin(double x) {
    x = x % (2 * 3.14159265358979);
    double result = x;
    double term = x;
    for (int i = 1; i <= 8; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  @override
  bool shouldRepaint(_HexPainter old) =>
      old.fill != fill || old.border != border;
}

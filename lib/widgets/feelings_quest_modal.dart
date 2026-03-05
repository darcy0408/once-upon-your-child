// lib/widgets/feelings_quest_modal.dart
//
// Full-screen Feelings Quest modal.
//
// Age-based depth:
//   ≤ 5  (Sprout)     → core only (7 big cloud cards)
//   6–8  (Explorer)   → core → secondary (drill-down)
//   9+   (Adventurer+)→ core → secondary → tertiary chips
//
// Cloud face images: assets/feelings_faces/clouds/{id}.png (user-generated).
// Falls back to assets/feelings_faces/{id}.png then to emoji.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../feelings_wheel_data.dart';

class FeelingsQuestModal {
  /// Opens the modal and returns the selected feeling labels, e.g.:
  ///   ['happy']
  ///   ['happy', 'playful']
  ///   ['happy', 'playful', 'silly']
  /// Returns null if the user dismissed without selecting.
  static Future<List<String>?> show(
    BuildContext context, {
    required int childAge,
  }) {
    return Navigator.of(context).push<List<String>>(
      PageRouteBuilder(
        fullscreenDialog: true,
        opaque: true,
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) =>
            _FeelingsQuestScreen(childAge: childAge),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FeelingsQuestScreen extends StatefulWidget {
  final int childAge;
  const _FeelingsQuestScreen({required this.childAge});

  @override
  State<_FeelingsQuestScreen> createState() => _FeelingsQuestScreenState();
}

class _FeelingsQuestScreenState extends State<_FeelingsQuestScreen> {
  int _level = 0; // 0 = core, 1 = secondary, 2 = tertiary
  CoreEmotion? _selectedCore;
  SecondaryFeeling? _selectedSecondary;

  /// How deep the picker goes for this user's age.
  int get _maxLevel {
    if (widget.childAge <= 5) return 0;
    if (widget.childAge <= 8) return 1;
    return 2;
  }

  static const List<String> _titles = [
    'How are you feeling?',
    'Tell me more…',
    'Even more specific?',
  ];

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _pickCore(CoreEmotion emotion) {
    HapticFeedback.lightImpact();
    if (_maxLevel == 0) {
      Navigator.of(context).pop([emotion.id]);
      return;
    }
    setState(() {
      _selectedCore = emotion;
      _level = 1;
    });
  }

  void _pickSecondary(SecondaryFeeling secondary) {
    HapticFeedback.lightImpact();
    if (_maxLevel < 2 || secondary.tertiary.isEmpty) {
      Navigator.of(context).pop([_selectedCore!.id, secondary.id]);
      return;
    }
    setState(() {
      _selectedSecondary = secondary;
      _level = 2;
    });
  }

  void _pickTertiary(String tertiary) {
    HapticFeedback.mediumImpact();
    Navigator.of(context)
        .pop([_selectedCore!.id, _selectedSecondary!.id, tertiary.toLowerCase()]);
  }

  void _goBack() {
    setState(() {
      if (_level == 2) {
        _level = 1;
        _selectedSecondary = null;
      } else if (_level == 1) {
        _level = 0;
        _selectedCore = null;
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E3A),
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              title: _titles[_level],
              level: _level,
              onBack: _goBack,
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(_level > 0 ? 0.15 : -0.15, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: switch (_level) {
                  1 => _SecondaryGrid(
                      key: ValueKey('sec_${_selectedCore!.id}'),
                      core: _selectedCore!,
                      onPick: _pickSecondary,
                    ),
                  2 => _TertiaryGrid(
                      key: ValueKey('ter_${_selectedSecondary!.id}'),
                      core: _selectedCore!,
                      secondary: _selectedSecondary!,
                      onPick: _pickTertiary,
                    ),
                  _ => _CoreGrid(
                      key: const ValueKey('core'),
                      onPick: _pickCore,
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String title;
  final int level;
  final VoidCallback onBack;
  final VoidCallback onClose;

  const _Header({
    required this.title,
    required this.level,
    required this.onBack,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: level > 0
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: onBack,
                  )
                : IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 22),
                    onPressed: onClose,
                  ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level grids
// ─────────────────────────────────────────────────────────────────────────────

class _CoreGrid extends StatelessWidget {
  final void Function(CoreEmotion) onPick;
  const _CoreGrid({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final cores = FeelingsWheelData.coreEmotions;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
        childAspectRatio: 0.88,
      ),
      itemCount: cores.length,
      itemBuilder: (_, i) => _CloudEmotionCard(
        id: cores[i].id,
        name: cores[i].name,
        emoji: cores[i].emoji,
        color: cores[i].color!,
        onTap: () => onPick(cores[i]),
      ),
    );
  }
}

class _SecondaryGrid extends StatelessWidget {
  final CoreEmotion core;
  final void Function(SecondaryFeeling) onPick;
  const _SecondaryGrid({super.key, required this.core, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final secondary = core.secondary;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.82,
      ),
      itemCount: secondary.length,
      itemBuilder: (_, i) => _CloudEmotionCard(
        id: secondary[i].id,
        name: secondary[i].name,
        emoji: secondary[i].emoji,
        color: core.secondaryColor ?? core.color!,
        onTap: () => onPick(secondary[i]),
        small: true,
      ),
    );
  }
}

class _TertiaryGrid extends StatelessWidget {
  final CoreEmotion core;
  final SecondaryFeeling secondary;
  final void Function(String) onPick;

  const _TertiaryGrid({
    super.key,
    required this.core,
    required this.secondary,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final tertiary = secondary.tertiary;
    final color = core.tertiaryColor ?? core.secondaryColor ?? core.color!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pick the one that fits best:',
              style: GoogleFonts.fredoka(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: tertiary
                  .map((t) => _TertiaryChip(
                        label: t,
                        color: color,
                        onTap: () => onPick(t),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cloud card
// ─────────────────────────────────────────────────────────────────────────────

class _CloudEmotionCard extends StatefulWidget {
  final String id;
  final String name;
  final String emoji;
  final Color color;
  final VoidCallback onTap;
  final bool small;

  const _CloudEmotionCard({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.onTap,
    this.small = false,
  });

  @override
  State<_CloudEmotionCard> createState() => _CloudEmotionCardState();
}

class _CloudEmotionCardState extends State<_CloudEmotionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.91).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _ctrl.forward();
  void _onTapUp(_) {
    _ctrl.reverse();
    widget.onTap();
  }
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    final cloudH = widget.small ? 72.0 : 100.0;
    final faceH = widget.small ? 44.0 : 64.0;
    final fontSize = widget.small ? 12.0 : 14.0;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cloud body
            SizedBox(
              height: cloudH,
              child: ClipPath(
                clipper: _CloudClipper(),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.color.withAlpha(220),
                  ),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: cloudH * 0.05),
                      child: _FaceImage(
                        id: widget.id,
                        emoji: widget.emoji,
                        height: faceH,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.name,
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tertiary chip
// ─────────────────────────────────────────────────────────────────────────────

class _TertiaryChip extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TertiaryChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_TertiaryChip> createState() => _TertiaryChipState();
}

class _TertiaryChipState extends State<_TertiaryChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: widget.color.withAlpha(200),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha(100),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Face image with fallback chain
// ─────────────────────────────────────────────────────────────────────────────

class _FaceImage extends StatelessWidget {
  final String id;
  final String emoji;
  final double height;

  const _FaceImage({
    required this.id,
    required this.emoji,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    // Try cloud-face variant first (user-generated assets), then standard face.
    return Image.asset(
      'assets/feelings_faces/clouds/$id.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/feelings_faces/$id.png',
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Text(emoji, style: TextStyle(fontSize: height * 0.65)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cloud clipper
// ─────────────────────────────────────────────────────────────────────────────

class _CloudClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    // Bottom-left corner
    path.moveTo(w * 0.08, h);
    path.quadraticBezierTo(0, h, 0, h * 0.72);
    // Left side — small left bump
    path.quadraticBezierTo(0, h * 0.52, w * 0.12, h * 0.50);
    path.quadraticBezierTo(w * 0.08, h * 0.26, w * 0.28, h * 0.22);
    // Center-left bump (tallest)
    path.quadraticBezierTo(w * 0.28, 0.0, w * 0.50, 0.0);
    // Center-right bump
    path.quadraticBezierTo(w * 0.72, 0.0, w * 0.74, h * 0.20);
    // Right bump
    path.quadraticBezierTo(w * 0.90, h * 0.14, w * 0.96, h * 0.36);
    // Right side down
    path.quadraticBezierTo(w, h * 0.50, w, h * 0.72);
    path.quadraticBezierTo(w, h, w * 0.92, h);
    // Bottom edge
    path.lineTo(w * 0.08, h);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(_CloudClipper oldClipper) => false;
}

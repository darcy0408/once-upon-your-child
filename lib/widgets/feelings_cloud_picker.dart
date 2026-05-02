// lib/widgets/feelings_cloud_picker.dart
//
// Shared cloud-card emotion picker used in:
//   - FeelingsQuestModal  (pre-story full-screen)
//   - FeelingsGardenScreen Zone 2  (inline explorer)
//
// Age-based depth:
//   ≤ 5  → core only
//   6–8  → core → secondary
//   9+   → core → secondary → tertiary
//
// Self-contained: owns its own level/back-navigation state.
// Reports selection via [onSelected] with a [FeelingSelection] result.
//
// Cloud images: assets/feelings_faces/{id}.png  (optional, falls back to emoji)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../feelings_wheel_data.dart';
import '../theme/age_band_asset_resolver.dart';
import '../theme/age_band_theme.dart';
import 'safe_asset_image.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public result type
// ─────────────────────────────────────────────────────────────────────────────

class FeelingSelection {
  final CoreEmotion core;
  final SecondaryFeeling? secondary;
  final String? tertiary;

  const FeelingSelection({
    required this.core,
    this.secondary,
    this.tertiary,
  });

  /// Flat id list — e.g. ['happy', 'playful', 'silly']
  List<String> get ids => [
        core.id,
        if (secondary != null) secondary!.id,
        if (tertiary != null) tertiary!.toLowerCase(),
      ];

  String get displayName => tertiary ?? secondary?.name ?? core.name;
  String get emoji => secondary?.emoji ?? core.emoji;
  Color get color =>
      core.tertiaryColor ?? core.secondaryColor ?? core.color!;
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

class FeelingsCloudPicker extends StatefulWidget {
  final int childAge;

  /// Called when the user completes a selection at the deepest available level.
  final ValueChanged<FeelingSelection> onSelected;

  /// Optional: notified whenever the drill-down level changes (0/1/2).
  final ValueChanged<int>? onLevelChanged;

  /// Optional: pre-select a core emotion on mount.
  final String? initialCoreId;

  const FeelingsCloudPicker({
    super.key,
    required this.childAge,
    required this.onSelected,
    this.onLevelChanged,
    this.initialCoreId,
  });

  @override
  State<FeelingsCloudPicker> createState() => FeelingsCloudPickerState();
}

class FeelingsCloudPickerState extends State<FeelingsCloudPicker> {
  int _level = 0;
  CoreEmotion? _core;
  SecondaryFeeling? _secondary;

  int get _maxLevel {
    if (widget.childAge <= 5) return 0;
    if (widget.childAge <= 8) return 1;
    return 2;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialCoreId != null) {
      _core = FeelingsWheelData.coreEmotions
          .where((c) => c.id == widget.initialCoreId)
          .firstOrNull;
      if (_core != null && _maxLevel > 0) _level = 1;
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _pickCore(CoreEmotion emotion) {
    HapticFeedback.lightImpact();
    if (_maxLevel == 0) {
      widget.onSelected(FeelingSelection(core: emotion));
      return;
    }
    setState(() {
      _core = emotion;
      _secondary = null;
      _level = 1;
    });
    widget.onLevelChanged?.call(1);
  }

  void _pickSecondary(SecondaryFeeling secondary) {
    HapticFeedback.lightImpact();
    if (_maxLevel < 2 || secondary.tertiary.isEmpty) {
      widget.onSelected(FeelingSelection(core: _core!, secondary: secondary));
      return;
    }
    setState(() {
      _secondary = secondary;
      _level = 2;
    });
    widget.onLevelChanged?.call(2);
  }

  void _pickTertiary(String tertiary) {
    HapticFeedback.mediumImpact();
    widget.onSelected(
        FeelingSelection(core: _core!, secondary: _secondary!, tertiary: tertiary));
  }

  /// Go back one level. Returns true if we went back, false if already at core.
  bool goBack() {
    if (_level == 2) {
      setState(() {
        _level = 1;
        _secondary = null;
      });
      widget.onLevelChanged?.call(1);
      return true;
    }
    if (_level == 1) {
      setState(() {
        _level = 0;
        _core = null;
      });
      widget.onLevelChanged?.call(0);
      return true;
    }
    return false;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb / back row (only when drilled in)
        if (_level > 0)
          _Breadcrumb(
            core: _core,
            secondary: _secondary,
            level: _level,
            onBack: goBack,
          ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(_level > 0 ? 0.12 : -0.12, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: switch (_level) {
              1 => _SecondaryGrid(
                  key: ValueKey('sec_${_core!.id}'),
                  core: _core!,
                  onPick: _pickSecondary,
                ),
              2 => _TertiaryGrid(
                  key: ValueKey('ter_${_secondary!.id}'),
                  core: _core!,
                  secondary: _secondary!,
                  onPick: _pickTertiary,
                ),
              _ => _CoreGrid(
                  key: const ValueKey('core'),
                  childAge: widget.childAge,
                  onPick: _pickCore,
                ),
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Breadcrumb bar
// ─────────────────────────────────────────────────────────────────────────────

class _Breadcrumb extends StatelessWidget {
  final CoreEmotion? core;
  final SecondaryFeeling? secondary;
  final int level;
  final VoidCallback onBack;

  const _Breadcrumb({
    required this.core,
    required this.secondary,
    required this.level,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isMature =
        Theme.of(context).extension<AgeBandThemeData>()?.band.isMature ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white70, size: 18),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          if (core != null) ...[
            _crumb(core!.emoji, core!.name, core!.color!, isMature: isMature),
          ],
          if (secondary != null) ...[
            const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
            _crumb(secondary!.emoji, secondary!.name,
                core?.secondaryColor ?? core?.color ?? Colors.white,
                isMature: isMature),
          ],
        ],
      ),
    );
  }

  Widget _crumb(String emoji, String name, Color color, {bool isMature = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(60),
        borderRadius: BorderRadius.circular(isMature ? 8 : 20),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        isMature ? name : '$emoji $name',
        style: isMature
            ? TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              )
            : GoogleFonts.fredoka(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grids
// ─────────────────────────────────────────────────────────────────────────────

class _CoreGrid extends StatefulWidget {
  final int childAge;
  final void Function(CoreEmotion) onPick;
  const _CoreGrid({super.key, required this.childAge, required this.onPick});

  @override
  State<_CoreGrid> createState() => _CoreGridState();
}

class _CoreGridState extends State<_CoreGrid> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cores = FeelingsWheelData.coreEmotionsForAge(widget.childAge);
    // Taller ratio (closer to 1.0) for fewer items so all cards fit on screen;
    // narrower ratio for larger lists (9+) keeps the familiar card shape.
    final aspectRatio = cores.length <= 4 ? 1.1 : cores.length <= 6 ? 1.05 : 0.88;
    return Scrollbar(
      controller: _scrollController,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 18,
          childAspectRatio: aspectRatio,
        ),
        itemCount: cores.length,
        itemBuilder: (_, i) => CloudEmotionCard(
          id: cores[i].id,
          name: cores[i].name,
          emoji: cores[i].emoji,
          color: cores[i].color!,
          onTap: () => widget.onPick(cores[i]),
        ),
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: secondary.length,
      itemBuilder: (_, i) => CloudEmotionCard(
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
    final isMature =
        Theme.of(context).extension<AgeBandThemeData>()?.band.isMature ?? false;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isMature ? 'Which feels most accurate?' : 'Pick the one that fits best:',
              style: isMature
                  ? const TextStyle(color: Colors.white70, fontSize: 16)
                  : GoogleFonts.fredoka(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              alignment: WrapAlignment.center,
              children: tertiary
                  .map((t) => _TertiaryChip(
                        label: t,
                        color: color,
                        onTap: () => onPick(t),
                        isMature: isMature,
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
// Cloud card  (public so Garden can also import it if needed)
// ─────────────────────────────────────────────────────────────────────────────

class CloudEmotionCard extends StatefulWidget {
  final String id;
  final String name;
  final String emoji;
  final Color color;
  final VoidCallback onTap;
  final bool small;

  const CloudEmotionCard({
    super.key,
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.onTap,
    this.small = false,
  });

  @override
  State<CloudEmotionCard> createState() => _CloudEmotionCardState();
}

class _CloudEmotionCardState extends State<CloudEmotionCard>
    with TickerProviderStateMixin {
  late final AnimationController _tapCtrl;
  late final Animation<double> _tapScale;
  late final AnimationController _breatheCtrl;
  late final Animation<double> _breatheScale;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
    _tapScale = Tween<double>(begin: 1.0, end: 0.95).animate(
        CurvedAnimation(parent: _tapCtrl, curve: Curves.easeInOut));
    // Subtle 2.5s breathe on the character image only — replaces the noisy
    // pulse-aura design with something gentle that still says "I'm alive."
    _breatheCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat(reverse: true);
    _breatheScale = Tween<double>(begin: 1.0, end: 1.04).animate(
        CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    _breatheCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _tapCtrl.forward();
  void _onTapUp(TapUpDetails _) {
    _tapCtrl.reverse();
    widget.onTap();
  }
  void _onTapCancel() => _tapCtrl.reverse();

  @override
  Widget build(BuildContext context) {
    final cardH = widget.small ? 88.0 : 120.0;
    final faceH = widget.small ? 56.0 : 80.0;
    final fontSize = widget.small ? 14.0 : 18.0;
    final isMature =
        Theme.of(context).extension<AgeBandThemeData>()?.band.isMature ?? false;

    // Soften the per-feeling color to a ~40% saturation tint and build a
    // gentle top-to-bottom lightness shift. Avoids the cartoony heavy fill
    // while keeping the Inside-Out colour cue (yellow=happy, blue=sad, etc.).
    final hsl = HSLColor.fromColor(widget.color);
    final softened =
        hsl.withSaturation((hsl.saturation * 0.4).clamp(0.0, 1.0));
    final topTint = softened
        .withLightness((softened.lightness + 0.10).clamp(0.0, 1.0))
        .toColor();
    final bottomTint = softened
        .withLightness((softened.lightness - 0.02).clamp(0.0, 1.0))
        .toColor();

    Widget cardFace = Center(
      child: ScaleTransition(
        scale: _breatheScale,
        child: _FaceImage(
          id: widget.id,
          emoji: widget.emoji,
          height: faceH,
        ),
      ),
    );

    Widget cardShape;
    if (isMature) {
      // Mature: flat rounded rectangle, subtle border, no cloud clip
      cardShape = Container(
        height: cardH,
        decoration: BoxDecoration(
          color: widget.color.withAlpha(50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.color.withAlpha(140), width: 1),
          boxShadow: [
            BoxShadow(
              color: widget.color.withAlpha(60),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: cardFace,
      );
    } else {
      // Young: clean squircle, soft tint gradient, drop shadow.
      // No cloud clip, no outer aura/glow — those read as amateur.
      cardShape = Container(
        height: cardH,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topTint, bottomTint],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withAlpha(76), // ~30% white inner glow border
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: cardFace,
      );
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _tapScale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            cardShape,
            const SizedBox(height: 8),
            Text(
              widget.name,
              textAlign: TextAlign.center,
              style: isMature
                  ? TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                    )
                  : GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
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
  final bool isMature;
  const _TertiaryChip(
      {required this.label, required this.color, required this.onTap, this.isMature = false});

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
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
          padding: EdgeInsets.symmetric(
            horizontal: widget.isMature ? 20 : 26,
            vertical: widget.isMature ? 10 : 13,
          ),
          decoration: BoxDecoration(
            color: widget.isMature
                ? widget.color.withAlpha(60)
                : widget.color.withAlpha(200),
            borderRadius: BorderRadius.circular(widget.isMature ? 10 : 50),
            border: widget.isMature
                ? Border.all(color: widget.color.withAlpha(160), width: 1)
                : null,
            boxShadow: [
              BoxShadow(
                  color: widget.color.withAlpha(widget.isMature ? 60 : 100),
                  blurRadius: 12,
                  spreadRadius: 1),
            ],
          ),
          child: Text(
            widget.label,
            style: widget.isMature
                ? TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  )
                : GoogleFonts.fredoka(
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
// Face image
// ─────────────────────────────────────────────────────────────────────────────

class _FaceImage extends StatelessWidget {
  final String id;
  final String emoji;
  final double height;
  const _FaceImage(
      {required this.id, required this.emoji, required this.height});

  @override
  Widget build(BuildContext context) {
    final band = Theme.of(context).extension<AgeBandThemeData>()?.band;
    final flatPath = 'assets/feelings_faces/$id.png';

    // Try band-specific artwork first; fall back to global flat library; then emoji.
    if (band != null) {
      final bandPath = AgeBandAssetResolver.feelingPath(band, id);
      return SafeAssetImage(
        bandPath,
        height: height,
        fit: BoxFit.contain,
        placeholder: SafeAssetImage(
          flatPath,
          height: height,
          fit: BoxFit.contain,
          placeholder: Text(emoji, style: TextStyle(fontSize: height * 0.65)),
        ),
      );
    }

    return SafeAssetImage(
      flatPath,
      height: height,
      fit: BoxFit.contain,
      placeholder: Text(emoji, style: TextStyle(fontSize: height * 0.65)),
    );
  }
}


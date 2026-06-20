import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/age_band_theme.dart';
import '../safe_asset_image.dart';

class ImagineItHeroCard extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;
  const ImagineItHeroCard({super.key, required this.isSelected, required this.onTap});

  @override
  State<ImagineItHeroCard> createState() => _ImagineItHeroCardState();
}

class _ImagineItHeroCardState extends State<ImagineItHeroCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  // The shared card art reads too bright in the Sprout band. Nudge contrast
  // up (×1.18) and brightness down so the scene art has more depth. Offset
  // -53 keeps mid-tones near pivot: 128*(1-1.18) ≈ -23, plus -30 brightness.
  static const ColorFilter _sproutContrastFilter = ColorFilter.matrix(<double>[
    1.18, 0, 0, 0, -53, //
    0, 1.18, 0, 0, -53, //
    0, 0, 1.18, 0, -53, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Widget _maybeToneDown(bool isSprout, Widget child) => isSprout
      ? ColorFiltered(colorFilter: _sproutContrastFilter, child: child)
      : child;

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final isSprout = band.band == AgeBand.sprout;
    // Audit S-02: the shared Imagine It art is a ~5-6yo girl with a picture
    // book — far too young for the older bands. Each band from Adventurer up
    // serves its own age-tuned, textless dreamscape; Sprout/Explorer keep the
    // original. (Resolver mirrors sceneAsset() in hero_creator_scene_page.dart.)
    final sceneArtDir = switch (band.band) {
      AgeBand.adventurer => 'adventurer',
      AgeBand.creator => 'creator',
      AgeBand.adolescent => 'adolescent',
      AgeBand.adult => 'adult',
      _ => null,
    };
    final asset = sceneArtDir != null
        ? 'assets/images/scenarios/$sceneArtDir/imagine_it.webp'
        : 'assets/images/scenarios/imagine_it_btn_pressed.webp';

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: isSprout ? 'Make one up' : 'Imagine It — create your own world',
      hint: widget.isSelected
          ? 'Currently selected. Double tap to change your idea.'
          : isSprout
              ? 'Double tap to tell us your own place.'
              : 'Double tap to open the imagine-it screen and describe your scene.',
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.mediumImpact();
          setState(() => _pressed = true);
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedBuilder(
          animation: _glowAnim,
          builder: (context, child) {
            return AnimatedScale(
              scale: _pressed ? 0.96 : 1.0,
              duration: const Duration(milliseconds: 80),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.isSelected
                        ? const Color(0xFFFFD700)
                        : const Color(0xFFFFD700)
                            .withAlpha((_glowAnim.value * 160).round()),
                    width: widget.isSelected ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withAlpha(
                          ((_glowAnim.value) * (widget.isSelected ? 120 : 80))
                              .round()),
                      blurRadius: widget.isSelected ? 22 : 16,
                      spreadRadius: widget.isSelected ? 3 : 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 360 / 220,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 80),
                          foregroundDecoration: BoxDecoration(
                            color: _pressed
                                ? Colors.black.withAlpha(70)
                                : Colors.transparent,
                          ),
                          child: _maybeToneDown(
                            isSprout,
                            SafeAssetImage(
                              asset,
                              fit: BoxFit.cover,
                              placeholder: Container(
                                color: const Color(0xFF2C1B47),
                                child: Center(
                                  child: Text(
                                    isSprout
                                        ? 'Make One Up! ✨'
                                        : 'Imagine It ✨',
                                    style: GoogleFonts.fredoka(
                                        color: const Color(0xFFFFD700),
                                        fontSize: 22),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color(0xFF1A0E36), Color(0x00000000)],
                              stops: [0.0, 0.5],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isSprout ? '✨  Make One Up!' : '✨  Imagine It',
                                style: GoogleFonts.fredoka(
                                  color: const Color(0xFFFFD700),
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  shadows: const [
                                    Shadow(
                                        color: Colors.black,
                                        blurRadius: 6,
                                        offset: Offset(0, 1))
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isSprout
                                    ? 'Tell us a place you want to visit'
                                    : 'Describe any world you can dream up',
                                style: GoogleFonts.fredoka(
                                  color: Colors.white.withAlpha(210),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (widget.isSelected)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFD700),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                color: Colors.black, size: 16),
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

class SceneButtonData {
  final String id;
  final String label;
  final String normalAsset;
  final String pressedAsset;
  /// Creator band: evocative psychological hook shown below the title.
  final String? thematicQuestion;

  /// Adventurer band: one-line "what happens here" tease shown below the title
  /// so a 9–11yo can tell worlds apart (and so the opaque "Life Quest" tile
  /// explains itself). Sourced from `ScenarioCard.descriptionForAge`.
  final String? description;

  /// When true the tile renders an accent gradient (with [emoji], if given)
  /// instead of loading [normalAsset] — used for worlds that have no bespoke
  /// per-band art yet, so the grid stays uniform instead of showing a harsh
  /// placeholder box (MT-269).
  final bool useAccentGradient;

  /// Large glyph centered in the gradient fallback tile.
  final String? emoji;

  const SceneButtonData({
    required this.id,
    required this.label,
    required this.normalAsset,
    required this.pressedAsset,
    this.thematicQuestion,
    this.description,
    this.useAccentGradient = false,
    this.emoji,
  });
}

class SceneImageButton extends StatefulWidget {
  final SceneButtonData data;
  final bool isSelected;
  final double labelFontSize;
  final VoidCallback onTap;
  /// When true, shows `data.thematicQuestion` (if present) in the label overlay.
  final bool showThematicQuestion;

  /// When true, shows `data.description` (if present) under the title — used by
  /// the Adventurer band so each world tile self-explains.
  final bool showDescription;

  /// Selection accent (border / glow / check badge). Defaults to the legacy
  /// gold; mature bands that intentionally dropped gold (Creator purple,
  /// Adolescent teal — MT-273) pass `band.accent` instead.
  final Color accentColor;

  const SceneImageButton({
    super.key,
    required this.data,
    required this.isSelected,
    required this.onTap,
    this.labelFontSize = 13.0,
    this.showThematicQuestion = false,
    this.showDescription = false,
    this.accentColor = const Color(0xFFFFD700),
  });

  @override
  State<SceneImageButton> createState() => _SceneImageButtonState();
}

class _SceneImageButtonState extends State<SceneImageButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final asset = _pressed ? widget.data.pressedAsset : widget.data.normalAsset;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: 'Scene: ${widget.data.label}',
      hint: widget.isSelected
          ? 'Currently selected. Double tap to keep this scene.'
          : 'Double tap to choose this scene for your adventure.',
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _pressed = true);
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Container(
            width: null,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isSelected
                    ? widget.accentColor
                    : Colors.transparent,
                width: widget.isSelected ? 3 : 0,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: widget.accentColor.withAlpha(120),
                        blurRadius: 16,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 360 / 220,
                    child: widget.data.useAccentGradient
                        ? Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  widget.accentColor.withAlpha(90),
                                  const Color(0xFF140A24),
                                ],
                              ),
                            ),
                            child: widget.data.emoji != null
                                ? Center(
                                    child: Text(
                                      widget.data.emoji!,
                                      style: const TextStyle(fontSize: 44),
                                    ),
                                  )
                                : null,
                          )
                        : SafeAssetImage(
                            asset,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              color: const Color(0xFF3A1070),
                              child: Center(
                                child: Text(widget.data.label,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14)),
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          // S-07: deepen the bottom scrim so the title and
                          // description stay legible over the brightest tile
                          // art (e.g. the rainbow world).
                          colors: [Colors.transparent, Color(0xE61A0040)],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.data.label,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: widget.labelFontSize,
                              fontWeight: FontWeight.bold,
                              shadows: const [
                                Shadow(
                                    color: Colors.black,
                                    blurRadius: 4,
                                    offset: Offset(0, 1))
                              ],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.showThematicQuestion &&
                              widget.data.thematicQuestion != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.data.thematicQuestion!,
                              style: GoogleFonts.bitter(
                                color: Colors.white70,
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (widget.showDescription &&
                              widget.data.description != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.data.description!,
                              style: GoogleFonts.bitter(
                                color: Colors.white.withAlpha(225),
                                fontSize: 10.5,
                                height: 1.15,
                              ),
                              textAlign: TextAlign.center,
                              // S-01: allow a third line so the tightened
                              // Adventurer hooks render in full instead of
                              // truncating mid-word at narrow tile widths.
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (widget.isSelected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: widget.accentColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.black, size: 14),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

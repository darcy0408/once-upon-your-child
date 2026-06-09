// Superhero Mode (Sprout 3-5, Explorer 6-8, Adventurer 9-12) — 3-tap costume picker.
//
// Three sequential pages inside a single Scaffold (PageView controlled
// programmatically): color → cape → emblem. Auto-advances on color tap;
// cape and emblem require explicit tap-then-advance with a brief
// confirmation animation.
//
// Writes selections back to [WizardData.heroCostumeColor], heroCapeStyle,
// heroEmblem. Does NOT save the HeroProfile yet — that happens after the
// power picker completes (see [SuperheroPowerScreen]).
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models.dart';
import '../../theme/age_band_theme.dart';
import 'superhero_power_screen.dart';

class SuperheroCostumeScreen extends StatefulWidget {
  final WizardData wizardData;

  /// Visual band (drives palette + which emblems show). Defaults to sprout
  /// so existing callers that don't pass a band keep the original behavior.
  final AgeBand band;

  const SuperheroCostumeScreen({
    super.key,
    required this.wizardData,
    this.band = AgeBand.sprout,
  });

  @override
  State<SuperheroCostumeScreen> createState() => _SuperheroCostumeScreenState();
}

class _SuperheroCostumeScreenState extends State<SuperheroCostumeScreen> {
  static const _gold = Color(0xFFFFD700);

  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _justSelectedSnapshot;

  static const _colors = <_ColorOption>[
    _ColorOption(id: 'red', label: 'Red', color: Color(0xFFE53935)),
    _ColorOption(id: 'blue', label: 'Blue', color: Color(0xFF1E88E5)),
    _ColorOption(id: 'green', label: 'Green', color: Color(0xFF43A047)),
    _ColorOption(id: 'yellow', label: 'Yellow', color: Color(0xFFFDD835)),
    _ColorOption(id: 'purple', label: 'Purple', color: Color(0xFF8E24AA)),
    _ColorOption(id: 'pink', label: 'Pink', color: Color(0xFFEC407A)),
  ];

  // C2: Adventurer (9-12) and Creator (13-14) see cooler "suit theme" names
  // instead of plain color words — same color ids, just a less babyish label.
  static const Map<String, String> _adventurerColorNames = {
    'red': 'Inferno',
    'blue': 'Frostbite',
    'green': 'Venom',
    'yellow': 'Voltage',
    'purple': 'Nightshade',
    'pink': 'Nova',
  };

  /// Display label for a costume color, band-aware (Adventurer + Creator get
  /// suit themes; younger bands keep plain color words).
  String _colorLabel(_ColorOption c) => (widget.band == AgeBand.adventurer ||
          widget.band == AgeBand.creator ||
          widget.band == AgeBand.adolescent)
      ? (_adventurerColorNames[c.id] ?? c.label)
      : c.label;

  static const _capes = <_CapeOption>[
    _CapeOption(id: 'none', label: 'No cape', emoji: '🦸'),
    _CapeOption(id: 'matching', label: 'Matching cape', emoji: '🟦'),
    _CapeOption(id: 'rainbow', label: 'Rainbow cape', emoji: '🌈'),
  ];

  // Shared emblem set (Sprout band shows these 6).
  static const _baseEmblems = <_EmblemOption>[
    _EmblemOption(id: 'star', label: 'Star', emoji: '⭐'),
    _EmblemOption(id: 'lightning', label: 'Lightning', emoji: '⚡'),
    _EmblemOption(id: 'heart', label: 'Heart', emoji: '❤️'),
    _EmblemOption(id: 'moon', label: 'Moon', emoji: '🌙'),
    _EmblemOption(id: 'paw', label: 'Paw', emoji: '🐾'),
    _EmblemOption(id: 'rainbow', label: 'Rainbow', emoji: '🌈'),
  ];

  // Explorer-only emblems (appended after the base 6 → 8 total for Explorer).
  static const _explorerExtraEmblems = <_EmblemOption>[
    _EmblemOption(id: 'bolt', label: 'Bolt', emoji: '🔱'),
    _EmblemOption(id: 'comet', label: 'Comet', emoji: '☄️'),
  ];

  List<_EmblemOption> get _emblems => (widget.band == AgeBand.explorer ||
          widget.band == AgeBand.adventurer ||
          widget.band == AgeBand.creator ||
          widget.band == AgeBand.adolescent)
      ? <_EmblemOption>[..._baseEmblems, ..._explorerExtraEmblems]
      : _baseEmblems;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _advance() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      // Final page — go to power picker.
      Navigator.of(context)
          .push(
        MaterialPageRoute<bool>(
          builder: (_) => SuperheroPowerScreen(
            wizardData: widget.wizardData,
            band: widget.band,
          ),
        ),
      )
          .then((result) {
        if (!mounted) return;
        // If the power picker completed successfully, propagate the pop.
        if (result == true) {
          Navigator.of(context).pop(true);
        }
      });
    }
  }

  /// "🎲 Surprise me!" — rolls a complete random costume (color + cape +
  /// emblem) and jumps straight to the power picker with a random power
  /// pre-selected, so a kid can mint a full hero in one tap. The power screen
  /// shows a "surprise" banner and a reroll so it stays playful and editable.
  void _surpriseMe() {
    final rng = Random();
    final color = _colors[rng.nextInt(_colors.length)];
    final cape = _capes[rng.nextInt(_capes.length)];
    final emblem = _emblems[rng.nextInt(_emblems.length)];
    HapticFeedback.mediumImpact();
    setState(() {
      widget.wizardData.heroCostumeColor = color.id;
      widget.wizardData.heroCapeStyle = cape.id;
      widget.wizardData.heroEmblem = emblem.id;
    });
    Navigator.of(context)
        .push(
      MaterialPageRoute<bool>(
        builder: (_) => SuperheroPowerScreen(
          wizardData: widget.wizardData,
          band: widget.band,
          surprise: true,
        ),
      ),
    )
        .then((result) {
      if (!mounted) return;
      if (result == true) {
        Navigator.of(context).pop(true);
      }
    });
  }

  Future<void> _selectAndAdvance(String snapshot) async {
    HapticFeedback.lightImpact();
    setState(() => _justSelectedSnapshot = snapshot);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _justSelectedSnapshot = null);
    _advance();
  }

  @override
  Widget build(BuildContext context) {
    // Explorer + Adventurer share the older, less babyish copy.
    final isExplorer = widget.band == AgeBand.explorer ||
        widget.band == AgeBand.adventurer ||
        widget.band == AgeBand.creator ||
        widget.band == AgeBand.adolescent;
    // Pull the canonical band gradient instead of hardcoding a new palette.
    final gradient = themeForBand(widget.band).backgroundGradient;
    final appBarTitle = isExplorer ? 'Design Your Hero!' : 'Make Your Hero!';
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          appBarTitle,
          style: GoogleFonts.fredoka(
            color: _gold,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Column(
            children: [
              _ProgressDots(currentPage: _currentPage, total: 3),
              const SizedBox(height: 10),
              // One-tap "build me a random hero" — high-replayability shortcut.
              Semantics(
                button: true,
                label: 'Surprise me — build a random superhero',
                child: TextButton.icon(
                  onPressed: _surpriseMe,
                  style: TextButton.styleFrom(
                    foregroundColor: _gold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: _gold.withAlpha(120), width: 1.5),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  ),
                  icon: const Text('🎲', style: TextStyle(fontSize: 18)),
                  label: Text(
                    'Surprise me!',
                    style: GoogleFonts.fredoka(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _gold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (p) => setState(() => _currentPage = p),
                  children: [
                    _buildColorPage(),
                    _buildCapePage(),
                    _buildEmblemPage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageHeader(String emoji, String title, String subtitle) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: _gold,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: Colors.white.withAlpha(210),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // ── Page 1: color ──────────────────────────────────────────────────────────

  Widget _buildColorPage() {
    // Explorer + Adventurer share the older, less babyish copy.
    final isExplorer = widget.band == AgeBand.explorer ||
        widget.band == AgeBand.adventurer ||
        widget.band == AgeBand.creator ||
        widget.band == AgeBand.adolescent;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        children: [
          _pageHeader(
            '🎨',
            isExplorer ? 'Choose your hero color' : 'Pick your hero color!',
            isExplorer
                ? 'Tap the color that matches your hero'
                : 'Tap a color to choose',
          ),
          const SizedBox(height: 22),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
            children: _colors.map((c) {
              final selected = widget.wizardData.heroCostumeColor == c.id;
              final flash = _justSelectedSnapshot == 'color:${c.id}';
              return GestureDetector(
                onTap: () {
                  setState(() => widget.wizardData.heroCostumeColor = c.id);
                  _selectAndAdvance('color:${c.id}');
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: c.color,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: (selected || flash) ? _gold : Colors.white24,
                      width: (selected || flash) ? 4 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: c.color.withAlpha(180),
                        blurRadius: flash ? 24 : 12,
                        spreadRadius: flash ? 4 : 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _colorLabel(c),
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Page 2: cape ───────────────────────────────────────────────────────────

  Widget _buildCapePage() {
    // Explorer + Adventurer share the older, less babyish copy.
    final isExplorer = widget.band == AgeBand.explorer ||
        widget.band == AgeBand.adventurer ||
        widget.band == AgeBand.creator ||
        widget.band == AgeBand.adolescent;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        children: [
          _pageHeader(
            '🦸',
            isExplorer ? 'Choose your cape' : 'Pick your cape!',
            isExplorer
                ? 'Every hero needs a signature cape'
                : 'A cape makes you fly!',
          ),
          const SizedBox(height: 22),
          ..._capes.map((cape) {
            final selected = widget.wizardData.heroCapeStyle == cape.id;
            final flash = _justSelectedSnapshot == 'cape:${cape.id}';
            final isRainbow = cape.id == 'rainbow';
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () {
                  setState(() => widget.wizardData.heroCapeStyle = cape.id);
                  _selectAndAdvance('cape:${cape.id}');
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: isRainbow
                        ? const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFE53935),
                              Color(0xFFFFB300),
                              Color(0xFF43A047),
                              Color(0xFF1E88E5),
                              Color(0xFF8E24AA),
                            ],
                          )
                        : null,
                    color: isRainbow ? null : Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (selected || flash) ? _gold : Colors.white24,
                      width: (selected || flash) ? 4 : 2,
                    ),
                    boxShadow: flash
                        ? [
                            BoxShadow(
                              color: _gold.withAlpha(160),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Text(cape.emoji, style: const TextStyle(fontSize: 36)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          cape.label,
                          style: GoogleFonts.fredoka(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            shadows: const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Page 3: emblem ─────────────────────────────────────────────────────────

  Widget _buildEmblemPage() {
    // Explorer + Adventurer share the older, less babyish copy.
    final isExplorer = widget.band == AgeBand.explorer ||
        widget.band == AgeBand.adventurer ||
        widget.band == AgeBand.creator ||
        widget.band == AgeBand.adolescent;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        children: [
          _pageHeader(
            '✨',
            isExplorer ? 'Choose your emblem' : 'Pick your symbol!',
            isExplorer ? 'Your hero\'s signature mark' : 'Tap your hero emblem',
          ),
          const SizedBox(height: 22),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
            children: _emblems.map((e) {
              final selected = widget.wizardData.heroEmblem == e.id;
              final flash = _justSelectedSnapshot == 'emblem:${e.id}';
              return GestureDetector(
                onTap: () {
                  setState(() => widget.wizardData.heroEmblem = e.id);
                  _selectAndAdvance('emblem:${e.id}');
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: (selected || flash) ? _gold : Colors.white24,
                      width: (selected || flash) ? 4 : 2,
                    ),
                    boxShadow: flash
                        ? [
                            BoxShadow(
                              color: _gold.withAlpha(160),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(e.emoji, style: const TextStyle(fontSize: 56)),
                      const SizedBox(height: 6),
                      Text(
                        e.label,
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int currentPage;
  final int total;

  const _ProgressDots({required this.currentPage, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final filled = i <= currentPage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: filled ? 14 : 10,
              height: filled ? 14 : 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? const Color(0xFFFFD700)
                    : Colors.white.withAlpha(80),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ColorOption {
  final String id;
  final String label;
  final Color color;
  const _ColorOption({
    required this.id,
    required this.label,
    required this.color,
  });
}

class _CapeOption {
  final String id;
  final String label;
  final String emoji;
  const _CapeOption({
    required this.id,
    required this.label,
    required this.emoji,
  });
}

class _EmblemOption {
  final String id;
  final String label;
  final String emoji;
  const _EmblemOption({
    required this.id,
    required this.label,
    required this.emoji,
  });
}

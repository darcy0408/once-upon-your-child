// Superhero Mode (Sprout 3-5, Explorer 6-8, Adventurer 9-12) — 3-tap costume picker.
//
// Three sequential pages inside a single Scaffold (PageView controlled
// programmatically). Page order is band-aware:
//   • Adolescent (15-17): color → mark(emblem) → identity (the noir "double
//     life" prompts; no cape page).
//   • Every other band: color → cape → emblem (unchanged).
// Auto-advances on color tap; cape and emblem require explicit tap-then-advance
// with a brief confirmation animation; the identity page has its own Continue.
//
// Writes selections back to [WizardData.heroCostumeColor], heroCapeStyle,
// heroEmblem, and (Adolescent only) heroSecret / heroTell / heroLine. Does NOT
// save the HeroProfile yet — that happens after the power picker completes
// (see [SuperheroPowerScreen]).
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
  // Noir reskin: Adolescent (teal) and Creator (purple) use the band accent;
  // the gold-themed younger bands keep the established gold. (MT-273)
  Color get _gold =>
      (widget.band == AgeBand.adolescent || widget.band == AgeBand.creator)
          ? themeForBand(widget.band).accent
          : const Color(0xFFFFD700);

  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _justSelectedSnapshot;

  // Adolescent-only "Identity" page: a custom-text controller per prompt so a
  // teen can write their own answer instead of (or overriding) a preset chip.
  final TextEditingController _secretController = TextEditingController();
  final TextEditingController _tellController = TextEditingController();
  final TextEditingController _lineController = TextEditingController();
  final TextEditingController _seenByController = TextEditingController();

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
  String _colorLabel(_ColorOption c) =>
      (widget.band == AgeBand.adventurer ||
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

  List<_EmblemOption> get _emblems =>
      (widget.band == AgeBand.explorer ||
          widget.band == AgeBand.adventurer ||
          widget.band == AgeBand.creator ||
          widget.band == AgeBand.adolescent)
      ? <_EmblemOption>[..._baseEmblems, ..._explorerExtraEmblems]
      : _baseEmblems;

  @override
  void dispose() {
    _pageController.dispose();
    _secretController.dispose();
    _tellController.dispose();
    _lineController.dispose();
    _seenByController.dispose();
    super.dispose();
  }

  // Band-aware page order. Adolescent's noir "double life" flow drops the cape
  // page and adds an Identity page: [Color, Mark(emblem), Identity]. Every other
  // band keeps the original [Color, Cape, Emblem] exactly as before.
  List<Widget> get _pages => widget.band == AgeBand.adolescent
      ? [_buildColorPage(), _buildEmblemPage(), _buildIdentityPage()]
      : [_buildColorPage(), _buildCapePage(), _buildEmblemPage()];

  void _advance() {
    if (_currentPage < _pages.length - 1) {
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
    final isAdolescent = widget.band == AgeBand.adolescent;
    final color = _colors[rng.nextInt(_colors.length)];
    // Adolescent's flow has no cape page and filters out a few too-young
    // emblems — keep surprise inside that same allowed set so it can't pick a
    // mark the grid hides. heroSecret/heroTell/heroLine get seeded below from
    // the same chip lists the Identity page offers.
    final emblemPool = isAdolescent
        ? _emblems
              .where(
                (e) => !(e.id == 'heart' || e.id == 'paw' || e.id == 'rainbow'),
              )
              .toList()
        : _emblems;
    final emblem = emblemPool[rng.nextInt(emblemPool.length)];
    HapticFeedback.mediumImpact();
    setState(() {
      widget.wizardData.heroCostumeColor = color.id;
      if (!isAdolescent) {
        widget.wizardData.heroCapeStyle = _capes[rng.nextInt(_capes.length)].id;
      } else {
        // Adolescent's signature step is Identity — seed it too so a random
        // cover isn't left blank on the band's defining page. Controllers stay
        // empty, so the seeded field drives the chip-highlight + backend.
        widget.wizardData.heroSecret =
            _secretChips[rng.nextInt(_secretChips.length)];
        widget.wizardData.heroTell = _tellChips[rng.nextInt(_tellChips.length)];
        widget.wizardData.heroLine = _lineChips[rng.nextInt(_lineChips.length)];
        widget.wizardData.heroSeenBy =
            _seenByChips[rng.nextInt(_seenByChips.length)];
      }
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
    final isExplorer =
        widget.band == AgeBand.explorer ||
        widget.band == AgeBand.adventurer ||
        widget.band == AgeBand.creator ||
        widget.band == AgeBand.adolescent;
    // Pull the canonical band gradient instead of hardcoding a new palette.
    final gradient = themeForBand(widget.band).backgroundGradient;
    final appBarTitle = widget.band == AgeBand.adolescent
        ? 'Build your cover'
        : isExplorer
        ? 'Design Your Hero!'
        : 'Make Your Hero!';
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          appBarTitle,
          style: _noirAwareText(
            widget.band == AgeBand.adolescent,
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
              _ProgressDots(
                  currentPage: _currentPage,
                  total: _pages.length,
                  color: _gold),
              const SizedBox(height: 10),
              // One-tap "build me a random hero" — high-replayability shortcut.
              Semantics(
                button: true,
                label: widget.band == AgeBand.adolescent
                    ? 'Randomize — build a cover for me'
                    : 'Surprise me — build a random superhero',
                child: TextButton.icon(
                  onPressed: _surpriseMe,
                  style: TextButton.styleFrom(
                    foregroundColor: _gold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: _gold.withAlpha(120), width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                  ),
                  icon: const Text('🎲', style: TextStyle(fontSize: 18)),
                  label: Text(
                    widget.band == AgeBand.adolescent
                        ? 'Randomize'
                        : 'Surprise me!',
                    style: _noirAwareText(
                      widget.band == AgeBand.adolescent,
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
                  children: _pages,
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
          style: _noirAwareText(
            widget.band == AgeBand.adolescent,
            color: _gold,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: _noirAwareText(
            widget.band == AgeBand.adolescent,
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
    final isExplorer =
        widget.band == AgeBand.explorer ||
        widget.band == AgeBand.adventurer ||
        widget.band == AgeBand.creator ||
        widget.band == AgeBand.adolescent;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        children: [
          _pageHeader(
            '🎨',
            widget.band == AgeBand.adolescent
                ? 'Choose your colors'
                : isExplorer
                ? 'Choose your hero color'
                : 'Pick your hero color!',
            widget.band == AgeBand.adolescent
                ? 'What you wear when you need to blend in'
                : isExplorer
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
                      style: _noirAwareText(
                        widget.band == AgeBand.adolescent,
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
    final isExplorer =
        widget.band == AgeBand.explorer ||
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
          // Noir reskin: the rainbow cape reads too young for the antihero
          // band; hide it for Adolescent (a dark cape/cloak still fits).
          ..._capes
              .where(
                (cape) =>
                    !(widget.band == AgeBand.adolescent &&
                        cape.id == 'rainbow'),
              )
              .map((cape) {
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
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
                          Text(
                            cape.emoji,
                            style: const TextStyle(fontSize: 36),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              cape.label,
                              style: _noirAwareText(
                                widget.band == AgeBand.adolescent,
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
    final isExplorer =
        widget.band == AgeBand.explorer ||
        widget.band == AgeBand.adventurer ||
        widget.band == AgeBand.creator ||
        widget.band == AgeBand.adolescent;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        children: [
          _pageHeader(
            '✨',
            widget.band == AgeBand.adolescent
                ? 'Choose your mark'
                : isExplorer
                ? 'Choose your emblem'
                : 'Pick your symbol!',
            widget.band == AgeBand.adolescent
                ? 'One small thing you keep on you'
                : isExplorer
                ? 'Your hero\'s signature mark'
                : 'Tap your hero emblem',
          ),
          const SizedBox(height: 22),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
            children: _emblems
                .where(
                  (e) =>
                      !(widget.band == AgeBand.adolescent &&
                          (e.id == 'heart' ||
                              e.id == 'paw' ||
                              e.id == 'rainbow')),
                )
                .map((e) {
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
                        style: _noirAwareText(
                          widget.band == AgeBand.adolescent,
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

  // ── Page 3 (Adolescent only): identity / double life ───────────────────────
  //
  // Replaces the cape page for the noir band. Four optional prompts that let a
  // teen define the texture of their double life. Each writes to a nullable
  // WizardData field (heroSecret / heroTell / heroLine / heroSeenBy); all four
  // may stay blank — Continue is always enabled and the backend falls back
  // gracefully. The fourth ("who sees the real you") is the authenticity
  // counterweight to the three concealment prompts: it gives the story a person
  // to move toward, so a secret like "That I'm not okay" bends toward being
  // seen, never deeper hiding (MT-266).

  // Preset chips per prompt. Tone is grounded prestige-YA, not cutesy.
  static const _secretChips = <String>[
    "That I'm not okay",
    'What I can really do',
    "Who I'm protecting",
    "A mistake I haven't owned",
    "That I've changed",
  ];
  static const _tellChips = <String>[
    'I go quiet',
    'I overexplain',
    'I disappear',
    "I can't meet their eyes",
    'I get too calm',
  ];
  static const _lineChips = <String>[
    'Never sell out a friend',
    'No hitting first',
    "Don't lie to family",
    'Never use it on someone weaker',
    "No deal I can't undo",
  ];
  static const _seenByChips = <String>[
    'One friend who knows everything',
    "A sibling who'd never tell",
    "Someone I haven't told yet",
    "The person I'm scared to lose",
    'No one — not yet',
  ];

  Widget _buildIdentityPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pageHeader(
            '🎭',
            'Your double life',
            'Four things that make this real. All optional.',
          ),
          const SizedBox(height: 24),
          _identitySection(
            header: 'What are you hiding?',
            chips: _secretChips,
            controller: _secretController,
            current: widget.wizardData.heroSecret,
            hint: 'Or write your own…',
            onSelected: (value) => widget.wizardData.heroSecret = value,
          ),
          const SizedBox(height: 28),
          _identitySection(
            header: 'What gives you away?',
            chips: _tellChips,
            controller: _tellController,
            current: widget.wizardData.heroTell,
            hint: 'Or write your own…',
            onSelected: (value) => widget.wizardData.heroTell = value,
          ),
          const SizedBox(height: 28),
          _identitySection(
            header: "The line you won't cross?",
            chips: _lineChips,
            controller: _lineController,
            current: widget.wizardData.heroLine,
            hint: 'Or write your own…',
            onSelected: (value) => widget.wizardData.heroLine = value,
          ),
          const SizedBox(height: 28),
          _identitySection(
            header: 'Who gets to see the real you?',
            chips: _seenByChips,
            controller: _seenByController,
            current: widget.wizardData.heroSeenBy,
            hint: 'Or write your own…',
            onSelected: (value) => widget.wizardData.heroSeenBy = value,
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _advance,
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Continue',
                style: _noirAwareText(
                  true,
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One identity prompt: a noir header line, a wrap of single-select chips,
  /// and a "write your own" TextField that overrides the chip when typed in.
  /// Selection is reflected by comparing [current] to each chip label; typing
  /// in the field clears the chip highlight (the field value becomes the
  /// answer). All state lives on [wizardData] + the per-prompt controller.
  Widget _identitySection({
    required String header,
    required List<String> chips,
    required TextEditingController controller,
    required String? current,
    required String hint,
    required ValueChanged<String?> onSelected,
  }) {
    // The chip is "active" only when the saved answer matches a preset AND the
    // custom field is empty (typing always takes precedence).
    final customActive = controller.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header,
          style: _noirAwareText(
            true,
            color: _gold,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: chips.map((label) {
            final selected = !customActive && current == label;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  // Selecting a chip overrides any custom text.
                  controller.clear();
                  onSelected(label);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(selected ? 38 : 20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? _gold : Colors.white24,
                    width: selected ? 3 : 2,
                  ),
                ),
                child: Text(
                  label,
                  style: _noirAwareText(
                    true,
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          maxLines: 1,
          textInputAction: TextInputAction.done,
          style: _noirAwareText(true, color: Colors.white, fontSize: 15),
          cursorColor: _gold,
          onChanged: (value) {
            // Typing overrides any chip: the trimmed field becomes the answer,
            // or null when cleared.
            setState(() {
              final trimmed = value.trim();
              onSelected(trimmed.isEmpty ? null : trimmed);
            });
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _noirAwareText(
              true,
              color: Colors.white.withAlpha(120),
              fontSize: 15,
            ),
            filled: true,
            fillColor: Colors.white.withAlpha(14),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: customActive ? _gold : Colors.white24,
                width: customActive ? 3 : 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _gold, width: 3),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int currentPage;
  final int total;
  final Color color;

  const _ProgressDots({
    required this.currentPage,
    required this.total,
    required this.color,
  });

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
                color: filled ? color : Colors.white.withAlpha(80),
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

/// Band-aware text style for the costume builder. The Adolescent (15-17) noir
/// "cover" flow uses a crisper grotesque (Source Sans 3) so it reads less
/// childish; every younger band keeps the original rounded Fredoka exactly as
/// before. Pass `noir: true` only for [AgeBand.adolescent].
TextStyle _noirAwareText(
  bool noir, {
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
  List<Shadow>? shadows,
}) {
  final base = noir
      ? GoogleFonts.sourceSans3(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
        )
      : GoogleFonts.fredoka(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
        );
  return shadows == null ? base : base.copyWith(shadows: shadows);
}

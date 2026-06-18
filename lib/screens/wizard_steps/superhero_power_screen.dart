// Superhero Mode (Sprout 3-5, Explorer 6-8, Adventurer 9-12) — power picker.
//
// 2x4 grid of 8 powers. Tap-to-select; tap "Pick this power!" to confirm.
// On confirm:
//   1. Sets [WizardData.heroPower] + the costume fields (already set by the
//      costume screens upstream).
//   2. Builds a display hero name ("Super Hugs Mia") and stores it on
//      [WizardData.heroSuperpower].
//   3. Saves a [HeroProfileLocal] via the Riverpod controller.
//   4. Sets [WizardData.selectedScenario] = 'superhero' and
//      [WizardData.customElements] = 'being a superhero'.
//   5. Pops back to the wizard root with `true`.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models.dart';
import '../../models/local/hero_profile_local.dart';
import '../../providers/hero_profile_provider.dart';
import '../../superhero_name_generator.dart';
import '../../theme/age_band_theme.dart';
import 'superhero_entry_screen.dart';
import 'superhero_reveal_screen.dart';

class SuperheroPowerScreen extends ConsumerStatefulWidget {
  final WizardData wizardData;

  /// Visual band — controls which power options are shown, how they're
  /// labeled, and the screen palette. Defaults to sprout for back-compat.
  final AgeBand band;

  /// When true the kid arrived via "🎲 Surprise me!" — pre-select a random
  /// power and show a playful surprise banner + reroll affordance.
  final bool surprise;

  const SuperheroPowerScreen({
    super.key,
    required this.wizardData,
    this.band = AgeBand.sprout,
    this.surprise = false,
  });

  @override
  ConsumerState<SuperheroPowerScreen> createState() =>
      _SuperheroPowerScreenState();
}

class _SuperheroPowerScreenState extends ConsumerState<SuperheroPowerScreen> {
  // Noir reskin: Adolescent (teal) and Creator (purple) use the band accent;
  // the gold-themed younger bands (Explorer/Adventurer) keep gold. (MT-273)
  Color get _gold =>
      (widget.band == AgeBand.adolescent || widget.band == AgeBand.creator)
          ? themeForBand(widget.band).accent
          : const Color(0xFFFFD700);

  // Sprout power set — preserved exactly. Explorer reuses these 8 IDs but
  // overrides the display labels (see `_explorerNameOverrides`).
  static const List<_PowerOption> _sproutPowers = [
    _PowerOption(
      id: 'super_speed',
      emoji: '⚡',
      name: 'Super Speed',
      description: 'Zoom and zip!',
    ),
    _PowerOption(
      id: 'flying',
      emoji: '🪽',
      name: 'Flying',
      description: 'Up, up, up!',
    ),
    _PowerOption(
      id: 'super_strength',
      emoji: '💪',
      name: 'Super Strength',
      description: 'Lift big things!',
    ),
    _PowerOption(
      id: 'super_hearing',
      emoji: '👂',
      name: 'Super Hearing',
      description: 'Hear everything!',
    ),
    _PowerOption(
      id: 'super_smile',
      emoji: '😄',
      name: 'Super Smile',
      description: 'Beam joy back!',
    ),
    _PowerOption(
      id: 'super_hugs',
      emoji: '🤗',
      name: 'Super Hugs',
      description: 'Warm and kind!',
    ),
    _PowerOption(
      id: 'super_whisper',
      emoji: '🤫',
      name: 'Super Whisper',
      description: 'Gentle the loud!',
    ),
    _PowerOption(
      id: 'super_sharing',
      emoji: '🤝',
      name: 'Super Sharing',
      description: 'Share with all!',
    ),
  ];

  // Explorer adds two extra power IDs (locked-in spec, must match backend
  // EXPLORER_POWERS matrix). Shown only when band == AgeBand.explorer.
  static const List<_PowerOption> _explorerExtraPowers = [
    _PowerOption(
      id: 'feeling_sense',
      emoji: '💗',
      name: 'Feeling Sense',
      description: 'Read the room.',
    ),
    _PowerOption(
      id: 'invisibility',
      emoji: '👣',
      name: 'Soft Step',
      description: 'Move unseen.',
    ),
  ];

  // Explorer-tier display label overrides for the shared 8 power IDs.
  // Order/keys must stay aligned with the backend `EXPLORER_POWERS` map.
  static const Map<String, _BandCopy> _explorerNameOverrides = {
    'super_speed': _BandCopy('Lightning Speed', 'Run faster than thought.'),
    'flying': _BandCopy('Sky Glide', 'Ride the air currents.'),
    'super_strength': _BandCopy('Strong Lift', 'Move what others can\'t.'),
    'super_hearing': _BandCopy('Keen Ears', 'Hear what others miss.'),
    'super_smile': _BandCopy('Bright Smile', 'Brighten any room.'),
    'super_hugs': _BandCopy('Big Heart Hug', 'Comfort with kindness.'),
    'super_whisper': _BandCopy('Quiet Voice', 'Calm the chaos.'),
    'super_sharing': _BandCopy('Fair Share', 'Make sure everyone gets some.'),
  };

  // Adventurer adds two extra power IDs (must match backend ADVENTURER_POWERS).
  static const List<_PowerOption> _adventurerExtraPowers = [
    _PowerOption(
      id: 'strategist',
      emoji: '🧠',
      name: 'Master Strategist',
      description: 'Out-think any scheme.',
    ),
    _PowerOption(
      id: 'gadgeteer',
      emoji: '🛠️',
      name: 'Gadgeteer',
      description: 'Rig the perfect gadget.',
    ),
  ];

  // Adventurer-tier display label overrides for the shared 8 power IDs.
  // Names must match the backend `ADVENTURER_POWERS` map so the picked power
  // reads identically in the generated story.
  static const Map<String, _BandCopy> _adventurerNameOverrides = {
    'super_speed': _BandCopy('Velocity', 'Move before they can blink.'),
    'flying': _BandCopy('Skyborne', 'Take the high ground.'),
    'super_strength': _BandCopy(
      'Titan Strength',
      'Shift what no one else can.',
    ),
    'super_hearing': _BandCopy('Echo Sense', 'Catch the faintest clue.'),
    'super_smile': _BandCopy(
      'Disarming Charm',
      'Win people over.',
      emoji: '😎',
    ),
    'super_hugs': _BandCopy(
      'Steadfast Heart',
      'Stand by anyone.',
      emoji: '🛡️',
    ),
    'super_whisper': _BandCopy('Calm Voice', 'Steady the storm.'),
    'super_sharing': _BandCopy('Fair Hand', 'Make it fair for everyone.'),
  };

  // Creator adds two extra power IDs (must match backend CREATOR_POWERS).
  static const List<_PowerOption> _creatorExtraPowers = [
    _PowerOption(
      id: 'strategist',
      emoji: '🧠',
      name: 'Mastermind',
      description: 'Out-plan the whole scheme.',
    ),
    _PowerOption(
      id: 'gadgeteer',
      emoji: '🛠️',
      name: 'Technomancer',
      description: 'Engineer the perfect solve.',
    ),
  ];

  // Creator-tier (13-14) display overrides for the shared 8 power IDs. Names
  // must match the backend `CREATOR_POWERS` map so the picked power reads
  // identically in the generated Issue. Cutesy emoji are overridden so the
  // grid doesn't read young for this band.
  static const Map<String, _BandCopy> _creatorNameOverrides = {
    'super_speed': _BandCopy('Overclock', 'Move faster than the moment.'),
    'flying': _BandCopy('Skyline', 'Own the high vantage.'),
    'super_strength': _BandCopy('Kinetic', 'Move the immovable.'),
    'super_hearing': _BandCopy(
      'Signal Sense',
      'Catch the whisper under the noise.',
      emoji: '📡',
    ),
    'super_smile': _BandCopy(
      'Magnetism',
      'Rally people to pull together.',
      emoji: '🧲',
    ),
    'super_hugs': _BandCopy(
      'Anchor',
      'Stand with them when it counts.',
      emoji: '⚓',
    ),
    'super_whisper': _BandCopy(
      'Cool Head',
      'Speak calm into the chaos.',
      emoji: '😌',
    ),
    'super_sharing': _BandCopy(
      'Equalizer',
      'Make it fair for everyone.',
      emoji: '⚖️',
    ),
  };

  // Adolescent-tier (15-17) "Edge" display overrides for the shared 8 power
  // IDs. Names MUST match the backend `ADOLESCENT_POWERS` map so the picked
  // Edge reads identically in the generated chapter. Every Edge has a cost.
  static const Map<String, _BandCopy> _adolescentNameOverrides = {
    'super_speed': _BandCopy(
      'Borrowed Time',
      'Buy back a few seconds — at a cost.',
    ),
    'flying': _BandCopy(
      'Ghost',
      'Move unseen and unheard — the better you hide, the more alone you are.',
    ),
    'super_strength': _BandCopy('Nerve', 'Hold the line when others fold.'),
    'super_hearing': _BandCopy(
      'Read the Room',
      'Read what people hide. Can\'t switch it off.',
      emoji: '👁️',
    ),
    'super_smile': _BandCopy(
      'Pull',
      'Get people to actually listen.',
      emoji: '🧲',
    ),
    'super_hugs': _BandCopy(
      'Anchor',
      'Stand with them when it\'s hardest.',
      emoji: '⚓',
    ),
    'super_whisper': _BandCopy(
      'Cool Head',
      'Speak calm into the chaos.',
      emoji: '🧊',
    ),
    'super_sharing': _BandCopy(
      'The Fixer',
      'Even the odds for everyone.',
      emoji: '⚖️',
    ),
  };

  // Adolescent adds two Edge IDs (must match backend ADOLESCENT_POWERS).
  static const List<_PowerOption> _adolescentExtraPowers = [
    _PowerOption(
      id: 'strategist',
      emoji: '🎭',
      name: 'The Tell',
      description: 'Know when anyone is lying.',
    ),
    _PowerOption(
      id: 'gadgeteer',
      emoji: '🎲',
      name: 'Bend the Odds',
      description: 'Tilt the odds — luck has a price.',
    ),
  ];

  /// Returns the band-appropriate power list, with band renames applied.
  List<_PowerOption> get powers {
    final overrides = widget.band == AgeBand.explorer
        ? _explorerNameOverrides
        : widget.band == AgeBand.adventurer
        ? _adventurerNameOverrides
        : widget.band == AgeBand.creator
        ? _creatorNameOverrides
        : widget.band == AgeBand.adolescent
        ? _adolescentNameOverrides
        : null;
    final base = _sproutPowers.map((p) {
      if (overrides == null) return p;
      final override = overrides[p.id];
      if (override == null) return p;
      return _PowerOption(
        id: p.id,
        emoji: override.emoji ?? p.emoji,
        name: override.name,
        description: override.description,
      );
    }).toList();
    if (widget.band == AgeBand.explorer) {
      base.addAll(_explorerExtraPowers);
    } else if (widget.band == AgeBand.adventurer) {
      base.addAll(_adventurerExtraPowers);
    } else if (widget.band == AgeBand.creator) {
      base.addAll(_creatorExtraPowers);
    } else if (widget.band == AgeBand.adolescent) {
      base.addAll(_adolescentExtraPowers);
    }
    return base;
  }

  String? _selectedPowerId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.surprise) {
      // Roll a random power so the kid lands on a complete, ready-to-go hero.
      final all = powers;
      _selectedPowerId = all[Random().nextInt(all.length)].id;
    }
  }

  /// Re-roll the random power (used by the surprise banner's 🎲 button).
  void _rerollPower() {
    HapticFeedback.lightImpact();
    final all = powers;
    setState(() {
      _selectedPowerId = all[Random().nextInt(all.length)].id;
    });
  }

  /// Upper-cases the first letter of each whitespace-separated word, leaving
  /// the rest untouched (preserves intentional caps like "McFly"). Used so a
  /// kid-typed name ("jason", "mary jane") reads as a proper codename.
  static String _titleCaseName(String s) => s
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  Future<void> _confirm() async {
    if (_selectedPowerId == null || _saving) return;
    HapticFeedback.mediumImpact();

    final power = powers.firstWhere((p) => p.id == _selectedPowerId);
    final wd = widget.wizardData;
    // Sprout's auto formula name ("{power} {name}") is left unchanged.
    // Title-case the kid's typed name so "jason" doesn't render as
    // "Gadgeteer jason" — kids type lowercase and the formula must still read
    // like a proper hero codename.
    final heroFirstName = _titleCaseName(wd.characterName.trim());
    // Adolescent (15-17): the Edge name alone IS a clean noir alias ("Ghost",
    // "Borrowed Time") — don't append the kid's first name.
    final formulaName = widget.band == AgeBand.adolescent
        ? power.name
        : heroFirstName.isNotEmpty
        ? '${power.name} $heroFirstName'
        : power.name;

    // B2 + B3: Explorer (6-8) and Adventurer (9-12) get a funny-name + optional
    // catchphrase chooser. Sprout keeps the silent formula name. The chooser is
    // cancelable — a null result aborts the confirm so the kid can re-pick.
    var displayName = formulaName;
    final isOlder =
        widget.band == AgeBand.explorer ||
        widget.band == AgeBand.adventurer ||
        widget.band == AgeBand.creator ||
        widget.band == AgeBand.adolescent;
    if (isOlder) {
      final result = await _showNameAndCatchphraseChooser(
        formulaName: formulaName,
      );
      if (result == null) return; // dismissed — stay on the power screen.
      displayName = result.heroName;
      wd.heroCatchphrase = result.catchphrase;
    }

    // C4: Adventurer (9-12) + Creator (13-14) optional nemesis pick. Dismiss =
    // null = the server surprise-picks, so a null result does NOT abort confirm.
    if (widget.band == AgeBand.adventurer || widget.band == AgeBand.creator) {
      wd.heroNemesisId = await _showNemesisPicker(initial: wd.heroNemesisId);
      if (!mounted) return;
    }

    if (!mounted) return;
    setState(() => _saving = true);

    // 1-4: populate WizardData.
    wd.heroPower = power.id;
    wd.heroSuperpower = displayName;
    wd.selectedScenario = 'superhero';
    // Preserve a custom "Imagine It" idea the kid typed before tapping
    // "Be a superhero!" (e.g. "ride a magic wand"). The superhero tier routes
    // off `heroPower` (wizard_data_mapper MT-118), so `customElements` is just
    // free must-include text — unconditionally overwriting it here silently
    // dropped the kid's own idea from the story. Keep theirs when present and
    // fall back to the generic marker only when they typed nothing.
    final typedIdea = wd.customElements.trim();
    wd.customElements = typedIdea.isEmpty ? 'being a superhero' : typedIdea;

    final characterId = SuperheroEntryScreen.resolveCharacterId(wd);
    final profile = HeroProfileLocal()
      ..characterId = characterId
      ..costumeColor = wd.heroCostumeColor
      ..capeStyle = wd.heroCapeStyle
      ..emblem = wd.heroEmblem
      ..power = power.id
      ..heroName = displayName
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    try {
      await ref.read(heroProfileControllerProvider.notifier).save(profile);
    } catch (_) {
      // Persistence failure should not block the wizard — the in-memory
      // wizardData still has everything we need for THIS story. The next
      // run will simply not see "welcome back".
    }

    if (!mounted) return;

    // Superhero portrait reveal: turn the kid's existing avatar into a
    // superhero image. Best-effort — fails soft and never blocks the wizard.
    // Skipped for Adolescent: mature bands build heroes via the Creative Brief
    // (no avatar generation), and the comic "ISSUE #1" reveal would read young.
    // A noir reveal is future polish if the band ever gains avatar generation.
    if (isOlder &&
        widget.band != AgeBand.adolescent &&
        wd.generatedAvatar?.imageBase64.contains(',') == true) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SuperheroRevealScreen(
            wizardData: wd,
            band: widget.band,
            heroName: displayName,
          ),
        ),
      );
      if (!mounted) return;
    }

    // Pop back to the wizard root: pop both power + costume screens.
    Navigator.of(context).pop(true);
  }

  HeroNameRegister get _nameRegister => widget.band == AgeBand.adolescent
      ? HeroNameRegister.adolescent
      : (widget.band == AgeBand.adventurer || widget.band == AgeBand.creator)
      ? HeroNameRegister.adventurer
      : HeroNameRegister.explorer;

  /// B2 + B3: shows a bottom sheet letting Explorer/Adventurer kids pick a
  /// funny codename (generated options + the "{power} {name}" formula option +
  /// reroll + type-your-own) and an optional catchphrase. Returns null if the
  /// kid dismisses the sheet (so the caller can abort the confirm cleanly).
  Future<_HeroNameChoice?> _showNameAndCatchphraseChooser({
    required String formulaName,
  }) {
    return showModalBottomSheet<_HeroNameChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _NameCatchphraseSheet(
        formulaName: formulaName,
        register: _nameRegister,
        gradient: themeForBand(widget.band).backgroundGradient,
      ),
    );
  }

  /// C4: Adventurer-only "choose your nemesis" sheet. Returns the chosen villain
  /// id, or null for "Surprise me" / dismissed (server picks). [initial] keeps
  /// the prior pick highlighted if the kid revisits.
  Future<String?> _showNemesisPicker({String? initial}) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NemesisPickerSheet(
        initial: initial,
        nemeses: widget.band == AgeBand.creator
            ? _creatorNemeses
            : _adventurerNemeses,
        gradient: themeForBand(widget.band).backgroundGradient,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedPowerId != null;
    // Explorer + Adventurer get the older, less babyish copy.
    final isOlder =
        widget.band == AgeBand.explorer ||
        widget.band == AgeBand.adventurer ||
        widget.band == AgeBand.creator ||
        widget.band == AgeBand.adolescent;
    final gradient = themeForBand(widget.band).backgroundGradient;
    final isAdolescent = widget.band == AgeBand.adolescent;
    final appBarTitle = isAdolescent
        ? 'Choose your edge'
        : isOlder
        ? 'Choose your power'
        : 'Pick your power!';
    final heading = isAdolescent
        ? "What's your edge?"
        : isOlder
        ? 'What is your hero power?'
        : 'What is your superpower?';
    final ctaIdle = isAdolescent
        ? 'Lock in this edge'
        : isOlder
        ? 'Choose this power'
        : 'Pick this power!';
    final ctaEmpty = 'Tap a power above';
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
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Column(
            children: [
              _ProgressDots(currentPage: 2, total: 3, color: _gold),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      if (widget.surprise) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _gold.withAlpha(28),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _gold.withAlpha(120)),
                          ),
                          child: Row(
                            children: [
                              const Text('🎲', style: TextStyle(fontSize: 24)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.band == AgeBand.adolescent
                                      ? 'Here\'s a starting point. Tap an edge '
                                            'to change it, or reshuffle.'
                                      : 'Here\'s your surprise hero! Tap a power '
                                            'to change it, or roll again.',
                                  style: _noirAwareText(
                                    widget.band == AgeBand.adolescent,
                                    color: Colors.white.withAlpha(230),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Semantics(
                                button: true,
                                label: 'Roll a different power',
                                child: IconButton(
                                  onPressed: _rerollPower,
                                  icon: const Icon(Icons.casino_rounded),
                                  color: _gold,
                                  tooltip: 'Roll again',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Text('✨', style: const TextStyle(fontSize: 40)),
                      const SizedBox(height: 4),
                      Text(
                        heading,
                        textAlign: TextAlign.center,
                        style: _noirAwareText(
                          widget.band == AgeBand.adolescent,
                          color: _gold,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.95,
                        children: powers.map((p) {
                          final selected = _selectedPowerId == p.id;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedPowerId = p.id);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? _gold.withAlpha(40)
                                    : Colors.white.withAlpha(20),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected ? _gold : Colors.white24,
                                  width: selected ? 4 : 2,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: _gold.withAlpha(140),
                                          blurRadius: 18,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    p.emoji,
                                    style: const TextStyle(fontSize: 44),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p.name,
                                    textAlign: TextAlign.center,
                                    style: _noirAwareText(
                                      widget.band == AgeBand.adolescent,
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    p.description,
                                    textAlign: TextAlign.center,
                                    style: _noirAwareText(
                                      widget.band == AgeBand.adolescent,
                                      color: Colors.white.withAlpha(200),
                                      fontSize: 12,
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
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: _gold.withAlpha(80),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: hasSelection && !_saving ? _confirm : null,
                    child: _saving
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black,
                              ),
                            ),
                          )
                        : Text(
                            hasSelection ? ctaIdle : ctaEmpty,
                            style: _noirAwareText(
                              widget.band == AgeBand.adolescent,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

class _PowerOption {
  final String id;
  final String emoji;
  final String name;
  final String description;
  const _PowerOption({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
  });
}

/// Band-tier display copy for a shared power id (Explorer or Adventurer).
/// [emoji] optionally overrides the base (Sprout) icon when the shared emoji
/// reads too young for the older band (e.g. 😄/🤗 on a 9-12 power card).
class _BandCopy {
  final String name;
  final String description;
  final String? emoji;
  const _BandCopy(this.name, this.description, {this.emoji});
}

/// Result of the B2/B3 chooser: the chosen hero name + an optional catchphrase
/// (null/empty when the kid skips it).
class _HeroNameChoice {
  final String heroName;
  final String? catchphrase;
  const _HeroNameChoice({required this.heroName, this.catchphrase});
}

/// Bottom sheet for the funny-name picker (B2) + catchphrase picker (B3).
/// Matches the gold-on-gradient styling of the power screen.
class _NameCatchphraseSheet extends StatefulWidget {
  final String formulaName;
  final HeroNameRegister register;
  final Gradient gradient;

  const _NameCatchphraseSheet({
    required this.formulaName,
    required this.register,
    required this.gradient,
  });

  @override
  State<_NameCatchphraseSheet> createState() => _NameCatchphraseSheetState();
}

class _NameCatchphraseSheetState extends State<_NameCatchphraseSheet> {
  static const _gold = Color(0xFFFFD700);

  late List<String> _nameOptions; // generated funny names (excludes formula)
  String? _selectedName; // null until the kid taps a chip / types one
  final TextEditingController _customNameCtl = TextEditingController();

  late List<String> _catchphraseOptions;
  String? _selectedCatchphrase;
  final TextEditingController _customCatchphraseCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rerollNames();
    _catchphraseOptions = SuperheroNameGenerator.generateIdeas(
      count: 4,
    ).map((i) => i.catchPhrase).toSet().toList();
    // Default selection: the formula name (always present as an option).
    _selectedName = widget.formulaName;
  }

  @override
  void dispose() {
    _customNameCtl.dispose();
    _customCatchphraseCtl.dispose();
    super.dispose();
  }

  void _rerollNames() {
    HapticFeedback.lightImpact();
    setState(() {
      _nameOptions = HeroFunnyNameGenerator.pickNames(
        widget.register,
        count: 3,
      );
      // If the previously-selected name was a generated one that's now gone,
      // fall back to the formula name. Custom-typed names are preserved.
      final typed = _customNameCtl.text.trim();
      if (_selectedName != null &&
          _selectedName != widget.formulaName &&
          _selectedName != typed &&
          !_nameOptions.contains(_selectedName)) {
        _selectedName = widget.formulaName;
      }
    });
  }

  void _confirmChoice() {
    final typedName = _customNameCtl.text.trim();
    final heroName = typedName.isNotEmpty
        ? typedName
        : (_selectedName ?? widget.formulaName);

    final typedPhrase = _customCatchphraseCtl.text.trim();
    final catchphrase = typedPhrase.isNotEmpty
        ? typedPhrase
        : _selectedCatchphrase;

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(
      _HeroNameChoice(
        heroName: heroName,
        catchphrase: (catchphrase != null && catchphrase.trim().isNotEmpty)
            ? catchphrase.trim()
            : null,
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _gold.withAlpha(40) : Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _gold : Colors.white24,
            width: selected ? 3 : 1.5,
          ),
        ),
        child: Text(
          label,
          style: _noirAwareText(
            widget.register == HeroNameRegister.adolescent,
            color: Colors.white,
            fontSize: 15,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    // Selecting a generated/formula chip clears any typed name (and vice
    // versa, handled by the text field's onChanged).
    return Container(
      decoration: BoxDecoration(
        gradient: widget.gradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + viewInsets),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.register == HeroNameRegister.adolescent
                  ? 'Choose your alias'
                  : 'Pick your hero name',
              style: _noirAwareText(
                widget.register == HeroNameRegister.adolescent,
                color: _gold,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final name in _nameOptions)
                  _chip(
                    label: name,
                    selected:
                        _selectedName == name && _customNameCtl.text.isEmpty,
                    onTap: () {
                      _customNameCtl.clear();
                      setState(() => _selectedName = name);
                    },
                  ),
                _chip(
                  label: widget.formulaName,
                  selected:
                      _selectedName == widget.formulaName &&
                      _customNameCtl.text.isEmpty,
                  onTap: () {
                    _customNameCtl.clear();
                    setState(() => _selectedName = widget.formulaName);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _rerollNames,
                  icon: const Text('🎲', style: TextStyle(fontSize: 18)),
                  label: Text(
                    'Reroll names',
                    style: _noirAwareText(
                      widget.register == HeroNameRegister.adolescent,
                      color: _gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Semantics(
              label: 'Character name',
              textField: true,
              child: TextField(
                controller: _customNameCtl,
                style: _noirAwareText(
                  widget.register == HeroNameRegister.adolescent,
                  color: Colors.white,
                ),
                cursorColor: _gold,
                decoration: InputDecoration(
                  hintText: 'Or type my own name…',
                  hintStyle: _noirAwareText(
                    widget.register == HeroNameRegister.adolescent,
                    color: Colors.white.withAlpha(140),
                  ),
                  // Explicit dark-translucent fill so white text/hint stay
                  // readable even if a global inputDecorationTheme forces a
                  // light fill (matches the withAlpha(20) chips above).
                  filled: true,
                  fillColor: Colors.white.withAlpha(20),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _gold, width: 2),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              widget.register == HeroNameRegister.adolescent
                  ? 'A line that\'s yours (optional)'
                  : 'Add a catchphrase (optional)',
              style: _noirAwareText(
                widget.register == HeroNameRegister.adolescent,
                color: _gold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.register == HeroNameRegister.adolescent
                  ? 'Something they\'d actually say. Or leave it blank.'
                  : 'Your hero can shout this at the big moment.',
              style: _noirAwareText(
                widget.register == HeroNameRegister.adolescent,
                color: Colors.white.withAlpha(200),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final phrase in _catchphraseOptions)
                  _chip(
                    label: phrase,
                    selected:
                        _selectedCatchphrase == phrase &&
                        _customCatchphraseCtl.text.isEmpty,
                    onTap: () {
                      _customCatchphraseCtl.clear();
                      setState(
                        () => _selectedCatchphrase =
                            _selectedCatchphrase == phrase ? null : phrase,
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Your superhero catchphrase',
              textField: true,
              child: TextField(
                controller: _customCatchphraseCtl,
                style: _noirAwareText(
                  widget.register == HeroNameRegister.adolescent,
                  color: Colors.white,
                ),
                cursorColor: _gold,
                decoration: InputDecoration(
                  hintText: 'Or type my own catchphrase…',
                  hintStyle: _noirAwareText(
                    widget.register == HeroNameRegister.adolescent,
                    color: Colors.white.withAlpha(140),
                  ),
                  // Explicit dark-translucent fill so white text/hint stay
                  // readable even if a global inputDecorationTheme forces a
                  // light fill (matches the withAlpha(20) chips above).
                  filled: true,
                  fillColor: Colors.white.withAlpha(20),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _gold, width: 2),
                  ),
                ),
                onChanged: (_) => setState(() {
                  if (_customCatchphraseCtl.text.isNotEmpty) {
                    _selectedCatchphrase = null;
                  }
                }),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _confirmChoice,
                child: Text(
                  widget.register == HeroNameRegister.adolescent
                      ? 'Lock in alias'
                      : 'That\'s my hero!',
                  style: _noirAwareText(
                    widget.register == HeroNameRegister.adolescent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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

/// C4: Adventurer arch-villain roster — ids + names mirror backend
/// ADVENTURER_VILLAINS (backend/data/superhero_matrix.py). Kid-facing blurbs
/// summarize each villain's funny scheme so a 9-12 can pick a nemesis they'll
/// love; the backend carries the full motive/backstory that shapes the story.
class _Nemesis {
  final String id;
  final String name;
  final String blurb;
  final String emoji;
  const _Nemesis(this.id, this.name, this.blurb, this.emoji);
}

const List<_Nemesis> _adventurerNemeses = [
  _Nemesis(
    'gigawatt',
    'Gigawatt',
    "Buries the town in 'helpful' gadgets that take over every chore — whether you want it or not.",
    '⚡',
  ),
  _Nemesis(
    'lord_loading_screen',
    'Lord Loading Screen',
    'Makes every door, game, and lesson stall and buffer so nothing ever quite finishes.',
    '⏳',
  ),
  _Nemesis(
    'doctor_detention',
    'Doctor Detention',
    'Freezes every clock so the bell never rings and school never, ever ends.',
    '🔔',
  ),
  _Nemesis(
    'mister_meh',
    'Mister Meh',
    'Drains the fun out of birthdays, games, and even superpowers until everything feels gray.',
    '😑',
  ),
  _Nemesis(
    'booger_baron',
    'The Booger Baron',
    "Flings sticky green goo and nose-shaped drones to keep everyone at arm's length.",
    '🤧',
  ),
  _Nemesis(
    'llama_of_doom',
    'The Llama of Doom',
    'Stages giant dramatic scenes and demands that llamas finally rule the whole town.',
    '🦙',
  ),
  _Nemesis(
    'professor_picklejuice',
    'Professor Picklejuice',
    'Fires sour-pickle blasts and locks every snack in town inside a giant brine vault.',
    '🥒',
  ),
  _Nemesis(
    'count_copypaste',
    'Count Copy-Paste',
    "Spins out dozens of arguing copies of himself, each one sure it's the real Count.",
    '📋',
  ),
  _Nemesis(
    'the_overlooked',
    'The Overlooked',
    'Sabotages the big festival because no one ever once chose them to lead.',
    '👤',
  ),
  _Nemesis(
    'the_gatekeeper',
    'The Gatekeeper',
    'Walls off the old quarter to keep every outsider away after being hurt once.',
    '🔒',
  ),
];

/// Creator (13-14) "Hero Saga" arch-villain roster — ids + names mirror backend
/// CREATOR_VILLAINS (backend/data/superhero_matrix.py). Blurbs lead with each
/// villain's BELIEF, so a 13-14 picks a nemesis whose argument they can almost
/// agree with; the backend carries the full motive + resolution.
const List<_Nemesis> _creatorNemeses = [
  _Nemesis(
    'cipher_zero',
    'Cipher Zero',
    'Leaks every secret in the city, certain that total transparency is the only real justice.',
    '🛰️',
  ),
  _Nemesis(
    'the_optimizer',
    'the Optimizer',
    'Rewrites the city to erase every risk — and every freedom along with it.',
    '⚙️',
  ),
  _Nemesis(
    'the_understudy',
    'the Understudy',
    "Sabotages the city's stars after a lifetime of being the overlooked second-best.",
    '🎭',
  ),
  _Nemesis(
    'the_magnate',
    'the Magnate',
    "Buys up the old district and erases the people who built it, sure he's improving it.",
    '💰',
  ),
  _Nemesis(
    'riptide',
    'Riptide',
    'Floods the harbor to take the coast back for the wildlife the city paved over.',
    '🌊',
  ),
  _Nemesis(
    'redact',
    'Redact',
    'Erases inconvenient history so the city can never be shamed by its past.',
    '▪️',
  ),
  _Nemesis(
    'gridlock',
    'Gridlock',
    'Freezes the whole city to force everyone to face a danger they keep ignoring.',
    '🚦',
  ),
  _Nemesis(
    'the_mirror',
    'the Mirror',
    'Exposes powerful hypocrites — but ruins innocent bystanders in the crossfire.',
    '🪞',
  ),
  _Nemesis(
    'nightjar',
    'Nightjar',
    'A vigilante who hunts wrongdoers, trampling the law and the innocent in the chase.',
    '🦅',
  ),
  _Nemesis(
    'the_benefactor',
    'the Benefactor',
    "Secretly controls the city's heroes like puppets, 'for their own good.'",
    '🎩',
  ),
];

/// C4 nemesis picker bottom sheet. Pops the chosen villain id, or null for
/// "Surprise me" / dismissed.
class _NemesisPickerSheet extends StatefulWidget {
  final String? initial;
  final List<_Nemesis> nemeses;
  final Gradient gradient;
  const _NemesisPickerSheet({
    required this.initial,
    required this.nemeses,
    required this.gradient,
  });

  @override
  State<_NemesisPickerSheet> createState() => _NemesisPickerSheetState();
}

class _NemesisPickerSheetState extends State<_NemesisPickerSheet> {
  static const _gold = Color(0xFFFFD700);
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Text(
                'Choose your nemesis',
                style: GoogleFonts.fredoka(
                  color: _gold,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Every great hero needs a worthy rival. (Optional!)',
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  color: Colors.white.withAlpha(200),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _tile(
                      selected: _selected == null,
                      onTap: () => setState(() => _selected = null),
                      emoji: '🎲',
                      title: 'Surprise me',
                      blurb: 'Let the story pick a villain for you.',
                    ),
                    for (final n in widget.nemeses)
                      _tile(
                        selected: _selected == n.id,
                        onTap: () => setState(() => _selected = n.id),
                        emoji: n.emoji,
                        title: n.name,
                        blurb: n.blurb,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: Text(
                    _selected == null ? 'Surprise me!' : 'Lock it in!',
                    style: GoogleFonts.fredoka(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile({
    required bool selected,
    required VoidCallback onTap,
    required String emoji,
    required String title,
    required String blurb,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: selected,
        label: title,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? _gold.withAlpha(40)
                  : Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? _gold : Colors.white24,
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        blurb,
                        style: GoogleFonts.fredoka(
                          color: Colors.white.withAlpha(200),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: _gold, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Adolescent (15-17) noir reskin uses a clean sans (Source Sans 3) so the
/// "Edge"/alias screens don't read young; every other band keeps the rounded
/// Fredoka. [noir] is the band/register gate so younger bands are untouched.
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

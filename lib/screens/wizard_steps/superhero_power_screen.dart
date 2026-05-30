// Superhero Mode (ages 3-5) — power picker.
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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models.dart';
import '../../models/local/hero_profile_local.dart';
import '../../providers/hero_profile_provider.dart';
import '../../theme/age_band_theme.dart';
import 'superhero_entry_screen.dart';

class SuperheroPowerScreen extends ConsumerStatefulWidget {
  final WizardData wizardData;

  /// Visual band — controls which power options are shown, how they're
  /// labeled, and the screen palette. Defaults to sprout for back-compat.
  final AgeBand band;

  const SuperheroPowerScreen({
    super.key,
    required this.wizardData,
    this.band = AgeBand.sprout,
  });

  @override
  ConsumerState<SuperheroPowerScreen> createState() =>
      _SuperheroPowerScreenState();
}

class _SuperheroPowerScreenState extends ConsumerState<SuperheroPowerScreen> {
  static const _gold = Color(0xFFFFD700);

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
    'super_strength': _BandCopy('Titan Strength', 'Shift what no one else can.'),
    'super_hearing': _BandCopy('Echo Sense', 'Catch the faintest clue.'),
    'super_smile': _BandCopy('Disarming Charm', 'Win people over.'),
    'super_hugs': _BandCopy('Steadfast Heart', 'Stand by anyone.'),
    'super_whisper': _BandCopy('Calm Voice', 'Steady the storm.'),
    'super_sharing': _BandCopy('Fair Hand', 'Make it fair for everyone.'),
  };

  /// Returns the band-appropriate power list, with band renames applied.
  List<_PowerOption> get powers {
    final overrides = widget.band == AgeBand.explorer
        ? _explorerNameOverrides
        : widget.band == AgeBand.adventurer
            ? _adventurerNameOverrides
            : null;
    final base = _sproutPowers.map((p) {
      if (overrides == null) return p;
      final override = overrides[p.id];
      if (override == null) return p;
      return _PowerOption(
        id: p.id,
        emoji: p.emoji,
        name: override.name,
        description: override.description,
      );
    }).toList();
    if (widget.band == AgeBand.explorer) {
      base.addAll(_explorerExtraPowers);
    } else if (widget.band == AgeBand.adventurer) {
      base.addAll(_adventurerExtraPowers);
    }
    return base;
  }

  String? _selectedPowerId;
  bool _saving = false;

  Future<void> _confirm() async {
    if (_selectedPowerId == null || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final power = powers.firstWhere((p) => p.id == _selectedPowerId);
    final wd = widget.wizardData;
    final displayName = wd.characterName.trim().isNotEmpty
        ? '${power.name} ${wd.characterName.trim()}'
        : power.name;

    // 1-4: populate WizardData.
    wd.heroPower = power.id;
    wd.heroSuperpower = displayName;
    wd.selectedScenario = 'superhero';
    wd.customElements = 'being a superhero';

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
      await ref
          .read(heroProfileControllerProvider.notifier)
          .save(profile);
    } catch (_) {
      // Persistence failure should not block the wizard — the in-memory
      // wizardData still has everything we need for THIS story. The next
      // run will simply not see "welcome back".
    }

    if (!mounted) return;
    // Pop back to the wizard root: pop both power + costume screens.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedPowerId != null;
    // Explorer + Adventurer get the older, less babyish copy.
    final isOlder = widget.band == AgeBand.explorer ||
        widget.band == AgeBand.adventurer;
    final gradient = themeForBand(widget.band).backgroundGradient;
    final appBarTitle = isOlder ? 'Choose your power' : 'Pick your power!';
    final heading = isOlder
        ? 'What is your hero power?'
        : 'What is your superpower?';
    final ctaIdle = isOlder ? 'Choose this power' : 'Pick this power!';
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
          style: GoogleFonts.fredoka(
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
              const _ProgressDots(currentPage: 2, total: 3),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      Text(
                        '✨',
                        style: const TextStyle(fontSize: 40),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        heading,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.fredoka(
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
                                  horizontal: 8, vertical: 12),
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
                                  Text(p.emoji,
                                      style: const TextStyle(fontSize: 44)),
                                  const SizedBox(height: 4),
                                  Text(
                                    p.name,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.fredoka(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    p.description,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.fredoka(
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : Text(
                            hasSelection ? ctaIdle : ctaEmpty,
                            style: GoogleFonts.fredoka(
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
class _BandCopy {
  final String name;
  final String description;
  const _BandCopy(this.name, this.description);
}

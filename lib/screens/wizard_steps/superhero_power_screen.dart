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
import 'superhero_entry_screen.dart';

class SuperheroPowerScreen extends ConsumerStatefulWidget {
  final WizardData wizardData;

  const SuperheroPowerScreen({
    super.key,
    required this.wizardData,
  });

  @override
  ConsumerState<SuperheroPowerScreen> createState() =>
      _SuperheroPowerScreenState();
}

class _SuperheroPowerScreenState extends ConsumerState<SuperheroPowerScreen> {
  static const _gold = Color(0xFFFFD700);

  static const List<_PowerOption> powers = [
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Pick your power!',
          style: GoogleFonts.fredoka(
            color: _gold,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2D1B42),
              Color(0xFF5F2776),
              Color(0xFF8B3A6B),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
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
                        'What is your superpower?',
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
                            hasSelection
                                ? 'Pick this power!'
                                : 'Tap a power above',
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

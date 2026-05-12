// Superhero Mode (ages 3-5) — "welcome back" screen.
//
// Shown when the child already has a saved [HeroProfileLocal] for this
// character. Two paths:
//   1. "Yes! Start adventure" — re-apply the saved costume/power to
//      WizardData, set scenario, pop with `true`.
//   2. "Edit my hero" — push the costume picker, which then chains to the
//      power picker and finally pops back here. We propagate that pop.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models.dart';
import '../../models/local/hero_profile_local.dart';
import 'superhero_costume_screen.dart';

class SuperheroWelcomeBackScreen extends StatelessWidget {
  static const _gold = Color(0xFFFFD700);

  final WizardData wizardData;
  final HeroProfileLocal profile;

  const SuperheroWelcomeBackScreen({
    super.key,
    required this.wizardData,
    required this.profile,
  });

  static const _emblemEmoji = <String, String>{
    'star': '⭐',
    'lightning': '⚡',
    'heart': '❤️',
    'moon': '🌙',
    'paw': '🐾',
    'rainbow': '🌈',
  };

  static const _colorHex = <String, Color>{
    'red': Color(0xFFE53935),
    'blue': Color(0xFF1E88E5),
    'green': Color(0xFF43A047),
    'yellow': Color(0xFFFDD835),
    'purple': Color(0xFF8E24AA),
    'pink': Color(0xFFEC407A),
  };

  void _startAdventure(BuildContext context) {
    HapticFeedback.mediumImpact();
    wizardData.heroCostumeColor = profile.costumeColor;
    wizardData.heroCapeStyle = profile.capeStyle;
    wizardData.heroEmblem = profile.emblem;
    wizardData.heroPower = profile.power;
    wizardData.heroSuperpower = profile.heroName;
    wizardData.selectedScenario = 'superhero';
    wizardData.customElements = 'being a superhero';
    Navigator.of(context).pop(true);
  }

  Future<void> _editHero(BuildContext context) async {
    HapticFeedback.lightImpact();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SuperheroCostumeScreen(wizardData: wizardData),
      ),
    );
    if (saved == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorHex[profile.costumeColor] ?? const Color(0xFF8E24AA);
    final emblem = _emblemEmoji[profile.emblem] ?? '⭐';
    final hasCape = profile.capeStyle != null && profile.capeStyle != 'none';
    final isRainbowCape = profile.capeStyle == 'rainbow';
    final heroName = profile.heroName?.trim().isNotEmpty == true
        ? profile.heroName!.trim()
        : 'Super Hero';

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hero badge: a colored circle with optional cape backing
                // and the emblem on top.
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (hasCape)
                        Positioned(
                          top: 20,
                          child: Container(
                            width: 180,
                            height: 200,
                            decoration: BoxDecoration(
                              gradient: isRainbowCape
                                  ? const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFE53935),
                                        Color(0xFFFFB300),
                                        Color(0xFF43A047),
                                        Color(0xFF1E88E5),
                                        Color(0xFF8E24AA),
                                      ],
                                    )
                                  : null,
                              color: isRainbowCape ? null : color,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(40),
                                topRight: Radius.circular(40),
                                bottomLeft: Radius.circular(80),
                                bottomRight: Radius.circular(80),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(120),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(color: _gold, width: 5),
                          boxShadow: [
                            BoxShadow(
                              color: color.withAlpha(180),
                              blurRadius: 32,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            emblem,
                            style: const TextStyle(fontSize: 80),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome back,',
                  style: GoogleFonts.fredoka(
                    color: Colors.white.withAlpha(220),
                    fontSize: 20,
                  ),
                ),
                Text(
                  '$heroName!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(
                    color: _gold,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 6,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ready for another adventure?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(
                    color: Colors.white.withAlpha(220),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => _startAdventure(context),
                    child: Text(
                      'Yes! Start adventure',
                      style: GoogleFonts.fredoka(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _gold,
                      side: const BorderSide(color: _gold, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => _editHero(context),
                    child: Text(
                      'Edit my hero',
                      style: GoogleFonts.fredoka(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

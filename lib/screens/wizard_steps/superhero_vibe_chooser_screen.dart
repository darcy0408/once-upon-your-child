// Superhero "vibe chooser" (Adolescent 15-17 only) — MT-303.
//
// The teen superhero flow has two flavours that, until now, were reachable only
// by two different entry points (the "Superhero Story" scenario tile dead-ended;
// the "Live a double life" button launched the antihero saga). This screen is
// the single front door: it lets a teen pick the vibe up front, records it on
// [WizardData.heroMode], and then launches the existing costume → power → reveal
// flow ([SuperheroEntryScreen]).
//
//   🦸 "Be a Hero"        → heroMode = 'classic'  → aspirational powers, the
//                            double-life Identity page + distress mechanic are
//                            skipped downstream (see SuperheroCostumeScreen).
//   🎭 "Live a Double Life" → heroMode = 'antihero' → the existing noir saga,
//                            unchanged.
//
// Creator (13-14) deliberately does NOT use this chooser: that band has no
// double-life/Identity/distress path to skip (its costume flow is Color → Cape →
// Emblem and its "Hero Saga" is already a classic hero saga), so a two-card
// "real cost" choice would be a false promise. Adolescent is the only band with
// a genuine antihero path, so it's the only band that gets a vibe choice.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models.dart';
import '../../theme/age_band_theme.dart';
import 'superhero_entry_screen.dart';

class SuperheroVibeChooserScreen extends StatelessWidget {
  final WizardData wizardData;

  /// Visual band (drives palette). Defaults to adolescent — this chooser is
  /// only ever shown for the Adolescent band today.
  final AgeBand band;

  const SuperheroVibeChooserScreen({
    super.key,
    required this.wizardData,
    this.band = AgeBand.adolescent,
  });

  Color get _accent => themeForBand(band).accent;

  /// Sets the chosen vibe and pushes the existing superhero flow. Propagates the
  /// flow's `true` pop result back to the wizard so it can advance.
  Future<void> _choose(BuildContext context, String mode) async {
    HapticFeedback.mediumImpact();
    wizardData.heroMode = mode;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SuperheroEntryScreen(wizardData: wizardData),
      ),
    );
    if (!context.mounted) return;
    // If the downstream flow completed (or was cancelled), bubble its result up
    // so the caller's `.then((result) => ...)` sees the same value it would
    // have seen launching SuperheroEntryScreen directly.
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final gradient = themeForBand(band).backgroundGradient;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Pick your vibe',
          style: GoogleFonts.sourceSans3(
            color: _accent,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Two ways to do this',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sourceSans3(
                    color: _accent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Same powers underneath — different story.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sourceSans3(
                    color: Colors.white.withAlpha(200),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 28),
                _VibeCard(
                  emoji: '🦸',
                  title: 'Be a Hero',
                  subtitle: 'Pick your powers. Fly, run, lift the impossible.',
                  accent: _accent,
                  onTap: () => _choose(context, 'classic'),
                ),
                const SizedBox(height: 18),
                _VibeCard(
                  emoji: '🎭',
                  title: 'Live a Double Life',
                  subtitle: 'An antihero saga — real stakes, a real cost.',
                  accent: _accent,
                  onTap: () => _choose(context, 'antihero'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VibeCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _VibeCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withAlpha(160), width: 2),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.sourceSans3(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.sourceSans3(
                        color: Colors.white.withAlpha(200),
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: accent.withAlpha(200)),
            ],
          ),
        ),
      ),
    );
  }
}

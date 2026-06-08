// Superhero Mode (Sprout 3-5, Explorer 6-8, Adventurer 9-12) — entry dispatcher.
//
// Reads the [heroProfileProvider] for the current character and renders
// either the welcome-back screen (returning user) or the costume picker
// (first run) directly inside this widget. We deliberately do NOT use
// pushReplacement — replacing the route would null out the Future
// returned to the caller (Navigator pops only propagate to the route
// that's on the stack at pop time).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models.dart';
import '../../providers/hero_profile_provider.dart';
import '../../providers/hero_saga_provider.dart';
import '../../theme/age_band_theme.dart';
import 'superhero_costume_screen.dart';
import 'superhero_welcome_back_screen.dart';

class SuperheroEntryScreen extends ConsumerWidget {
  final WizardData wizardData;

  const SuperheroEntryScreen({
    super.key,
    required this.wizardData,
  });

  /// Resolves a STABLE per-child key for the HeroProfile SharedPreferences
  /// record. Uses the child's name first (which is set in wizard step 1 and
  /// preserved across "New Story" pops), not `wd.characterId`, because the
  /// latter is only assigned by [magic_review_step.dart] AFTER the first story
  /// generates — so the same kid would have a null id on run 1's save and a
  /// real UUID on run 2's load, missing the welcome-back screen entirely.
  static String resolveCharacterId(WizardData wd) {
    final name =
        wd.characterName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    if (name.isNotEmpty) return 'name_$name';
    final raw = wd.characterId?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return 'temp_hero';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characterId = resolveCharacterId(wizardData);
    final async = ref.watch(heroProfileProvider(characterId));
    // Derive band from the character's age. The Superhero flow supports
    // Sprout (3-5), Explorer (6-8), Adventurer (9-12), and Creator (13-14 —
    // Hero Saga) — each with its own palette, copy register, power roster, and
    // backend prompt tier (T9_SUPERHERO_CREATOR). 15+ has no tier yet.
    final band = ageBandFromAge(wizardData.characterAge);

    return async.when(
      loading: () => _loadingScaffold(band),
      error: (_, __) =>
          SuperheroCostumeScreen(wizardData: wizardData, band: band),
      data: (profile) {
        if (profile != null && profile.power != null) {
          // MT-235 Phase 2 (the returnable saga): for a returning Creator hero,
          // surface the persisted continuity as a "Previously…" recap on the
          // welcome-back screen. Younger bands have no saga and skip the watch.
          // A saga read failure / first Issue simply yields a null saga → no
          // recap, never a blocked welcome-back.
          final saga = band == AgeBand.creator
              ? ref.watch(heroSagaProvider(characterId)).valueOrNull
              : null;
          return SuperheroWelcomeBackScreen(
            wizardData: wizardData,
            profile: profile,
            band: band,
            saga: saga,
          );
        }
        return SuperheroCostumeScreen(wizardData: wizardData, band: band);
      },
    );
  }

  Widget _loadingScaffold(AgeBand band) {
    // MT-121: don't hardcode Sprout's plum here — read the loading background
    // from the current band so Explorer doesn't briefly flash Sprout dark navy.
    final bandTheme = themeForBand(band);
    return Scaffold(
      backgroundColor: bandTheme.gradientStart,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
            ),
            const SizedBox(height: 16),
            Text(
              'Getting your hero ready…',
              style: GoogleFonts.fredoka(
                color: Colors.white.withAlpha(220),
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

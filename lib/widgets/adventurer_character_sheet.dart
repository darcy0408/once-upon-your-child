import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/wizard_data.dart';
import '../theme/age_band_theme.dart';
import '../data/scenario_data.dart';
import '../widgets/archetype_card.dart';

/// RPG-style character sheet shown in Magic Review for the Adventurer band (9–11).
/// Replaces the orb-centric layout with a stat-card layout: Name, Class, Special
/// Ability, Companions, and Scenario/Mission Hook.
class AdventurerCharacterSheet extends StatelessWidget {
  final WizardData wizardData;
  final AgeBandThemeData band;
  /// Hero avatar widget — caller provides so this widget stays decoupled.
  final Widget heroAvatar;
  /// Optional: tap the NAME row to jump back to the hero/name step.
  /// Audit F-04 — matches the affordance the story-type and wish rows already
  /// have. When null, the row remains non-tappable.
  final VoidCallback? onTapName;
  /// Optional: tap the PARTY row to jump back to the companions step.
  final VoidCallback? onTapParty;

  const AdventurerCharacterSheet({
    super.key,
    required this.wizardData,
    required this.band,
    required this.heroAvatar,
    this.onTapName,
    this.onTapParty,
  });

  @override
  Widget build(BuildContext context) {
    final archetype = wizardData.selectedArchetypeId != null
        ? CharacterArchetypes.all
            .where((a) => a.name == wizardData.selectedArchetypeId)
            .firstOrNull
        : null;

    final scenarioCard = wizardData.selectedScenario != null
        ? ScenarioData.getById(wizardData.selectedScenario!)
        : null;
    // Review-screen audit F-01: "Unknown Mission" with no objective deflates
    // the child and reads like a bug to a parent. When no scenario resolves
    // (rare — usually a free-text setting reaches here without a derived
    // title), fall back to an inviting line and ensure a hook is shown.
    final scenarioTitle = scenarioCard?.titleForBand(band.band) ??
        wizardData.selectedScenario ??
        'A surprise quest awaits!';
    final missionHook = scenarioCard?.conflictHookForAge(wizardData.characterAge)
        ?? (scenarioCard == null
            ? 'Something amazing is about to happen — tap MISSION READY to begin.'
            : null);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF80CBC4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF80CBC4).withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header bar ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A4E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Text(
              'MISSION BRIEFING',
              textAlign: TextAlign.center,
              style: GoogleFonts.bitter(
                // Audit F-02: bumped from 11px so the section header is
                // comfortably readable at the band floor (9-year-old) and
                // for a parent scanning the card.
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF80CBC4),
                letterSpacing: 2.5,
              ),
            ),
          ),

          // ── Avatar + stats ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar column
                Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF80CBC4), width: 1.5),
                        color: const Color(0xFF1A1A4E),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: heroAvatar,
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // Stats column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Audit F-04: NAME row is now tappable when onTapName
                      // is provided, matching the affordance the summary
                      // rows below already have. Falls back to a static row
                      // when no callback is wired.
                      _TappableWrap(
                        onTap: onTapName,
                        child: _StatLine(
                          label: 'NAME',
                          value: wizardData.characterName.isNotEmpty
                              ? wizardData.characterName
                              : '—',
                          isHero: true,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (archetype != null) ...[
                        _StatLine(
                          label: 'CLASS',
                          value: archetype.name,
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (archetype?.adventurerDescription != null) ...[
                        _StatLine(
                          label: 'ROLE',
                          value: archetype!.adventurerDescription!,
                          italic: true,
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (wizardData.heroSuperpower?.isNotEmpty == true) ...[
                        _StatLine(
                          label: 'POWER',
                          value: wizardData.heroSuperpower!,
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (wizardData.companionNames.isNotEmpty)
                        // Audit F-04: PARTY row is now tappable when
                        // onTapParty is provided.
                        _TappableWrap(
                          onTap: onTapParty,
                          child: _StatLine(
                            label: 'PARTY',
                            value: wizardData.companionNames.join(', '),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ─────────────────────────────────────────────────────
          const Divider(color: Color(0xFF1A1A4E), thickness: 1.5, height: 1),

          // ── Scenario / mission objective ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 14, color: Color(0xFF80CBC4)),
                    const SizedBox(width: 6),
                    Text(
                      'MISSION',
                      style: GoogleFonts.bitter(
                        // Audit F-02: bumped from 10px so the section label is
                        // legible at band floor.
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF80CBC4),
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  scenarioTitle,
                  style: GoogleFonts.bitter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFD700),
                  ),
                ),
                if (missionHook != null && missionHook.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    missionHook,
                    style: GoogleFonts.bitter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isHero;
  final bool italic;

  const _StatLine({
    required this.label,
    required this.value,
    this.isHero = false,
    this.italic = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Teal left accent
        Container(
          width: 3,
          height: isHero ? 22 : 18,
          color: const Color(0xFF80CBC4),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label  ',
                  style: GoogleFonts.bitter(
                    // Audit F-02: bumped from 9px so NAME / CLASS / ROLE /
                    // POWER / PARTY labels are legible at band floor and for
                    // a parent skimming the card. Kept letter-spacing.
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF80CBC4),
                    letterSpacing: 1.5,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: GoogleFonts.bitter(
                    fontSize: isHero ? 16 : 13,
                    fontWeight:
                        isHero ? FontWeight.bold : FontWeight.normal,
                    color: isHero
                        ? const Color(0xFFFFD700)
                        : Colors.white.withValues(alpha: 0.9),
                    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Wraps a [_StatLine] in a tap handler when [onTap] is non-null. When null,
/// renders the child unchanged so non-tappable rows look the same as before
/// the F-04 fix. Uses Material+InkWell so the tap surface gets standard ripple
/// feedback at the band-appropriate touch target size.
class _TappableWrap extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _TappableWrap({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: child,
        ),
      ),
    );
  }
}

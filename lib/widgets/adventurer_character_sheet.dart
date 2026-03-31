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

  const AdventurerCharacterSheet({
    super.key,
    required this.wizardData,
    required this.band,
    required this.heroAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final archetype = wizardData.selectedArchetypeId != null
        ? CharacterArchetypes.all
            .where((a) => a.name.toLowerCase().replaceAll(' ', '_') ==
                wizardData.selectedArchetypeId)
            .firstOrNull
        : null;

    final scenarioCard = wizardData.selectedScenario != null
        ? ScenarioData.getById(wizardData.selectedScenario!)
        : null;
    final scenarioTitle = scenarioCard?.titleForAge(wizardData.characterAge) ??
        wizardData.selectedScenario ??
        'Unknown Mission';
    final missionHook = scenarioCard?.conflictHookForAge(wizardData.characterAge);

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
                fontSize: 11,
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
                      _StatLine(
                        label: 'NAME',
                        value: wizardData.characterName.isNotEmpty
                            ? wizardData.characterName
                            : '—',
                        isHero: true,
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
                        _StatLine(
                          label: 'PARTY',
                          value: wizardData.companionNames.join(', '),
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
                        fontSize: 10,
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
                    fontSize: 9,
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

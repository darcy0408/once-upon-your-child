// lib/widgets/parent_sensitivity_interstitial.dart
//
// MT-158 / content-safety audit F-08 + F-16 — parent-facing heads-up surface
// shown BEFORE a Life Quest that touches a sensitive theme (parental
// conflict, peer mental-health crisis, breakup, family argument, online
// shaming) starts playing.
//
// Tone is "quiet heads-up", not "warning". Visual palette mirrors
// `crisis_resources_panel.dart` (warm earthy sand/clay) so a parent who has
// seen the existing sensitive-content treatment recognises this surface as
// the same family — supportive, not alarming.
//
// The acknowledgement is persisted in SharedPreferences keyed by quest id so
// that a parent who picks the same quest a second time isn't nagged again.
// Wiring lives in `LifeQuestScreen`; this widget just renders the surface
// and reports the two button presses.
//
// IMPORTANT: This widget is purely presentational. It does NOT touch
// SharedPreferences itself — the screen owns that read/write because the
// screen also owns the "should I even show the interstitial?" decision.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/age_band_theme.dart';

/// Calm, parent-facing heads-up surface. Caller wires:
///
///   * [questTitle] — the quest's title, shown as the headline.
///   * [topics] — short noun phrases rendered as chips. Empty list is
///     allowed but the caller should normally only show this widget when
///     `topics.isNotEmpty`.
///   * [parentNote] — 1-2 sentences of body copy aimed at the grown-up.
///   * [onStart] — fired when the parent taps "Start the story".
///   * [onBack] — fired when the parent taps "Choose a different story".
class ParentSensitivityInterstitial extends StatelessWidget {
  const ParentSensitivityInterstitial({
    super.key,
    required this.questTitle,
    required this.topics,
    required this.parentNote,
    required this.onStart,
    required this.onBack,
  });

  final String questTitle;
  final List<String> topics;
  final String parentNote;
  final VoidCallback onStart;
  final VoidCallback onBack;

  // Earthy warm sand/clay base — matches CrisisResourcesPanel so the
  // sensitive-content treatment reads as one consistent family. Independent
  // of the band accent so the panel always says "support information" rather
  // than "story content".
  static const Color _warmBase = Color(0xFFC9A678);
  static const Color _warmDeep = Color(0xFF8B6B3D);

  @override
  Widget build(BuildContext context) {
    final band = Theme.of(context).extension<AgeBandThemeData>();
    final useSerif = band == null || band.band.isMature;

    final headlineStyle = useSerif
        ? GoogleFonts.sourceSans3(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.25,
          )
        : GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.25,
          );
    final eyebrowStyle = useSerif
        ? GoogleFonts.sourceSans3(
            color: _warmBase,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          )
        : GoogleFonts.fredoka(
            color: _warmBase,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          );
    final bodyStyle = useSerif
        ? GoogleFonts.sourceSans3(
            color: Colors.white.withAlpha(220),
            fontSize: 15,
            height: 1.55,
          )
        : GoogleFonts.fredoka(
            color: Colors.white.withAlpha(220),
            fontSize: 15,
            height: 1.55,
          );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Eyebrow + a soft "for a grown-up" cue. No red, no exclamation
            // marks — the icon is a heart, matching the crisis panel.
            Row(
              children: [
                Icon(Icons.favorite_rounded,
                    size: 16, color: _warmBase.withAlpha(230)),
                const SizedBox(width: 6),
                Text('A QUIET HEADS-UP FOR A GROWN-UP', style: eyebrowStyle),
              ],
            ),
            const SizedBox(height: 16),
            // Card body — warm sand gradient + tan border, matching
            // CrisisResourcesPanel. The card holds the title, topic chips,
            // and the parent note.
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _warmBase.withAlpha(60),
                    _warmDeep.withAlpha(35),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: _warmBase.withAlpha(140), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(questTitle, style: headlineStyle),
                  if (topics.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in topics) _TopicChip(label: t),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(parentNote, style: bodyStyle),
                ],
              ),
            ),
            const Spacer(),
            // Primary action — "Start the story". Filled, warm.
            FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: _warmBase,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Start the story',
                style: useSerif
                    ? GoogleFonts.sourceSans3(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      )
                    : GoogleFonts.fredoka(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
              ),
            ),
            const SizedBox(height: 10),
            // Secondary action — back out to the quest selector.
            OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withAlpha(60)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Choose a different story',
                style: useSerif
                    ? GoogleFonts.sourceSans3(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      )
                    : GoogleFonts.fredoka(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single sensitivity topic rendered as a small earthy chip. Stays in the
/// warm-sand family so the chips read as "tags about the story", not "alert
/// labels".
class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final band = Theme.of(context).extension<AgeBandThemeData>();
    final useSerif = band == null || band.band.isMature;
    final style = useSerif
        ? GoogleFonts.sourceSans3(
            color: Colors.white.withAlpha(235),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          )
        : GoogleFonts.fredoka(
            color: Colors.white.withAlpha(235),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ParentSensitivityInterstitial._warmBase.withAlpha(55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ParentSensitivityInterstitial._warmBase.withAlpha(140),
          width: 1,
        ),
      ),
      child: Text(label, style: style),
    );
  }
}

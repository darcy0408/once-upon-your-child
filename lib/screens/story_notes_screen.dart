// Story Notes reveal screen — the "Why this story? 💛" disclosure (MT-254).
//
// This is the PULL side of the design: a child (or a co-reading adult) chooses
// to open it from a quiet button at the end of a story. It is a calm, separate
// screen — the story stays immersive; the reveal is its own beat afterward.
// Reuses the band theme so it reads in the child's own visual language, and
// borrows the Saga Record screen's "gradient + bordered card" structure.
//
// The disclosure copy is built by [buildStoryNotes] (lib/models/story_notes.dart)
// from the story's per-story `practiced` focus (MT-254 fork #2 = per-story).
import 'package:flutter/material.dart';

import '../models/story_notes.dart';
import '../theme/age_band_theme.dart';

class StoryNotesScreen extends StatelessWidget {
  final StoryNotesContent content;
  final AgeBand band;

  const StoryNotesScreen({
    super.key,
    required this.content,
    required this.band,
  });

  /// Convenience constructor: build the reveal directly from the story's
  /// `practiced` focus value, so callers don't touch [buildStoryNotes].
  factory StoryNotesScreen.fromFocus({
    Key? key,
    required String focusValue,
    required AgeBand band,
    String? heroName,
    String? caregiverName,
  }) {
    return StoryNotesScreen(
      key: key,
      band: band,
      content: buildStoryNotes(
        focusValue: focusValue,
        band: band,
        heroName: heroName,
        caregiverName: caregiverName,
      ),
    );
  }

  String get _doneLabel {
    switch (content.tone) {
      case StoryNotesTone.relational:
      case StoryNotesTone.gentle:
        return 'Back to stories';
      case StoryNotesTone.direct:
      case StoryNotesTone.transparent:
        return 'Got it';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeForBand(band);
    final accent = theme.accent;
    final onDark = theme.textOnDark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: onDark),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: theme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    content.headline,
                    textAlign: TextAlign.center,
                    style: theme.storyTitleStyle.copyWith(color: onDark),
                  ),
                  const SizedBox(height: 22),

                  // The disclosure itself.
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(40),
                      borderRadius: BorderRadius.circular(theme.cardRadiusBase),
                      border: Border.all(color: accent.withAlpha(90)),
                    ),
                    child: Text(
                      content.body,
                      textAlign: TextAlign.center,
                      style: theme.storyBodyStyle.copyWith(
                        color: onDark,
                        fontSize: 18 * theme.bodyScale,
                        height: 1.6,
                      ),
                    ),
                  ),

                  // The co-read invitation (when present).
                  if (content.coReadPrompt != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.favorite_rounded,
                            color: accent.withAlpha(220), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            content.coReadPrompt!,
                            style: theme.storyBodyStyle.copyWith(
                              color: onDark.withAlpha(220),
                              fontSize: 15 * theme.bodyScale,
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: theme.textOnLight,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(theme.buttonRadiusBase),
                        ),
                      ),
                      child: Text(
                        _doneLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The quiet "Why this story? 💛" entry point — the PULL trigger.
///
/// Drop this at the end of a guided story (e.g. on the story result screen)
/// when the story carried a `practiced` focus. Tapping it opens
/// [StoryNotesScreen]. Low-pressure by design: a child may tap it or not, and
/// the disclosure to the trusted adult is guaranteed separately in Parent
/// Controls (MT-254 fork #1).
class StoryNotesButton extends StatelessWidget {
  final String focusValue;
  final AgeBand band;
  final String? heroName;
  final String? caregiverName;

  const StoryNotesButton({
    super.key,
    required this.focusValue,
    required this.band,
    this.heroName,
    this.caregiverName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = themeForBand(band);
    return TextButton.icon(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StoryNotesScreen.fromFocus(
              focusValue: focusValue,
              band: band,
              heroName: heroName,
              caregiverName: caregiverName,
            ),
          ),
        );
      },
      icon: const Text('💛', style: TextStyle(fontSize: 16)),
      label: Text(
        'Why this story?',
        style: TextStyle(
          color: theme.textOnDark.withAlpha(200),
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: theme.accent.withAlpha(150),
        ),
      ),
    );
  }
}

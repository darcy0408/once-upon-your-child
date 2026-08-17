// lib/data/band_story_defaults.dart
//
// Narrative defaults derived from a reader's age band — the story-side
// counterpart to the visual mapping in theme/age_band_theme.dart.
//
// Kept here rather than inline at call sites: the tone map previously lived
// only inside magic_review_step.dart, so every other entry point into story
// generation had to either re-derive it or guess. ChronicleScreen guessed, and
// sent 'whimsical' for every chapter at every age — a 16-year-old's next
// chapter was generated in the same register as a 4-year-old's.

import '../theme/age_band_theme.dart';

/// Narrative tone for [band], as sent to the story generator.
///
/// These strings are contract values shared with the backend prompt builder —
/// changing one changes generated prose, so they are not free-form labels.
String storyToneForBand(AgeBand band) => switch (band) {
      AgeBand.sprout => 'whimsical',
      AgeBand.explorer => 'whimsical',
      AgeBand.adventurer => 'fantasy',
      AgeBand.creator => 'mystery',
      AgeBand.adolescent => 'atmospheric',
      AgeBand.adult => 'literary',
    };

/// Convenience wrapper for callers that hold an age rather than a band.
String storyToneForAge(int age) => storyToneForBand(ageBandFromAge(age));

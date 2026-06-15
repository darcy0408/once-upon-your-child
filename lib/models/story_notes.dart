// Story Notes — the age-gated transparency layer over the hidden parent
// context (MT-254). After a guided story, the child can tap a quiet
// "Why this story? 💛" button and see, at an age-appropriate level of
// directness, what the story was practicing. The reveal lives at the EDGE
// of the story (a separate screen), never inside it.
//
// This file is the pure, testable core: it turns the story's `practiced`
// focus (the backend field naming which ParentHiddenContext trigger was
// actually woven in) plus the child's age band into the disclosure copy.
//
// Directness scales with band — this is the design's answer to "transparent
// without disrupting engagement":
//   • Sprout 3-5      → relational only (no lesson named)
//   • Explorer 6-8    → names the skill gently + a co-read question
//   • Adventurer 9-12 → direct, but preserves the child's sense of agency
//   • Creator/Adolescent/Adult 13+ → full transparency, respects autonomy
import '../data/parent_focus_keys.dart';
import '../theme/age_band_theme.dart';

/// How directly the Story Notes disclosure names the guided lesson.
enum StoryNotesTone { relational, gentle, direct, transparent }

/// Maps an age band to its disclosure directness. Mirrors the
/// young / mature groupings in [AgeBandGroups].
StoryNotesTone toneForBand(AgeBand band) {
  switch (band) {
    case AgeBand.sprout:
      return StoryNotesTone.relational;
    case AgeBand.explorer:
      return StoryNotesTone.gentle;
    case AgeBand.adventurer:
      return StoryNotesTone.direct;
    case AgeBand.creator:
    case AgeBand.adolescent:
    case AgeBand.adult:
      return StoryNotesTone.transparent;
  }
}

/// The resolved, ready-to-render disclosure for one story.
class StoryNotesContent {
  /// Screen title, e.g. "What this story was about 💛".
  final String headline;

  /// The disclosure itself — what the story practiced, phrased for the band.
  final String body;

  /// An optional invitation to talk it over with a trusted adult. Null for
  /// the youngest band (a co-read line is offered there too, but the screen
  /// keeps it to one warm sentence).
  final String? coReadPrompt;

  /// The directness level that produced this copy (drives button labels, etc).
  final StoryNotesTone tone;

  const StoryNotesContent({
    required this.headline,
    required this.body,
    required this.tone,
    this.coReadPrompt,
  });
}

/// Child-safe phrasing for each parent-selected focus.
///
/// Keyed by [ParentFocusKeys] — the single source of truth shared with the
/// Big Feelings parent picker (`_triggerData` in parent_controls_screen.dart).
/// This map MUST cover every key in [ParentFocusKeys.all]; the guard test in
/// test/models/story_notes_test.dart fails if one is missing (which would
/// silently degrade that focus's disclosure to generic copy).
class _FocusCopy {
  /// A short phrase for direct/transparent tones, e.g. `hearing "no"`.
  final String short;

  /// A fuller, warmer phrase for the gentle tone, e.g.
  /// `hearing "no" — and finding a way to feel calm again after`.
  final String long;

  const _FocusCopy(this.short, this.long);
}

const Map<String, _FocusCopy> _focusCopy = {
  ParentFocusKeys.limitSet: _FocusCopy(
    'hearing "no"',
    'hearing "no" — and finding a way to feel calm again after',
  ),
  ParentFocusKeys.siblingConflict: _FocusCopy(
    'working things out with a sibling',
    'cooling down after a fight with a sibling and finding a way back to each other',
  ),
  ParentFocusKeys.friendshipBump: _FocusCopy(
    'repairing a friendship',
    'sitting with hurt feelings and finding a way to reconnect with a friend',
  ),
  ParentFocusKeys.nighttimeUncertain: _FocusCopy(
    'facing nighttime worries',
    'feeling brave and steady when the dark feels big',
  ),
  ParentFocusKeys.transition: _FocusCopy(
    'handling a hard change',
    'staying steady when things change all of a sudden',
  ),
  ParentFocusKeys.meltdownWhenStuck: _FocusCopy(
    'pushing through frustration',
    'staying calm when something feels too hard — and asking for help',
  ),
};

String _trimOr(String? value, String fallback) {
  final v = value?.trim();
  return (v != null && v.isNotEmpty) ? v : fallback;
}

/// Joins phrases the way a person would speak them:
/// `[a]` → "a", `[a, b]` → "a and b", `[a, b, c]` → "a, b, and c".
String _joinNatural(List<String> parts) {
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;
  if (parts.length == 2) return '${parts[0]} and ${parts[1]}';
  return '${parts.sublist(0, parts.length - 1).join(', ')}, and ${parts.last}';
}

/// Builds the disclosure for a single story.
///
/// [focusValue] is the story's `practiced` field. A story may be guided toward
/// several configured focuses, in which case this is the Big Feelings trigger
/// values comma-joined (e.g. `'a limit is set, a sibling conflict starts'`);
/// they are all named, naturally. [caregiverName] is the per-child caregiver
/// label (e.g. "Mommy") when set; otherwise a warm default stands in.
/// [heroName] is woven into the co-read question for the gentle tone.
StoryNotesContent buildStoryNotes({
  required String focusValue,
  required AgeBand band,
  String? heroName,
  String? caregiverName,
}) {
  final tone = toneForBand(band);
  final hero = _trimOr(heroName, 'your hero');

  // Resolve every configured focus (capped at 3 so the disclosure stays
  // readable). A single focus gets the richer "long" phrasing; multiples use
  // the shorter phrases so the sentence doesn't sprawl.
  final copies = focusValue
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .map((k) => _focusCopy[k])
      .whereType<_FocusCopy>()
      .take(3)
      .toList();
  final useLong = copies.length == 1;
  final String? gentleSkill = copies.isEmpty
      ? null
      : _joinNatural([for (final c in copies) useLong ? c.long : c.short]);
  final String? shortSkill =
      copies.isEmpty ? null : _joinNatural([for (final c in copies) c.short]);

  switch (tone) {
    case StoryNotesTone.relational:
      // Sprout: a 3-5yo can't process persuasion, so we never name a lesson —
      // just keep the loving adult visibly in the loop.
      final who = _trimOr(caregiverName, 'A grown-up who loves you');
      return StoryNotesContent(
        tone: tone,
        headline: 'Made just for you 💛',
        body: '$who picked this story just for you.',
      );

    case StoryNotesTone.gentle:
      final who = _trimOr(caregiverName, 'your grown-up');
      final skill = gentleSkill ?? 'something your grown-up wanted to help with';
      return StoryNotesContent(
        tone: tone,
        headline: 'What this story was about 💛',
        body: 'This adventure was about practicing $skill.',
        coReadPrompt:
            'Read this part with $who. Did $hero find a way to feel better? '
            'What helped?',
      );

    case StoryNotesTone.direct:
      final who = _trimOr(caregiverName, 'a grown-up who cares about you');
      final skill = shortSkill ?? 'something they wanted to help with';
      return StoryNotesContent(
        tone: tone,
        headline: 'Why this story',
        body: 'Heads up — $who helped shape this one toward $skill. '
            "The choices were really yours; the theme wasn't random.",
        coReadPrompt: 'Worth talking about together?',
      );

    case StoryNotesTone.transparent:
      final who = _trimOr(caregiverName, 'someone who cares about you');
      final skill = shortSkill ?? 'something they wanted to open up';
      return StoryNotesContent(
        tone: tone,
        headline: 'Why this story',
        body: 'Straight up: $who set this story up to explore $skill. '
            'What you did with it was yours.',
        coReadPrompt: 'Worth a conversation?',
      );
  }
}

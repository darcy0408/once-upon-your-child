// lib/utils/distress_detector.dart
//
// Free-text safety net: scans what a child actually types for clear
// self-harm / suicidal-ideation language so the app can surface real-world
// crisis resources (see widgets/crisis_resources_panel.dart) at the moment a
// child commits distressing text — not just on pre-tagged content.
//
// This is a SAFETY NET, not a clinical tool. It does not diagnose, score,
// log, or report; it only answers one question: "should we *offer* support
// right now?". It is deliberately tuned for HIGH PRECISION over recall — this
// is a kids' story app where violent-play language ("kill the dragon", "the
// bad guy died") is everywhere, so a curated multi-word phrase list is used
// instead of bare tokens like "die" / "kill" / "dead", which would fire
// constantly and needlessly alarm a child at play.
//
// US/English phrasing for now, to match the US crisis lines it surfaces.
//
// TODO(i18n): these phrases are English/US-centric. When the app gains
// AppLocalizations, replace this constant with a locale-aware phrase set
// alongside the locale-aware crisis lines in crisis_resources_panel.dart.

/// Curated, high-precision self-harm / suicidal-ideation phrases.
///
/// All entries are pre-normalised: lower-case, apostrophes removed (so
/// "don't" == "dont"), single-spaced. Matching is word/phrase-boundary based
/// (see [_normalize] + [containsDistressSignal]), so a phrase only fires when
/// its words appear adjacent — "kill myself" does NOT match "kill the dragon
/// myself".
///
/// Deliberately EXCLUDED to avoid false positives in a kids' story app:
///   • bare "die" / "died" / "dead" / "kill" / "killed" / "killing" — ordinary
///     story/game violence ("kill the dragon", "the monster died", "the bad
///     guy died", "defeat the villain").
///   • "kill me" / "kill you" — hyperbole and play, not self-directed intent.
///   • bare "suicide" — collides with "Suicide Squad", a hugely popular
///     superhero franchise a child is very likely to name. We require the
///     higher-signal "commit suicide" / "suicidal" instead.
///   • "hate myself" / "i hate myself" — common non-clinical venting
///     ("I hate myself for forgetting"); too noisy to be actionable here.
///   • "dying to ..." (e.g. "dying to see the dragon") — idiom, not distress;
///     never matches because the list has no bare "dying".
const List<String> _distressPhrases = [
  // ── suicidal ideation ──────────────────────────────────────────────────
  'want to die',
  'wanna die',
  'wish i was dead',
  'wish i were dead',
  'wish i was never born',
  'wish i wasnt born',
  'better off dead',
  'better off without me',
  'no reason to live',
  'nothing to live for',
  // Borderline: "disappear" also has an innocent magical-story reading
  // ("disappear into the painting"). Kept because the full phrase "want to
  // disappear" is a well-documented ideation idiom and the cost of a missed
  // signal outweighs an occasional gentle, dismissable offer of support.
  'want to disappear',
  'wanna disappear',
  'dont want to live',
  'dont want to be alive',
  'dont want to be here',
  'dont want to wake up',
  'do not want to live',
  'do not want to be here',
  'end my life',
  'end it all',
  'take my own life',
  'taking my own life',
  'kill myself',
  'killing myself',
  'kill my self',
  'commit suicide',
  'suicidal',
  // ── self-harm ──────────────────────────────────────────────────────────
  'hurt myself',
  'hurting myself',
  'harm myself',
  'harming myself',
  'cut myself',
  'cutting myself',
  'self harm',
];

/// Lower-cases [text], drops apostrophes so contractions match their bare
/// forms, turns every other run of non-alphanumerics into a single space, and
/// pads the result with a leading + trailing space so phrase lookups can match
/// on word boundaries via a simple `contains(' phrase ')`.
String _normalize(String text) {
  final stripped = text
      .toLowerCase()
      .replaceAll(RegExp("['’`]"), '') // join "don't" -> "dont"
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ') // punctuation -> space
      .trim();
  return ' $stripped ';
}

/// Returns true when [text] contains clear self-harm / suicidal-ideation
/// language from the curated [_distressPhrases] list.
///
/// Case- and whitespace-insensitive, and matches on word/phrase boundaries so
/// game/story violence ("kill the dragon", "the monster died") does NOT trip
/// it. Empty / whitespace-only input is always false. Intended to gate an
/// *offer* of [CrisisResourcesPanel]; it never blocks the child's flow.
bool containsDistressSignal(String text) {
  if (text.trim().isEmpty) return false;
  final haystack = _normalize(text);
  for (final phrase in _distressPhrases) {
    if (haystack.contains(' $phrase ')) return true;
  }
  return false;
}

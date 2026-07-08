// lib/data/story_scaffolds.dart
//
// Offline story scaffolds — pre-written branching templates used as a
// deterministic fallback when AI generation is unavailable (network down,
// timeout, quota exhausted, 5xx). The kid still gets a personalized story
// using their name, companion, and pronouns — they never see an error.
//
// CONTRACT
// --------
// Scaffolds reuse the EXACT same interpolation contract as
// `lib/data/life_quest_data.dart`. Authors should think of a scaffold as a
// "Quest with a scenarioId" — a branching narrative that fills the same
// {name}/{companion}/{pronoun}/{Pronoun}/{possessive} slots and uses the
// same «companion-conditional» markers. We deliberately reuse
// `interpolateQuest()` from that file so there is exactly one
// interpolation engine in the codebase.
//
// String interpolation slots:
//   {name}       — child's name (used in dialogue/address by others)
//   {companion}  — companion name, or empty string
//   {pronoun}    — "she" / "he" / "they"
//   {Pronoun}    — "She" / "He" / "They"
//   {possessive} — "her" / "his" / "their"
//
// Companion-conditional text: wrap in «» — stripped entirely when companion
// is empty, markers removed when companion is present.
//   e.g. «{companion} squeezes your hand. »
//
// AUTHORING NEW SCAFFOLDS
// -----------------------
// 1. Pick a `scenarioId` that matches an existing `ScenarioCard.id` from
//    `lib/data/scenario_data.dart` (e.g. 'volcano_dragons', 'neon_jungle',
//    'crystal_cavern', 'space_station_dreams', etc.).
// 2. Write 4-6 segments. Each non-ending segment should have 2-3 choices.
//    All paths must reach an `isEnding: true` segment with a positive
//    resolution. Sprout band targets 200-400 words total per scaffold.
// 3. Use second-person ("you") for Sprout — concrete, body-aware language.
//    Older bands can use third-person with {name}.
// 4. Optionally set `archetypeFilter` (subset of hero archetype ids) and
//    `feelingFilter` (subset of feeling ids — matches the badge grid ids
//    used in life_quest_data) to narrow when this scaffold is eligible.
//    `null` means "match any".
// 5. Add the new scaffold to `allStoryScaffolds`.
//
// PICKER
// ------
// `pickScaffoldFor()` selects the best matching scaffold for a given
// scenario + band + (optional) archetype/feeling. Falls back to
// scenario-only matches if filtered matches are empty, and finally to
// any Sprout-band scaffold if the scenario is unrecognised. Returns
// `null` only when the library is completely empty for the band.

import '../theme/age_band_theme.dart' show AgeBand;
import 'life_quest_data.dart' show QuestSegment, QuestChoice, interpolateQuest;

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

/// A pre-written branching story template that can stand in for an AI
/// generation when the backend is unreachable. Plugs into the same
/// rendering pipeline because it produces a `StoryGenerationResult` via
/// [interpolateScaffold] — see lib/services/story_scaffold_fallback.dart.
class StoryScaffold {
  /// Unique scaffold id (e.g. 'volcano_dragons_sprout_stomp').
  final String id;

  /// Human title for the rendered story (will be interpolated too).
  final String title;

  /// Matches an existing `ScenarioCard.id` from scenario_data.dart.
  /// E.g. 'volcano_dragons', 'neon_jungle'.
  final String scenarioId;

  /// Which age bands this scaffold is appropriate for.
  final List<AgeBand> recommendedBands;

  /// All segments keyed by segment id. Reuses the QuestSegment type from
  /// life_quest_data.dart so the rendering pipeline (and authoring
  /// patterns) stay identical.
  final Map<String, QuestSegment> segments;

  /// The id of the first segment.
  final String startSegmentId;

  /// Optional: only show for these hero archetype ids. `null` = any.
  /// Matches archetype ids used by character_traits_data.dart.
  final List<String>? archetypeFilter;

  /// Optional: only show when the child's currentFeeling is in this list.
  /// Matches the feeling/emotion ids used by life_quest_data and the
  /// Big Feelings badge grid (e.g. 'sad', 'worried', 'happy').
  /// `null` = any feeling.
  final List<String>? feelingFilter;

  /// Optional one-sentence prompt for a grown-up to read aloud after the
  /// story ends. Mirrors `LifeQuestScenario.grownupTip`.
  final String? grownupTip;

  /// Bedtime scaffolds are calm, short, and end on a sleep transition.
  /// They are ONLY served when the caller asks for bedtime (so a daytime
  /// request never gets a sleepy story), and are PREFERRED for bedtime
  /// requests (so a network hiccup at lights-out never serves an
  /// energetic adventure).
  final bool isBedtime;

  const StoryScaffold({
    required this.id,
    required this.title,
    required this.scenarioId,
    required this.recommendedBands,
    required this.segments,
    required this.startSegmentId,
    this.archetypeFilter,
    this.feelingFilter,
    this.grownupTip,
    this.isBedtime = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Interpolation + flattening
// ─────────────────────────────────────────────────────────────────────────────

/// Walks a scaffold from its start segment to an ending, picking the
/// FIRST choice at each branch. Deterministic so the same kid + scaffold
/// always yields the same story (which is what we want for a fallback —
/// no surprise variation between runs). Returns the joined, fully
/// interpolated story prose ready to drop into `StoryGenerationResult.storyText`.
///
/// We deliberately do not present choices in the offline fallback. The
/// existing rendering pipeline expects a single block of prose; offering
/// branching choices would require new UI, which is out of scope.
String flattenAndInterpolateScaffold(
  StoryScaffold scaffold, {
  required String name,
  String companion = '',
  String pronoun = 'they',
  String pronounCap = 'They',
  String possessive = 'their',
}) {
  final buffer = StringBuffer();
  String? currentId = scaffold.startSegmentId;
  // Cycle guard — bounded by segment count to handle authoring mistakes
  // without infinite-looping.
  final visited = <String>{};
  while (currentId != null && !visited.contains(currentId)) {
    visited.add(currentId);
    final segment = scaffold.segments[currentId];
    if (segment == null) break;
    final interpolated = interpolateQuest(
      segment.content,
      name: name,
      companion: companion,
      pronoun: pronoun,
      pronounCap: pronounCap,
      possessive: possessive,
    );
    if (buffer.isNotEmpty) buffer.write('\n\n');
    buffer.write(interpolated);
    if (segment.isEnding || segment.choices.isEmpty) break;
    currentId = segment.choices.first.nextSegmentId;
  }
  return buffer.toString();
}

/// Convenience: interpolate the scaffold title using the same engine.
String interpolateScaffoldTitle(
  StoryScaffold scaffold, {
  required String name,
  String companion = '',
  String pronoun = 'they',
  String pronounCap = 'They',
  String possessive = 'their',
}) {
  return interpolateQuest(
    scaffold.title,
    name: name,
    companion: companion,
    pronoun: pronoun,
    pronounCap: pronounCap,
    possessive: possessive,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Picker
// ─────────────────────────────────────────────────────────────────────────────

/// Picks the best matching scaffold for the given scenario + band, with
/// optional archetype / feeling filters. Search order:
///   1. scenario + band + archetype + feeling all match
///   2. scenario + band + (archetype OR feeling) match
///   3. scenario + band match
///   4. band match (any scenario) — last-resort fallback so the kid
///      always gets *something* personalized.
/// Returns null only if no scaffold exists for the band at all.
StoryScaffold? pickScaffoldFor({
  required String scenarioId,
  required AgeBand band,
  String? archetypeId,
  String? feelingId,
  bool bedtime = false,
}) {
  // Bedtime requests strongly prefer a bedtime scaffold: a network failure
  // at lights-out should produce a wind-down story, not a daytime
  // adventure. Non-bedtime requests never see bedtime scaffolds.
  if (bedtime) {
    final bedtimeMatches = allStoryScaffolds
        .where((s) => s.isBedtime && s.recommendedBands.contains(band))
        .toList(growable: false);
    if (bedtimeMatches.isNotEmpty) {
      final scenarioMatch =
          bedtimeMatches.where((s) => s.scenarioId == scenarioId).toList();
      return scenarioMatch.isNotEmpty
          ? scenarioMatch.first
          : bedtimeMatches.first;
    }
    // No bedtime scaffold for this band — fall through to the normal
    // library rather than returning nothing at all.
  }

  final bandMatches = allStoryScaffolds
      .where((s) => !s.isBedtime && s.recommendedBands.contains(band))
      .toList(growable: false);
  if (bandMatches.isEmpty) return null;

  final scenarioMatches =
      bandMatches.where((s) => s.scenarioId == scenarioId).toList();
  if (scenarioMatches.isEmpty) return bandMatches.first;

  bool matchesArchetype(StoryScaffold s) =>
      archetypeId == null ||
      s.archetypeFilter == null ||
      s.archetypeFilter!.contains(archetypeId);
  bool matchesFeeling(StoryScaffold s) =>
      feelingId == null ||
      s.feelingFilter == null ||
      s.feelingFilter!.contains(feelingId);

  // Tier 1: both filters happy.
  final tier1 = scenarioMatches
      .where((s) => matchesArchetype(s) && matchesFeeling(s))
      .toList();
  if (tier1.isNotEmpty) return tier1.first;

  // Tier 2: at least one filter happy.
  final tier2 = scenarioMatches
      .where((s) => matchesArchetype(s) || matchesFeeling(s))
      .toList();
  if (tier2.isNotEmpty) return tier2.first;

  // Tier 3: scenario + band only.
  return scenarioMatches.first;
}

// ─────────────────────────────────────────────────────────────────────────────
// Library
// ─────────────────────────────────────────────────────────────────────────────

/// All bundled scaffolds. Currently seeded with two Sprout-band examples
/// as templates for future content authoring. Library expansion is
/// tracked separately.
const List<StoryScaffold> allStoryScaffolds = <StoryScaffold>[
  scaffoldVolcanoDragonsSproutStomp,
  scaffoldNeonJungleSproutForest,
  scaffoldBedtimeYoungStarlitMeadow,
  scaffoldBedtimeOlderQuietHarbor,
];

// ═══════════════════════════════════════════════════════════════════════════════
// SCAFFOLD 1: Stomp with the Dinosaurs!  [volcano_dragons / Sprout]
// Sprout-band framing of the volcano_dragons scenario uses friendly
// dinosaurs (matches `sproutTitle` and `sproutIllustration` on the
// existing ScenarioCard). All paths end with a warm, body-aware moment.
// Word target: ~280 words across the linear path.
// ═══════════════════════════════════════════════════════════════════════════════

const scaffoldVolcanoDragonsSproutStomp = StoryScaffold(
  id: 'volcano_dragons_sprout_stomp',
  title: 'Stomp with the Dinosaurs, {name}!',
  scenarioId: 'volcano_dragons',
  recommendedBands: [AgeBand.sprout],
  startSegmentId: 'vds_start',
  grownupTip:
      "Ask: 'What does YOUR brave stomp sound like? Can we stomp together?'",
  segments: {
    'vds_start': QuestSegment(
      id: 'vds_start',
      content: 'You are walking on a warm, bumpy path.\n\n'
          'The ground says, "Rumble, rumble."\n\n'
          'A friendly dinosaur peeks out. '
          '«{companion} peeks out too. »'
          '"Hi, {name}!" the dinosaur says.\n\n'
          'The dinosaur is BIG. '
          'But {possessive} smile is gentle.',
      choices: [
        QuestChoice(
          id: 'vds_c1a',
          text: 'Stomp hello back',
          nextSegmentId: 'vds_stomp',
        ),
        QuestChoice(
          id: 'vds_c1b',
          text: 'Wave a tiny wave',
          nextSegmentId: 'vds_wave',
        ),
      ],
    ),
    'vds_stomp': QuestSegment(
      id: 'vds_stomp',
      content: 'You stomp. STOMP-STOMP!\n\n'
          'The dinosaur giggles a deep giggle.\n\n'
          '"You stomp like me!" {pronoun} rumbles.\n\n'
          'Your feet feel strong. '
          'Your tummy feels happy.',
      choices: [
        QuestChoice(
          id: 'vds_c2a',
          text: 'Follow the dinosaur to the warm pond',
          nextSegmentId: 'vds_pond',
        ),
        QuestChoice(
          id: 'vds_c2b',
          text: 'Climb on a warm rock',
          nextSegmentId: 'vds_rock',
        ),
      ],
    ),
    'vds_wave': QuestSegment(
      id: 'vds_wave',
      content: 'You wave. Just a tiny wave.\n\n'
          'The dinosaur waves back with one big toe.\n\n'
          '«{companion} hides behind your leg. »'
          'Tiny waves are big enough. '
          'Brave does not have to be loud.',
      choices: [
        QuestChoice(
          id: 'vds_c3a',
          text: 'Walk to the warm pond together',
          nextSegmentId: 'vds_pond',
        ),
        QuestChoice(
          id: 'vds_c3b',
          text: 'Sit on a warm rock',
          nextSegmentId: 'vds_rock',
        ),
      ],
    ),
    'vds_pond': QuestSegment(
      id: 'vds_pond',
      content: 'The pond is warm like bath water.\n\n'
          'Tiny dinosaurs splash in it. '
          'Splish! Splash!\n\n'
          'You dip one toe in. '
          'It feels cozy.\n\n'
          'A baby dinosaur climbs in your lap. '
          'It is the size of a kitten.\n\n'
          'You and the baby dinosaur breathe together. '
          'In... and out.\n\n'
          'Big things and little things '
          'can be friends, {name}.',
      isEnding: true,
    ),
    'vds_rock': QuestSegment(
      id: 'vds_rock',
      content: 'The rock is warm like a hug from the sun.\n\n'
          'You sit. The big dinosaur sits next to you. '
          'BOOM. The ground wiggles.\n\n'
          'You giggle. The dinosaur giggles.\n\n'
          '«{companion} curls up in your lap. »'
          'Together you watch the clouds float by. '
          'Slow, slow, slow.\n\n'
          'Brave hearts can rest, too. '
          'You did it, {name}.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// SCAFFOLD 2: The Magical Forest  [neon_jungle / Sprout]
// Sprout-band framing of the neon_jungle scenario as a glowing forest
// (matches `sproutTitle` "The Magical Forest" and `sproutIllustration`
// 'forest.png' on the existing ScenarioCard). Word target: ~280 words.
// ═══════════════════════════════════════════════════════════════════════════════

const scaffoldNeonJungleSproutForest = StoryScaffold(
  id: 'neon_jungle_sprout_forest',
  title: 'The Magical Forest of {name}',
  scenarioId: 'neon_jungle',
  recommendedBands: [AgeBand.sprout],
  startSegmentId: 'mjs_start',
  grownupTip:
      "Ask: 'What color would YOUR magic forest glow? Can we whisper a kind word together?'",
  segments: {
    'mjs_start': QuestSegment(
      id: 'mjs_start',
      content: 'You step into a soft, glowing forest.\n\n'
          'The trees are green. The flowers are pink. '
          'Even the moss glows!\n\n'
          '«{companion} sniffs the air. »'
          'A tiny voice whispers, "Hello, {name}."\n\n'
          'It is a sleepy little flower. '
          'Its petals are dim.',
      choices: [
        QuestChoice(
          id: 'mjs_c1a',
          text: 'Whisper a kind word to the flower',
          nextSegmentId: 'mjs_whisper',
        ),
        QuestChoice(
          id: 'mjs_c1b',
          text: 'Hum a soft song',
          nextSegmentId: 'mjs_hum',
        ),
      ],
    ),
    'mjs_whisper': QuestSegment(
      id: 'mjs_whisper',
      content: 'You lean down close.\n\n'
          'You whisper, "You are pretty."\n\n'
          'The flower glows BRIGHT pink!\n\n'
          'Then a tree glows.\n\n'
          'Then ten more flowers glow.\n\n'
          'Kind words are like sunshine '
          'for glowing things.',
      choices: [
        QuestChoice(
          id: 'mjs_c2a',
          text: 'Skip down the glowing path',
          nextSegmentId: 'mjs_heart',
        ),
        QuestChoice(
          id: 'mjs_c2b',
          text: 'Tiptoe to find more sleepy plants',
          nextSegmentId: 'mjs_more',
        ),
      ],
    ),
    'mjs_hum': QuestSegment(
      id: 'mjs_hum',
      content: 'You hum. Mmm-hmm-hmm.\n\n'
          'The little flower hums back.\n\n'
          'Soon the whole forest hums with you. '
          'Like a soft lullaby.\n\n'
          'Your shoulders feel light.\n\n'
          'When you make a happy sound, '
          'happy things hum with you.',
      choices: [
        QuestChoice(
          id: 'mjs_c3a',
          text: 'Skip down the glowing path',
          nextSegmentId: 'mjs_heart',
        ),
        QuestChoice(
          id: 'mjs_c3b',
          text: 'Wake up more sleepy plants',
          nextSegmentId: 'mjs_more',
        ),
      ],
    ),
    'mjs_more': QuestSegment(
      id: 'mjs_more',
      content: 'You tiptoe.\n\n'
          'You find a sleepy mushroom. You whisper, "Good morning."\n\n'
          'POP! It glows orange.\n\n'
          'You find a sleepy vine. You whisper, "I see you."\n\n'
          'POP! It glows blue.\n\n'
          '«{companion} tries it too! »'
          'The forest is waking up because of YOU, {name}.',
      choices: [
        QuestChoice(
          id: 'mjs_c4a',
          text: 'Walk to the big glowing tree in the middle',
          nextSegmentId: 'mjs_heart',
        ),
      ],
    ),
    'mjs_heart': QuestSegment(
      id: 'mjs_heart',
      content: 'In the middle of the forest is a HUGE tree.\n\n'
          'It is the Heart Tree. '
          'It glows like a warm rainbow.\n\n'
          'You put your hand on the bark. '
          'It feels alive. Bu-bump. Bu-bump.\n\n'
          'The tree whispers, "Thank you, {name}. '
          'You woke us up gently."\n\n'
          '«{companion} curls up near your feet. »'
          'You sit in the soft moss. '
          'The whole forest glows around you.\n\n'
          'Your kind voice is magic, {name}.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// SCAFFOLD 3: The Starlit Meadow  [bedtime / Sprout + Explorer]
// Offline wind-down story for the screen-free Bedtime Mode. Deliberately
// linear (one segment) and QUIET: no stakes, no surprises, descending
// energy, a breathing beat, and a sleep-transition ending. Served only
// when pickScaffoldFor(bedtime: true) — see the picker notes above.
// Word target: ~300 words.
// ═══════════════════════════════════════════════════════════════════════════════

const scaffoldBedtimeYoungStarlitMeadow = StoryScaffold(
  id: 'bedtime_young_starlit_meadow',
  title: 'The Starlit Meadow',
  scenarioId: 'bedtime',
  recommendedBands: [AgeBand.sprout, AgeBand.explorer],
  isBedtime: true,
  startSegmentId: 'bym_all',
  grownupTip:
      "Ask softly: 'Which sleepy animal did you like best?' Then take one "
      "big slow breath together.",
  segments: {
    'bym_all': QuestSegment(
      id: 'bym_all',
      content: 'The sun has gone to bed, {name}.\n\n'
          'The sky is soft and purple. '
          'One little star wakes up. '
          'Then another. '
          'Then another.\n\n'
          'You walk down a quiet path. '
          '«{companion} walks beside you, slow and sleepy. »'
          'The grass is cool. '
          'The air smells like flowers.\n\n'
          'You come to a meadow full of starlight. '
          'Everything here is getting ready for sleep.\n\n'
          'A bunny yawns a tiny yawn. '
          'A bird tucks its head under its wing. '
          'Even the flowers close their petals, one by one.\n\n'
          'The wind whispers, "Hushhh. Hushhh."\n\n'
          'You find a nest of moss, just your size. '
          'It is warm. '
          'It is soft. '
          '«{companion} curls up next to you, warm as a blanket. »'
          'You lie back and look up at the stars.\n\n'
          'You take a big slow breath in... and let it out, nice and slow. '
          'The stars twinkle a little softer.\n\n'
          'You take another slow breath... in... and out. '
          'Your arms feel heavy and cozy. '
          'Your eyes feel soft.\n\n'
          'The moon peeks over the hill. '
          'It smiles at you, {name}. '
          '"Goodnight, little friend," the moon hums. '
          '"You did so many good things today. '
          'Now it is time to rest."\n\n'
          'The meadow rocks you gently, like a boat on calm water. '
          'The stars sing a quiet song with no words.\n\n'
          'Your eyes close, soft as petals.\n\n'
          'Goodnight, {name}. '
          'Sweet dreams.',
      isEnding: true,
    ),
  },
);

// ═══════════════════════════════════════════════════════════════════════════════
// SCAFFOLD 4: The Quiet Harbor  [bedtime / Adventurer through Adult]
// Older-band register for the same job: a calm, linear wind-down with a
// sleep-transition ending. Second person to match bedtime voice mode.
// Word target: ~380 words.
// ═══════════════════════════════════════════════════════════════════════════════

const scaffoldBedtimeOlderQuietHarbor = StoryScaffold(
  id: 'bedtime_older_quiet_harbor',
  title: 'The Quiet Harbor',
  scenarioId: 'bedtime',
  recommendedBands: [
    AgeBand.adventurer,
    AgeBand.creator,
    AgeBand.adolescent,
    AgeBand.adult,
  ],
  isBedtime: true,
  startSegmentId: 'boh_all',
  grownupTip:
      'Every day ends like a boat coming home — whatever the weather was, '
      'the harbor is still there.',
  segments: {
    'boh_all': QuestSegment(
      id: 'boh_all',
      content: 'By the time you reach the harbor, {name}, the day is already '
          'folding itself away.\n\n'
          'The sky over the water has gone the color of slate and rose. '
          'Lanterns blink on along the pier, one by one, each small light '
          'steady against the dusk. '
          '«{companion} falls into step beside you, unhurried for once. »'
          'Nobody here is in a rush anymore.\n\n'
          'The last boats are coming in. '
          'You watch them cross the calm water, slow and sure, their wakes '
          'smoothing out behind them until the surface forgets they passed. '
          'Whatever the day held for them — good winds or hard ones — it is '
          'over now, and the harbor takes them all the same.\n\n'
          'You find a bench at the end of the pier, wood worn smooth by '
          'years of people doing exactly what you are doing: sitting down, '
          'setting the day beside them, and letting it be finished.\n\n'
          'So set yours down too. '
          'The things you did well. '
          'The things you would do differently. '
          'They can all wait on the bench until morning — none of them need '
          'you tonight.\n\n'
          'The tide moves under the pier, in and out, patient as breathing. '
          'You let your own breath slow to match it. '
          'In, as the water gathers. '
          'Out, as it eases back. '
          '«Beside you, {companion} has gone still, breathing the same slow '
          'rhythm. »'
          'Again. '
          'In... and out.\n\n'
          'The lanterns blur a little at the edges. '
          'The rocking of the water settles into your shoulders, your arms, '
          'the backs of your eyes.\n\n'
          'Far out past the harbor mouth, the first stars are surfacing, '
          'quiet as fish rising in dark water. '
          'You do not need to count them. '
          'They will keep watch tonight.\n\n'
          'The harbor holds the boats. '
          'The night holds the harbor. '
          'And sleep, arriving softly now like a tide you do not have to '
          'swim against, holds you.\n\n'
          'Rest well, {name}.',
      isEnding: true,
    ),
  },
);

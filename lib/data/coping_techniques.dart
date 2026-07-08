// lib/data/coping_techniques.dart
//
// Pre-built coping technique scripts for the Coping Toolbox and the
// in-story "Try it with [hero]!" break. Each technique is a sequence of
// timed steps the practice widget animates and (optionally) speaks.
//
// Two registers live here:
//  - The young set (ages 6-12) — short cycles, simple language, concrete
//    imagery. Sprout reuses Belly Breath only via the in-story break.
//  - The teen set (ages 13-17, Creator/Adolescent) — same practice
//    machinery, reframed language: no cartoon imagery, evidence-flavored
//    descriptions, techniques teens actually recognize (box breathing,
//    physiological sigh, body scan). Pick via [copingTechniquesForAge].

/// A single beat inside a coping technique — one breath, one trace, one
/// grounding prompt. The widget renders the label/cue and animates for the
/// given duration before advancing to the next step.
class CopingStep {
  /// Big-text headline shown in the practice sheet (e.g. "Breathe in").
  final String label;

  /// Smaller cue line that explains *how* (e.g. "through your nose, slow").
  final String? cue;

  /// How long the widget animates this beat. Tuned to be developmentally
  /// realistic — a 7yo cannot hold a 10-second exhale.
  final Duration duration;

  /// Drives the visual animation (orb expanding for breathe-in, contracting
  /// for breathe-out, paused for hold, prompt-only for grounding steps).
  final CopingAction action;

  const CopingStep({
    required this.label,
    required this.duration,
    required this.action,
    this.cue,
  });
}

enum CopingAction {
  breatheIn,   // orb expands, soft inhale sound
  breatheOut,  // orb contracts, soft exhale sound
  hold,        // orb pulses, no movement
  prompt,      // no animation — pure instruction (grounding steps)
}

/// One pre-built coping technique. Steps repeat [cycles] times.
class CopingTechnique {
  final String id;
  final String name;        // "Dragon's Breath"
  final String emoji;
  final String tagline;     // shown on the toolbox card under the name
  final String description; // shown on the practice sheet intro screen
  final List<CopingStep> steps;
  final int cycles;
  /// Color seed for the practice orb. Picked per-technique for vibe match
  /// (red/orange for fiery dragon, blue for calm belly, etc.).
  final int colorSeed;

  /// Cooler, less-babyish label for ages ~9+ (Adventurer and up). Same
  /// exercise — just the name a 12-year-old won't roll their eyes at
  /// ("Belly Breath" -> "Steady Breath"). Optional; falls back to [name].
  final String? olderName;

  /// Teen-register (13+) copy overrides for techniques that appear in both
  /// sets (currently 5-4-3-2-1). The name swap starts at 9 ([olderName])
  /// because Adventurers eye-roll at babyish *labels*; the full tagline/
  /// description reframe waits until 13 because the younger copy is what
  /// shipped for 9-12 and reads fine there. Optional; fall back to base.
  final String? olderTagline;
  final String? olderDescription;

  const CopingTechnique({
    required this.id,
    required this.name,
    required this.emoji,
    required this.tagline,
    required this.description,
    required this.steps,
    this.cycles = 3,
    required this.colorSeed,
    this.olderName,
    this.olderTagline,
    this.olderDescription,
  });

  /// Band-appropriate display name. 9+ gets [olderName] when set.
  String nameForAge(int age) =>
      (age >= 9 && olderName != null) ? olderName! : name;

  /// Band-appropriate tagline / description. 13+ (Creator/Adolescent) gets
  /// the teen-register copy when set.
  String taglineForAge(int age) =>
      (age >= teenCopingAge && olderTagline != null) ? olderTagline! : tagline;
  String descriptionForAge(int age) =>
      (age >= teenCopingAge && olderDescription != null)
          ? olderDescription!
          : description;

  /// Total duration of one full practice (all cycles).
  Duration get totalDuration {
    final perCycle = steps.fold<Duration>(
      Duration.zero,
      (sum, step) => sum + step.duration,
    );
    return perCycle * cycles;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Technique library
// ─────────────────────────────────────────────────────────────────────────────

/// Age at which the teen set + teen-register copy kick in. Mirrors the
/// Creator-band floor in `ageBandFromAge` (≤12 is Adventurer) — kept as a
/// local const so this file stays a pure-data module with no theme import.
const int teenCopingAge = 13;

/// The young set (6-12): playful, concrete imagery.
const allCopingTechniques = <CopingTechnique>[
  copingDragonBreath,
  copingBellyBreath,
  copingStarBreath,
  copingVolcanoBreath,
  copingHotCocoaBreath,
  copingGrounding54321,
];

/// The teen set (13-17, Creator/Adolescent): the "reframed-language
/// techniques" the toolbox gate in life_quest_screen was waiting on.
/// 5-4-3-2-1 appears in both sets (same object, teen copy via older*).
const teenCopingTechniques = <CopingTechnique>[
  copingBoxBreath,
  copingPhysioSigh,
  copingBodyScan,
  copingGrounding54321,
];

/// Band-appropriate technique list for the Coping Toolbox / Reset kit.
List<CopingTechnique> copingTechniquesForAge(int age) =>
    age >= teenCopingAge ? teenCopingTechniques : allCopingTechniques;

/// Lookup by id across BOTH sets — in-story coping breaks reference ids
/// from either register. Returns null if not found.
CopingTechnique? copingById(String id) {
  for (final t in allCopingTechniques) {
    if (t.id == id) return t;
  }
  for (final t in teenCopingTechniques) {
    if (t.id == id) return t;
  }
  return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🐉 Dragon's Breath — for big mad feelings
// ═══════════════════════════════════════════════════════════════════════════════

const copingDragonBreath = CopingTechnique(
  id: 'dragon_breath',
  name: "Dragon's Breath",
  emoji: '🐉',
  tagline: 'Breathe out the fire.',
  description:
      "When the mad feeling gets really big, dragons let it out as fire. "
      "Breathe in like you're filling up your dragon belly — then breathe "
      "out long and hot, like a roar of warm air. The fire whooshes away "
      "and takes the mad with it.",
  colorSeed: 0xFFFF6B3D, // dragon-fire orange
  cycles: 3,
  steps: [
    CopingStep(
      label: 'Breathe in',
      cue: 'through your nose — fill up like a dragon',
      duration: Duration(seconds: 4),
      action: CopingAction.breatheIn,
    ),
    CopingStep(
      label: 'HOLD',
      cue: 'feel the fire ready',
      duration: Duration(seconds: 1),
      action: CopingAction.hold,
    ),
    CopingStep(
      label: 'ROOOAR!',
      cue: 'breathe out long and hot through your mouth',
      duration: Duration(seconds: 6),
      action: CopingAction.breatheOut,
    ),
  ],
);

// ═══════════════════════════════════════════════════════════════════════════════
// 🎈 Belly Breath — for worried / wobbly feelings
// ═══════════════════════════════════════════════════════════════════════════════

const copingBellyBreath = CopingTechnique(
  id: 'belly_breath',
  name: 'Belly Breath',
  olderName: 'Steady Breath',
  emoji: '🎈',
  tagline: 'Fill up like a balloon.',
  description:
      "Put one hand on your belly. Breathe in slow and watch your belly "
      "fill up like a balloon. Then breathe out and watch it gently go "
      "back down. Slow belly-breaths tell your body, 'It's okay. We're "
      "safe.'",
  colorSeed: 0xFF7CB9E8, // soft balloon blue
  cycles: 4,
  steps: [
    CopingStep(
      label: 'Breathe in',
      cue: 'fill your belly like a balloon',
      duration: Duration(seconds: 4),
      action: CopingAction.breatheIn,
    ),
    CopingStep(
      label: 'Breathe out',
      cue: 'let the balloon go down slowly',
      duration: Duration(seconds: 4),
      action: CopingAction.breatheOut,
    ),
  ],
);

// ═══════════════════════════════════════════════════════════════════════════════
// ⭐ Star Breath — for any big feeling, very visual
// ═══════════════════════════════════════════════════════════════════════════════

const copingStarBreath = CopingTechnique(
  id: 'star_breath',
  name: 'Star Breath',
  olderName: 'Reset Breath',
  emoji: '⭐',
  tagline: 'Trace a star with your finger.',
  description:
      "Hold one hand up like a starfish. With your other finger, trace up "
      "one side of a star — breathe in. Trace down the other side — breathe "
      "out. Five points, five breaths. By the end, the bright feeling is "
      "smaller, and you are right here.",
  colorSeed: 0xFFFFD54F, // starlight gold
  cycles: 5,
  steps: [
    CopingStep(
      label: 'Trace UP',
      cue: 'breathe in as your finger goes up',
      duration: Duration(seconds: 3),
      action: CopingAction.breatheIn,
    ),
    CopingStep(
      label: 'Trace DOWN',
      cue: 'breathe out as your finger comes down',
      duration: Duration(seconds: 3),
      action: CopingAction.breatheOut,
    ),
  ],
);

// ═══════════════════════════════════════════════════════════════════════════════
// 🌋 Volcano Breath — for releasing big body energy
// ═══════════════════════════════════════════════════════════════════════════════

const copingVolcanoBreath = CopingTechnique(
  id: 'volcano_breath',
  name: 'Volcano Breath',
  emoji: '🌋',
  tagline: 'Whoosh the big feeling out.',
  description:
      "Hands together at your heart. Breathe in slow — pressure building. "
      "Then PUSH your hands up over your head like a volcano erupting and "
      "let your breath whoosh out. Wave your arms back down to your sides. "
      "All that big stuck energy — gone, like steam.",
  colorSeed: 0xFFE57373, // volcano red
  cycles: 3,
  steps: [
    CopingStep(
      label: 'Hands at your heart',
      cue: 'breathe in slow',
      duration: Duration(seconds: 4),
      action: CopingAction.breatheIn,
    ),
    CopingStep(
      label: 'ERUPT! 🌋',
      cue: 'hands shoot up — whoosh out',
      duration: Duration(seconds: 5),
      action: CopingAction.breatheOut,
    ),
  ],
);

// ═══════════════════════════════════════════════════════════════════════════════
// ☕ Hot Cocoa Breath — for soothing / settling
// ═══════════════════════════════════════════════════════════════════════════════

const copingHotCocoaBreath = CopingTechnique(
  id: 'hot_cocoa_breath',
  name: 'Hot Cocoa Breath',
  olderName: 'Cool-Down Breath',
  emoji: '☕',
  tagline: 'Smell it, then cool it.',
  description:
      "Cup your hands like you're holding a warm mug of cocoa. Breathe in "
      "slow through your nose — mmm, cocoa smell. Then breathe out gently "
      "through your mouth to cool it down. Don't burn your tongue! Cozy "
      "and slow.",
  colorSeed: 0xFFA1887F, // cocoa brown
  cycles: 3,
  steps: [
    CopingStep(
      label: 'Smell the cocoa',
      cue: 'breathe in through your nose',
      duration: Duration(seconds: 4),
      action: CopingAction.breatheIn,
    ),
    CopingStep(
      label: 'Cool it down',
      cue: 'breathe out gently through your mouth',
      duration: Duration(seconds: 6),
      action: CopingAction.breatheOut,
    ),
  ],
);

// ═══════════════════════════════════════════════════════════════════════════════
// 👀 5-4-3-2-1 — for panic / overwhelm / "I can't think"
// ═══════════════════════════════════════════════════════════════════════════════

const copingGrounding54321 = CopingTechnique(
  id: 'grounding_54321',
  name: '5-4-3-2-1',
  olderName: '5-4-3-2-1 Grounding',
  emoji: '👀',
  tagline: 'Find your way back here.',
  olderTagline: 'Come back to right now.',
  description:
      "When everything feels too big, your body forgets where you are. "
      "This is a tiny treasure hunt that brings you back. Look around. "
      "Each step pulls you a little more into right-now, where you're "
      "safe.",
  olderDescription:
      "When your head is spinning, your senses are the fastest road back. "
      "Work through them one at a time — it interrupts the spiral by "
      "giving your brain something real to hold onto.",
  colorSeed: 0xFF81C784, // grounded green
  cycles: 1,
  steps: [
    CopingStep(
      label: '5 things you can SEE',
      cue: 'look around — what colors, shapes, lights?',
      duration: Duration(seconds: 12),
      action: CopingAction.prompt,
    ),
    CopingStep(
      label: '4 things you can HEAR',
      cue: 'close your eyes — what sounds are around you?',
      duration: Duration(seconds: 10),
      action: CopingAction.prompt,
    ),
    CopingStep(
      label: '3 things you can TOUCH',
      cue: 'feel your clothes, your chair, the floor',
      duration: Duration(seconds: 8),
      action: CopingAction.prompt,
    ),
    CopingStep(
      label: '2 things you can SMELL',
      cue: 'soap on your hands? snack? fresh air?',
      duration: Duration(seconds: 8),
      action: CopingAction.prompt,
    ),
    CopingStep(
      label: '1 thing you can TASTE',
      cue: 'just notice your mouth — that counts',
      duration: Duration(seconds: 6),
      action: CopingAction.prompt,
    ),
  ],
);

// ═══════════════════════════════════════════════════════════════════════════════
// Teen set (13-17) — reframed register, no cartoon imagery.
// ═══════════════════════════════════════════════════════════════════════════════

// 🟦 Box Breath — focus / steadiness before pressure moments
const copingBoxBreath = CopingTechnique(
  id: 'box_breath',
  name: 'Box Breath',
  emoji: '🟦',
  tagline: 'Four counts a side. Steady.',
  description:
      "Breathe around a square: in for 4, hold 4, out 4, hold 4. Pilots "
      "and pro athletes use it before high-pressure moments — the even "
      "count gives your mind one simple thing to track while your body "
      "settles.",
  colorSeed: 0xFF4DB6AC, // steady teal
  cycles: 4,
  steps: [
    CopingStep(
      label: 'Breathe in',
      cue: 'count 4 — up one side of the square',
      duration: Duration(seconds: 4),
      action: CopingAction.breatheIn,
    ),
    CopingStep(
      label: 'Hold',
      cue: 'count 4 — across the top',
      duration: Duration(seconds: 4),
      action: CopingAction.hold,
    ),
    CopingStep(
      label: 'Breathe out',
      cue: 'count 4 — down the other side',
      duration: Duration(seconds: 4),
      action: CopingAction.breatheOut,
    ),
    CopingStep(
      label: 'Hold',
      cue: 'count 4 — along the bottom',
      duration: Duration(seconds: 4),
      action: CopingAction.hold,
    ),
  ],
);

// 🌊 Physiological Sigh — fastest downshift when stress spikes
const copingPhysioSigh = CopingTechnique(
  id: 'physio_sigh',
  name: 'Physiological Sigh',
  emoji: '🌊',
  tagline: 'The fastest reset there is.',
  description:
      "Two inhales through your nose — one big, then a short top-up — "
      "then one long, slow exhale through your mouth. It's the quickest "
      "known way to dial your body's stress response down. Two or three "
      "rounds is plenty.",
  colorSeed: 0xFF64B5F6, // cool blue
  cycles: 3,
  steps: [
    CopingStep(
      label: 'Breathe in',
      cue: 'through your nose, most of the way full',
      duration: Duration(seconds: 2),
      action: CopingAction.breatheIn,
    ),
    CopingStep(
      label: 'Top it up',
      cue: 'one more short sip of air',
      duration: Duration(seconds: 1),
      action: CopingAction.breatheIn,
    ),
    CopingStep(
      label: 'Long exhale',
      cue: 'slow, through your mouth — all the way out',
      duration: Duration(seconds: 6),
      action: CopingAction.breatheOut,
    ),
  ],
);

// 🧍 Body Scan — find and release parked tension (salvaged from the
// retired coping_strategy_library; rebuilt on the CopingStep model)
const copingBodyScan = CopingTechnique(
  id: 'body_scan',
  name: 'Body Scan',
  emoji: '🧍',
  tagline: 'Find where the stress is hiding.',
  description:
      "Tension parks itself in your body — jaw, shoulders, hands — long "
      "before you notice it. Move your attention downward and let each "
      "spot go loose. Nothing to force; just notice, soften, move on.",
  colorSeed: 0xFF9575CD, // dusk violet
  cycles: 1,
  steps: [
    CopingStep(
      label: 'Jaw + face',
      cue: 'unclench your teeth, let your face go slack',
      duration: Duration(seconds: 10),
      action: CopingAction.prompt,
    ),
    CopingStep(
      label: 'Shoulders',
      cue: 'let them drop away from your ears',
      duration: Duration(seconds: 10),
      action: CopingAction.prompt,
    ),
    CopingStep(
      label: 'Hands',
      cue: 'uncurl your fingers, let them go heavy',
      duration: Duration(seconds: 10),
      action: CopingAction.prompt,
    ),
    CopingStep(
      label: 'Chest + belly',
      cue: 'send one slow breath into any tight spot',
      duration: Duration(seconds: 10),
      action: CopingAction.prompt,
    ),
    CopingStep(
      label: 'Legs + feet',
      cue: 'notice the floor holding you up',
      duration: Duration(seconds: 10),
      action: CopingAction.prompt,
    ),
  ],
);

// lib/data/coping_techniques.dart
//
// Pre-built coping technique scripts for the Coping Toolbox and the
// in-story "Try it with [hero]!" break. Each technique is a sequence of
// timed steps the practice widget animates and (optionally) speaks.
//
// Authored for ages 6-8 (Explorer band) — short cycles, simple language,
// concrete imagery. Sprout reuses Belly Breath only via the in-story break.

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

  const CopingTechnique({
    required this.id,
    required this.name,
    required this.emoji,
    required this.tagline,
    required this.description,
    required this.steps,
    this.cycles = 3,
    required this.colorSeed,
  });

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

const allCopingTechniques = <CopingTechnique>[
  copingDragonBreath,
  copingBellyBreath,
  copingStarBreath,
  copingVolcanoBreath,
  copingHotCocoaBreath,
  copingGrounding54321,
];

/// Lookup by id — returns null if not found.
CopingTechnique? copingById(String id) {
  for (final t in allCopingTechniques) {
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
  emoji: '👀',
  tagline: 'Find your way back here.',
  description:
      "When everything feels too big, your body forgets where you are. "
      "This is a tiny treasure hunt that brings you back. Look around. "
      "Each step pulls you a little more into right-now, where you're "
      "safe.",
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

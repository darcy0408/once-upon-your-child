// lib/superhero_name_generator.dart
// Therapeutic superhero idea generator focused on playful emotional support.

import 'dart:math';

/// Represents a complete superhero concept tailored to a therapeutic focus.
class SuperheroIdea {
  final String name;
  final String powerTheme;
  final String mission;
  final String catchPhrase;
  final String supportAction;
  final String focusArea;

  const SuperheroIdea({
    required this.name,
    required this.powerTheme,
    required this.mission,
    required this.catchPhrase,
    required this.supportAction,
    required this.focusArea,
  });

  Map<String, String> toMap() => {
        'name': name,
        'powerTheme': powerTheme,
        'mission': mission,
        'catchPhrase': catchPhrase,
        'supportAction': supportAction,
        'focusArea': focusArea,
      };
}

class SuperheroNameGenerator {
  static final Random _random = Random();

  static final List<_SuperheroArchetype> _archetypes = [
    _SuperheroArchetype(
      id: 'friendship',
      focusArea: 'Making Friends',
      keywords: [
        'friend',
        'friendship',
        'lonely',
        'alone',
        'social',
        'shy',
        'kindness',
      ],
      heroNames: [
        'Captain High-Five',
        'The Buddy Beam',
        'Connector Comet',
        'Giggle Guardian',
        'Handshake Hurricane',
        'Circle Maker',
      ],
      powers: [
        'Super-charged icebreakers',
        'Friendship radar that spots fellow kind kids',
        'High-five force fields that welcome everyone in',
        'Giggle-powered conversation starters',
        'Confidence confetti that says “come play with us!”',
      ],
      missions: [
        'turn awkward silences into laugh-out-loud moments',
        'make sure every lunch table has room for one more friend',
        'help shy heroes brave the first hello',
        'spark buddy adventures on the playground',
      ],
      catchPhrases: [
        'No kid sits alone on my watch!',
        'Friendship powers: activate!',
        'Let’s make the circle wider!',
        'Capes are optional, kindness is mandatory!',
      ],
      supportActions: [
        'Leads a “three compliments in three minutes” challenge.',
        'Hands out bravery buttons for saying hello.',
        'Teaches a secret handshake that anyone can learn in seconds.',
        'Creates a shared joke jar to break the ice.',
      ],
    ),
    _SuperheroArchetype(
      id: 'calm',
      focusArea: 'Big Worries & Anxiety',
      keywords: [
        'anxiety',
        'worried',
        'nervous',
        'panic',
        'stress',
        'scared',
        'overwhelm',
        'overwhelmed',
      ],
      heroNames: [
        'Captain Calm-Down',
        'The Soothing Cyclone',
        'Breath Blazer',
        'Serenity Sprinter',
        'Bubble-Barrier Buddy',
        'Zen Zebra',
      ],
      powers: [
        'Mega-deep-breath bubbles that float away worries',
        'Calming sparkle shields that hush noisy thoughts',
        'Mindful music waves that slow everything down',
        'Grounding stomp boots that keep feet planted and hearts steady',
      ],
      missions: [
        'shrink worry monsters down to cartoon-size',
        'teach super breathing before big feelings burst',
        'turn shaking knees into steady steps',
        'help heroes feel safe before any quest',
      ],
      catchPhrases: [
        'In through the nose, out through the cape!',
        'Worry clouds don’t stand a chance.',
        'One breath at a time, teammate.',
        'Feelings are big, but we are bigger.',
      ],
      supportActions: [
        'Blows a glitter bubble and asks kids to trace it with their breathing.',
        'Hands out “calm cards” with silly grounding prompts.',
        'Leads a “wiggle-wiggle-freeze” exercise to reset tense muscles.',
        'Shows how to park a worry in an imaginary cloud locker for later.',
      ],
    ),
    _SuperheroArchetype(
      id: 'confidence',
      focusArea: 'Confidence & Bravery',
      keywords: [
        'confidence',
        'brave',
        'courage',
        'fear',
        'presentation',
        'test',
        'stage',
        'performance',
      ],
      heroNames: [
        'Boost Brigade Leader',
        'The Brave Beacon',
        'Pep-Talk Paladin',
        'Captain Can-Do',
        'Super Spark Starter',
        'Major Momentum',
      ],
      powers: [
        'Pep-talk megaphones that blast encouragement',
        'Armor made of past victories',
        'Courage capes that grow brighter with every try',
        'Positivity boomerangs that bounce doubts away',
      ],
      missions: [
        'turn “I can’t” into “I’ll try”',
        'remind heroes of the times they already showed courage',
        'celebrate brave attempts louder than perfect scores',
        'spot secret strengths hiding in plain sight',
      ],
      catchPhrases: [
        'We don’t chase perfection—we celebrate progress!',
        'Confidence mode: ON.',
        'Every brave step counts!',
        'You already have the spark—let’s turn it into fireworks!',
      ],
      supportActions: [
        'Leads a power-pose parade before tough moments.',
        'Hands out “I tried something new today” stickers.',
        'Coaches kids to list three super skills they already have.',
        'Scripts a silly cheer for every small win.',
      ],
    ),
    _SuperheroArchetype(
      id: 'big-feelings',
      focusArea: 'Big Feelings & Anger',
      keywords: [
        'anger',
        'mad',
        'frustrated',
        'meltdown',
        'explode',
        'rage',
        'temper',
        'big feelings',
      ],
      heroNames: [
        'The Chill Volcano',
        'Captain Cool-Down',
        'Storm Tamer',
        'Mood Moose',
        'Lightning Listener',
        'Tempest Tapper',
      ],
      powers: [
        'Mood thermometers that glow when feelings rise',
        'Silly stomp dances that shake out extra energy',
        'Listening lightning bolts that zap cranky thoughts',
        'Calm-down clouds that rain giggle drops',
      ],
      missions: [
        'help big feelings speak without shouting',
        'turn furious fists into creative fists-bumps',
        'teach heroes how to press the pause button',
        'make space where every feeling gets heard',
      ],
      catchPhrases: [
        'Hot feelings, cool moves.',
        'Pause. Breathe. Pow-wow.',
        'Let’s listen to what the roar is really saying.',
        'We can turn a volcano into a campfire.',
      ],
      supportActions: [
        'Builds a feelings playlist—one song for each emotion.',
        'Leads a “name it, tame it, reframe it” chant.',
        'Hands out squish-stars for squeezing instead of shouting.',
        'Helps create a calm corner packed with sensory tools.',
      ],
    ),
  ];

  static final List<String> _quirkyBoosters = [
    'cape stitched from shimmering motivational posters',
    'gadget belt filled with glitter glue and grounding cards',
    'sidekick therapy llama named “Hugbug”',
    'pocket full of glow-stick medals for bravery',
    'hoverboard powered by belly laughs',
    'utility pouch stocked with talking stress balls',
    'boots that leave pep-talk footprints',
  ];

  /// Generates a superhero concept tailored to the provided challenge.
  /// If [challenge] is omitted, a random supportive archetype is used.
  static SuperheroIdea generateCompleteIdea({String? challenge}) {
    final archetype = _chooseArchetype(challenge);
    final name = _pick(archetype.heroNames);
    final power = _pick(archetype.powers);
    final mission = _decorateWithQuirk(_pick(archetype.missions));
    final catchPhrase = _pick(archetype.catchPhrases);
    final supportAction = _pick(archetype.supportActions);

    return SuperheroIdea(
      name: name,
      powerTheme: power,
      mission: mission,
      catchPhrase: catchPhrase,
      supportAction: supportAction,
      focusArea: archetype.focusArea,
    );
  }

  /// Returns multiple ideas that share the same focus area, useful for choice UIs.
  static List<SuperheroIdea> generateIdeas({
    String? challenge,
    int count = 3,
  }) {
    final ideas = <SuperheroIdea>[];
    for (var i = 0; i < count; i++) {
      ideas.add(generateCompleteIdea(challenge: challenge));
    }
    return ideas;
  }

  static _SuperheroArchetype _chooseArchetype(String? challenge) {
    if (challenge == null || challenge.trim().isEmpty) {
      return _pick(_archetypes);
    }
    final lower = challenge.toLowerCase();
    for (final archetype in _archetypes) {
      final match = archetype.keywords.any(lower.contains);
      if (match) return archetype;
    }
    return _pick(_archetypes);
  }

  static T _pick<T>(List<T> list) => list[_random.nextInt(list.length)];

  static String _decorateWithQuirk(String mission) {
    if (_random.nextBool()) {
      final booster = _pick(_quirkyBoosters);
      return '$mission using a $booster.';
    }
    return mission;
  }
}

class _SuperheroArchetype {
  final String id;
  final String focusArea;
  final List<String> keywords;
  final List<String> heroNames;
  final List<String> powers;
  final List<String> missions;
  final List<String> catchPhrases;
  final List<String> supportActions;

  const _SuperheroArchetype({
    required this.id,
    required this.focusArea,
    required this.keywords,
    required this.heroNames,
    required this.powers,
    required this.missions,
    required this.catchPhrases,
    required this.supportActions,
  });
}

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

/// Reader register for the funny-name picker (B2). Sprout keeps its
/// auto-generated formula name and never reaches this generator — only
/// Explorer (6-8), Adventurer (9-12), and Adolescent (15-17) pick a "cool"
/// funny name.
enum HeroNameRegister { explorer, adventurer, adolescent }

/// Generates COOL, kid-safe superhero codenames for the Explorer/Adventurer/
/// Adolescent funny-name picker (Chunk B2). These pools are intentionally
/// separate from the therapeutic [SuperheroNameGenerator] archetype names
/// ("Captain High-Five"), which read too young for 9-12s. Names here are
/// playful but not cutesy ("The Quiet Storm", "Nightcircuit", "Sir
/// Reacts-a-Lot"). The Adolescent pool goes a notch older and darker — a
/// neo-noir / prestige-YA register fit for a teen antihero living a double
/// life ("Nightjar", "The Static", "Halflight").
///
/// Determinism: when an optional [Random] (seeded) is supplied the output is
/// reproducible, which the sanity test relies on.
class HeroFunnyNameGenerator {
  static final Random _defaultRandom = Random();

  // Explorer 6-8 — a touch cooler than the therapeutic pool, still warm and
  // approachable. Wholesome, no scary/edgy connotations.
  static const List<String> explorerNames = [
    'Captain Can-Do',
    'The Bright Spark',
    'Major Marvel',
    'Sir Bounce-a-Lot',
    'The Kind Comet',
    'Turbo Tucker',
    'The Helpful Hurricane',
    'Captain Curious',
    'The Cheerful Charge',
    'Doctor Dazzle',
    'The Brave Beacon',
    'Zippy Justice',
  ];

  // Adventurer 9-12 — genuinely cool OR genuinely funny codenames a tween would
  // love and never find babyish. Playful wordplay welcome; still wholesome and
  // kid-safe (no violence / no combat-implying names). The deadpan, adult-ironic
  // entries (Doctor Deadpan, The Unbothered, The Slow Clap, Midnight Reasonable)
  // were dropped — a 9-12 doesn't read them as cool, just confusing.
  static const List<String> adventurerNames = [
    // Cool codenames.
    'The Quiet Storm',
    'Nightcircuit',
    'The Velvet Bolt',
    'Echo Vanguard',
    'The Last Word',
    'Static Fox',
    'The Calm Current',
    'Riddlewing',
    'Shadow Fox',
    'Neon Nova',
    'Sky Falcon',
    'Star Sentinel',
    'The Wonderbolt',
    // Tech / gadget.
    'Pixel Power',
    'Circuit Kid',
    'Gizmo Guardian',
    'Glitch Fixer',
    // Funny / playful.
    'Sir Reacts-a-Lot',
    'Captain Clutch',
    'Bubble Blast',
    'Major Marshmallow',
    'The Amazing Achoo',
    'The Human Hiccup',
    'Super Sock',
    'Power Panda',
    'The Brave Badger',
  ];

  // Adolescent 15-17 — neo-noir / prestige-YA. Understated, grounded,
  // morally-grey, alias-like; the codename a teenager leading a double life
  // would actually pick. No "Captain/Sir/Major/Doctor", no goofy alliteration,
  // no cutesy/wholesome tone, no power-explicit names. Still strictly kid-safe:
  // no violence, weapons, drugs, gore, or edgelord shock — just darker mood.
  static const List<String> adolescentNames = [
    'Nightjar',
    'The Static',
    'Cipher',
    'Halflight',
    'Greyline',
    'The Tally',
    'Holloway',
    'Nocturne',
    'The Undertow',
    'Ashen',
    'Tessellate',
    'The Long Hush',
  ];

  // Explorer 6-8 catchphrase pool (MT-284). Early readers (ages 6-8) decode
  // short, common, phonetically simple words — so these lines stay punchy and
  // sound-it-out friendly. They intentionally DROP the therapeutic-adult
  // phrasing that leaks from [SuperheroNameGenerator]'s archetype catchPhrases
  // ("We don't chase perfection—we celebrate progress!", "Feelings are big,
  // but we are bigger.") which read as grown-up coping scripts, not something a
  // 6-year-old hero would shout. Stable pool: no big words, no em-dashes, no
  // abstract feelings vocabulary — just brave, cheerful hero energy.
  static const List<String> explorerCatchphrases = [
    'To the rescue!',
    'Here I come!',
    'I can help!',
    'Time to be brave!',
    'Up, up, and go!',
    'I never give up!',
    'Hero power, on!',
    "Let's go, team!",
    "I've got this!",
    'Watch me shine!',
    'Ready for action!',
    'Kind and brave!',
  ];

  /// Returns [count] DISTINCT Explorer (6-8) catchphrases, drawn from the
  /// stable, decodable [explorerCatchphrases] pool (MT-284). Mirrors
  /// [pickNames]: pass a seeded [random] for reproducible output, and if the
  /// pool is smaller than [count] the whole (shuffled) pool is returned.
  static List<String> pickExplorerCatchphrases({
    int count = 4,
    Random? random,
  }) {
    final rng = random ?? _defaultRandom;
    final pool = List<String>.from(explorerCatchphrases);
    pool.shuffle(rng);
    final n = count < pool.length ? count : pool.length;
    return pool.sublist(0, n);
  }

  static List<String> _poolFor(HeroNameRegister register) {
    switch (register) {
      case HeroNameRegister.explorer:
        return explorerNames;
      case HeroNameRegister.adventurer:
        return adventurerNames;
      case HeroNameRegister.adolescent:
        return adolescentNames;
    }
  }

  /// Returns [count] DISTINCT funny names for the given [register]. If the
  /// pool is smaller than [count] the whole (shuffled) pool is returned.
  /// Pass a seeded [random] for reproducible output.
  static List<String> pickNames(
    HeroNameRegister register, {
    int count = 3,
    Random? random,
  }) {
    final rng = random ?? _defaultRandom;
    final pool = List<String>.from(_poolFor(register));
    pool.shuffle(rng);
    final n = count < pool.length ? count : pool.length;
    return pool.sublist(0, n);
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

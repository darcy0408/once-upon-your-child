import '../theme/age_band_theme.dart';
import '../theme/age_band_asset_resolver.dart';

class ScenarioCard {
  final String id;
  final String emoji;
  final String title;
  final String illustration;
  final String description;
  final String conflictHook;
  final String sensoryPalette;
  final String category; // 'Magical Worlds' or 'Real-Life Heroes'
  final AgeBand? minBand; // null = all ages; set = only shown for this band and above
  final String worldBible; // Rich world description for AI consistency
  // Sprout-band (ages 2-5) specific wording — even simpler than youngTitle, and
  // matched to the sproutIllustration tile image shown in the setting picker.
  final String? sproutTitle;
  final String? sproutDescription;
  // Age-appropriate alternatives for younger children (ages 6-8, Explorer band)
  final String? youngTitle;
  final String? youngDescription;
  final String? youngConflictHook;
  final String? youngWorldBible;
  // Age-appropriate alternatives for tweens/teens (ages 10+)
  final String? matureTitle;
  final String? matureDescription;
  final String? matureConflictHook;
  final String? matureWorldBible;
  // Age-appropriate alternative for creator band (ages 12-14) — more personal/identity-focused
  // than the adult mature framing, less whimsical than the young framing.
  // When null, falls back to matureTitle.
  final String? creatorTitle;
  // Thematic / psychological hook shown on scenario cards for Creator band.
  // A single evocative question that draws 12-14 year-olds in emotionally.
  // When null, no thematic question is shown.
  final String? creatorThematicQuestion;
  // Age-appropriate alternative for adult band (ages 18+) — existential/philosophical framing.
  // When null, falls back to matureTitle.
  final String? adultTitle;
  // Adult-band world bible — richer, psychologically grounded setting lore for 18+.
  // When null, worldBibleForAge falls back to matureWorldBible then worldBible.
  final String? adultWorldBible;
  // Evocative introspective question shown on scenario cards for the adult band (18+).
  // Mirrors creatorThematicQuestion but pitched at adult emotional complexity.
  // When null, no thematic question overlay is shown.
  final String? adultThematicQuestion;
  final bool featured; // Pinned at the top of scenario selection
  // Sprout-band (ages 2-5) specific tile image, displayed instead of the
  // general illustration when the child is in the sprout band.
  final String? sproutIllustration;
  // Per-band scene art from age_band_assets/.
  // youngBandSceneId  → used for explorer band (ages 6-8); file stem in early_readers/scenes/.
  // olderBandSceneId  → used for adventurer+ (ages 9+); file stem in adventurers/scenes/ and above.
  // Both are optional — falls back to illustration when null.
  final String? youngBandSceneId;
  final String? olderBandSceneId;

  const ScenarioCard({
    required this.id,
    required this.emoji,
    required this.title,
    required this.illustration,
    required this.description,
    required this.conflictHook,
    required this.sensoryPalette,
    this.category = 'Magical Worlds',
    this.minBand,
    this.featured = false,
    this.worldBible = '',
    this.sproutTitle,
    this.sproutDescription,
    this.youngTitle,
    this.youngDescription,
    this.youngConflictHook,
    this.youngWorldBible,
    this.matureTitle,
    this.matureDescription,
    this.matureConflictHook,
    this.matureWorldBible,
    this.creatorTitle,
    this.creatorThematicQuestion,
    this.adultTitle,
    this.adultWorldBible,
    this.adultThematicQuestion,
    this.sproutIllustration,
    this.youngBandSceneId,
    this.olderBandSceneId,
  });

  /// Get the title appropriate for the given age.
  String titleForAge(int age) {
    // Sprout band (ages 2-5) gets its own tile-matched wording when available.
    if (age <= 5 && sproutTitle != null) return sproutTitle!;
    // Explorer band (ages 6-8) gets the young/accessible version.
    if (age <= 8 && youngTitle != null) return youngTitle!;
    // Creator band (ages 12-14) gets an identity-focused framing when available.
    if (age >= 12 && age <= 14 && creatorTitle != null) return creatorTitle!;
    // Adult band (ages 18+) gets existential framing when available.
    if (age >= 18 && adultTitle != null) return adultTitle!;
    // Ages 12+ get the mature title if defined; Adventurer (9-11) uses standard title.
    if (age >= 12 && matureTitle != null) return matureTitle!;
    return title;
  }

  /// Get the description appropriate for the given age.
  String descriptionForAge(int age) {
    // Sprout band (ages 2-5) gets its own tile-matched description when available.
    if (age <= 5 && sproutDescription != null) return sproutDescription!;
    if (age <= 8 && youngDescription != null) return youngDescription!;
    if (age >= 12 && matureDescription != null) return matureDescription!;
    return description;
  }

  /// Get the conflict hook appropriate for the given age.
  String conflictHookForAge(int age) {
    if (age <= 8 && youngConflictHook != null) return youngConflictHook!;
    if (age >= 12 && matureConflictHook != null) return matureConflictHook!;
    return conflictHook;
  }

  /// Get the world bible appropriate for the given age.
  String worldBibleForAge(int age) {
    if (age <= 8 && youngWorldBible != null) return youngWorldBible!;
    if (age >= 18 && adultWorldBible != null) return adultWorldBible!;
    if (age >= 12 && matureWorldBible != null) return matureWorldBible!;
    return worldBible;
  }

  /// Get the scenario title appropriate for the current age band.
  String titleForBand(AgeBand band) {
    switch (band) {
      case AgeBand.sprout:
        return sproutTitle ?? youngTitle ?? title;
      case AgeBand.explorer:
        return youngTitle ?? title;
      case AgeBand.adventurer:
        return title;
      case AgeBand.creator:
        // Creator band (12-14) gets identity-focused framing; falls back to matureTitle.
        return creatorTitle ?? matureTitle ?? title;
      case AgeBand.adolescent:
        return matureTitle ?? title;
      case AgeBand.adult:
        return adultTitle ?? matureTitle ?? title;
    }
  }

  /// Get the illustration path appropriate for the given age.
  /// Sprout (≤5): dedicated tile image. Explorer (6-8): youngBandSceneId art.
  /// Adventurer+ (≥9): olderBandSceneId art. Falls back to illustration.
  String illustrationForAge(int age) {
    if (age <= 5 && sproutIllustration != null) return sproutIllustration!;
    if (age <= 8 && youngBandSceneId != null) {
      return AgeBandAssetResolver.scenePath(AgeBand.explorer, youngBandSceneId!);
    }
    if (age >= 9 && olderBandSceneId != null) {
      return AgeBandAssetResolver.scenePath(AgeBand.adventurer, olderBandSceneId!);
    }
    return illustration;
  }
}

class ScenarioData {
  static const List<ScenarioCard> all = [
    // --- MAGICAL WORLDS ---
    ScenarioCard(
      id: 'doorway_seasons',
      emoji: '🚪',
      title: 'The Doorway Between Seasons',
      illustration: 'images/scenarios/magic_door.webp',
      description:
          'Each magic door leads to a different season. Can you find your way home?',
      conflictHook:
          'A glitch in the magic doors is mixing up winter and summer!',
      sensoryPalette:
          'Swirling leaves, changing temperatures, the smell of fresh rain and autumn wood.',
      category: 'Magical Worlds',
      worldBible:
          'A circular hall of four ornate doors — Spring (green vines), Summer (golden light), Autumn (amber leaves), Winter (frost crystals). Each door opens to a full landscape of that season. The Season Keeper, a gentle clock-like being, maintains balance. Creatures from each season (snowflake sprites, sunbeam foxes, leaf dancers, blossom bunnies) live in their own realm but visit the hall. Magic rule: carrying an object from one season into another causes playful chaos — snowballs bloom flowers, autumn leaves turn into butterflies.',
      sproutTitle: 'Zoom to the Stars!',
      sproutDescription: 'Hop in a rocket and fly up to the twinkly stars!',
      youngTitle: 'The Magic Door',
      youngDescription:
          'Open the magic door and see what fun season is waiting for you!',
      youngConflictHook:
          'Oops! The magic door opened to a silly season - snowflakes and sunflowers together!',
      youngWorldBible:
          'Four big colourful doors in a round room — a green one, a sunny one, an orange one, and a sparkly white one. Behind each door is a whole land full of that season! Friendly little animals live there — snow bunnies, sunshine birds, leaf puppies, and flower kittens. The kind Clock-Keeper makes sure everything works right.',
      matureTitle: 'The Temporal Threshold',
      matureDescription:
          'Ancient portals connect parallel timelines where seasons never end. Navigate the paradox.',
      matureConflictHook:
          'The timeline is fracturing—if you don\'t stabilize it, both worlds collapse into eternal winter.',
      matureWorldBible:
          'An ancient nexus chamber with four temporal gates, each a stable wormhole to a pocket dimension locked in perpetual season. The Chronokeeper, an ageless entity bound to a celestial orrery, regulates the energy exchange between realms. Each dimension has evolved its own civilisation adapted to eternal climate — the Winterhold with its ice-forged architecture, the Summerlands with solar-powered cities. Temporal physics: objects carried between gates retain their native time-signature, creating paradox-fields that must be resolved or they cascade into reality tears.',
      creatorTitle: "The Door You're Afraid to Open",
      creatorThematicQuestion: "What are you afraid to face?",
      adultTitle: "Doors We Can't Reopen",
      adultWorldBible:
          'The Nexus exists between what was and what might have been — a liminal hall of doors that no longer open. Each is sealed: a summer that ended too soon, a winter you never got to finish, a season you left before you understood what it was teaching you. The Chronokeeper no longer maintains these doors — it mourns them, cataloguing what each closed door cost the traveller who walked through it. The seasons themselves are not weather here; they are states of a relationship, a career, a version of yourself you outgrew before you were ready. Some doors are warm to the touch. Some have grown cold. Physics: you can press your ear to any door and hear an echo of what was — but opening them is not the work. The work is learning why you are still standing in the hall.',
      adultThematicQuestion: "Which door do you keep coming back to?",
      sproutIllustration: 'assets/images/ui/sprout/tiles/space.webp',
      youngBandSceneId: 'star_village',
      olderBandSceneId: 'ruined_citadel',
    ),
    ScenarioCard(
      id: 'volcano_dragons',
      emoji: '🐉',
      title: 'The Volcano of Sleeping Dragons',
      illustration: 'images/scenarios/sleeping_dragon.webp',
      description:
          'Wake the kindest dragon to stop the volcano from sneezing rainbow lava!',
      conflictHook:
          'The Fire-Sneeze Dragon is about to wake up and needs a gentle lullaby.',
      sensoryPalette:
          'Warm rumbling ground, the smell of toasted marshmallows, glowing embers.',
      category: 'Magical Worlds',
      worldBible:
          'A dormant volcano island with terraced ledges where dragons of all sizes sleep in nests of warm obsidian. The volcano rumbles gently like a purring cat. Inside, lava rivers flow in channels alongside walkable crystal bridges. Each dragon has a unique breath — rainbow fire, bubble breath, sparkle mist, warm-cookie scent. The Elder Dragon (enormous but gentle) sleeps at the caldera\'s heart. Lava flowers bloom along the paths and glow-moths light the tunnels. The dragons communicate through musical hums and only wake fully when sung to. Treasure: not gold, but memory-crystals that replay happy moments.',
      sproutTitle: 'Stomp with the Dinosaurs!',
      sproutDescription: 'Meet big, friendly dinosaurs who love to stomp and play!',
      youngTitle: 'Friendly Dragons',
      youngDescription:
          'Meet friendly dragons who love to play and go on adventures with you!',
      youngConflictHook:
          'Your dragon friend wants to learn how to blow rainbow bubbles instead of fire!',
      youngWorldBible:
          'A big warm mountain where friendly dragons sleep on cozy rock beds. The mountain hums like a lullaby. Inside are paths with glowing flowers and sparkly bridges. Each dragon does something different — one blows rainbow bubbles, one breathes warm cookie smell, one makes sparkly dust. The biggest dragon sleeps in the middle and is the friendliest of all. Little glow-bugs light the way.',
      matureTitle: 'The Dragon\'s Lair',
      matureDescription:
          'Deep within an active volcano, ancient wyrms guard secrets worth dying for.',
      matureConflictHook:
          'The alpha dragon demands tribute or annihilation. You have one chance to negotiate.',
      matureWorldBible:
          'A volcanic caldera housing the last dragon colony — a complex society with castes, customs, and a code of honour older than human civilisation. The dragons range from hatchling-sized to leviathan elders who remember the world before humans. Their lair is an architectural marvel: obsidian halls, magma forges, memory-crystal archives containing millennia of draconic history. Dragon politics are ruthless but fair — disputes are settled through riddle-contests or aerial trials. The volcano itself is alive, a symbiotic entity the dragons tend like a garden. Outsiders must prove worth through a Trial of Three: wit, courage, and compassion.',
      creatorTitle: 'What Wakes the Fire Inside',
      creatorThematicQuestion: "What wakes the fire inside?",
      adultTitle: 'The Weight of Old Fire',
      adultWorldBible:
          'The last dragon colony carries wounds older than living memory — debts of fire, broken oaths, extinctions caused by pride. The elders sleep not from peace but from exhaustion: there is nothing left to prove and no one left to prove it to. The volcanic caldera is a graveyard of decisions that felt necessary at the time. Young dragons are born already knowing the names of ancestors who failed honourably. The Trial of Three still stands, but the elders know: the real trial is what you do with fire after you have used it wrong. The volcano does not threaten — it waits, patient as grief, for someone to stop trying to control it and start listening to what it is saying.',
      adultThematicQuestion: "What are you still carrying that was never yours to carry?",
      sproutIllustration: 'assets/images/ui/sprout/tiles/dinosaurs.webp',
      youngBandSceneId: 'enchanted_forest',
      olderBandSceneId: 'tidal_shrine',
    ),
    ScenarioCard(
      id: 'neon_jungle',
      emoji: '🌴',
      title: 'The Neon Jungle of Whispers',
      illustration: 'images/scenarios/glowing_forest.webp',
      description:
          'A jungle where the trees forget their colors at night unless you whisper to them.',
      conflictHook:
          'The colors are disappearing! You must find the Heart of the Jungle to bring them back.',
      sensoryPalette:
          'Glowing moss, humming vines, the sweet scent of star-fruit.',
      category: 'Magical Worlds',
      worldBible:
          'A dense tropical jungle where every plant bioluminesces — trees pulse in neon greens and blues, flowers glow hot pink and amber. The jungle is alive and sentient; it communicates through whispers carried by the wind. Whispering a kind word to a plant makes it glow brighter. The Jungle Heart is a massive ancient tree at the centre whose roots connect all life. Animals include luminous tree frogs, firefly-mane monkeys, and silk-wing parrots that echo whispers. Rivers run with water that shimmers like liquid starlight. At night, the whole jungle becomes a light show — but only if the inhabitants remember to whisper.',
      sproutTitle: 'The Magical Forest',
      sproutDescription: 'Skip through a glowing forest and find friendly animals!',
      youngTitle: 'The Glowing Jungle',
      youngDescription:
          'A magical jungle where the trees and flowers glow in pretty colors!',
      youngConflictHook:
          'Help the jungle animals find their favorite glowing flowers for a party!',
      youngWorldBible:
          'A jungle where all the plants glow like night-lights! Trees shine green and blue, flowers glow pink and orange. If you whisper nice things to a plant, it glows even brighter! Friendly glowing frogs, sparkly monkeys, and singing birds live here. A really big magic tree in the middle keeps everything glowing. The rivers sparkle like glitter water.',
      matureTitle: 'The Bioluminescent Depths',
      matureDescription:
          'A rainforest where every organism pulses with living light—and something hunts in the dark.',
      matureConflictHook:
          'A parasitic darkness is consuming the light. Track it to its source before it spreads.',
      matureWorldBible:
          'A closed-canopy megaforest where bioluminescence has replaced photosynthesis as the primary energy cycle. The ecosystem runs on light-exchange — organisms trade luminous energy through root networks and airborne spores. The Nexus Tree, a kilometres-wide neural hub, processes the forest\'s collective consciousness. Apex predators are shadow-stalkers — creatures that absorb light rather than emit it, creating zones of absolute darkness. The jungle\'s whisper-network carries data like a biological internet. Human-equivalent intelligence exists in the Elder Groves — collectives of ancient trees that debate, remember, and scheme.',
      creatorTitle: 'The Part of You That Glows',
      creatorThematicQuestion: "What part of you is waiting to be seen?",
      adultTitle: 'The Light That Waits',
      sproutIllustration: 'assets/images/ui/sprout/tiles/forest.webp',
      youngBandSceneId: 'enchanted_forest',
      olderBandSceneId: 'deep_archive',
    ),
    ScenarioCard(
      id: 'crystal_cavern',
      emoji: '💎',
      title: 'The Crystal Cavern of Echoes',
      illustration: 'images/scenarios/sparkle_cave.webp',
      description:
          'A cave where echoes steal voices if you are too loud. Speak in whispers!',
      conflictHook:
          'The Echo-King has borrowed your friend\'s voice, and you need a clever riddle to get it back.',
      sensoryPalette:
          'Glittering walls, dripping water sounds, cool smooth stone underfoot.',
      category: 'Magical Worlds',
      worldBible:
          'An enormous underground cavern system with chambers of crystals in every colour — amethyst cathedrals, emerald grottos, diamond corridors. Sound behaves magically here: whispers travel for miles, shouts become solid shapes, singing creates temporary light bridges. The Echo-King is a crystal golem who collects beautiful sounds and stores them in singing crystals. Friendly cave creatures include echo-bats (repeat the last nice thing said), crystal snails (leave trails of gemstone dust), and glow-worms that spell words on the ceiling. Underground lakes reflect everything upside-down, showing the hidden truth of whatever you ask. The only rule: be gentle with your voice, because loud sounds crack the crystals.',
      sproutTitle: 'Under the Sea!',
      sproutDescription: 'Swim with colorful fish and make friends under the waves!',
      youngTitle: 'Cave Full of Crystals',
      youngDescription:
          'A sparkly cave full of shiny crystals that make beautiful music!',
      youngConflictHook:
          'Help the crystals learn a new song to play for their friends!',
      youngWorldBible:
          'A big sparkly cave with crystals everywhere — purple ones, green ones, shiny clear ones! When you whisper, the cave whispers back in a friendly way. When you sing, the crystals glow and make music. Cute little crystal snails leave sparkly trails, and friendly bats repeat nice words. There are underground pools that shimmer like magic mirrors. The Crystal King is a big friendly crystal who loves collecting pretty sounds.',
      matureTitle: 'The Resonance Caverns',
      matureDescription:
          'Crystalline formations amplify thoughts into reality. Be careful what you think.',
      matureConflictHook:
          'Someone\'s nightmare is echoing through the caves, manifesting as something real.',
      matureWorldBible:
          'A vast subterranean crystal network where sound frequencies interact with crystalline structures to manipulate matter. The caverns operate on resonance physics — specific tonal frequencies unlock passages, reshape walls, or summon stored memories from crystal archives. The Echo Sovereign is an ancient AI-like consciousness distributed across the crystal lattice, cataloguing every sound ever uttered underground. The deeper you go, the more the crystals respond to thought rather than voice, eventually manifesting emotions as tangible constructs. This is both powerful and dangerous — uncontrolled fear creates shadow-creatures, while focused calm can reshape the caverns themselves.',
      creatorTitle: 'The Echo Inside',
      creatorThematicQuestion: "What have you been telling yourself?",
      adultTitle: 'What Echoes Back',
      sproutIllustration: 'assets/images/ui/sprout/tiles/ocean.webp',
      youngBandSceneId: 'ocean_depths',
      olderBandSceneId: 'deep_archive',
    ),
    ScenarioCard(
      id: 'storm_chaser_sky',
      emoji: '☁️',
      title: "The Storm-Chaser's Sky Fortress",
      illustration: 'images/scenarios/cloud_castle.webp',
      description:
          'A floating fortress racing through a sea of lightning clouds!',
      conflictHook:
          'The steering wheel of the Sky Fortress is stuck in a giant cloud-whirlpool.',
      sensoryPalette:
          'Deep thunder rumbles, the smell of ozone, static tingles in the air.',
      category: 'Magical Worlds',
      worldBible:
          'A massive airborne fortress built from cloudstone and bronze, sailing through an endless sky filled with storm-clouds, rainbows, and floating islands. The fortress has sails made of woven lightning, a helm that steers by singing, and rooms that rearrange when the wind changes. Crew includes sky-sailors, weather-weavers (who knit clouds into useful shapes), and storm-dancers who redirect lightning. Sky wildlife: thunder-whales that breach through clouds, spark-finches that nest in lightning rods, and cloud-sheep whose wool is literally fog. Below the clouds, the ground is a distant memory. Navigation uses constellation maps that only appear during storms.',
      sproutTitle: 'The Fluffy Cloud Castle',
      sproutDescription: 'Bounce on soft clouds and play in a cozy castle in the sky!',
      youngTitle: 'Candy Cloud Castle',
      youngDescription:
          'A fluffy castle in the clouds made of cotton candy and rainbows!',
      youngConflictHook:
          'The cloud castle needs more colors - help paint the rainbow bridge!',
      youngWorldBible:
          'A fluffy castle floating in the sky made of cotton-candy clouds, rainbow bridges, and sparkly rain. Friendly cloud-sheep bounce around like pillows. Little birds that sparkle fly between the towers. You can slide down rainbows and bounce on cloud trampolines. The wind is gentle and warm and smells like candy floss. Everything is soft and safe — if you fall, a cloud catches you!',
      matureTitle: 'The Stormrunner Citadel',
      matureDescription:
          'A rogue airship racing through supercell storms, outrunning something worse than lightning.',
      matureConflictHook:
          'The engines are failing and a rival faction is closing in. Fight or flight—you decide.',
      matureWorldBible:
          'A militarised sky-citadel — part aircraft carrier, part floating city — navigating a perpetual superstorm belt that encircles the planet. The storm belt is both barrier and resource: its lightning powers the citadel\'s engines, but its winds can shred unshielded hulls. The crew operates under a strict chain of command with storm-runner scouts, tactical navigators, and combat weather-shapers who weaponise atmospheric conditions. Rival sky-nations compete for storm-corridor control. The citadel\'s greatest secret: its core contains a captured storm-entity, a sentient weather phenomenon that powers everything but yearns for freedom.',
      // Adventure scenario — matureTitle works for 12-14; no distinct framing needed.
      creatorTitle: null,
      creatorThematicQuestion: "What storm are you running from?",
      adultTitle: 'The Storm You\'ve Been Feeding',
      sproutIllustration: 'assets/images/ui/sprout/tiles/castle.webp',
      youngBandSceneId: 'cloud_castle',
      olderBandSceneId: 'orbital_station',
    ),
    ScenarioCard(
      id: 'vanishing_colors',
      emoji: '🌈',
      title: 'The Land of Vanishing Colors',
      illustration: 'images/scenarios/rainbow_land.webp',
      description:
          'Someone is erasing the world! Use your magic to paint it back to life.',
      conflictHook:
          'The Great Eraser is turning everything gray, and only your creativity can stop it.',
      sensoryPalette:
          'Shimmering air, the smell of wet paint, smooth canvas textures.',
      category: 'Magical Worlds',
      worldBible:
          'A world that looks like a living painting — rolling hills of brushstroke grass, skies layered in watercolour gradients, rivers of liquid pigment. Colour is the life-force here: when a flower loses its colour, it wilts; when a creature turns grey, it falls asleep. The Great Eraser is a fog-like entity that absorbs colour and leaves monochrome in its wake. Allies include the Paint Sprites (tiny beings that each carry one colour), the Palette Guardian (a wise rainbow tortoise), and Brushstroke Birds that trail colour behind them as they fly. The hero can restore colour through creative acts — painting, singing, dancing, telling stories. Each restored colour brings back a sense: red returns warmth, blue returns sound, yellow returns smell, green returns taste. THE JELLO ROAD: The main road through this land is paved in solid rainbow gelatin. In dry weather it is firm and springy, with a satisfying bounce underfoot — like walking on the world\'s bounciest trampoline. When it rains, the surface turns frictionless and slick, becoming a wild slip-and-slide (fast travel, zero control). After the rain stops, the road goes through a sticky phase — anything on it gets gently held in place for a minute while it sets — before firming back up. Locals know to read the road like weather: bounce means go, slide means hang on, sticky means wait.',
      sproutTitle: 'Rainbow World',
      sproutDescription: 'A yummy world full of rainbows, sweets, and happy surprises!',
      youngTitle: 'Rainbow World',
      youngDescription:
          'A magical land full of rainbows, colors, and happy surprises!',
      youngConflictHook:
          'Help your friends find all the colors of the rainbow for a big celebration!',
      youngWorldBible:
          'A happy land where everything is made of colours — the grass is crayon-green, the sky is painted blue, and the rivers are sparkly rainbow water. Cute little Paint Sprites carry buckets of colour. A friendly rainbow turtle helps everyone stay colourful. Birds fly and leave pretty colour trails behind them. When something loses its colour and turns grey, it falls asleep — but you can wake it up by painting it, singing to it, or giving it a hug! THE JELLO ROAD: The road through Rainbow World is made of real bouncy jello! It\'s springy and fun to hop on when it\'s dry. When it rains, it turns into a slippery slip-and-slide and everyone goes zooming! But once the rain stops, it gets sticky for a little while — if you step on it you get stuck like a frog on a leaf until it dries! Then it goes bouncy again.',
      matureTitle: 'The Fading Realm',
      matureDescription:
          'Reality itself is being unmade. Every hour, more of the world turns to static.',
      matureConflictHook:
          'The Void is sentient, and it wants to consume everything. You\'re the last line of defense.',
      matureWorldBible:
          'A dimension where perception literally shapes reality — colour, sound, and texture are manifestations of collective consciousness. The Entropy (called "the Eraser" by younger inhabitants) is a natural force of creative decay, accelerated by despair and apathy. As regions lose colour, they don\'t just go grey — they lose dimensional complexity, flattening into 2D, then 1D, then nothing. Resistance comes through authentic creative expression, not just art but genuine emotional honesty. The Chromatists are a resistance movement who\'ve learned to weaponise creativity, but they\'re fractured by debate: fight the Entropy or accept it as a natural cycle? The hero must navigate both the external threat and the philosophical divide. THE JELLO ROAD: The primary artery of this realm is the Chromatic Causeway — a road paved in solid pigment-gelatin that shifts state with the weather. Dry: firm and springy, each footfall sending up a small chromatic ripple. Rain: instantly frictionless, a mirror-smooth slide that moves people whether they want to move or not. Post-rain: a brief adhesive window where the surface grips everything touching it — creatures, objects, secrets — before releasing as it sets. The Causeway is both infrastructure and metaphor: the Chromatists say the road reflects the realm\'s emotional state. A sticky road means something is holding on. A sliding road means something is out of control. A bouncy road means the world is still alive.',
      creatorTitle: 'When Everything Fades',
      creatorThematicQuestion: "What would you save if everything faded?",
      adultTitle: 'When Meaning Dissolves',
      sproutIllustration: 'assets/images/ui/sprout/tiles/candy_land.webp',
      youngBandSceneId: 'cloud_castle',
      olderBandSceneId: 'ruined_citadel',
    ),

    // --- REAL-LIFE HEROES ---
    ScenarioCard(
      id: 'brave_friend',
      emoji: '🤝',
      title: 'The Brave Friend',
      illustration: 'images/scenarios/making_friends.webp',
      description: 'Learning to say hello and join in the fun with new people.',
      conflictHook:
          'A group of kids is playing a fun game, but asking to join feels like climbing a giant mountain.',
      sensoryPalette:
          'Happy laughter, the sound of running feet, the smell of fresh cut grass.',
      category: 'Real-Life Heroes',
      worldBible:
          'A realistic neighbourhood setting — a sunny park with a big playground, a grassy field, benches under shady trees, and paths winding between gardens. A group of kids is already playing together. The park feels welcoming but the hero feels like an outsider looking in. Small magical touches: a friendly dog that nudges the hero forward, a ball that rolls their way as an invitation, a butterfly that lands on their shoulder for courage. The emotional landscape is the real terrain — the "mountain" of shyness, the "bridge" of a first hello, the "victory flag" of being included. Every brave step forward makes the world literally a little brighter and more colourful.',
      youngTitle: 'Making a New Friend',
      youngDescription:
          'Saying hello is the first step to a big new adventure!',
      youngConflictHook: 'Let\'s find a fun way to say "Hi" and play together!',
      youngWorldBible:
          'A sunny park with swings, slides, and a big sandpit. Other children are playing and laughing. The hero watches from a bench, feeling a bit shy. A friendly puppy comes over and wags its tail. A ball rolls to the hero\'s feet — someone waves and smiles. Each brave thing the hero does makes the sun shine a tiny bit brighter and flowers pop up in the grass. Saying "hello" is the magic word that opens the gate to fun!',
      matureTitle: 'Breaking the Ice',
      matureDescription:
          'Navigating social dynamics and finding your crew when everyone else already has one.',
      matureConflictHook:
          'The group seems tight-knit and you\'re the outsider. How do you find your way in?',
      matureWorldBible:
          'A realistic school or community setting — hallways, lunch tables, after-school hangouts. Social groups are already established with their own codes, jokes, and history. The hero is new or newly alone, reading the room and looking for an in. No magic here — just the real, raw mechanics of social navigation: finding common ground, risking rejection, learning that vulnerability is strength. The "quest" is internal: overcoming the voice that says "they don\'t want you here" and finding the courage to show up authentically. Success isn\'t instant popularity — it\'s one real conversation, one genuine laugh, one person who says "sit with us."',
      creatorTitle: 'Showing Up',
      creatorThematicQuestion: "What does it cost you to show up?",
      adultTitle: 'The Cost of Showing Up',
    ),
    ScenarioCard(
      id: 'standing_tall',
      emoji: '🛡️',
      title: 'Standing Tall',
      illustration: 'images/scenarios/confidence.webp',
      description:
          'When someone is being mean, your heart is your strongest shield.',
      conflictHook:
          'A playground shadow is making everyone feel small. It\'s time to find your voice.',
      sensoryPalette:
          'Deep steady breaths, the feeling of solid ground, a warm glow in your chest.',
      category: 'Real-Life Heroes',
      worldBible:
          'A school playground where a bully (portrayed as a growing shadow, never a named villain) is making other kids feel small — literally, in the story world, unkind words cause kids to shrink. The hero discovers their inner strength manifests as a warm golden glow from the chest — the brighter it glows, the taller they stand. Allies: a quiet friend who\'s been shrunk and needs encouragement, a teacher who notices but wants the hero to try first. The bully-shadow shrinks when confronted calmly and firmly — it feeds on fear and starves on courage. Resolution is never violence; it\'s boundary-setting, seeking help, and solidarity. The hero learns: standing up doesn\'t mean standing alone.',
      youngTitle: 'The Brave Heart',
      youngDescription:
          'You are strong and kind, even when things feel a little scary.',
      youngConflictHook: 'Use your kind words to stand tall and be a hero!',
      youngWorldBible:
          'A playground where a grumpy shadow is making the other kids feel small and sad. But the hero has a special warm glow in their tummy that gets brighter when they are brave! When the hero says kind, strong words like "Stop, that\'s not nice!" the shadow gets smaller and smaller. A quiet friend needs help being brave too. Together they stand tall, and the shadow puffs away like smoke. Being brave means using your words and asking a grown-up for help.',
      matureTitle: 'Standing Your Ground',
      matureDescription:
          'Dealing with someone who\'s giving you a hard time without losing yourself.',
      matureConflictHook:
          'They\'re testing you in front of everyone. Walk away or face them down?',
      matureWorldBible:
          'A realistic school setting where social aggression takes many forms — public humiliation, exclusion, rumour-spreading, or direct confrontation. The story explores the internal battle: the urge to retaliate vs. the strength of composure, the fear of being seen as weak vs. the courage of walking away, the temptation to become what you hate. No magical solutions — the hero navigates with real strategies: documenting incidents, building alliances, setting firm boundaries, knowing when to involve adults. The "victory" is nuanced: the bully may not transform, but the hero reclaims their power and self-respect.',
      creatorTitle: 'Who You Are Under Pressure',
      creatorThematicQuestion: "Who are you when no one's watching?",
      adultTitle: 'Holding the Line',
    ),
    ScenarioCard(
      id: 'big_feelings_quest',
      emoji: '🌊',
      title: 'Life Quest',
      illustration: 'images/scenarios/feelings_quest.webp',
      description:
          'Riding the waves of being worried or mad without getting swept away.',
      conflictHook:
          'A giant storm-cloud of "Mad" has arrived. Can you find the calm center?',
      sensoryPalette:
          'Swirling clouds, rumbly tummy feelings, the cool touch of a breeze.',
      category: 'Real-Life Heroes',
      sproutTitle: 'Big Feelings',
      worldBible:
          'An inner landscape where emotions are weather and terrain. Anger is a rumbling volcano, worry is a foggy maze, sadness is a rainy valley, joy is a sunlit meadow. The hero travels through their own emotional world, learning that every feeling has a place and a purpose. The Feeling Guides are friendly creatures: a calm turtle for breathing exercises, a brave lion for facing fears, a gentle rain-cloud that shows crying is okay. The "calm centre" is a peaceful lake at the heart of the landscape where all weather is visible but none is overwhelming. The hero learns tools at each stop: belly breathing at the volcano, grounding at the maze, self-compassion at the valley. Resolution: feelings aren\'t enemies to defeat but weather to navigate.',
      youngTitle: 'Life Quest',
      youngDescription:
          'Feelings come and go like the wind. You can be the boss of your clouds!',
      youngConflictHook:
          'Let\'s find our happy sunshine after the rainy clouds pass by.',
      youngWorldBible:
          'A land inside your heart where feelings are like weather! When you\'re mad, there\'s a grumbly little volcano that puffs red clouds. When you\'re sad, gentle rain falls. When you\'re scared, there\'s a foggy path. But in the middle is a beautiful calm pond where you can sit and breathe. Friendly helpers are there: a slow-breathing turtle, a brave little lion, and a cuddly rain-cloud. They show you that all feelings are okay, and they all pass like clouds in the sky. Taking big breaths is the magic that clears the sky!',
      matureTitle: 'Riding the Storm',
      matureDescription:
          'Managing anxiety and anger when everything feels out of control.',
      matureConflictHook:
          'The pressure is building and you\'re about to snap. How do you keep it together?',
      matureWorldBible:
          'A psychological landscape rendered as a realistic internal world — the hero navigates their own emotional architecture. Anxiety manifests as a labyrinth with walls that close in; anger as a pressure cooker reaching critical; sadness as gravity that makes every step exhausting. No cute metaphors — the feelings are raw and recognisable. The hero learns evidence-based coping techniques woven naturally into the narrative: cognitive reframing, grounding (5-4-3-2-1 senses), emotional regulation through physical movement, and the power of naming what you feel. The "calm centre" isn\'t happiness — it\'s equanimity, the ability to hold difficult emotions without being controlled by them. The story validates that struggling is normal and seeking help is strength.',
      creatorTitle: 'The Feeling That Won\'t Let Go',
      creatorThematicQuestion: "What feeling runs your life right now?",
      adultTitle: 'Sitting With It',
      adultWorldBible:
          'The inner landscape is not a storm to be conquered — it never was. The terrain is built from every feeling that was swallowed, every rage that had nowhere to go, every grief that got called overreacting. The Feeling Keepers here are not therapists or guides; they are the feelings themselves, grown large from years of being ignored. Anxiety has built an elaborate city. Grief has become a body of water with no clear shore. The work is not to drain the lake or demolish the city — it is to sit on the bank without needing it to be different. Each evidence-based coping technique has a physical form here, a place you can return to. But the portal home opens only when you stop trying to find it.',
      adultThematicQuestion: "What are you trying not to feel right now?",
    ),
    ScenarioCard(
      id: 'change_is_coming',
      emoji: '🦋',
      title: 'Change is Coming!',
      illustration: 'images/scenarios/transitions.webp',
      description:
          'Moving to a new house or starting a new school is a cocoon turning into a butterfly.',
      conflictHook:
          'Everything is packed in boxes, and the new place feels like a mysterious planet.',
      sensoryPalette:
          'Rustling paper, the smell of new paint, the echo of an empty room.',
      category: 'Real-Life Heroes',
      worldBible:
          'A story that transitions between two worlds — the familiar old place (warm, detailed, full of memories rendered as golden snapshots) and the unknown new place (exciting but overwhelming, full of empty spaces that slowly fill with new experiences). The hero carries a Memory Box (metaphorical or literal) with treasures from before. Each new experience in the new place adds something to the box rather than replacing what was there. Friendly helpers: a neighbourhood cat who knows all the secrets of the new area, a moving-box that refuses to stay packed (comic relief), a window that shows the old room at sunset. The message: you don\'t lose who you were — you add who you\'re becoming.',
      youngTitle: 'Something New!',
      youngDescription:
          'A new school or a new house is a exciting mystery waiting for you!',
      youngConflictHook:
          'Let\'s find all the fun things hidden in our new adventure!',
      youngWorldBible:
          'The hero is in a new place — maybe a new house or a new school. It feels big and different and a little bit scary. But there are surprises everywhere! A friendly cat shows them around. Boxes from the old house have favourite toys inside — like treasure chests! Each room or corner of the new place has something fun waiting to be discovered. The old place isn\'t gone — it\'s in the hero\'s heart, like a warm hug they carry with them. And the new place is becoming home, one happy moment at a time.',
      matureTitle: 'Unknown Territory',
      matureDescription:
          'Starting over when everything familiar is gone and nobody knows who you are.',
      matureConflictHook:
          'New school, new rules, new people. Do you reinvent yourself or stay true to who you were?',
      matureWorldBible:
          'A grounded, realistic story about displacement — new city, new school, zero social capital. The hero grapples with identity: the freedom and terror of being unknown. Do you perform a new version of yourself or risk showing the real one? The old life exists through phone screens and fading group chats that slowly go quiet. The new environment has its own culture, slang, and social hierarchies to decode. No instant fixes — the story follows the slow, authentic process of planting roots: the first awkward lunch alone, the first genuine conversation, the first time the new place feels less foreign. The message: home isn\'t a place, it\'s a feeling you rebuild.',
      creatorTitle: 'Leaving the Person You Were',
      creatorThematicQuestion: "What part of yourself are you leaving behind?",
      adultTitle: 'Starting Over',
    ),
    ScenarioCard(
      id: 'safe_space',
      emoji: '✨',
      title: 'Imagine It',
      illustration: 'images/scenarios/safe_space.webp',
      description:
          'Dream up any world you want. Tell us where your adventure should take place and we\'ll bring it to life.',
      conflictHook:
          'You choose the setting — anywhere your imagination can reach. We\'ll weave a story around it.',
      sensoryPalette:
          'Soft cushions, warm glowing lights, the gentle sound of wind chimes.',
      category: 'Real-Life Heroes',
      featured: true,
      worldBible:
          'Draw inspiration from the child\'s description and bring their ideas to life with rich sensory detail. If they give a brief description, expand it with warm, imaginative touches. If they give a detailed description, honour its spirit faithfully. Always maintain internal consistency with the world the child has imagined. Keep all content age-appropriate and safe.',
      youngTitle: 'Make One Up!',
      youngDescription:
          'What magical place do you want to visit? Tell us and we\'ll go there!',
      youngConflictHook:
          'Anywhere you want — a candy castle, a space station, a rainbow mountain. You decide!',
      youngWorldBible:
          'Whatever the child describes, build it with simple, warm, safe details. Keep it bright, friendly, and full of wonder. Add friendly animals and cozy touches. Nothing scary, nothing too complex. If they say "a castle," make it a friendly castle with nice people inside.',
      matureTitle: 'Imagine It',
      matureDescription:
          'Your story, your world. Describe the setting and we\'ll build the adventure around it.',
      matureConflictHook:
          'Any place, any atmosphere, any vibe. Set the scene and we\'ll do the rest.',
      matureWorldBible:
          'Draw deeply on the user\'s creative vision. Build the world with sophisticated detail, internal logic, and atmospheric depth appropriate to whatever they describe. If they give a genre (sci-fi, fantasy, realistic), lean into its conventions. Add complexity, moral ambiguity, and stakes appropriate to their age. Keep all content appropriate for the user\'s age band.',
      // The title is intentionally shared — "Imagine It" resonates equally well at 12-14.
      creatorTitle: null,
    ),
    // --- ADVENTURER+ EXCLUSIVE ---
    ScenarioCard(
      id: 'midnight_mystery',
      emoji: '🔍',
      title: 'The Midnight Mystery',
      illustration: 'images/scenarios/mystery.webp',
      description:
          'Something has gone missing and only you can piece together the clues before dawn.',
      conflictHook:
          'The clues lead somewhere unexpected — and the clock is ticking.',
      sensoryPalette:
          'Hushed voices, the scratch of a pen on paper, dim lamplight, the smell of old books.',
      category: 'Magical Worlds',
      minBand: AgeBand.adventurer,
      worldBible:
          'A richly detailed mystery world — part noir, part adventure. A grand old building (manor, library, museum, school) at night holds a secret. Clues are scattered: a torn letter, a muddy footprint, an alibi that doesn\'t add up. The hero is the only detective. Each clue reveals a layer of the truth. Suspects have motives but none are purely villainous — the real culprit made a mistake, not a crime. The investigation teaches logical deduction, attention to detail, and that truth is rarely simple. Resolution: the hero exposes the truth in a satisfying reveal, choosing mercy over punishment.',
      matureTitle: 'The Unsolved Case',
      matureDescription:
          'Every witness is hiding something. The truth is buried — and dangerous.',
      matureConflictHook:
          'The evidence points to someone you trust. Do you follow the facts wherever they lead?',
      matureWorldBible:
          'A morally complex mystery where the solution is uncomfortable. The case involves real stakes — reputation, relationships, someone\'s future. The hero must weigh justice against loyalty, truth against kindness. Evidence contradicts itself; witnesses lie for understandable reasons. The investigation requires reading people as much as reading clues. The "villain" is sympathetic — driven by fear, love, or desperation rather than malice. Resolution is ambiguous: the hero discovers the full truth and must decide what to do with it, with no easy answer provided.',
      creatorTitle: "The Truth You Don't Want to Find",
      creatorThematicQuestion: "What truth are you afraid to follow?",
      adultTitle: 'Every Answer Costs Something',
    ),
    ScenarioCard(
      id: 'survival_island',
      emoji: '🏝️',
      title: "Survival Island",
      illustration: 'images/scenarios/survival.webp',
      description:
          'Stranded somewhere wild, you must use your wits and grit to find a way through.',
      conflictHook:
          'Resources are limited. Every choice matters. Can you make it out?',
      sensoryPalette:
          'Salt air, rustling leaves, the crackle of a fire, the ache of tired muscles.',
      category: 'Magical Worlds',
      minBand: AgeBand.adventurer,
      worldBible:
          'A survival scenario set on a lush island, a dense forest, or an isolated wilderness. The hero has limited supplies and must prioritise: shelter, water, fire, food, signal. The environment is challenging but not hostile — it rewards patience and problem-solving over brute force. Wildlife is realistic, weather shifts, and each day brings new challenges. A secondary goal: figure out how you got here and find a way out. The survival skills woven in are real (fire-starting, water collection, navigation by stars, basic first aid). The tone is empowering — hardship as a teacher, not a punishment. Teamwork option: a companion with complementary skills.',
      matureTitle: 'Into the Wild',
      matureDescription:
          'No map. No signal. No rescue coming. Just you, the elements, and your choices.',
      matureConflictHook:
          'Your supplies are gone. Someone is injured. And the weather is turning. What do you do first?',
      matureWorldBible:
          'A grounded, psychologically real survival story. Physical challenges are secondary to mental ones: managing fear, making decisions under pressure, accepting when a plan has failed. The environment is genuinely dangerous — weather, injury, dehydration all have real consequences in the narrative. Moral dilemmas arise: ration the last of the food alone or share? Take a dangerous shortcut or wait for rescue? The story explores the hierarchy of needs — safety, water, food, warmth — and the psychology of survival: the importance of small goals, staying rational, not surrendering to despair. Resolution comes through persistence and ingenuity, not luck.',
      // Survival scenario — matureTitle works for 12-14; no distinct framing needed.
      creatorTitle: null,
      creatorThematicQuestion: "What do you do when there's no one left to help you?",
      adultTitle: 'Only What You Carry',
    ),
    // --- SUPERHERO MODE (ages 3-5 / Sprout band) ---
    // Registered so [WizardDataMapper] doesn't choke when wizardData.selectedScenario
    // == 'superhero'. The backend recognizes theme=='superhero' as the special
    // routing key (see backend/main.py /generate-story); the prompt itself is
    // constructed server-side from the costume + power + villain matrix.
    ScenarioCard(
      id: 'superhero',
      emoji: '🦸',
      title: 'Superhero Story',
      illustration: 'images/scenarios/my_big_feelings_btn.webp',
      description:
          'A superhero adventure where the child is the hero.',
      conflictHook:
          'A silly villain causes mischief; the hero solves it with kindness.',
      sensoryPalette:
          'Bright primary colors, the swoosh of a cape, the warm glow of the hero emblem.',
      category: 'Magical Worlds',
      worldBible:
          'A child-sized superhero adventure for ages 3-5. The hero wears a colorful costume with their chosen emblem and may have a cape. The villain is a "silly" mischief-maker — never scary, never violent — who creates a small, solvable problem (mixed-up colors, stuck zippers, missing socks, grumpy clouds). The hero uses their chosen super-power along with kindness, sharing, and gentle words to resolve it. Every story ends with everyone happy and friends.',
      sproutTitle: 'Be a Superhero!',
      sproutDescription: 'Save the day with your superpower!',
    ),
  ];

  static ScenarioCard? getById(String id) {
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }
}

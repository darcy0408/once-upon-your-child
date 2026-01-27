class ScenarioCard {
  final String id;
  final String emoji;
  final String title;
  final String illustration;
  final String description;
  final String conflictHook;
  final String sensoryPalette;
  final String category; // 'Magical Worlds' or 'Real-Life Heroes'
  // Age-appropriate alternatives for younger children (ages 3-6)
  final String? youngTitle;
  final String? youngDescription;
  final String? youngConflictHook;

  const ScenarioCard({
    required this.id,
    required this.emoji,
    required this.title,
    required this.illustration,
    required this.description,
    required this.conflictHook,
    required this.sensoryPalette,
    this.category = 'Magical Worlds',
    this.youngTitle,
    this.youngDescription,
    this.youngConflictHook,
  });

  /// Get the title appropriate for the given age.
  String titleForAge(int age) => (age <= 6 && youngTitle != null) ? youngTitle! : title;

  /// Get the description appropriate for the given age.
  String descriptionForAge(int age) =>
      (age <= 6 && youngDescription != null) ? youngDescription! : description;

  /// Get the conflict hook appropriate for the given age.
  String conflictHookForAge(int age) =>
      (age <= 6 && youngConflictHook != null) ? youngConflictHook! : conflictHook;
}

class ScenarioData {
  static const List<ScenarioCard> all = [
    // --- MAGICAL WORLDS ---
    ScenarioCard(
      id: 'doorway_seasons',
      emoji: '🚪',
      title: 'The Doorway Between Seasons',
      illustration: 'images/scenarios/magic_door.png',
      description: 'Each magic door leads to a different season. Can you find your way home?',
      conflictHook: 'A glitch in the magic doors is mixing up winter and summer!',
      sensoryPalette: 'Swirling leaves, changing temperatures, the smell of fresh rain and autumn wood.',
      category: 'Magical Worlds',
      youngTitle: 'The Magic Door',
      youngDescription: 'Open the magic door and see what fun season is waiting for you!',
      youngConflictHook: 'Oops! The magic door opened to a silly season - snowflakes and sunflowers together!',
    ),
    ScenarioCard(
      id: 'volcano_dragons',
      emoji: '🐉',
      title: 'The Volcano of Sleeping Dragons',
      illustration: 'images/scenarios/sleeping_dragon.png',
      description: 'Wake the kindest dragon to stop the volcano from sneezing rainbow lava!',
      conflictHook: 'The Fire-Sneeze Dragon is about to wake up and needs a gentle lullaby.',
      sensoryPalette: 'Warm rumbling ground, the smell of toasted marshmallows, glowing embers.',
      category: 'Magical Worlds',
      youngTitle: 'Dragon Friends',
      youngDescription: 'Meet friendly dragons who love to play and go on adventures with you!',
      youngConflictHook: 'Your dragon friend wants to learn how to blow rainbow bubbles instead of fire!',
    ),
    ScenarioCard(
      id: 'neon_jungle',
      emoji: '🌴',
      title: 'The Neon Jungle of Whispers',
      illustration: 'images/scenarios/glowing_forest.png',
      description: 'A jungle where the trees forget their colors at night unless you whisper to them.',
      conflictHook: 'The colors are disappearing! You must find the Heart of the Jungle to bring them back.',
      sensoryPalette: 'Glowing moss, humming vines, the sweet scent of star-fruit.',
      category: 'Magical Worlds',
      youngTitle: 'The Glowing Jungle',
      youngDescription: 'A magical jungle where the trees and flowers glow in pretty colors!',
      youngConflictHook: 'Help the jungle animals find their favorite glowing flowers for a party!',
    ),
    ScenarioCard(
      id: 'crystal_cavern',
      emoji: '💎',
      title: 'The Crystal Cavern of Echoes',
      illustration: 'images/scenarios/sparkle_cave.png',
      description: 'A cave where echoes steal voices if you are too loud. Speak in whispers!',
      conflictHook: 'The Echo-King has borrowed your friend\'s voice, and you need a clever riddle to get it back.',
      sensoryPalette: 'Glittering walls, dripping water sounds, cool smooth stone underfoot.',
      category: 'Magical Worlds',
      youngTitle: 'Crystal Cave',
      youngDescription: 'A sparkly cave full of shiny crystals that make beautiful music!',
      youngConflictHook: 'Help the crystals learn a new song to play for their friends!',
    ),
    ScenarioCard(
      id: 'storm_chaser_sky',
      emoji: '☁️',
      title: "The Storm-Chaser's Sky Fortress",
      illustration: 'images/scenarios/cloud_castle.png',
      description: 'A floating fortress racing through a sea of lightning clouds!',
      conflictHook: 'The steering wheel of the Sky Fortress is stuck in a giant cloud-whirlpool.',
      sensoryPalette: 'Deep thunder rumbles, the smell of ozone, static tingles in the air.',
      category: 'Magical Worlds',
      youngTitle: 'Candy Cloud Castle',
      youngDescription: 'A fluffy castle in the clouds made of cotton candy and rainbows!',
      youngConflictHook: 'The cloud castle needs more colors - help paint the rainbow bridge!',
    ),
    ScenarioCard(
      id: 'vanishing_colors',
      emoji: '🌈',
      title: 'The Land of Vanishing Colors',
      illustration: 'images/scenarios/rainbow_land.png',
      description: 'Someone is erasing the world! Use your magic to paint it back to life.',
      conflictHook: 'The Great Eraser is turning everything gray, and only your creativity can stop it.',
      sensoryPalette: 'Shimmering air, the smell of wet paint, smooth canvas textures.',
      category: 'Magical Worlds',
      youngTitle: 'Rainbow Land',
      youngDescription: 'A magical land full of rainbows, colors, and happy surprises!',
      youngConflictHook: 'Help your friends find all the colors of the rainbow for a big celebration!',
    ),

    // --- REAL-LIFE HEROES ---
    ScenarioCard(
      id: 'brave_friend',
      emoji: '🤝',
      title: 'The Brave Friend',
      illustration: 'images/scenarios/making_friends.png',
      description: 'Learning to say hello and join in the fun with new people.',
      conflictHook: 'A group of kids is playing a fun game, but asking to join feels like climbing a giant mountain.',
      sensoryPalette: 'Happy laughter, the sound of running feet, the smell of fresh cut grass.',
      category: 'Real-Life Heroes',
      youngTitle: 'Making a New Friend',
      youngDescription: 'Saying hello is the first step to a big new adventure!',
      youngConflictHook: 'Let\'s find a fun way to say "Hi" and play together!',
    ),
    ScenarioCard(
      id: 'standing_tall',
      emoji: '🛡️',
      title: 'Standing Tall',
      illustration: 'images/scenarios/confidence.png',
      description: 'When someone is being mean, your heart is your strongest shield.',
      conflictHook: 'A playground shadow is making everyone feel small. It\'s time to find your voice.',
      sensoryPalette: 'Deep steady breaths, the feeling of solid ground, a warm glow in your chest.',
      category: 'Real-Life Heroes',
      youngTitle: 'The Brave Heart',
      youngDescription: 'You are strong and kind, even when things feel a little scary.',
      youngConflictHook: 'Use your kind words to stand tall and be a hero!',
    ),
    ScenarioCard(
      id: 'big_feelings_quest',
      emoji: '🌊',
      title: 'Big Feelings Quest',
      illustration: 'images/scenarios/feelings_quest.png',
      description: 'Riding the waves of being worried or mad without getting swept away.',
      conflictHook: 'A giant storm-cloud of "Mad" has arrived. Can you find the calm center?',
      sensoryPalette: 'Swirling clouds, rumbly tummy feelings, the cool touch of a breeze.',
      category: 'Real-Life Heroes',
      youngTitle: 'My Big Feelings',
      youngDescription: 'Feelings come and go like the wind. You can be the boss of your clouds!',
      youngConflictHook: 'Let\'s find our happy sunshine after the rainy clouds pass by.',
    ),
    ScenarioCard(
      id: 'change_is_coming',
      emoji: '🦋',
      title: 'Change is Coming!',
      illustration: 'images/scenarios/transitions.png',
      description: 'Moving to a new house or starting a new school is a cocoon turning into a butterfly.',
      conflictHook: 'Everything is packed in boxes, and the new place feels like a mysterious planet.',
      sensoryPalette: 'Rustling paper, the smell of new paint, the echo of an empty room.',
      category: 'Real-Life Heroes',
      youngTitle: 'Something New!',
      youngDescription: 'A new school or a new house is a exciting mystery waiting for you!',
      youngConflictHook: 'Let\'s find all the fun things hidden in our new adventure!',
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
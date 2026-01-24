class ScenarioCard {
  final String id;
  final String emoji;
  final String title;
  final String illustration;
  final String description;
  final String conflictHook;
  final String sensoryPalette;
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
    ScenarioCard(
      id: 'doorway_seasons',
      emoji: '🚪',
      title: 'The Doorway Between Seasons',
      illustration: 'images/scenarios/magic_door.png',
      description: 'Each magic door leads to a different season. Can you find your way home?',
      conflictHook: 'A glitch in the magic doors is mixing up winter and summer!',
      sensoryPalette: 'Swirling leaves, changing temperatures, the smell of fresh rain and autumn wood.',
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
      youngTitle: 'Rainbow Land',
      youngDescription: 'A magical land full of rainbows, colors, and happy surprises!',
      youngConflictHook: 'Help your friends find all the colors of the rainbow for a big celebration!',
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
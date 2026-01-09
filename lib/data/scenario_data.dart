class ScenarioCard {
  final String id;
  final String emoji;
  final String title;
  final String illustration;
  final String description;
  final String conflictHook;
  final String sensoryPalette;

  const ScenarioCard({
    required this.id,
    required this.emoji,
    required this.title,
    required this.illustration,
    required this.description,
    required this.conflictHook,
    required this.sensoryPalette,
  });
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
    ),
    ScenarioCard(
      id: 'volcano_dragons',
      emoji: '🌋',
      title: 'The Volcano of Sleeping Dragons',
      illustration: 'images/scenarios/sleeping_dragon.png',
      description: 'Wake the kindest dragon to stop the volcano from sneezing rainbow lava!',
      conflictHook: 'The Fire-Sneeze Dragon is about to wake up and needs a gentle lullaby.',
      sensoryPalette: 'Warm rumbling ground, the smell of toasted marshmallows, glowing embers.',
    ),
    ScenarioCard(
      id: 'neon_jungle',
      emoji: '🌴',
      title: 'The Neon Jungle of Whispers',
      illustration: 'images/scenarios/glowing_forest.png',
      description: 'A jungle where the trees forget their colors at night unless you whisper to them.',
      conflictHook: 'The colors are disappearing! You must find the Heart of the Jungle to bring them back.',
      sensoryPalette: 'Glowing moss, humming vines, the sweet scent of star-fruit.',
    ),
    ScenarioCard(
      id: 'crystal_cavern',
      emoji: '💎',
      title: 'The Crystal Cavern of Echoes',
      illustration: 'images/scenarios/sparkle_cave.png',
      description: 'A cave where echoes steal voices if you are too loud. Speak in whispers!',
      conflictHook: 'The Echo-King has borrowed your friend\'s voice, and you need a clever riddle to get it back.',
      sensoryPalette: 'Glittering walls, dripping water sounds, cool smooth stone underfoot.',
    ),
    ScenarioCard(
      id: 'storm_chaser_sky',
      emoji: '🌩️',
      title: "The Storm-Chaser's Sky Fortress",
      illustration: 'images/scenarios/cloud_castle.png',
      description: 'A floating fortress racing through a sea of lightning clouds!',
      conflictHook: 'The steering wheel of the Sky Fortress is stuck in a giant cloud-whirlpool.',
      sensoryPalette: 'Deep thunder rumbles, the smell of ozone, static tingles in the air.',
    ),
    ScenarioCard(
      id: 'vanishing_colors',
      emoji: '🎨',
      title: 'The Land of Vanishing Colors',
      illustration: 'images/scenarios/rainbow_land.png',
      description: 'Someone is erasing the world! Use your magic to paint it back to life.',
      conflictHook: 'The Great Eraser is turning everything gray, and only your creativity can stop it.',
      sensoryPalette: 'Shimmering air, the smell of wet paint, smooth canvas textures.',
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
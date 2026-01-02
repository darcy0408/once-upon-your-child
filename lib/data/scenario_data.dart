
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
      id: 'school_jitters',
      emoji: '🚪',
      title: 'The Magic Door',
      illustration: 'images/scenarios/magic_door.png',
      description: 'A special door that takes you somewhere magical!',
      conflictHook: 'Must find the right magic door to return home',
      sensoryPalette: 'Warm golden light, tinkling sounds, sweet air',
    ),
    ScenarioCard(
      id: 'big_feelings',
      emoji: '🐉',
      title: 'The Sleeping Dragon',
      illustration: 'images/scenarios/sleeping_dragon.png',
      description: 'Help wake up a friendly sleeping dragon!',
      conflictHook: 'Must gently wake the sleeping dragon with kindness',
      sensoryPalette: 'Warm breath, soft snoring, cozy cave',
    ),
    ScenarioCard(
      id: 'making_friends',
      emoji: '🌳',
      title: 'The Glowing Forest',
      illustration: 'images/scenarios/glowing_forest.png',
      description: 'Trees that glow like nightlights!',
      conflictHook: 'The forest is losing its glow and needs help shining again',
      sensoryPalette: 'Soft glowing lights, gentle rustling, sweet flower smells',
    ),
    ScenarioCard(
      id: 'being_brave',
      emoji: '💎',
      title: 'The Sparkle Cave',
      illustration: 'images/scenarios/sparkle_cave.png',
      description: 'A cave full of beautiful sparkling crystals!',
      conflictHook: 'Must speak softly to keep the crystals sparkling',
      sensoryPalette: 'Twinkling lights, dripping water, cool smooth stones',
    ),
    ScenarioCard(
      id: 'calm_moments',
      emoji: '☁️',
      title: 'The Cloud Castle',
      illustration: 'images/scenarios/cloud_castle.png',
      description: 'A soft, fluffy castle made of clouds!',
      conflictHook: 'The castle is floating away and needs an anchor',
      sensoryPalette: 'Soft fluffy clouds, gentle breezes, sunshine warmth',
    ),
    ScenarioCard(
      id: 'creative_ideas',
      emoji: '🎨',
      title: 'The Rainbow Land',
      illustration: 'images/scenarios/rainbow_land.png',
      description: 'A magical place where colors come to life!',
      conflictHook: 'The colors are fading and need to be painted back',
      sensoryPalette: 'Bright colors everywhere, paint smells, smooth brushes',
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

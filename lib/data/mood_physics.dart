class MoodPhysics {
  final String id;
  final String moodName;
  final String worldRule;
  final String sensoryChange;

  const MoodPhysics({
    required this.id,
    required this.moodName,
    required this.worldRule,
    required this.sensoryChange,
  });
}

const List<MoodPhysics> moodPhysicsRules = [
  MoodPhysics(
    id: 'stormy',
    moodName: 'Stormy', // For 'Mad' or 'Stormy'
    worldRule: 'Gravity glitches whenever someone yells or stomps.',
    sensoryChange: ' The air tastes like battery acid and thunder rumbles in the ground.',
  ),
  MoodPhysics(
    id: 'blue',
    moodName: 'Blue', // For 'Sad' or 'Blue'
    worldRule: 'Raindrops act like tiny mirrors, showing memories instead of reflections.',
    sensoryChange: 'Everything sounds underwater and muted.',
  ),
  MoodPhysics(
    id: 'creative',
    moodName: 'Creative', // For 'Creative' or 'Inspired'
    worldRule: 'If you describe an object out loud, it changes form to match your description.',
    sensoryChange: 'Colors are brighter than usual and smell like crayons.',
  ),
  MoodPhysics(
    id: 'peaceful',
    moodName: 'Peaceful', // For 'Calm' or 'Peaceful'
    worldRule: 'Time moves slower the deeper you breathe.',
    sensoryChange: 'The wind whispers encouraging words and feels like a soft blanket.',
  ),
  MoodPhysics(
    id: 'brave',
    moodName: 'Brave', // For 'Brave' or 'Scared'
    worldRule: 'Shadows run away from you if you look them in the eye.',
    sensoryChange: 'Your footsteps sound like drums.',
  ),
  MoodPhysics(
    id: 'joyful',
    moodName: 'Joyful', // For 'Happy' or 'Joyful'
    worldRule: 'Laughter makes you float slightly off the ground.',
    sensoryChange: 'The air smells like cotton candy and bubbles float everywhere.',
  ),
  MoodPhysics(
    id: 'friendly',
    moodName: 'Friendly', // For 'Friends'
    worldRule: 'Language barriers disappear; everyone and everything understands you.',
    sensoryChange: 'Everything feels warm, like a hug.',
  ),
];

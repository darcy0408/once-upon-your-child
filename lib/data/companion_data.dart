class CompanionData {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final String signaturePower;
  final String powerConstraint;
  final String sensoryTell;
  final List<String> tags;

  const CompanionData({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.signaturePower,
    required this.powerConstraint,
    required this.sensoryTell,
    this.tags = const [],
  });
}

const List<CompanionData> magicCompanions = [
  CompanionData(
    id: 'dragon',
    name: 'a tiny dragon',
    emoji: '🐉',
    description: 'Breathes rainbow fire that reveals hidden paths',
    signaturePower: 'Rainbow Fire: Breathes magical fire that reveals secrets and hidden paths instead of burning things.',
    powerConstraint: 'The fire only reveals what is true; it cannot hurt anyone.',
    sensoryTell: 'Smells like campfires and cinnamon.',
    tags: ['Fire', 'Truth', 'Revealer'],
  ),
  CompanionData(
    id: 'owl',
    name: 'a wise owl',
    emoji: '🦉',
    description: 'Can see through time to show what will happen',
    signaturePower: 'Time Gaze: Can swivel its head to look briefly into the future to warn of danger.',
    powerConstraint: 'Can only see one minute ahead.',
    sensoryTell: 'Sounds like soft fluttering pages.',
    tags: ['Time', 'Wisdom', 'Future'],
  ),
  CompanionData(
    id: 'cat',
    name: 'a shadow cat',
    emoji: '🐱',
    description: 'Walks through walls and brings things from dreams',
    signaturePower: 'Dream Walk: Can walk through solid walls and fetch objects from the dream world.',
    powerConstraint: 'Must hold its breath to stay immaterial.',
    sensoryTell: 'Feels like cold mist and soft fur.',
    tags: ['Stealth', 'Dreams', 'Magic'],
  ),
  CompanionData(
    id: 'dog',
    name: 'a star dog',
    emoji: '🐕',
    description: 'Barks constellations into existence to guide the way',
    signaturePower: 'Star Bark: Barks glowing stars that form maps or light up dark places.',
    powerConstraint: 'Can only create stars when happy.',
    sensoryTell: 'Smells like fresh rain and ozone.',
    tags: ['Light', 'Guide', 'Constellations'],
  ),
  CompanionData(
    id: 'unicorn',
    name: 'a magic unicorn',
    emoji: '🦄',
    description: 'Creates bridges made of starlight and moonbeams',
    signaturePower: 'Starlight Bridge: Gallops to leave a trail of solid light that can be walked on.',
    powerConstraint: 'The bridge disappears when the sun rises.',
    sensoryTell: 'Sounds like wind chimes.',
    tags: ['Light', 'Travel', 'Magic'],
  ),
  CompanionData(
    id: 'fox',
    name: 'a clever fox',
    emoji: '🦊',
    description: 'Transforms into any shape to solve impossible puzzles',
    signaturePower: 'Shape Shift: Can turn into any object (key, ladder, umbrella) to solve a puzzle.',
    powerConstraint: 'Cannot turn into living things, only objects.',
    sensoryTell: 'Smells like pine needles and old books.',
    tags: ['Puzzle', 'Shape', 'Clever'],
  ),
  CompanionData(
    id: 'robin',
    name: 'a rockin\' robin',
    emoji: '🐦',
    description: 'Plays magical music that makes everyone dance with joy',
    signaturePower: 'Rhythm Magic: Plays a drum beat that forces anyone who hears it to dance uncontrollably or feel happy.',
    powerConstraint: 'The music stops working if the robin stops drumming.',
    sensoryTell: 'Sounds like a catchy drum beat and feels like a tapping foot.',
    tags: ['Music', 'Joy', 'Dance'],
  ),
];

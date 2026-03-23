class CompanionData {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final String signaturePower;
  final String powerConstraint;
  final String sensoryTell;
  /// A recurring personality behavior that shows up throughout every story —
  /// not just at the climax. Use this to make the character feel consistent
  /// and real across adventures.
  final String behaviorPattern;
  final List<String> tags;

  const CompanionData({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.signaturePower,
    required this.powerConstraint,
    required this.sensoryTell,
    required this.behaviorPattern,
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
    behaviorPattern: 'The tiny dragon is always first to investigate. The moment something new appears — a door, a shadow, a sound — they dart straight at it and sniff hard before anyone else gets close. Every discovery earns a small involuntary burst of color from their nostrils, whether anyone is watching or not. They celebrate the small things.',
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
    behaviorPattern: 'The wise owl swivels their head slowly before saying anything — as if checking two or three possible futures before settling on words. They offer advice as questions rather than answers. When they go very still and completely silent, something important is about to happen. Everyone around them learns to notice the stillness.',
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
    behaviorPattern: 'The shadow cat moves without permission and vanishes without warning. They reappear carrying something — an object, a clue, an impression from somewhere else — and offer it without explanation. They never apologize for disappearing and never explain where they went. Sometimes what they bring back turns out to be exactly what was needed.',
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
    behaviorPattern: 'The star dog is relentlessly optimistic. When things go wrong, they wag first and assess second. They have a habit of pressing their warm weight against whoever seems most discouraged — not saying anything, just being there. And in the darkest moments, they bark a single glowing star into the air whether anyone asked them to or not.',
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
    behaviorPattern: 'The magic unicorn moves at exactly the pace the moment needs — never rushing, never dragging. When a gap appears — a chasm, an awkward silence, a relationship that\'s cracked — they walk quietly to the edge and begin. They do not announce what they\'re doing. They finish what they start before moving on to the next thing.',
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
    behaviorPattern: 'The clever fox always finds an angle others miss — and they find it slightly too late, just after someone has struggled. They notice everything but share nothing until the right moment. If you catch them smiling, a solution is probably already in motion. They won\'t tell you what it is. They\'ll just ask one small question that points the way.',
    tags: ['Puzzle', 'Shape', 'Clever'],
  ),
  CompanionData(
    id: 'robin',
    name: 'Robin',
    emoji: '🐦‍⬛',
    description: 'Flies ahead to scout the path and keeps the group safe from danger',
    signaturePower: 'Guardian Flight: Darts ahead of the group to map the path, then calls back with her song — one long clear note means safe, three sharp chirps means stop and wait. She can distract or redirect anything threatening long enough for the group to find another way.',
    powerConstraint: 'She can warn, distract, and redirect — but she trusts the hero to be brave when the path is clear. She never fights alone.',
    sensoryTell: 'The faint smell of warm morning air, and a quick melodic whistle that sounds exactly like a hello.',
    behaviorPattern: 'Robin scouts every step before the group takes it — threshold for danger: very low. Three sharp chirps means stop; one long note means safe. When she decides something is a threat she launches herself at it wings-first, loud and fearless, batting it back — she has been wrong before and does not slow down. There is no quiet version of Robin alarmed. When the danger clears she lands on the hero\'s shoulder and may bring a small gift: a berry, a bright pebble, a feather pulled from her own chest. The love is obvious through every frantic, shrieking, wing-flapping moment of it.',
    tags: ['Scout', 'Protector', 'Guardian'],
  ),
];

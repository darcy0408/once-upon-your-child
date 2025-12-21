class SparkTool {
  final String id;
  final String name;
  final String emoji;
  final String description;

  const SparkTool({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
  });
}

const List<SparkTool> sparkTools = [
  SparkTool(
    id: 'door_chalk',
    name: 'Door-Chalk',
    emoji: '🖍️',
    description: 'Draw a door on any wall to walk through it.',
  ),
  SparkTool(
    id: 'thunderbell',
    name: 'Pocket Thunderbell',
    emoji: '🔔',
    description: 'Rings with the sound of a storm to scare away fears.',
  ),
  SparkTool(
    id: 'gravity_ribbon',
    name: 'Ribbon of Gravity',
    emoji: '🎀',
    description: 'Ties things down or lets them float away.',
  ),
  SparkTool(
    id: 'sun_jar',
    name: 'Sun-In-A-Jar',
    emoji: '☀️',
    description: 'Release a burst of pure sunlight in dark places.',
  ),
  SparkTool(
    id: 'whisper_net',
    name: 'Whisper-Net',
    emoji: '🕸️',
    description: 'Catch secrets or soft sounds from far away.',
  ),
  SparkTool(
    id: 'cloud_whistle',
    name: 'Cloud-Whistle',
    emoji: '🌬️',
    description: 'Summon a small cloud to ride or rain on command.',
  ),
  SparkTool(
    id: 'truth_lens',
    name: 'Truth-Lens',
    emoji: '🔍',
    description: 'Look through it to see things as they really are.',
  ),
  SparkTool(
    id: 'shadow_needle',
    name: 'Shadow-Needle',
    emoji: '🪡',
    description: 'Sew shadows together to make bridges or traps.',
  ),
    SparkTool(
    id: 'echo_shell',
    name: 'Echo-Shell',
    emoji: '🐚',
    description: 'Record a sound and play it back later, or send a message.',
  ),
  SparkTool(
    id: 'frost_key',
    name: 'Frost-Key',
    emoji: '🗝️',
    description: 'Freeze anything you touch with it, or unlock frozen things.',
  ),
];

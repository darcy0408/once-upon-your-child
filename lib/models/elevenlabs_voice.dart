/// ElevenLabs voice model and curated voice list for the voice picker.
class ElevenLabsVoice {
  final String id;
  final String name;
  final String gender;
  final String accent;
  final String description;
  final bool recommended;
  final String ageHint;

  const ElevenLabsVoice({
    required this.id,
    required this.name,
    required this.gender,
    required this.accent,
    required this.description,
    this.recommended = false,
    this.ageHint = 'all ages',
  });

  /// Default voice ID (Rachel — warm female, ideal for kids).
  static const String defaultVoiceId = '21m00Tcm4TlvDq8ikWAM';

  /// SharedPreferences key for persisted voice selection.
  static const String prefsKey = 'tts_voice_id';

  static ElevenLabsVoice? byId(String id) {
    try {
      return curated.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  static const List<ElevenLabsVoice> curated = [
    ElevenLabsVoice(
      id: '21m00Tcm4TlvDq8ikWAM',
      name: 'Rachel',
      gender: 'female',
      accent: 'American',
      description: 'Warm and gentle — perfect for bedtime stories',
      recommended: true,
    ),
    ElevenLabsVoice(
      id: 'XrExE9yKIg1WjnnlVkGX',
      name: 'Matilda',
      gender: 'female',
      accent: 'American',
      description: 'Bright and friendly narrator kids love',
    ),
    ElevenLabsVoice(
      id: 'ThT5KcBeYPX3keUQqHPh',
      name: 'Dorothy',
      gender: 'female',
      accent: 'British',
      description: 'Classic British storyteller, calm and clear',
    ),
    ElevenLabsVoice(
      id: 'jBpfuIE2acCO8z3wKNLl',
      name: 'Gigi',
      gender: 'female',
      accent: 'American',
      description: 'Playful and childlike — great for little ones',
      ageHint: 'ages 3–7',
    ),
    ElevenLabsVoice(
      id: 'JBFqnCBsd6RMkjVDRZzb',
      name: 'George',
      gender: 'male',
      accent: 'British',
      description: 'Rich British narrator — ideal for adventures',
    ),
    ElevenLabsVoice(
      id: 'IKne3meq5aSn9XLyUdCD',
      name: 'Charlie',
      gender: 'male',
      accent: 'Australian',
      description: 'Relaxed and warm Australian storyteller',
    ),
    ElevenLabsVoice(
      id: 'N2lVS1w4EtoT3dr4eOWO',
      name: 'Callum',
      gender: 'male',
      accent: 'American',
      description: 'Clear and expressive — great for action tales',
      ageHint: 'ages 8+',
    ),
    ElevenLabsVoice(
      id: 'D38z5RcWu1voky8WS1ja',
      name: 'Fin',
      gender: 'male',
      accent: 'Irish',
      description: 'Charming Irish lilt — magical and enchanting',
    ),
  ];
}

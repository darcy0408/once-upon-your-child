import '../theme/age_band_theme.dart';

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

  /// Default voice ID (Matilda — warm expressive narrator, best for kids' stories).
  static const String defaultVoiceId = 'XrExE9yKIg1WjnnlVkGX';

  /// SharedPreferences key for persisted voice selection.
  static const String prefsKey = 'tts_voice_id';

  /// SharedPreferences key for persisted playback speed.
  static const String playbackRatePrefsKey = 'tts_playback_rate';

  /// Returns the age-appropriate default voice ID for the given [band].
  /// This is the voice that will be pre-selected for new users.
  /// User overrides stored in SharedPreferences always take priority.
  static String defaultVoiceIdForBand(AgeBand band) {
    switch (band) {
      case AgeBand.sprout:
      case AgeBand.explorer:
        return 'jBpfuIE2acCO8z3wKNLl'; // Gigi — playful, childlike
      case AgeBand.adventurer:
      case AgeBand.creator:
        return 'XrExE9yKIg1WjnnlVkGX'; // Matilda — warm storyteller
      case AgeBand.adolescent:
        return 'N2lVS1w4EtoT3dr4eOWO'; // Callum — clear, expressive, older
      case AgeBand.adult:
        return '21m00Tcm4TlvDq8ikWAM'; // Rachel — calm, mature
    }
  }

  /// Returns the character voice ID to use when [narratorVoiceId] is the narrator.
  /// Female narrators → Fin (male, Irish, magical feel).
  /// Fin narrating → Callum.
  /// Male narrators (George/Charlie/Callum) → Gigi.
  static String characterVoiceForNarrator(String narratorVoiceId) {
    const _femaleIds = {
      'XrExE9yKIg1WjnnlVkGX', // Matilda
      '21m00Tcm4TlvDq8ikWAM', // Rachel
      'ThT5KcBeYPX3keUQqHPh', // Dorothy
      'jBpfuIE2acCO8z3wKNLl', // Gigi
    };
    const _finId = 'D38z5RcWu1voky8WS1ja';
    const _callumId = 'N2lVS1w4EtoT3dr4eOWO';
    const _gigiId = 'jBpfuIE2acCO8z3wKNLl';

    if (_femaleIds.contains(narratorVoiceId)) return _finId;
    if (narratorVoiceId == _finId) return _callumId;
    return _gigiId; // George, Charlie, Callum
  }

  static ElevenLabsVoice? byId(String id) {
    try {
      return curated.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  static const List<ElevenLabsVoice> curated = [
    ElevenLabsVoice(
      id: 'XrExE9yKIg1WjnnlVkGX',
      name: 'Matilda',
      gender: 'female',
      accent: 'American',
      description: 'Warm, expressive storyteller — best for children\'s narration',
      recommended: true,
    ),
    ElevenLabsVoice(
      id: '21m00Tcm4TlvDq8ikWAM',
      name: 'Rachel',
      gender: 'female',
      accent: 'American',
      description: 'Calm and gentle — great for bedtime stories',
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

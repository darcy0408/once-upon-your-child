// lib/emotion_models.dart

/// Emotion models for the feelings wheel implementation
class EmotionState {
  final CoreEmotion core;
  final String specific;
  final String faceKey;

  const EmotionState({
    required this.core,
    required this.specific,
    required this.faceKey,
  });

  EmotionState copyWith({
    CoreEmotion? core,
    String? specific,
    String? faceKey,
  }) {
    return EmotionState(
      core: core ?? this.core,
      specific: specific ?? this.specific,
      faceKey: faceKey ?? this.faceKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'core': core.name,
        'specific': specific,
        'face_key': faceKey,
      };

  factory EmotionState.fromJson(Map<String, dynamic> json) {
    return EmotionState(
      core: CoreEmotion.values.firstWhere(
        (e) => e.name == json['core'],
        orElse: () => CoreEmotion.joy,
      ),
      specific: json['specific'] ?? '',
      faceKey: json['face_key'] ?? 'neutral',
    );
  }
}

enum CoreEmotion {
  joy,
  love,
  surprise,
  sadness,
  fear,
  anger;

  String get displayName {
    switch (this) {
      case CoreEmotion.joy:
        return 'Joy';
      case CoreEmotion.love:
        return 'Love';
      case CoreEmotion.surprise:
        return 'Surprise';
      case CoreEmotion.sadness:
        return 'Sadness';
      case CoreEmotion.fear:
        return 'Fear';
      case CoreEmotion.anger:
        return 'Anger';
    }
  }

  String get emoji {
    switch (this) {
      case CoreEmotion.joy:
        return '😀';
      case CoreEmotion.love:
        return '🥰';
      case CoreEmotion.surprise:
        return '😲';
      case CoreEmotion.sadness:
        return '😢';
      case CoreEmotion.fear:
        return '😨';
      case CoreEmotion.anger:
        return '😠';
    }
  }
}

class SpecificEmotion {
  final String name;
  final String emoji;
  final String faceKey;
  final String description;

  const SpecificEmotion({
    required this.name,
    required this.emoji,
    required this.faceKey,
    required this.description,
  });
}

/// The Feelings Wheel - maps core emotions to specific feelings
class FeelingsWheel {
  static const Map<CoreEmotion, List<SpecificEmotion>> emotions = {
    CoreEmotion.joy: [
      SpecificEmotion(
        name: 'Proud',
        emoji: '😊',
        faceKey: 'joy_proud',
        description: 'Big smile, chin up',
      ),
      SpecificEmotion(
        name: 'Calm',
        emoji: '😌',
        faceKey: 'joy_calm',
        description: 'Soft smile, relaxed',
      ),
      SpecificEmotion(
        name: 'Excited',
        emoji: '🤩',
        faceKey: 'joy_excited',
        description: 'Wide smile, bright eyes',
      ),
      SpecificEmotion(
        name: 'Hopeful',
        emoji: '🙂',
        faceKey: 'joy_hopeful',
        description: 'Soft smile, upward brows',
      ),
      SpecificEmotion(
        name: 'Loved',
        emoji: '🥰',
        faceKey: 'joy_loved',
        description: 'Warm smile with hearts',
      ),
    ],
    CoreEmotion.love: [
      SpecificEmotion(
        name: 'Supported',
        emoji: '😊',
        faceKey: 'love_supported',
        description: 'Soft smile, relaxed eyes',
      ),
      SpecificEmotion(
        name: 'Connected',
        emoji: '🤗',
        faceKey: 'love_connected',
        description: 'Warm embrace feeling',
      ),
      SpecificEmotion(
        name: 'Caring',
        emoji: '🥰',
        faceKey: 'love_caring',
        description: 'Gentle smile, warm eyes',
      ),
      SpecificEmotion(
        name: 'Affectionate',
        emoji: '😘',
        faceKey: 'love_affectionate',
        description: 'Loving expression',
      ),
      SpecificEmotion(
        name: 'Warm',
        emoji: '☺️',
        faceKey: 'love_warm',
        description: 'Cozy, glowing feeling',
      ),
    ],
    CoreEmotion.surprise: [
      SpecificEmotion(
        name: 'Curious',
        emoji: '🤔',
        faceKey: 'surprise_curious',
        description: 'Raised eyebrow, thoughtful',
      ),
      SpecificEmotion(
        name: 'Confused',
        emoji: '😕',
        faceKey: 'surprise_confused',
        description: 'Tilted mouth, uneven brows',
      ),
      SpecificEmotion(
        name: 'Shocked',
        emoji: '😱',
        faceKey: 'surprise_shocked',
        description: 'Eyes huge, round mouth',
      ),
      SpecificEmotion(
        name: 'Amazed',
        emoji: '🤩',
        faceKey: 'surprise_amazed',
        description: 'Sparkle eyes, wow mouth',
      ),
    ],
    CoreEmotion.sadness: [
      SpecificEmotion(
        name: 'Lonely',
        emoji: '😔',
        faceKey: 'sad_lonely',
        description: 'Eyes looking down, slight frown',
      ),
      SpecificEmotion(
        name: 'Disappointed',
        emoji: '😞',
        faceKey: 'sad_disappointed',
        description: 'Slanted brows, flat mouth',
      ),
      SpecificEmotion(
        name: 'Guilty',
        emoji: '😣',
        faceKey: 'sad_guilty',
        description: 'Eyes sideways, small frown',
      ),
      SpecificEmotion(
        name: 'Ashamed',
        emoji: '😳',
        faceKey: 'sad_ashamed',
        description: 'Head tilted down, blush',
      ),
      SpecificEmotion(
        name: 'Powerless',
        emoji: '😓',
        faceKey: 'sad_powerless',
        description: 'Exhausted eyes, low energy',
      ),
    ],
    CoreEmotion.fear: [
      SpecificEmotion(
        name: 'Scared',
        emoji: '😨',
        faceKey: 'fear_scared',
        description: 'Wide eyes, open mouth',
      ),
      SpecificEmotion(
        name: 'Insecure',
        emoji: '😟',
        faceKey: 'fear_insecure',
        description: 'Worried eyes, tight mouth',
      ),
      SpecificEmotion(
        name: 'Helpless',
        emoji: '😢',
        faceKey: 'fear_helpless',
        description: 'Tears starting, sad brows',
      ),
      SpecificEmotion(
        name: 'Overwhelmed',
        emoji: '😰',
        faceKey: 'fear_overwhelmed',
        description: 'Stress lines, sweat drop',
      ),
    ],
    CoreEmotion.anger: [
      SpecificEmotion(
        name: 'Frustrated',
        emoji: '😤',
        faceKey: 'anger_frustrated',
        description: 'Brows down, clenched mouth',
      ),
      SpecificEmotion(
        name: 'Annoyed',
        emoji: '😒',
        faceKey: 'anger_annoyed',
        description: 'One brow down, flat mouth',
      ),
      SpecificEmotion(
        name: 'Jealous',
        emoji: '😠',
        faceKey: 'anger_jealous',
        description: 'Side-eye, tight mouth',
      ),
      SpecificEmotion(
        name: 'Resentful',
        emoji: '😡',
        faceKey: 'anger_resentful',
        description: 'Tense brows, slight frown',
      ),
    ],
  };

  static List<SpecificEmotion> getSpecificEmotions(CoreEmotion core) {
    return emotions[core] ?? [];
  }
}

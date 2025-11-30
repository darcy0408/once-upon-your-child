// lib/feelings_wheel_data.dart
// Feelings Wheel Data Structure for Flutter
// Cross-platform compatible with React web app

import 'package:flutter/material.dart';


class Feeling {
  final String id;
  final String name;
  final String emoji;
  final String eyeType;
  final String mouthType;
  final Color? color;

  const Feeling({
    required this.id,
    required this.name,
    required this.emoji,
    required this.eyeType,
    required this.mouthType,
    this.color,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'eyeType': eyeType,
        'mouthType': mouthType,
      };
}

class SecondaryFeeling extends Feeling {
  final List<String> tertiary;

  const SecondaryFeeling({
    required super.id,
    required super.name,
    required super.emoji,
    required super.eyeType,
    required super.mouthType,
    required this.tertiary,
  });
}

class CoreEmotion extends Feeling {
  final List<SecondaryFeeling> secondary;

  const CoreEmotion({
    required super.id,
    required super.name,
    required super.emoji,
    required super.eyeType,
    required super.mouthType,
    required super.color,
    required this.secondary,
  });
}

class SelectedFeeling {
  final String core;
  final String secondary;
  final String tertiary;
  final String emoji;
  final String eyeType;
  final String mouthType;
  final Color color;

  const SelectedFeeling({
    required this.core,
    required this.secondary,
    required this.tertiary,
    required this.emoji,
    required this.eyeType,
    required this.mouthType,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
        'core': core,
        'secondary': secondary,
        'tertiary': tertiary,
        'emoji': emoji,
        'eyeType': eyeType,
        'mouthType': mouthType,
        'color': '#${color.value.toRadixString(16).substring(2)}',
      };

  factory SelectedFeeling.fromJson(Map<String, dynamic> json) {
    return SelectedFeeling(
      core: json['core'] ?? '',
      secondary: json['secondary'] ?? '',
      tertiary: json['tertiary'] ?? '',
      emoji: json['emoji'] ?? '',
      eyeType: json['eyeType'] ?? 'Happy',
      mouthType: json['mouthType'] ?? 'Smile',
      color: _parseColor(json['color']),
    );
  }

  static Color _parseColor(String? colorString) {
    if (colorString == null) return const Color(0xFFFFD93D);
    final hex = colorString.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

class FeelingSupportInfo {
  final List<String> bodySignals;
  final List<String> copingIdeas;

  const FeelingSupportInfo({
    required this.bodySignals,
    required this.copingIdeas,
  });
}

/// Optional emoji mapping for tertiary feelings (matches FeelingsWheel.png)
class FeelingsEmojiLookup {
  static const Map<String, String> tertiary = {
    'Proud': '😊',
    'Calm': '😌',
    'Excited': '🤩',
    'Hopeful': '🙂',
    'Loved': '🥰',
    'Supported': '😊',
    'Connected': '🤗',
    'Caring': '🥰',
    'Affectionate': '😘',
    'Warm': '☺️',
    'Curious': '🤔',
    'Confused': '😕',
    'Shocked': '😱',
    'Amazed': '🤩',
    'Lonely': '😔',
    'Embarrassed': '😳',
    'Disappointed': '😞',
    'Hurt': '😢',
    'Guilty': '😟',
    'Scared': '😨',
    'Nervous': '😬',
    'Worried': '😟',
    'Anxious': '😰',
    'Panicked': '😱',
    'Angry': '😠',
    'Frustrated': '😤',
    'Annoyed': '😒',
    'Jealous': '😒',
    'Irritated': '😑',
  };

  static String? emojiFor(String name) => tertiary[name];
}

class FeelingDetail {
  final String description;
  final List<String> coping;
  final String? emoji;

  const FeelingDetail({
    required this.description,
    required this.coping,
    this.emoji,
  });
}

/// Child-friendly descriptions and coping ideas per feeling.
class FeelingDetails {
  static final Map<String, FeelingDetail> _details = {
    'Frustrated': const FeelingDetail(
      description: 'When things feel stuck or not going your way.',
      coping: [
        'Pause and take 3 slow breaths.',
        'Shake out your hands and stretch.',
        'Ask an adult to break the problem into small steps.',
      ],
      emoji: '😤',
    ),
    'Worried': const FeelingDetail(
      description: 'When your brain keeps thinking about “what if” things.',
      coping: [
        'Name five things you can see to feel calmer.',
        'Breathe in for 4, out for 4.',
        'Tell a trusted adult what you’re worried about.',
      ],
      emoji: '😟',
    ),
    'Lonely': const FeelingDetail(
      description: 'When you miss being with others or feel left out.',
      coping: [
        'Hug a stuffed friend or cozy pillow.',
        'Draw someone you like spending time with.',
        'Say hi to someone nearby or send a kind message.',
      ],
      emoji: '😔',
    ),
    'Vulnerable': const FeelingDetail(
      description: 'When you feel unprotected or unsure and need extra care.',
      coping: [
        'Sit close to someone safe.',
        'Place your hand on your heart and breathe slowly.',
        'Wrap in a blanket and notice you are safe right now.',
      ],
      emoji: '😟',
    ),
    'Despair': const FeelingDetail(
      description: 'When it feels like nothing will get better.',
      coping: [
        'Tell a trusted adult how heavy it feels.',
        'Name one small thing you can do next.',
        'Take three slow breaths and notice your feet on the ground.',
      ],
      emoji: '😞',
    ),
    'Guilty': const FeelingDetail(
      description: 'When you feel you did something wrong and wish you could undo it.',
      coping: [
        'Say sorry or make a small repair.',
        'Write or draw what you would do differently.',
        'Remind yourself mistakes help us learn.',
      ],
      emoji: '😔',
    ),
    'Depressed': const FeelingDetail(
      description: 'When you feel very low, empty, or drained for a while.',
      coping: [
        'Move your body gently, like a short walk or stretch.',
        'Talk to someone supportive about how long this has felt this way.',
        'Do one tiny kind thing for yourself, like a sip of water.',
      ],
      emoji: '☁️',
    ),
    'Mad': const FeelingDetail(
      description: 'When your body feels hot and you want things to change.',
      coping: [
        'Stomp safely like a dinosaur, then pause.',
        'Blow big dragon breaths into your hands.',
        'Talk about what bothered you.',
      ],
      emoji: '😠',
    ),
    'Excited': const FeelingDetail(
      description: 'When you feel super ready and full of energy.',
      coping: [
        'Do a happy dance.',
        'Tell someone your good news.',
        'Take a breath to enjoy the moment.',
      ],
      emoji: '🤩',
    ),
    'Calm': const FeelingDetail(
      description: 'When your body feels relaxed and peaceful.',
      coping: [
        'Listen to soft music or nature sounds.',
        'Take a slow stretch.',
        'Notice three things that feel good right now.',
      ],
      emoji: '😌',
    ),
    'Scared': const FeelingDetail(
      description: 'When something feels unsafe or surprising.',
      coping: [
        'Hold a comfort item.',
        'Look around and name things that are safe.',
        'Stand near a trusted adult.',
      ],
      emoji: '😨',
    ),
    'Sad': const FeelingDetail(
      description: 'When you feel down, miss someone, or something hurt your heart.',
      coping: [
        'Wrap up in a cozy blanket.',
        'Draw or write about your feeling.',
        'Talk to someone who listens kindly.',
      ],
      emoji: '😢',
    ),
    'Surprised': const FeelingDetail(
      description: 'When something unexpected happens fast.',
      coping: [
        'Blink slowly and take a breath.',
        'Share the surprise with someone.',
        'Stretch your arms wide and relax.',
      ],
      emoji: '😲',
    ),
    'Proud': const FeelingDetail(
      description: 'When you feel good about what you did.',
      coping: [
        'Tell someone what you accomplished.',
        'Write or draw your win.',
        'Help a friend using your new skill.',
      ],
      emoji: '😊',
    ),
  };

  static FeelingDetail forFeeling(SelectedFeeling feeling) {
    return _details[feeling.tertiary] ??
        _details[feeling.secondary] ??
        _details[feeling.core] ??
        const FeelingDetail(
          description: 'This is how you feel right now.',
          coping: [
            'Take a slow breath in and out.',
            'Share your feeling with someone you trust.',
          ],
          emoji: null,
        );
  }
}

class FeelingSupportLibrary {
  static final Map<String, FeelingSupportInfo> _secondaryLevel = {
    'Joyful': const FeelingSupportInfo(
      bodySignals: [
        'Big smiles',
        'Lots of energy',
        'Bouncing feet',
      ],
      copingIdeas: [
        'Share good news with someone',
        'Dance it out',
        'Take a deep breath to enjoy the moment',
      ],
    ),
    'Content': const FeelingSupportInfo(
      bodySignals: [
        'Loose shoulders',
        'Soft breathing',
        'Warm feeling in the chest',
      ],
      copingIdeas: [
        'Keep enjoying the calm moment',
        'Listen to quiet music',
        'Do a gentle stretch',
      ],
    ),
    'Proud': const FeelingSupportInfo(
      bodySignals: [
        'Standing tall',
        'Bright eyes',
        'Light, steady breathing',
      ],
      copingIdeas: [
        'Tell someone what you accomplished',
        'Write or draw the achievement',
        'Help a friend using your new skill',
      ],
    ),
    'Lonely': const FeelingSupportInfo(
      bodySignals: [
        'Heavy chest',
        'Downcast eyes',
        'Slow movements',
      ],
      copingIdeas: [
        'Reach out to a friend or family member',
        'Cuddle a favorite stuffed friend',
        'Read or listen to a comforting story',
      ],
    ),
    'Vulnerable': const FeelingSupportInfo(
      bodySignals: [
        'Looking around for safety',
        'Tight shoulders',
        'Wanting to curl up',
      ],
      copingIdeas: [
        'Sit with a trusted person or cozy item',
        'Place hand on heart and breathe slowly',
        'Remind yourself who keeps you safe',
      ],
    ),
    'Despair': const FeelingSupportInfo(
      bodySignals: [
        'Slumped posture',
        'Deep sighs',
        'Very low energy',
      ],
      copingIdeas: [
        'Ask for support from someone safe',
        'Name one small thing you can control',
        'Drink water and take 3 grounding breaths',
      ],
    ),
    'Guilty': const FeelingSupportInfo(
      bodySignals: [
        'Heavy stomach',
        'Avoiding eye contact',
        'Quiet voice',
      ],
      copingIdeas: [
        'Say sorry or make a repair if you can',
        'Write down what you learned',
        'Take a breath and plan a better choice next time',
      ],
    ),
    'Depressed': const FeelingSupportInfo(
      bodySignals: [
        'Very low energy',
        'Slow movements',
        'Wanting to stay still or alone',
      ],
      copingIdeas: [
        'Move gently: stretch, small walk, or sway',
        'Talk to someone supportive',
        'Do one tiny task, then rest',
      ],
    ),
    'Hurt': const FeelingSupportInfo(
      bodySignals: [
        'Tight throat',
        'Watering eyes',
        'Frowning mouth',
      ],
      copingIdeas: [
        'Talk about what happened with a trusted adult',
        'Place hands on heart and take deep breaths',
        'Write down feelings and crumple the paper gently',
      ],
    ),
    'Worried': const FeelingSupportInfo(
      bodySignals: [
        'Fluttering stomach',
        'Fast thoughts',
        'Fidgety hands',
      ],
      copingIdeas: [
        'Name five things you can see to stay present',
        'Breathe in for 4 counts, out for 4 counts',
        'Create a “what helps me” list',
      ],
    ),
    'Frustrated': const FeelingSupportInfo(
      bodySignals: [
        'Tight jaw',
        'Clenched fists',
        'Hot cheeks',
      ],
      copingIdeas: [
        'Take a break and shake out hands',
        'Count slowly to ten',
        'Talk through the problem step by step',
      ],
    ),
    'Mad': const FeelingSupportInfo(
      bodySignals: [
        'Fast heartbeat',
        'Loud voice',
        'Eyebrows pulled down',
      ],
      copingIdeas: [
        'Stomp feet safely like a dinosaur, then pause',
        'Blow big breaths into your hands',
        'Draw your angry monster and then give it a hug',
      ],
    ),
    'Scared': const FeelingSupportInfo(
      bodySignals: [
        'Cold hands',
        'Wide eyes',
        'Quick breathing',
      ],
      copingIdeas: [
        'Hold a comfort item or blanket',
        'Look around and name things that feel safe',
        'Ask for a reassuring hug',
      ],
    ),
    'Surprised': const FeelingSupportInfo(
      bodySignals: [
        'Raised eyebrows',
        'Gasps of breath',
        'Jumpy shoulders',
      ],
      copingIdeas: [
        'Blink slowly and take a breath',
        'Share the surprise with someone',
        'Stretch arms wide to release the burst of energy',
      ],
    ),
    'Calm': const FeelingSupportInfo(
      bodySignals: [
        'Soft muscles',
        'Gentle breathing',
        'Relaxed face',
      ],
      copingIdeas: [
        'Enjoy a mindful moment',
        'Listen to rain or nature sounds',
        'Write down grateful thoughts',
      ],
    ),
  };

  static final Map<String, FeelingSupportInfo> _coreFallback = {
    'Happy': const FeelingSupportInfo(
      bodySignals: ['Light steps', 'Smile on face'],
      copingIdeas: ['Share the joy', 'Capture the moment in a journal'],
    ),
    'Sad': const FeelingSupportInfo(
      bodySignals: ['Slow movements', 'Quiet voice'],
      copingIdeas: ['Talk to someone caring', 'Wrap up in a cozy blanket'],
    ),
    'Angry': const FeelingSupportInfo(
      bodySignals: ['Hot face', 'Tense muscles'],
      copingIdeas: ['Take a movement break', 'Squeeze a pillow or stress ball'],
    ),
    'Scared': const FeelingSupportInfo(
      bodySignals: ['Tight tummy', 'Wide eyes'],
      copingIdeas: ['Hold a comfort object', 'Breathe in for 4, out for 6'],
    ),
    'Surprised': const FeelingSupportInfo(
      bodySignals: ['Raised eyebrows', 'Open mouth'],
      copingIdeas: ['Talk about what happened', 'Do a grounding exercise'],
    ),
    'Calm': const FeelingSupportInfo(
      bodySignals: ['Loose shoulders', 'Soft gaze'],
      copingIdeas: ['Stay present and notice the peace', 'Share the calm feeling'],
    ),
  };

  static FeelingSupportInfo? findSupport(SelectedFeeling feeling) {
    return _secondaryLevel[feeling.secondary] ??
        _coreFallback[feeling.core];
  }
}

// Feelings Wheel Data
class FeelingsWheelData {
  static final List<CoreEmotion> coreEmotions = [
    CoreEmotion(
      id: 'happy',
      name: 'Happy',
      color: Color(0xFFFFD93D),
      emoji: '😊',
      eyeType: 'Happy',
      mouthType: 'Smile',
      secondary: [
        SecondaryFeeling(
          id: 'joyful',
          name: 'Joyful',
          emoji: '😄',
          eyeType: 'Happy',
          mouthType: 'Twinkle',
          tertiary: ['Excited', 'Cheerful', 'Playful', 'Energetic'],
        ),
        SecondaryFeeling(
          id: 'content',
          name: 'Content',
          emoji: '😌',
          eyeType: 'Default',
          mouthType: 'Smile',
          tertiary: ['Calm', 'Peaceful', 'Relaxed', 'Satisfied'],
        ),
        SecondaryFeeling(
          id: 'proud',
          name: 'Proud',
          emoji: '😊',
          eyeType: 'Happy',
          mouthType: 'Smile',
          tertiary: ['Confident', 'Strong', 'Capable', 'Brave'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'sad',
      name: 'Sad',
      color: Color(0xFF6495ED),
      emoji: '😢',
      eyeType: 'Dizzy',
      mouthType: 'Concerned',
      secondary: [
        SecondaryFeeling(
          id: 'vulnerable',
          name: 'Vulnerable',
          emoji: '😟',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Insecure', 'Exposed', 'Fragile', 'Sensitive'],
        ),
        SecondaryFeeling(
          id: 'despair',
          name: 'Despair',
          emoji: '😞',
          eyeType: 'Dizzy',
          mouthType: 'Concerned',
          tertiary: ['Hopeless', 'Helpless', 'Powerless', 'Overwhelmed'],
        ),
        SecondaryFeeling(
          id: 'guilty',
          name: 'Guilty',
          emoji: '😔',
          eyeType: 'Dizzy',
          mouthType: 'Concerned',
          tertiary: ['Ashamed', 'Sorry', 'Regretful', 'Responsible'],
        ),
        SecondaryFeeling(
          id: 'depressed',
          name: 'Depressed',
          emoji: '☁️',
          eyeType: 'Dizzy',
          mouthType: 'Concerned',
          tertiary: ['Empty', 'Numb', 'Drained', 'Low energy'],
        ),
        SecondaryFeeling(
          id: 'lonely',
          name: 'Lonely',
          emoji: '😔',
          eyeType: 'Dizzy',
          mouthType: 'Concerned',
          tertiary: ['Left out', 'Forgotten', 'Alone', 'Isolated'],
        ),
        SecondaryFeeling(
          id: 'hurt',
          name: 'Hurt',
          emoji: '😢',
          eyeType: 'Dizzy',
          mouthType: 'Concerned',
          tertiary: ['Disappointed', 'Let down', 'Upset', 'Heartbroken'],
        ),
        SecondaryFeeling(
          id: 'worried',
          name: 'Worried',
          emoji: '😟',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Nervous', 'Anxious', 'Stressed', 'Uneasy'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'angry',
      name: 'Angry',
      color: Color(0xFFFF6B6B),
      emoji: '😠',
      eyeType: 'EyeRoll',
      mouthType: 'Serious',
      secondary: [
        SecondaryFeeling(
          id: 'frustrated',
          name: 'Frustrated',
          emoji: '😤',
          eyeType: 'EyeRoll',
          mouthType: 'Serious',
          tertiary: ['Annoyed', 'Bothered', 'Irritated', 'Impatient'],
        ),
        SecondaryFeeling(
          id: 'mad',
          name: 'Mad',
          emoji: '😡',
          eyeType: 'EyeRoll',
          mouthType: 'Serious',
          tertiary: ['Furious', 'Outraged', 'Livid', 'Explosive'],
        ),
        SecondaryFeeling(
          id: 'jealous',
          name: 'Jealous',
          emoji: '😒',
          eyeType: 'EyeRoll',
          mouthType: 'Concerned',
          tertiary: ['Envious', 'Resentful', 'Left out', 'Wanting'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'scared',
      name: 'Scared',
      color: Color(0xFF9B59B6),
      emoji: '😨',
      eyeType: 'Surprised',
      mouthType: 'Concerned',
      secondary: [
        SecondaryFeeling(
          id: 'afraid',
          name: 'Afraid',
          emoji: '😰',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Frightened', 'Terrified', 'Panicked', 'Alarmed'],
        ),
        SecondaryFeeling(
          id: 'nervous',
          name: 'Nervous',
          emoji: '😬',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Worried', 'Anxious', 'Jittery', 'Tense'],
        ),
        SecondaryFeeling(
          id: 'confused',
          name: 'Confused',
          emoji: '😕',
          eyeType: 'Surprised',
          mouthType: 'Default',
          tertiary: ['Uncertain', 'Unsure', 'Puzzled', 'Lost'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'surprised',
      name: 'Surprised',
      color: Color(0xFFFF9FF3),
      emoji: '😮',
      eyeType: 'Surprised',
      mouthType: 'Default',
      secondary: [
        SecondaryFeeling(
          id: 'amazed',
          name: 'Amazed',
          emoji: '😲',
          eyeType: 'Surprised',
          mouthType: 'Twinkle',
          tertiary: ['Astonished', 'Shocked', 'Stunned', 'Wow'],
        ),
        SecondaryFeeling(
          id: 'excited',
          name: 'Excited',
          emoji: '🤩',
          eyeType: 'Happy',
          mouthType: 'Twinkle',
          tertiary: ['Thrilled', 'Eager', 'Pumped', 'Energized'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'disgusted',
      name: 'Disgusted',
      color: Color(0xFF7CB342),
      emoji: '🤢',
      eyeType: 'EyeRoll',
      mouthType: 'Concerned',
      secondary: [
        SecondaryFeeling(
          id: 'grossed-out',
          name: 'Grossed Out',
          emoji: '🤮',
          eyeType: 'EyeRoll',
          mouthType: 'Concerned',
          tertiary: ['Yucky', 'Icky', 'Nasty', 'Eww'],
        ),
        SecondaryFeeling(
          id: 'uncomfortable',
          name: 'Uncomfortable',
          emoji: '😣',
          eyeType: 'Default',
          mouthType: 'Concerned',
          tertiary: ['Awkward', 'Uneasy', 'Weird', 'Off'],
        ),
      ],
    ),
  ];

  // Helper method to get all feelings as flat list
  static List<Map<String, dynamic>> getAllFeelings() {
    List<Map<String, dynamic>> feelings = [];

    for (var core in coreEmotions) {
      feelings.add({
        'level': 'core',
        'id': core.id,
        'name': core.name,
        'emoji': core.emoji,
        'color': core.color,
        'eyeType': core.eyeType,
        'mouthType': core.mouthType,
      });

      for (var secondary in core.secondary) {
        feelings.add({
          'level': 'secondary',
          'coreId': core.id,
          'coreColor': core.color,
          'id': secondary.id,
          'name': secondary.name,
          'emoji': secondary.emoji,
          'eyeType': secondary.eyeType,
          'mouthType': secondary.mouthType,
        });

        for (var tertiary in secondary.tertiary) {
          feelings.add({
            'level': 'tertiary',
            'coreId': core.id,
            'coreColor': core.color,
            'secondaryId': secondary.id,
            'name': tertiary,
            'eyeType': secondary.eyeType,
            'mouthType': secondary.mouthType,
          });
        }
      }
    }

    return feelings;
  }

  // Get feeling by name
  static Map<String, dynamic>? getFeelingByName(String name) {
    return getAllFeelings().firstWhere(
      (f) => f['name'].toString().toLowerCase() == name.toLowerCase(),
      orElse: () => {},
    );
  }
}

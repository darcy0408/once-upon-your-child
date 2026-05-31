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
  final Color? secondaryColor;
  final Color? tertiaryColor;

  const CoreEmotion({
    required super.id,
    required super.name,
    required super.emoji,
    required super.eyeType,
    required super.mouthType,
    required super.color,
    required this.secondary,
    this.secondaryColor,
    this.tertiaryColor,
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
        'color': '#${color.toARGB32().toRadixString(16).substring(2)}',
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
    'Silly': '🤪',
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
    'Wronged': '😤',
  };

  static String? emojiFor(String name) => tertiary[name];
}

class FeelingDetail {
  final String description;
  final List<String> coping;
  final String? emoji;
  final List<String>? matureCoping;

  /// Coping for the Adventurer band (~ages 9-11) — between the young `coping`
  /// and the 12+ `matureCoping`. Framed as "get steady enough to think / get
  /// your power back" rather than little-kid soothing or full teen strategy.
  /// Optional: falls back to matureCoping, then coping. (Adventurer audit:
  /// coping used to jump straight from age-8 to age-12.)
  final List<String>? tweenCoping;

  const FeelingDetail({
    required this.description,
    required this.coping,
    this.emoji,
    this.matureCoping,
    this.tweenCoping,
  });

  List<String> copingForAge(int age) {
    if (age >= 12 && matureCoping != null) return matureCoping!;
    if (age >= 9 && tweenCoping != null) return tweenCoping!;
    return coping;
  }
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
      matureCoping: [
        'Step back and take a few slow breaths.',
        'Break the problem into smaller parts.',
        'Write down what\'s blocking you.',
      ],
      tweenCoping: [
        'Step away for a minute — you think clearer once the heat drops.',
        'Find the next one small move and just do that.',
        'Name what\'s actually blocking you, out loud or on paper.',
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
      matureCoping: [
        'Practice box breathing (4 in, 4 hold, 4 out, 4 hold).',
        'Write down your worry and challenge it with evidence.',
        'Talk to someone you trust about what\'s on your mind.',
      ],
      tweenCoping: [
        'Slow your breathing — 4 in, 4 out — until your thoughts stop racing.',
        'Sort it: what can I control, what can\'t I? Start with the part you can.',
        'Tell someone you trust — you don\'t have to carry the worry alone.',
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
      matureCoping: [
        'Reach out to one person, even with a simple message.',
        'Spend time in a shared space, even quietly.',
        'Remember that loneliness is temporary and common.',
      ],
      emoji: '😔',
    ),
    'Sensitive': const FeelingDetail(
      description: 'When you feel unprotected or unsure and need extra care.',
      coping: [
        'Sit close to someone safe.',
        'Place your hand on your heart and breathe slowly.',
        'Wrap in a blanket and notice you are safe right now.',
      ],
      matureCoping: [
        'Practice box breathing (4 in, 4 hold, 4 out, 4 hold).',
        'Write down your worry and challenge it with evidence.',
        'Talk to someone you trust about what\'s on your mind.',
      ],
      emoji: '😟',
    ),
    'Really Sad': const FeelingDetail(
      description: 'When it feels like nothing will get better.',
      coping: [
        'Tell a trusted adult how heavy it feels.',
        'Name one small thing you can do next.',
        'Take three slow breaths and notice your feet on the ground.',
      ],
      matureCoping: [
        'Let yourself feel it without judgment — deep sadness is valid.',
        'Reach out to one person, even just to say you\'re struggling.',
        'If it persists, consider talking to a counsellor or therapist.',
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
      matureCoping: [
        'Acknowledge what happened without over-punishing yourself.',
        'Make amends where possible — a genuine apology or a changed action.',
        'Reflect on what you\'d do differently; guilt that leads nowhere is not useful.',
      ],
      emoji: '😔',
    ),
    'Down': const FeelingDetail(
      description: 'When you feel very low, empty, or drained for a while.',
      coping: [
        'Move your body gently, like a short walk or stretch.',
        'Talk to someone supportive about how long this has felt this way.',
        'Do one tiny kind thing for yourself, like a sip of water.',
      ],
      matureCoping: [
        'Notice if this is situational or has been building — duration matters.',
        'Small physical acts help: daylight, movement, eating something.',
        'Don\'t isolate; low-key connection (a text, a walk with someone) can shift momentum.',
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
      matureCoping: [
        'Remove yourself from the situation for a few minutes.',
        'Use deep breathing to slow your heart rate.',
        'Journal about what triggered the anger.',
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
      matureCoping: [
        'Channel the energy productively — use it, don\'t fight it.',
        'Share it with someone who\'ll appreciate it.',
        'Savour the feeling; positive states deserve attention too.',
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
      matureCoping: [
        'Use this window — calm is a good time to reflect or plan.',
        'Deepen it: slow your exhale to twice the length of your inhale.',
        'Notice what brought this on; you can recreate the conditions.',
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
      matureCoping: [
        'Ground yourself: name 5 things you see, 4 you hear, 3 you feel.',
        'Remind yourself of times you\'ve faced fear before.',
        'Talk to someone you trust about what feels threatening.',
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
      matureCoping: [
        'Allow yourself to feel it — sadness is valid.',
        'Reach out to someone you trust.',
        'Do one small thing that usually brings you comfort.',
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
      matureCoping: [
        'Pause before reacting — the surprise itself isn\'t the full picture yet.',
        'Breathe and let your nervous system catch up with events.',
        'Decide how you want to respond once the initial jolt settles.',
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
      matureCoping: [
        'Let yourself feel it fully — you earned this.',
        'Reflect on what made it possible: effort, growth, support.',
        'Use it as a reference point for the next hard thing.',
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
    'Sensitive': const FeelingSupportInfo(
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
    'Really Sad': const FeelingSupportInfo(
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
    'Down': const FeelingSupportInfo(
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
  /// Four core emotions for Sprout band (ages ≤5): simple, positive-first.
  static final List<CoreEmotion> sproutCoreEmotions = [
    CoreEmotion(
      id: 'happy',
      name: 'Happy',
      color: Color(0xFFFFA726),
      secondaryColor: Color(0xFFFFB74D),
      tertiaryColor: Color(0xFFFFCC80),
      emoji: '😊',
      eyeType: 'Happy',
      mouthType: 'Smile',
      secondary: [],
    ),
    CoreEmotion(
      id: 'sad',
      name: 'Sad',
      color: Color(0xFF42A5F5),
      secondaryColor: Color(0xFF64B5F6),
      tertiaryColor: Color(0xFF90CAF9),
      emoji: '😢',
      eyeType: 'Dizzy',
      mouthType: 'Concerned',
      secondary: [],
    ),
    CoreEmotion(
      id: 'mad',
      name: 'Mad',
      color: Color(0xFFEF5350),
      secondaryColor: Color(0xFFE57373),
      tertiaryColor: Color(0xFFEF9A9A),
      emoji: '😠',
      eyeType: 'EyeRoll',
      mouthType: 'Serious',
      secondary: [],
    ),
    CoreEmotion(
      id: 'scared',
      name: 'Scared',
      color: Color(0xFF5E35B1),
      secondaryColor: Color(0xFF7E57C2),
      tertiaryColor: Color(0xFF9575CD),
      emoji: '😨',
      eyeType: 'Surprised',
      mouthType: 'Concerned',
      secondary: [],
    ),
  ];

  static final List<CoreEmotion> bigFeelingsCoreEmotionsAges6To8 = [
    CoreEmotion(
      id: 'excited',
      name: 'Excited',
      color: Color(0xFFFFA726),
      secondaryColor: Color(0xFFFFB74D),
      tertiaryColor: Color(0xFFFFCC80),
      emoji: '🤩',
      eyeType: 'Happy',
      mouthType: 'Twinkle',
      secondary: [
        SecondaryFeeling(
          id: 'bouncy',
          name: 'Bouncy',
          emoji: '😄',
          eyeType: 'Happy',
          mouthType: 'Twinkle',
          tertiary: ['Wiggly', 'Jumpy', 'Zoomy', 'Bursting'],
        ),
        SecondaryFeeling(
          id: 'proud',
          name: 'Proud',
          emoji: '😊',
          eyeType: 'Happy',
          mouthType: 'Smile',
          tertiary: ['Can-do', 'Tall', 'Shiny', 'Brave'],
        ),
        SecondaryFeeling(
          id: "can't-wait",
          name: "Can't Wait",
          emoji: '🥳',
          eyeType: 'Happy',
          mouthType: 'Twinkle',
          tertiary: ['Counting down', 'Buzzy', 'Ready now', 'So close'],
        ),
        SecondaryFeeling(
          id: 'hyper',
          name: 'Hyper',
          emoji: '🤸',
          eyeType: 'Happy',
          mouthType: 'Twinkle',
          tertiary: ['Buzzy', 'Fast', 'Zooming', 'Too much energy'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'angry',
      name: 'Angry',
      color: Color(0xFFEF5350),
      secondaryColor: Color(0xFFE57373),
      tertiaryColor: Color(0xFFEF9A9A),
      emoji: '😠',
      eyeType: 'EyeRoll',
      mouthType: 'Serious',
      secondary: [
        SecondaryFeeling(
          id: 'mad',
          name: 'Mad',
          emoji: '😡',
          eyeType: 'EyeRoll',
          mouthType: 'Serious',
          tertiary: ['Annoyed', 'Irritated', 'Furious', 'Hurt-mad'],
        ),
        SecondaryFeeling(
          id: 'annoyed',
          name: 'Annoyed',
          emoji: '😒',
          eyeType: 'Default',
          mouthType: 'Concerned',
          tertiary: ['Grumpy', 'Bothered', 'Irritated', 'Left-out mad'],
        ),
        SecondaryFeeling(
          id: 'furious',
          name: 'Furious',
          emoji: '😤',
          eyeType: 'EyeRoll',
          mouthType: 'Serious',
          tertiary: ['Ready-to-pop', 'Steaming', 'Too hot', 'Stormy'],
        ),
        SecondaryFeeling(
          id: 'hurt-mad',
          name: 'Hurt-mad',
          emoji: '🥺',
          eyeType: 'Dizzy',
          mouthType: 'Concerned',
          tertiary: ['Left out', 'Wronged', 'Stung', 'Sad-mad'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'worried',
      name: 'Worried',
      color: Color(0xFF5E35B1),
      secondaryColor: Color(0xFF7E57C2),
      tertiaryColor: Color(0xFF9575CD),
      emoji: '😟',
      eyeType: 'Surprised',
      mouthType: 'Concerned',
      secondary: [
        SecondaryFeeling(
          id: 'nervous',
          name: 'Nervous',
          emoji: '😬',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Jumpy', 'Uneasy', 'Shaky', 'What-if-y'],
        ),
        SecondaryFeeling(
          id: 'uneasy',
          name: 'Uneasy',
          emoji: '😟',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Unsure', 'Jittery', 'Wobbly', 'Careful'],
        ),
        SecondaryFeeling(
          id: 'scared',
          name: 'Scared',
          emoji: '😨',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Jumpy', 'Startled', 'Not ready', 'Small'],
        ),
        SecondaryFeeling(
          id: 'what-if-y',
          name: 'What-if-y',
          emoji: '🫣',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Spinning', 'Busy-brain', 'Unsure', 'Overthinking'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'sad',
      name: 'Sad',
      color: Color(0xFF5C6BC0),
      secondaryColor: Color(0xFF7986CB),
      tertiaryColor: Color(0xFF9FA8DA),
      emoji: '😢',
      eyeType: 'Dizzy',
      mouthType: 'Concerned',
      secondary: [
        SecondaryFeeling(
          id: 'lonely',
          name: 'Lonely',
          emoji: '😔',
          eyeType: 'Dizzy',
          mouthType: 'Concerned',
          tertiary: ['Left out', 'Alone', 'Miss-someone', 'Quiet'],
        ),
        SecondaryFeeling(
          id: 'disappointed',
          name: 'Disappointed',
          emoji: '😞',
          eyeType: 'Dizzy',
          mouthType: 'Concerned',
          tertiary: ['Let down', 'Bummed', 'Gloomy', 'Heavy'],
        ),
        SecondaryFeeling(
          id: 'hurt',
          name: 'Hurt',
          emoji: '😢',
          eyeType: 'Dizzy',
          mouthType: 'Concerned',
          tertiary: ['Teary', 'Left out', 'Tender', 'Bruised feelings'],
        ),
        SecondaryFeeling(
          id: 'gloomy',
          name: 'Gloomy',
          emoji: '☁️',
          eyeType: 'Dizzy',
          mouthType: 'Concerned',
          tertiary: ['Heavy', 'Gray', 'Down', 'Droopy'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'frustrated',
      name: 'Frustrated',
      color: Color(0xFFFF8A65),
      secondaryColor: Color(0xFFFFAB91),
      tertiaryColor: Color(0xFFFFCCBC),
      emoji: '😤',
      eyeType: 'Default',
      mouthType: 'Concerned',
      secondary: [
        SecondaryFeeling(
          id: 'stuck',
          name: 'Stuck',
          emoji: '🧩',
          eyeType: 'Default',
          mouthType: 'Concerned',
          tertiary: ['Mixed up', 'Trying-so-hard', 'Blocked', 'Tangled'],
        ),
        SecondaryFeeling(
          id: 'bothered',
          name: 'Bothered',
          emoji: '😣',
          eyeType: 'Default',
          mouthType: 'Concerned',
          tertiary: ['Annoyed', 'Over it', 'Bugged', 'Off-track'],
        ),
        SecondaryFeeling(
          id: 'overwhelmed',
          name: 'Overwhelmed',
          emoji: '😵',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Too much', 'Flooded', 'Mixed up', 'Ready-to-pop'],
        ),
        SecondaryFeeling(
          id: 'impatient',
          name: 'Impatient',
          emoji: '⏳',
          eyeType: 'EyeRoll',
          mouthType: 'Concerned',
          tertiary: ['Rushed', 'Done waiting', 'Antsy', 'Ready now'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'embarrassed',
      name: 'Embarrassed',
      color: Color(0xFFEC407A),
      secondaryColor: Color(0xFFF06292),
      tertiaryColor: Color(0xFFF48FB1),
      emoji: '😳',
      eyeType: 'Surprised',
      mouthType: 'Concerned',
      secondary: [
        SecondaryFeeling(
          id: 'awkward',
          name: 'Awkward',
          emoji: '🫠',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Weird', 'Clumsy', 'Oops', 'Wobbly'],
        ),
        SecondaryFeeling(
          id: 'red-faced',
          name: 'Red-faced',
          emoji: '😳',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Flustered', 'Warm cheeks', 'On the spot', 'Exposed'],
        ),
        SecondaryFeeling(
          id: 'wish-i-could-hide',
          name: 'Wish-I-Could-Hide',
          emoji: '🙈',
          eyeType: 'Dizzy',
          mouthType: 'Concerned',
          tertiary: ['Tiny', 'Seen too much', 'Oops', 'Please no'],
        ),
        SecondaryFeeling(
          id: 'exposed',
          name: 'Exposed',
          emoji: '🫣',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Put on the spot', 'Picked out', 'Notice me less', 'Vulnerable'],
        ),
      ],
    ),
  ];

  static final List<CoreEmotion> coreEmotions = [
    CoreEmotion(
      id: 'happy',
      name: 'Happy',
      color: Color(0xFFFFA726),           // Base: Medium amber
      secondaryColor: Color(0xFFFFB74D),  // Lighter amber (85% sat)
      tertiaryColor: Color(0xFFFFCC80),   // Lightest amber (70% sat)
      emoji: '😊',
      eyeType: 'Happy',
      mouthType: 'Smile',
      secondary: [
        SecondaryFeeling(
          id: 'playful',
          name: 'Playful',
          emoji: '😄',
          eyeType: 'Happy',
          mouthType: 'Twinkle',
          tertiary: ['Silly', 'Cheeky'],
        ),
        SecondaryFeeling(
          id: 'content',
          name: 'Content',
          emoji: '😌',
          eyeType: 'Default',
          mouthType: 'Smile',
          tertiary: ['Free', 'Joyful'],
        ),
        SecondaryFeeling(
          id: 'interested',
          name: 'Interested',
          emoji: '🤔',
          eyeType: 'Default',
          mouthType: 'Smile',
          tertiary: ['Curious', 'Inquisitive'],
        ),
        SecondaryFeeling(
          id: 'proud',
          name: 'Proud',
          emoji: '😊',
          eyeType: 'Happy',
          mouthType: 'Smile',
          tertiary: ['Successful', 'Confident'],
        ),
        SecondaryFeeling(
          id: 'accepted',
          name: 'Accepted',
          emoji: '🥰',
          eyeType: 'Happy',
          mouthType: 'Smile',
          tertiary: ['Respected', 'Valued'],
        ),
        SecondaryFeeling(
          id: 'powerful',
          name: 'Powerful',
          emoji: '💪',
          eyeType: 'Happy',
          mouthType: 'Smile',
          tertiary: ['Courageous', 'Creative'],
        ),
        SecondaryFeeling(
          id: 'peaceful',
          name: 'Peaceful',
          emoji: '😌',
          eyeType: 'Default',
          mouthType: 'Smile',
          tertiary: ['Loving', 'Thankful'],
        ),
        SecondaryFeeling(
          id: 'trusting',
          name: 'Trusting',
          emoji: '😊',
          eyeType: 'Happy',
          mouthType: 'Smile',
          tertiary: ['Sensitive', 'Connected'],
        ),
        SecondaryFeeling(
          id: 'optimistic',
          name: 'Optimistic',
          emoji: '🙂',
          eyeType: 'Happy',
          mouthType: 'Smile',
          tertiary: ['Hopeful', 'Inspired'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'surprised',
      name: 'Surprised',
      color: Color(0xFFEC407A),           // Base: Hot pink
      secondaryColor: Color(0xFFF06292),  // Lighter pink
      tertiaryColor: Color(0xFFF48FB1),   // Lightest pink
      emoji: '😮',
      eyeType: 'Surprised',
      mouthType: 'Default',
      secondary: [
        SecondaryFeeling(
          id: 'excited',
          name: 'Excited',
          emoji: '🤩',
          eyeType: 'Happy',
          mouthType: 'Twinkle',
          tertiary: ['Energetic', 'Eager'],
        ),
        SecondaryFeeling(
          id: 'amazed',
          name: 'Amazed',
          emoji: '😲',
          eyeType: 'Surprised',
          mouthType: 'Twinkle',
          tertiary: ['Awe', 'Astonished'],
        ),
        SecondaryFeeling(
          id: 'confused',
          name: 'Confused',
          emoji: '😕',
          eyeType: 'Surprised',
          mouthType: 'Default',
          tertiary: ['Perplexed', 'Disillusioned'],
        ),
        SecondaryFeeling(
          id: 'startled',
          name: 'Startled',
          emoji: '😳',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Dismayed', 'Shocked'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'bad',
      name: 'Bad',
      color: Color(0xFF7E57C2),           // Base: Medium purple
      secondaryColor: Color(0xFF9575CD),  // Lighter purple
      tertiaryColor: Color(0xFFB39DDB),   // Lightest purple
      emoji: '😞',
      eyeType: 'Dizzy',
      mouthType: 'Concerned',
      secondary: [
        SecondaryFeeling(
          id: 'tired',
          name: 'Tired',
          emoji: '😴',
          eyeType: 'Dizzy',
          mouthType: 'Concerned',
          tertiary: ['Unfocused', 'Sleepy'],
        ),
        SecondaryFeeling(
          id: 'stressed',
          name: 'Stressed',
          emoji: '😰',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Out of Control', 'Overwhelmed'],
        ),
        SecondaryFeeling(
          id: 'busy',
          name: 'Busy',
          emoji: '😓',
          eyeType: 'Default',
          mouthType: 'Concerned',
          tertiary: ['Rushed', 'Pressured'],
        ),
        SecondaryFeeling(
          id: 'bored',
          name: 'Bored',
          emoji: '😑',
          eyeType: 'Default',
          mouthType: 'Default',
          tertiary: ['Apathetic', 'Indifferent'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'fearful',
      name: 'Fearful',
      color: Color(0xFF5E35B1),           // Base: Deep purple
      secondaryColor: Color(0xFF7E57C2),  // Medium purple
      tertiaryColor: Color(0xFF9575CD),   // Light purple
      emoji: '😨',
      eyeType: 'Surprised',
      mouthType: 'Concerned',
      secondary: [
        SecondaryFeeling(
          id: 'scared',
          name: 'Scared',
          emoji: '😱',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Helpless', 'Frightened'],
        ),
        SecondaryFeeling(
          id: 'anxious',
          name: 'Anxious',
          emoji: '😰',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Overwhelmed', 'Worried'],
        ),
        SecondaryFeeling(
          id: 'insecure',
          name: 'Insecure',
          emoji: '😟',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Inadequate', 'Inferior'],
        ),
        SecondaryFeeling(
          id: 'weak',
          name: 'Weak',
          emoji: '😔',
          eyeType: 'Dizzy',
          mouthType: 'Concerned',
          tertiary: ['Not Good Enough', 'Insignificant'],
        ),
        SecondaryFeeling(
          id: 'rejected',
          name: 'Rejected',
          emoji: '😢',
          eyeType: 'Dizzy',
          mouthType: 'Concerned',
          tertiary: ['Excluded', 'Picked On'],
        ),
        SecondaryFeeling(
          id: 'threatened',
          name: 'Threatened',
          emoji: '😬',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Nervous', 'Exposed'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'sad',
      name: 'Sad',
      color: Color(0xFF5C6BC0),           // Base: Indigo
      secondaryColor: Color(0xFF7986CB),  // Lighter indigo
      tertiaryColor: Color(0xFF9FA8DA),   // Lightest indigo
      emoji: '😢',
      eyeType: 'Dizzy',
      mouthType: 'Concerned',
      secondary: [
        SecondaryFeeling(
          id: 'vulnerable',
          name: 'Sensitive',
          emoji: '😟',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Insecure', 'Exposed', 'Fragile', 'Sensitive'],
        ),
        SecondaryFeeling(
          id: 'despair',
          name: 'Really Sad',
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
          name: 'Down',
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
      id: 'disgusted',
      name: 'Disgusted',
      color: Color(0xFF8D6E63),           // Base: Brown
      secondaryColor: Color(0xFFA1887F),  // Lighter brown
      tertiaryColor: Color(0xFFBCAAA4),   // Lightest brown
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
    CoreEmotion(
      id: 'angry',
      name: 'Angry',
      color: Color(0xFFEF5350),           // Base: Red
      secondaryColor: Color(0xFFE57373),  // Lighter red
      tertiaryColor: Color(0xFFEF9A9A),   // Lightest red
      emoji: '😠',
      eyeType: 'EyeRoll',
      mouthType: 'Serious',
      secondary: [
        SecondaryFeeling(
          id: 'let-down',
          name: 'Let Down',
          emoji: '😞',
          eyeType: 'Dizzy',
          mouthType: 'Concerned',
          tertiary: ['Betrayed', 'Resentful'],
        ),
        SecondaryFeeling(
          id: 'humiliated',
          name: 'Embarrassed',
          emoji: '😳',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Disrespected', 'Ridiculed'],
        ),
        SecondaryFeeling(
          id: 'bitter',
          name: 'Bitter',
          emoji: '😒',
          eyeType: 'EyeRoll',
          mouthType: 'Concerned',
          tertiary: ['Indignant', 'Wronged'],
        ),
        SecondaryFeeling(
          id: 'mad',
          name: 'Mad',
          emoji: '😡',
          eyeType: 'EyeRoll',
          mouthType: 'Serious',
          tertiary: ['Really Angry', 'Jealous'],
        ),
        SecondaryFeeling(
          id: 'aggressive',
          name: 'Fired Up',
          emoji: '😤',
          eyeType: 'EyeRoll',
          mouthType: 'Serious',
          tertiary: ['Wound Up', 'Ready to Fight'],
        ),
        SecondaryFeeling(
          id: 'frustrated',
          name: 'Frustrated',
          emoji: '😣',
          eyeType: 'Default',
          mouthType: 'Concerned',
          tertiary: ['Steaming', 'Annoyed'],
        ),
        SecondaryFeeling(
          id: 'distant',
          name: 'Distant',
          emoji: '😐',
          eyeType: 'Default',
          mouthType: 'Default',
          tertiary: ['Withdrawn', 'Numb'],
        ),
        SecondaryFeeling(
          id: 'critical',
          name: 'Critical',
          emoji: '🤨',
          eyeType: 'Default',
          mouthType: 'Serious',
          tertiary: ['Judgmental', 'Skeptical'],
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

  static List<CoreEmotion> coreEmotionsForAge(int childAge) {
    if (childAge <= 5) return sproutCoreEmotions;
    if (childAge <= 8) return bigFeelingsCoreEmotionsAges6To8;
    return coreEmotions;
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../theme/age_band_theme.dart';
import '../theme/age_band_asset_resolver.dart';

class BigFeelingsFlowResult {
  const BigFeelingsFlowResult({
    required this.feeling,
    required this.trigger,
    required this.bodySignal,
    required this.copingTool,
  });

  final String feeling;
  final String trigger;
  final String bodySignal;
  final String copingTool;
}

class BigFeelingsFlowScreen extends StatefulWidget {
  const BigFeelingsFlowScreen({super.key, this.childAge = 5, this.gender = ''});
  final int childAge;
  /// 'Boy', 'Girl', or '' (defaults to non-gendered path)
  final String gender;

  static Future<BigFeelingsFlowResult?> show(
    BuildContext context, {
    int childAge = 5,
    String gender = '',
  }) {
    return Navigator.of(context, rootNavigator: true)
        .push<BigFeelingsFlowResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BigFeelingsFlowScreen(childAge: childAge, gender: gender),
      ),
    );
  }

  @override
  State<BigFeelingsFlowScreen> createState() => _BigFeelingsFlowScreenState();
}

class _BigFeelingsFlowScreenState extends State<BigFeelingsFlowScreen> {
  // Core 8 — shown to every band
  static const _feelingsCore = [
    _ChoiceOption(value: 'Happy',     label: 'Happy',     emoji: '😊', subtitle: 'Big smile feeling'),
    _ChoiceOption(value: 'Sad',       label: 'Sad',       emoji: '😢', subtitle: 'Heavy, teary feeling'),
    _ChoiceOption(value: 'Mad',       label: 'Mad',       emoji: '😠', subtitle: 'Big fire feeling'),
    _ChoiceOption(value: 'Scared',    label: 'Scared',    emoji: '😨', subtitle: 'Uh-oh feeling'),
    _ChoiceOption(value: 'Excited',   label: 'Excited',   emoji: '🤩', subtitle: 'Bouncy, can\'t-wait feeling'),
    _ChoiceOption(value: 'Calm',      label: 'Calm',      emoji: '🍃', subtitle: 'Quiet and peaceful'),
    _ChoiceOption(value: 'Confused',  label: 'Confused',  emoji: '🤨', subtitle: 'Thinking hard'),
    _ChoiceOption(value: 'Surprised', label: 'Surprised', emoji: '😮', subtitle: 'Oh my!'),
  ];

  // Explorer+ (7+) adds concrete body/social feelings
  static const _feelingsExplorer = [
    _ChoiceOption(value: 'Bothered',    label: 'Bothered',   emoji: '😒', subtitle: 'Itty-bitty mad'),
    _ChoiceOption(value: 'Bouncy',      label: 'Bouncy',     emoji: '🤸', subtitle: 'High energy fun'),
    _ChoiceOption(value: 'Grossed_Out', label: 'Grossed Out',emoji: '🤢', subtitle: 'Yucky feeling'),
    _ChoiceOption(value: 'Hurt_Mad',    label: 'Hurt-Mad',   emoji: '🤕', subtitle: 'Ouchy and angry'),
    _ChoiceOption(value: 'Hyper',       label: 'Hyper',      emoji: '🌪️', subtitle: 'Super-duper fast'),
  ];

  // Adventurer+ (10+) adds reflective/situational feelings
  static const _feelingsAdventurer = [
    _ChoiceOption(value: 'Gloomy',    label: 'Gloomy',    emoji: '☁️', subtitle: 'Raincloud feeling'),
    _ChoiceOption(value: 'Impatient', label: 'Impatient', emoji: '⏳', subtitle: 'Hard to wait'),
    _ChoiceOption(value: 'Let_Down',  label: 'Let Down',  emoji: '😔', subtitle: 'Expected more'),
    _ChoiceOption(value: 'Red_Faced', label: 'Red Faced', emoji: '😳', subtitle: 'Oopsie feeling'),
    _ChoiceOption(value: 'Stuck',     label: 'Stuck',     emoji: '🧱', subtitle: 'Don\'t know how'),
  ];

  // Creator+ (13+) adds self-awareness feelings
  static const _feelingsCreator = [
    _ChoiceOption(value: 'What_If_y',        label: 'What-if-y', emoji: '❓', subtitle: 'Thinking a lot'),
    _ChoiceOption(value: 'Wish_I_Could_Hide', label: 'Shy',       emoji: '🫣', subtitle: 'Peeking feeling'),
  ];

  /// Returns the age-appropriate feelings list for the given band.
  /// Sprout: 8 | Explorer: 13 | Adventurer: 18 | Creator+: 20
  static List<_ChoiceOption> _feelingsForBand(AgeBand band) {
    const explorer   = [..._feelingsCore, ..._feelingsExplorer];
    const adventurer = [...explorer, ..._feelingsAdventurer];
    const creator    = [...adventurer, ..._feelingsCreator];
    return switch (band) {
      AgeBand.sprout     => _feelingsCore,
      AgeBand.explorer   => explorer,
      AgeBand.adventurer => adventurer,
      _                  => creator,
    };
  }

  static const _triggerOptions = {
    'Happy': [
      _ChoiceOption(value: 'Did something fun', label: 'Fun', emoji: '🎉'),
      _ChoiceOption(value: 'Made a friend', label: 'Friend', emoji: '🤝'),
      _ChoiceOption(value: 'Got a surprise', label: 'Surprise', emoji: '🎁'),
    ],
    'Sad': [
      _ChoiceOption(value: 'Lost something', label: 'Lost', emoji: '🧸'),
      _ChoiceOption(value: 'Miss someone', label: 'Miss', emoji: '💭'),
      _ChoiceOption(value: 'Felt left out', label: 'Left out', emoji: '🫧'),
    ],
    'Mad': [
      _ChoiceOption(value: 'Had to wait', label: 'Wait', emoji: '⏳'),
      _ChoiceOption(value: 'Someone said no', label: 'No', emoji: '🙅'),
      _ChoiceOption(value: 'Something broke', label: 'Broken', emoji: '🧩'),
    ],
    'Scared': [
      _ChoiceOption(value: 'It was dark', label: 'Dark', emoji: '🌙'),
      _ChoiceOption(value: 'It was loud', label: 'Loud', emoji: '🔊'),
      _ChoiceOption(value: 'Something was new', label: 'New', emoji: '✨'),
    ],
    'Excited': [
      _ChoiceOption(value: 'Something is coming', label: 'Coming', emoji: '⏰'),
      _ChoiceOption(value: 'Going somewhere', label: 'Going', emoji: '✈️'),
      _ChoiceOption(value: 'Trying something new', label: 'New', emoji: '🌟'),
    ],
    'Calm': [
      _ChoiceOption(value: 'Soft music', label: 'Music', emoji: '🎵'),
      _ChoiceOption(value: 'Reading book', label: 'Book', emoji: '📖'),
      _ChoiceOption(value: 'Slow breath', label: 'Breath', emoji: '🌬️'),
    ],
    'Confused': [
      _ChoiceOption(value: 'Hard game', label: 'Game', emoji: '🎲'),
      _ChoiceOption(value: 'New rule', label: 'New rule', emoji: '📜'),
      _ChoiceOption(value: 'Lost my way', label: 'Lost', emoji: '🗺️'),
    ],
    'Surprised': [
      _ChoiceOption(value: 'Peek-a-boo', label: 'Peek-a-boo', emoji: '👀'),
      _ChoiceOption(value: 'Surprise gift', label: 'Gift', emoji: '🎁'),
      _ChoiceOption(value: 'Loud pop', label: 'Pop!', emoji: '💥'),
    ],
    'Bothered': [
      _ChoiceOption(value: 'Had to wait', label: 'Waiting', emoji: '⏳'),
      _ChoiceOption(value: 'Bug in the room', label: 'Bug', emoji: '🐜'),
      _ChoiceOption(value: 'Loud noise', label: 'Loud noise', emoji: '🔊'),
    ],
    'Bouncy': [
      _ChoiceOption(value: 'Going to park', label: 'Park', emoji: '🌳'),
      _ChoiceOption(value: 'New toy', label: 'New toy', emoji: '🧸'),
      _ChoiceOption(value: 'Music playing', label: 'Music', emoji: '🎶'),
    ],
    'Gloomy': [
      _ChoiceOption(value: 'Rainy day', label: 'Rainy day', emoji: '🌧️'),
      _ChoiceOption(value: 'Toy broke', label: 'Toy broke', emoji: '🧩'),
      _ChoiceOption(value: 'Friend left', label: 'Friend left', emoji: '👋'),
    ],
    'Grossed_Out': [
      _ChoiceOption(value: 'Smelly food', label: 'Smelly food', emoji: '🤢'),
      _ChoiceOption(value: 'Muddy shoes', label: 'Muddy shoes', emoji: '👟'),
      _ChoiceOption(value: 'Sticky hands', label: 'Sticky hands', emoji: '🍯'),
    ],
    'Hurt_Mad': [
      _ChoiceOption(value: 'Fell down', label: 'Fell down', emoji: '🩹'),
      _ChoiceOption(value: 'Toy taken', label: 'Toy taken', emoji: '🧸'),
      _ChoiceOption(value: 'Mean words', label: 'Mean words', emoji: '💬'),
    ],
    'Hyper': [
      _ChoiceOption(value: 'Party time', label: 'Party', emoji: '🎉'),
      _ChoiceOption(value: 'Lots of treats', label: 'Treats', emoji: '🍭'),
      _ChoiceOption(value: 'Big news', label: 'Big news', emoji: '📣'),
    ],
    'Impatient': [
      _ChoiceOption(value: 'Waiting in line', label: 'Line', emoji: '🚶'),
      _ChoiceOption(value: 'Car ride', label: 'Car ride', emoji: '🚗'),
      _ChoiceOption(value: 'Turn taking', label: 'Taking turns', emoji: '🔄'),
    ],
    'Let_Down': [
      _ChoiceOption(value: 'Trip cancelled', label: 'Cancelled', emoji: '❌'),
      _ChoiceOption(value: 'No more cake', label: 'No cake', emoji: '🍰'),
      _ChoiceOption(value: 'Rain at park', label: 'Rainy park', emoji: '🌧️'),
    ],
    'Red_Faced': [
      _ChoiceOption(value: 'Spilled juice', label: 'Spilled', emoji: '🧃'),
      _ChoiceOption(value: 'Tripped over', label: 'Tripped', emoji: '🦵'),
      _ChoiceOption(value: 'Forgot a word', label: 'Forgot', emoji: '💭'),
    ],
    'Stuck': [
      _ChoiceOption(value: 'Hard puzzle', label: 'Puzzle', emoji: '🧩'),
      _ChoiceOption(value: 'Tie shoes', label: 'Shoes', emoji: '👟'),
      _ChoiceOption(value: 'Lost a toy', label: 'Lost toy', emoji: '🧸'),
    ],
    'What_If_y': [
      _ChoiceOption(value: 'New place', label: 'New place', emoji: '🗺️'),
      _ChoiceOption(value: 'Dark room', label: 'Dark room', emoji: '🌙'),
      _ChoiceOption(value: 'Big change', label: 'Change', emoji: '✨'),
    ],
    'Wish_I_Could_Hide': [
      _ChoiceOption(value: 'New person', label: 'New person', emoji: '👋'),
      _ChoiceOption(value: 'Big group', label: 'Big group', emoji: '👨‍👩‍👧‍👦'),
      _ChoiceOption(value: 'Center stage', label: 'Stage', emoji: '🎭'),
    ],
  };

  static const _bodyOptions = {
    'Happy': [
      _ChoiceOption(value: 'Big smiles', label: 'Big smiles', emoji: '😁'),
      _ChoiceOption(value: 'Warm chest', label: 'Warm chest', emoji: '💛'),
      _ChoiceOption(value: 'Bouncy feet', label: 'Bouncy feet', emoji: '🦶'),
    ],
    'Sad': [
      _ChoiceOption(value: 'Tears', label: 'Tears', emoji: '💧'),
      _ChoiceOption(value: 'Heavy tummy', label: 'Heavy tummy', emoji: '🫶'),
      _ChoiceOption(value: 'Droopy body', label: 'Droopy body', emoji: '🫠'),
    ],
    'Mad': [
      _ChoiceOption(value: 'Hot face', label: 'Hot face', emoji: '🥵'),
      _ChoiceOption(value: 'Tight tummy', label: 'Tight tummy', emoji: '🫄'),
      _ChoiceOption(value: 'Stompy feet', label: 'Stompy feet', emoji: '🦶'),
    ],
    'Scared': [
      _ChoiceOption(value: 'Fast heart', label: 'Fast heart', emoji: '💓'),
      _ChoiceOption(value: 'Shaky hands', label: 'Shaky hands', emoji: '🫳'),
      _ChoiceOption(value: 'Hide close', label: 'Hide close', emoji: '🤗'),
    ],
    'Excited': [
      _ChoiceOption(value: 'Butterflies', label: 'Butterflies', emoji: '🦋'),
      _ChoiceOption(value: 'Fast talking', label: 'Fast talking', emoji: '💬'),
      _ChoiceOption(value: 'Wiggly body', label: 'Wiggly body', emoji: '🕺'),
    ],
    'Calm': [
      _ChoiceOption(value: 'Steady heart', label: 'Steady heart', emoji: '💓'),
      _ChoiceOption(value: 'Soft face', label: 'Soft face', emoji: '😌'),
      _ChoiceOption(value: 'Relaxed body', label: 'Relaxed body', emoji: '🧘'),
    ],
    'Confused': [
      _ChoiceOption(value: 'Scrunched brow', label: 'Scrunched brow', emoji: '🤨'),
      _ChoiceOption(value: 'Head tilt', label: 'Head tilt', emoji: '🤔'),
      _ChoiceOption(value: 'Shrugging', label: 'Shrugging', emoji: '🤷'),
    ],
    'Surprised': [
      _ChoiceOption(value: 'Big eyes', label: 'Big eyes', emoji: '👀'),
      _ChoiceOption(value: 'Open mouth', label: 'Open mouth', emoji: '😮'),
      _ChoiceOption(value: 'Jumping back', label: 'Jump back', emoji: '🏃'),
    ],
    'Bothered': [
      _ChoiceOption(value: 'Grumpy face', label: 'Grumpy face', emoji: '😒'),
      _ChoiceOption(value: 'Fidgety hands', label: 'Fidgety hands', emoji: '👐'),
      _ChoiceOption(value: 'Quiet voice', label: 'Quiet voice', emoji: '🤫'),
    ],
    'Bouncy': [
      _ChoiceOption(value: 'Jumping up', label: 'Jumping up', emoji: '⬆️'),
      _ChoiceOption(value: 'Fast heart', label: 'Fast heart', emoji: '💓'),
      _ChoiceOption(value: 'Wiggle arms', label: 'Wiggle arms', emoji: '💃'),
    ],
    'Gloomy': [
      _ChoiceOption(value: 'Droopy eyes', label: 'Droopy eyes', emoji: '😔'),
      _ChoiceOption(value: 'Quiet sighs', label: 'Quiet sighs', emoji: '🌬️'),
      _ChoiceOption(value: 'Slow walking', label: 'Slow walking', emoji: '🚶'),
    ],
    'Grossed_Out': [
      _ChoiceOption(value: 'Scrunched nose', label: 'Scrunched nose', emoji: '👃'),
      _ChoiceOption(value: 'Tongue out', label: 'Tongue out', emoji: '👅'),
      _ChoiceOption(value: 'Shiver', label: 'Shiver', emoji: '🥶'),
    ],
    'Hurt_Mad': [
      _ChoiceOption(value: 'Ouchy spot', label: 'Ouchy spot', emoji: '🩹'),
      _ChoiceOption(value: 'Watery eyes', label: 'Watery eyes', emoji: '😢'),
      _ChoiceOption(value: 'Clenched fists', label: 'Clenched fists', emoji: '✊'),
    ],
    'Hyper': [
      _ChoiceOption(value: 'Spinning around', label: 'Spinning', emoji: '🌀'),
      _ChoiceOption(value: 'Loud voice', label: 'Loud voice', emoji: '📢'),
      _ChoiceOption(value: 'Fast talking', label: 'Fast talking', emoji: '💬'),
    ],
    'Impatient': [
      _ChoiceOption(value: 'Tapping feet', label: 'Tapping feet', emoji: '🦶'),
      _ChoiceOption(value: 'Sighing loud', label: 'Sighing loud', emoji: '🌬️'),
      _ChoiceOption(value: 'Frowning', label: 'Frowning', emoji: '☹️'),
    ],
    'Let_Down': [
      _ChoiceOption(value: 'Quiet voice', label: 'Quiet voice', emoji: '🤫'),
      _ChoiceOption(value: 'Looking down', label: 'Looking down', emoji: '⬇️'),
      _ChoiceOption(value: 'Heavy tummy', label: 'Heavy tummy', emoji: '🫶'),
    ],
    'Red_Faced': [
      _ChoiceOption(value: 'Hot cheeks', label: 'Hot cheeks', emoji: '😳'),
      _ChoiceOption(value: 'Hiding face', label: 'Hiding face', emoji: '🙈'),
      _ChoiceOption(value: 'Shaky voice', label: 'Shaky voice', emoji: '🗣️'),
    ],
    'Stuck': [
      _ChoiceOption(value: 'Scratching head', label: 'Scratch head', emoji: '💆'),
      _ChoiceOption(value: 'Looking around', label: 'Looking around', emoji: '👀'),
      _ChoiceOption(value: 'Sighing', label: 'Sighing', emoji: '🌬️'),
    ],
    'What_If_y': [
      _ChoiceOption(value: 'Tummy flutters', label: 'Tummy flutters', emoji: '🦋'),
      _ChoiceOption(value: 'Wide eyes', label: 'Wide eyes', emoji: '👀'),
      _ChoiceOption(value: 'Holding self', label: 'Holding self', emoji: '🫂'),
    ],
    'Wish_I_Could_Hide': [
      _ChoiceOption(value: 'Hiding face', label: 'Hiding face', emoji: '🙈'),
      _ChoiceOption(value: 'Quiet voice', label: 'Quiet voice', emoji: '🤫'),
      _ChoiceOption(value: 'Small body', label: 'Small body', emoji: '🐭'),
    ],
  };

  static const _helperOptions = {
    'Happy': [
      _ChoiceOption(value: 'Share the joy', label: 'Share it', emoji: '💝'),
      _ChoiceOption(value: 'Do a happy dance', label: 'Dance', emoji: '💃'),
      _ChoiceOption(value: 'Draw the feeling', label: 'Draw it', emoji: '🖍️'),
    ],
    'Sad': [
      _ChoiceOption(value: 'Get a hug', label: 'Squeeze hug', emoji: '🤍'),
      _ChoiceOption(value: 'Ask for help', label: 'Ask for help', emoji: '🙋'),
      _ChoiceOption(
          value: 'Take a quiet breath', label: 'Quiet breath', emoji: '🌬️'),
    ],
    'Mad': [
      _ChoiceOption(
          value: 'Take a dragon breath', label: 'Dragon breaths', emoji: '🐉'),
      _ChoiceOption(value: 'Ask for help', label: 'Ask for help', emoji: '🙋'),
      _ChoiceOption(value: 'Use gentle words', label: 'Use words', emoji: '💬'),
    ],
    'Scared': [
      _ChoiceOption(
          value: 'Hold someone\'s hand', label: 'Hold hands', emoji: '🫱'),
      _ChoiceOption(
          value: 'Take a slow breath', label: 'Slow breath', emoji: '🌬️'),
      _ChoiceOption(value: 'Ask for help', label: 'Ask for help', emoji: '🙋'),
    ],
    'Excited': [
      _ChoiceOption(value: 'Take a deep breath', label: 'Deep breath', emoji: '🌬️'),
      _ChoiceOption(value: 'Tell someone', label: 'Tell someone', emoji: '🗣️'),
      _ChoiceOption(value: 'Count to ten', label: 'Count', emoji: '🔢'),
    ],
    'Calm': [
      _ChoiceOption(value: 'Keep breathing', label: 'Keep breathing', emoji: '🌬️'),
      _ChoiceOption(value: 'Smile soft', label: 'Smile soft', emoji: '😌'),
      _ChoiceOption(value: 'Gentle hum', label: 'Gentle hum', emoji: '🎶'),
    ],
    'Confused': [
      _ChoiceOption(value: 'Ask a question', label: 'Ask question', emoji: '🙋'),
      _ChoiceOption(value: 'Look again', label: 'Look again', emoji: '👀'),
      _ChoiceOption(value: 'Try one more', label: 'Try again', emoji: '🔄'),
    ],
    'Surprised': [
      _ChoiceOption(value: 'Take a breath', label: 'Take breath', emoji: '🌬️'),
      _ChoiceOption(value: 'Laugh it out', label: 'Laugh it out', emoji: '😄'),
      _ChoiceOption(value: 'Tell a friend', label: 'Tell a friend', emoji: '🗣️'),
    ],
    'Bothered': [
      _ChoiceOption(value: 'Deep breath', label: 'Deep breath', emoji: '🌬️'),
      _ChoiceOption(value: 'Walk away', label: 'Walk away', emoji: '🚶'),
      _ChoiceOption(value: 'Ask for space', label: 'Ask for space', emoji: '🤫'),
    ],
    'Bouncy': [
      _ChoiceOption(value: 'Dance it out', label: 'Dance it out', emoji: '💃'),
      _ChoiceOption(value: 'High five', label: 'High five', emoji: '🖐️'),
      _ChoiceOption(value: 'Run around', label: 'Run around', emoji: '🏃'),
    ],
    'Gloomy': [
      _ChoiceOption(value: 'Gentle hug', label: 'Gentle hug', emoji: '🤍'),
      _ChoiceOption(value: 'Draw a picture', label: 'Draw picture', emoji: '🖍️'),
      _ChoiceOption(value: 'Soft music', label: 'Soft music', emoji: '🎵'),
    ],
    'Grossed_Out': [
      _ChoiceOption(value: 'Wash hands', label: 'Wash hands', emoji: '🧼'),
      _ChoiceOption(value: 'Step away', label: 'Step away', emoji: '🚶'),
      _ChoiceOption(value: 'Take a breath', label: 'Take breath', emoji: '🌬️'),
    ],
    'Hurt_Mad': [
      _ChoiceOption(value: 'Get a hug', label: 'Squeeze hug', emoji: '🤍'),
      _ChoiceOption(value: 'Ice pack', label: 'Ice pack', emoji: '🧊'),
      _ChoiceOption(value: 'Tell someone you trust', label: 'Tell someone', emoji: '🗣️'),
    ],
    'Hyper': [
      _ChoiceOption(value: 'Dragon breath', label: 'Dragon breath', emoji: '🐉'),
      _ChoiceOption(value: 'Big squeeze', label: 'Big squeeze', emoji: '🫂'),
      _ChoiceOption(value: 'Sit and count', label: 'Sit and count', emoji: '🔢'),
    ],
    'Impatient': [
      _ChoiceOption(value: 'Count to ten', label: 'Count to ten', emoji: '🔢'),
      _ChoiceOption(value: 'Sing a song', label: 'Sing a song', emoji: '🎶'),
      _ChoiceOption(value: 'Deep breath', label: 'Deep breath', emoji: '🌬️'),
    ],
    'Let_Down': [
      _ChoiceOption(value: 'Talk about it', label: 'Talk about it', emoji: '🗣️'),
      _ChoiceOption(value: 'Find new fun', label: 'Find new fun', emoji: '✨'),
      _ChoiceOption(value: 'Big hug', label: 'Big hug', emoji: '🫂'),
    ],
    'Red_Faced': [
      _ChoiceOption(value: 'It\'s okay', label: 'It\'s okay', emoji: '🤍'),
      _ChoiceOption(value: 'Take a breath', label: 'Take breath', emoji: '🌬️'),
      _ChoiceOption(value: 'Try again', label: 'Try again', emoji: '🔄'),
    ],
    'Stuck': [
      _ChoiceOption(value: 'Ask for help', label: 'Ask for help', emoji: '🙋'),
      _ChoiceOption(value: 'Take a break', label: 'Take a break', emoji: '⏸️'),
      _ChoiceOption(value: 'Try a new way', label: 'Try new way', emoji: '💡'),
    ],
    'What_If_y': [
      _ChoiceOption(value: 'Hold a hand', label: 'Hold hand', emoji: '🤝'),
      _ChoiceOption(value: 'Ask questions', label: 'Ask questions', emoji: '❓'),
      _ChoiceOption(value: 'Deep breath', label: 'Deep breath', emoji: '🌬️'),
    ],
    'Wish_I_Could_Hide': [
      _ChoiceOption(value: 'Hold a hand', label: 'Hold hand', emoji: '🤝'),
      _ChoiceOption(value: 'Take a breath', label: 'Take breath', emoji: '🌬️'),
      _ChoiceOption(value: 'Gentle wave', label: 'Gentle wave', emoji: '👋'),
    ],
  };

  int _step = 0;
  String? _feeling;
  String? _trigger;
  String? _bodySignal;

  @override
  void initState() {
    super.initState();
  }

  bool get _isSproutBand => ageBandFromAge(widget.childAge) == AgeBand.sprout;

  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    // Sprout: only 2 steps — feeling → coping tool, so back always goes to step 0
    setState(() => _step = _isSproutBand ? 0 : _step - 1);
  }

  void _selectFeeling(String feeling) {
    setState(() {
      _feeling = feeling;
      _trigger = null;
      _bodySignal = null;
      // Sprout band skips trigger + body signal — go straight to coping tool
      _step = _isSproutBand ? 3 : 1;
    });
  }

  void _selectTrigger(String trigger) {
    setState(() {
      _trigger = trigger;
      _step = 2;
    });
  }

  void _selectBodySignal(String bodySignal) {
    setState(() {
      _bodySignal = bodySignal;
      _step = 3;
    });
  }

  void _selectCopingTool(String copingTool) {
    Navigator.of(context).pop(
      BigFeelingsFlowResult(
        feeling: _feeling!,
        trigger: _trigger ?? '',   // sprout skips trigger step
        bodySignal: _bodySignal ?? '', // sprout skips body signal step
        copingTool: copingTool,
      ),
    );
  }

  /// Returns the asset subfolder for feeling face images.
  /// Creator, Adolescent, and Adult use gendered subfolders (boy/girl).
  /// All younger bands use gender-neutral icons/blobs — no subfolder needed.
  String _bandFolder() {
    final band = ageBandFromAge(widget.childAge);
    const genderedBands = {AgeBand.creator, AgeBand.adolescent, AgeBand.adult};
    if (genderedBands.contains(band) && widget.gender.isNotEmpty) {
      final genderFolder = widget.gender.toLowerCase(); // 'boy' or 'girl'
      return '${band.name}/$genderFolder';
    }
    return band.name;
  }

  @override
  Widget build(BuildContext context) {
    final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final options = switch (_step) {
      0 => _feelingsForBand(ageBandFromAge(widget.childAge)),
      1 => _triggerOptions[_feeling] ?? const <_ChoiceOption>[],
      2 => _bodyOptions[_feeling] ?? const <_ChoiceOption>[],
      _ => _helperOptions[_feeling] ?? const <_ChoiceOption>[],
    };
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [band.gradientStart, band.gradientMid, band.gradientEnd],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _goBack,
                      icon: Icon(
                        _step == 0
                            ? Icons.close
                            : Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _titleForStep(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.getFont(
                          band.uiFontFamily,
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _subtitleForStep(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.getFont(
                    band.uiFontFamily,
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Expanded(
                  child: GridView.builder(
                    itemCount: options.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      return _BigFeelingsChoiceCard(
                        option: option,
                        isFirstStep: _step == 0,
                        bandFolder: _bandFolder(),
                        fontFamily: band.uiFontFamily,
                        ageBand: band.band,
                        onTap: () {
                          switch (_step) {
                            case 0:
                              _selectFeeling(option.value);
                              break;
                            case 1:
                              _selectTrigger(option.value);
                              break;
                            case 2:
                              _selectBodySignal(option.value);
                              break;
                            default:
                              _selectCopingTool(option.value);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _titleForStep() {
    if (_isSproutBand) {
      return _step == 0 ? 'How do you feel?' : 'What can help?';
    }
    switch (_step) {
      case 0:
        return 'A Big Feeling!';
      case 1:
        return 'What happened?';
      case 2:
        return 'What does the body say?';
      default:
        return 'Pick a helper';
    }
  }

  String _subtitleForStep() {
    if (_isSproutBand) {
      return _step == 0 ? 'Tap the feeling.' : 'Tap something to try!';
    }
    switch (_step) {
      case 0:
        return 'Help your hero.';
      case 1:
        return 'Pick the part that fits best.';
      case 2:
        return 'What does it feel like inside?';
      default:
        return 'Pick what could help right now.';
    }
  }
}

class _BigFeelingsChoiceCard extends StatelessWidget {
  const _BigFeelingsChoiceCard({
    required this.option,
    required this.onTap,
    this.isFirstStep = false,
    this.bandFolder = 'sprout',
    this.fontFamily = 'Fredoka',
    this.ageBand,
  });

  final _ChoiceOption option;
  final VoidCallback onTap;
  final bool isFirstStep;
  final String bandFolder;
  final String fontFamily;
  final AgeBand? ageBand;

  static bool _useAgeBandAssets(AgeBand band) =>
      band == AgeBand.sprout ||
      band == AgeBand.explorer ||
      band == AgeBand.adventurer;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: option.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isFirstStep)
                    Image.asset(
                      // Younger bands (sprout/explorer/adventurer) use the new
                      // per-band artwork from age_band_assets/. Creator+ keeps
                      // the gendered subfolders in assets/images/feelings/.
                      ageBand != null && _useAgeBandAssets(ageBand!)
                          ? AgeBandAssetResolver.feelingPath(
                              ageBand!,
                              option.value.toLowerCase(),
                            )
                          : 'assets/images/feelings/$bandFolder/${option.value.toLowerCase()}.png',
                      width: 48,
                      height: 48,
                      errorBuilder: (_, __, ___) => Text(option.emoji, style: const TextStyle(fontSize: 40)),
                    )
                  else
                    Text(option.emoji, style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    option.label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.getFont(
                      fontFamily,
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (option.subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      option.subtitle!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.getFont(
                        fontFamily,
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceOption {
  const _ChoiceOption({
    required this.value,
    required this.label,
    required this.emoji,
    this.subtitle,
  });

  final String value;
  final String label;
  final String emoji;
  final String? subtitle;
}

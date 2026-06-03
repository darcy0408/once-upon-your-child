import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_tts_service.dart';
import '../theme/app_theme.dart';
import '../theme/age_band_theme.dart';
import '../theme/age_band_asset_resolver.dart';
import '../widgets/body_outline_widget.dart';
import '../widgets/sprout_animations.dart';
import '../data/body_zone_mapping.dart' as body_map;

class BigFeelingsFlowResult {
  const BigFeelingsFlowResult({
    required this.feeling,
    required this.trigger,
    required this.bodySignal,
    required this.copingTool,
    this.journalEntry,
    this.bridgeToScenario = false,
  });

  final String feeling;
  final String trigger;
  final String bodySignal;
  final String copingTool;
  /// Creator-band only: optional one-sentence journal reflection
  final String? journalEntry;
  /// Adventurer-band: user chose "Yes, go on a quest" — caller should
  /// auto-select the big_feelings_quest scenario.
  final bool bridgeToScenario;
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

  /// Test-only: returns the user-facing feeling labels (in the order the wheel
  /// shows them) for [band]. Used to pin the MT-162 age-gating without having
  /// to render the screen, which depends on Google Fonts the test environment
  /// can't fetch (`SourceSansPro` on Creator+ bands).
  @visibleForTesting
  static List<String> debugFeelingLabelsForBand(AgeBand band) =>
      _BigFeelingsFlowScreenState._feelingsForBand(band)
          .map((o) => o.label)
          .toList(growable: false);
}

class _BigFeelingsFlowScreenState extends State<BigFeelingsFlowScreen> {
  // Sprout only (ages ≤5): 4 core feelings in a 2×2 grid with giant faces.
  // Simplified from the core 8 to avoid overwhelm for pre-readers.
  static const _feelingsSprout = [
    _ChoiceOption(value: 'Happy',  label: 'Happy',  emoji: '😊', subtitle: 'Big smile feeling'),
    _ChoiceOption(value: 'Sad',    label: 'Sad',    emoji: '😢', subtitle: 'Heavy, teary feeling'),
    _ChoiceOption(value: 'Mad',    label: 'Mad',    emoji: '😠', subtitle: 'Big fire feeling'),
    _ChoiceOption(value: 'Scared', label: 'Scared', emoji: '😨', subtitle: 'Uh-oh feeling'),
  ];

  // Core 8 — shown to Explorer band and above
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
    _ChoiceOption(value: 'Bothered',    label: 'Bothered',   emoji: '😒', subtitle: 'Itty-bitty mad',    matureLabel: 'Irritated',  matureSubtitle: 'Low-grade frustration'),
    _ChoiceOption(value: 'Bouncy',      label: 'Bouncy',     emoji: '🤸', subtitle: 'High energy fun',   matureLabel: 'Energized',  matureSubtitle: 'Elevated energy'),
    _ChoiceOption(value: 'Grossed_Out', label: 'Grossed Out',emoji: '🤢', subtitle: 'Yucky feeling',     matureLabel: 'Repulsed',   matureSubtitle: 'Visceral aversion'),
    _ChoiceOption(value: 'Hurt_Mad',    label: 'Hurt-Mad',   emoji: '🤕', subtitle: 'Ouchy and angry',   matureLabel: 'Betrayed',   matureSubtitle: 'Hurt and angry at once'),
    _ChoiceOption(value: 'Hyper',       label: 'Hyper',      emoji: '🌪️', subtitle: 'Super-duper fast',  matureLabel: 'Restless',   matureSubtitle: 'Difficulty settling'),
  ];

  // Adventurer+ (10+) adds reflective/situational feelings
  static const _feelingsAdventurer = [
    _ChoiceOption(value: 'Gloomy',    label: 'Gloomy',    emoji: '☁️', subtitle: 'Raincloud feeling', matureLabel: 'Despondent',    matureSubtitle: 'Weighed down and withdrawn'),
    _ChoiceOption(value: 'Impatient', label: 'Impatient', emoji: '⏳', subtitle: 'Hard to wait'),
    _ChoiceOption(value: 'Let_Down',  label: 'Let Down',  emoji: '😔', subtitle: 'Expected more',      matureLabel: 'Disappointed',  matureSubtitle: 'Unmet expectations'),
    _ChoiceOption(value: 'Red_Faced', label: 'Red Faced', emoji: '😳', subtitle: 'Oopsie feeling',     matureLabel: 'Embarrassed',   matureSubtitle: 'Self-conscious exposure'),
    _ChoiceOption(value: 'Stuck',     label: 'Stuck',     emoji: '🧱', subtitle: 'Don\'t know how',    matureLabel: 'Blocked',       matureSubtitle: 'Unable to move forward'),
  ];

  // Gentle grief-adjacent vocabulary inherited from Explorer up. The heavier
  // `Grief` entry below is gated to Adolescent+ (15+); content-safety audit
  // F-19 (MT-162) flagged that a grieving pre-teen had no matching word, and
  // Creator (13-14) doesn't yet get `Grief` either, so this carries through
  // the whole 6-and-up chain. From Adolescent+ both "Missing Someone" and
  // "Grief" coexist — different intensities, both valuable.
  static const _feelingsMissingSomeone = [
    _ChoiceOption(value: 'Missing_Someone', label: 'Missing Someone', emoji: '🫂', subtitle: 'When someone you love is far away'),
  ];

  // Creator+ (13+) adds self-awareness feelings
  static const _feelingsCreator = [
    _ChoiceOption(value: 'What_If_y',        label: 'What-if-y', emoji: '❓', subtitle: 'Thinking a lot',   matureLabel: 'Anxious', matureSubtitle: 'Persistent worry'),
    _ChoiceOption(value: 'Wish_I_Could_Hide', label: 'Shy',       emoji: '🫣', subtitle: 'Peeking feeling',  matureLabel: 'Exposed', matureSubtitle: 'Uncomfortable visibility'),
  ];

  // Adolescent+ (15+) adds nuanced emotional vocabulary
  static const _feelingsAdolescent = [
    _ChoiceOption(value: 'Grief',     label: 'Grief',     emoji: '🖤', subtitle: 'Deep loss that lingers'),
    _ChoiceOption(value: 'Resentful', label: 'Resentful', emoji: '😤', subtitle: "Anger that won't fade"),
    _ChoiceOption(value: 'Envious',   label: 'Envious',   emoji: '💚', subtitle: 'Wanting what others have'),
    _ChoiceOption(value: 'Restless',  label: 'Restless',  emoji: '🌀', subtitle: "Can't settle down"),
    _ChoiceOption(value: 'Hopeful',   label: 'Hopeful',   emoji: '🌅', subtitle: 'Quiet belief it gets better'),
  ];

  // Adult (18+) adds existential / philosophical emotional vocabulary
  static const _feelingsAdult = [
    _ChoiceOption(value: 'Melancholy',  label: 'Melancholy',  emoji: '🌧️', subtitle: 'Bittersweet ache'),
    _ChoiceOption(value: 'Contentment', label: 'Contentment', emoji: '☀️', subtitle: 'Quiet satisfaction'),
    _ChoiceOption(value: 'Indignation', label: 'Indignation', emoji: '⚡', subtitle: 'Righteous anger'),
    _ChoiceOption(value: 'Dread',       label: 'Dread',       emoji: '🕳️', subtitle: "Weight of what's coming"),
    _ChoiceOption(value: 'Anticipation',label: 'Anticipation',emoji: '⏳', subtitle: 'Expectant tension'),
  ];

  /// Returns the age-appropriate feelings list for the given band.
  /// Sprout: 4 | Explorer: 15 | Adventurer: 20 | Creator: 21 | Adolescent: 27 | Adult: 32
  ///
  /// `_feelingsMissingSomeone` (MT-162) flows through the normal inheritance
  /// chain — Explorer through Adult all get it. Creator (13-14) doesn't yet
  /// receive the heavier `Grief` word (that's Adolescent+ at `_feelingsAdolescent`),
  /// so dropping the softer form there would leave 13-14 year olds with no
  /// grief-adjacent vocabulary at all — exactly the F-19 gap the audit flagged.
  /// At Adolescent+ both options coexist deliberately: "Missing Someone" maps
  /// to absence/longing; "Grief" maps to deeper loss. Different intensities,
  /// both valuable.
  static List<_ChoiceOption> _feelingsForBand(AgeBand band) {
    const explorer    = [..._feelingsCore, ..._feelingsExplorer, ..._feelingsMissingSomeone];
    const adventurer  = [...explorer, ..._feelingsAdventurer];
    const creator     = [...adventurer, ..._feelingsCreator];
    const adolescent  = [...creator, ..._feelingsAdolescent];
    const adult       = [...adolescent, ..._feelingsAdult];
    return switch (band) {
      AgeBand.sprout      => _feelingsSprout,
      AgeBand.explorer    => explorer,
      AgeBand.adventurer  => adventurer,
      AgeBand.creator     => creator,
      AgeBand.adolescent  => adolescent,
      AgeBand.adult       => adult,
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
    'Missing_Someone': [
      _ChoiceOption(value: 'Someone is away', label: 'Away', emoji: '✈️'),
      _ChoiceOption(value: 'A pet is gone', label: 'My pet', emoji: '🐾'),
      _ChoiceOption(value: 'A goodbye that hurt', label: 'A goodbye', emoji: '👋'),
    ],
    'Grief': [
      _ChoiceOption(value: 'Someone left', label: 'Someone left', emoji: '🚪'),
      _ChoiceOption(value: 'Something ended', label: 'Something ended', emoji: '🕯️'),
      _ChoiceOption(value: 'Unexpected loss', label: 'Unexpected loss', emoji: '💔'),
    ],
    'Resentful': [
      _ChoiceOption(value: 'Treated unfairly', label: 'Unfair treatment', emoji: '⚖️'),
      _ChoiceOption(value: 'Old wound reopened', label: 'Old wound', emoji: '🔁'),
      _ChoiceOption(value: 'Promises broken', label: 'Broken promise', emoji: '🤝'),
    ],
    'Envious': [
      _ChoiceOption(value: "Someone has what I want", label: "They have it", emoji: '💚'),
      _ChoiceOption(value: 'Comparing myself', label: 'Comparing', emoji: '⚖️'),
      _ChoiceOption(value: 'Feeling behind', label: 'Feeling behind', emoji: '🐢'),
    ],
    'Restless': [
      _ChoiceOption(value: 'Nothing feels right', label: 'Nothing fits', emoji: '🌀'),
      _ChoiceOption(value: 'Too much stillness', label: 'Too still', emoji: '⏸️'),
      _ChoiceOption(value: 'Big decision ahead', label: 'Big decision', emoji: '🔀'),
    ],
    'Hopeful': [
      _ChoiceOption(value: 'Things may improve', label: 'Could improve', emoji: '🌱'),
      _ChoiceOption(value: 'Someone showed up', label: 'Someone helped', emoji: '🤝'),
      _ChoiceOption(value: 'Small sign of change', label: 'Small sign', emoji: '🌅'),
    ],
    'Melancholy': [
      _ChoiceOption(value: 'Nostalgia', label: 'Nostalgia', emoji: '📷'),
      _ChoiceOption(value: 'Time passing', label: 'Time passing', emoji: '⏳'),
      _ChoiceOption(value: 'Beauty that hurts', label: 'Beautiful ache', emoji: '🌸'),
    ],
    'Contentment': [
      _ChoiceOption(value: 'Nothing to fix', label: 'Nothing to fix', emoji: '☀️'),
      _ChoiceOption(value: 'Present moment', label: 'Right now', emoji: '🍃'),
      _ChoiceOption(value: 'Enough is enough', label: 'Enough', emoji: '🫶'),
    ],
    'Indignation': [
      _ChoiceOption(value: 'Injustice witnessed', label: 'Injustice', emoji: '⚡'),
      _ChoiceOption(value: 'Values were crossed', label: 'Values crossed', emoji: '🔥'),
      _ChoiceOption(value: 'Truth was ignored', label: 'Ignored truth', emoji: '🙈'),
    ],
    'Dread': [
      _ChoiceOption(value: 'Known outcome looming', label: 'Looming outcome', emoji: '🕳️'),
      _ChoiceOption(value: 'Repeating pattern', label: 'Here again', emoji: '🔁'),
      _ChoiceOption(value: 'No way to prepare', label: 'Can\'t prepare', emoji: '❓'),
    ],
    'Anticipation': [
      _ChoiceOption(value: 'Something is coming', label: 'Coming soon', emoji: '⏳'),
      _ChoiceOption(value: 'Uncertain outcome', label: 'Uncertain', emoji: '🎲'),
      _ChoiceOption(value: 'Long wait ending', label: 'Wait ending', emoji: '🏁'),
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
    'Missing_Someone': [
      _ChoiceOption(value: 'Heavy heart', label: 'Heavy heart', emoji: '💗'),
      _ChoiceOption(value: 'Quiet tears', label: 'Quiet tears', emoji: '💧'),
      _ChoiceOption(value: 'Empty hands', label: 'Empty hands', emoji: '🤲'),
    ],
    'Grief': [
      _ChoiceOption(value: 'Hollow chest', label: 'Hollow chest', emoji: '🫀'),
      _ChoiceOption(value: 'Slow breathing', label: 'Slow breathing', emoji: '🌬️'),
      _ChoiceOption(value: 'Waves of tears', label: 'Waves of tears', emoji: '💧'),
    ],
    'Resentful': [
      _ChoiceOption(value: 'Tight jaw', label: 'Tight jaw', emoji: '😤'),
      _ChoiceOption(value: 'Heat in chest', label: 'Heat in chest', emoji: '🔥'),
      _ChoiceOption(value: 'Withdrawn posture', label: 'Withdrawn', emoji: '🚪'),
    ],
    'Envious': [
      _ChoiceOption(value: 'Sinking stomach', label: 'Sinking stomach', emoji: '🫃'),
      _ChoiceOption(value: 'Looking away', label: 'Looking away', emoji: '👀'),
      _ChoiceOption(value: 'Tight throat', label: 'Tight throat', emoji: '😶'),
    ],
    'Restless': [
      _ChoiceOption(value: 'Can\'t sit still', label: "Can't sit still", emoji: '🪑'),
      _ChoiceOption(value: 'Buzzing energy', label: 'Buzzing', emoji: '⚡'),
      _ChoiceOption(value: 'Racing thoughts', label: 'Racing thoughts', emoji: '🧠'),
    ],
    'Hopeful': [
      _ChoiceOption(value: 'Lighter chest', label: 'Lighter chest', emoji: '🌤️'),
      _ChoiceOption(value: 'Slow exhale', label: 'Slow exhale', emoji: '🌬️'),
      _ChoiceOption(value: 'Eyes looking up', label: 'Eyes up', emoji: '👆'),
    ],
    'Melancholy': [
      _ChoiceOption(value: 'Slow heartbeat', label: 'Slow heart', emoji: '💓'),
      _ChoiceOption(value: 'Distant gaze', label: 'Distant gaze', emoji: '🌫️'),
      _ChoiceOption(value: 'Heavy limbs', label: 'Heavy limbs', emoji: '🧍'),
    ],
    'Contentment': [
      _ChoiceOption(value: 'Steady breath', label: 'Steady breath', emoji: '🌬️'),
      _ChoiceOption(value: 'Warm torso', label: 'Warm torso', emoji: '☀️'),
      _ChoiceOption(value: 'Relaxed shoulders', label: 'Relaxed shoulders', emoji: '🧘'),
    ],
    'Indignation': [
      _ChoiceOption(value: 'Upright posture', label: 'Standing tall', emoji: '🧍'),
      _ChoiceOption(value: 'Firm voice', label: 'Firm voice', emoji: '🗣️'),
      _ChoiceOption(value: 'Flushed face', label: 'Flushed face', emoji: '😠'),
    ],
    'Dread': [
      _ChoiceOption(value: 'Weighted chest', label: 'Weighted chest', emoji: '🏋️'),
      _ChoiceOption(value: 'Slow movements', label: 'Moving slowly', emoji: '🐌'),
      _ChoiceOption(value: 'Shallow breath', label: 'Shallow breath', emoji: '😮‍💨'),
    ],
    'Anticipation': [
      _ChoiceOption(value: 'Held breath', label: 'Held breath', emoji: '😮‍💨'),
      _ChoiceOption(value: 'Heightened senses', label: 'Heightened senses', emoji: '👁️'),
      _ChoiceOption(value: 'Restless hands', label: 'Restless hands', emoji: '🤲'),
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
    'Missing_Someone': [
      _ChoiceOption(value: 'Look at a photo together', label: 'Look at a photo', emoji: '🖼️'),
      _ChoiceOption(value: 'Tell a grown-up', label: 'Tell a grown-up', emoji: '🗣️'),
      _ChoiceOption(value: 'Draw them a picture', label: 'Draw a picture', emoji: '🖍️'),
    ],
    'Grief': [
      _ChoiceOption(value: 'Let yourself feel it', label: 'Feel it fully', emoji: '🖤'),
      _ChoiceOption(value: 'Talk to someone safe', label: 'Talk to someone', emoji: '🗣️'),
      _ChoiceOption(value: 'Write or draw it out', label: 'Write it out', emoji: '✍️'),
    ],
    'Resentful': [
      _ChoiceOption(value: 'Name what was unfair', label: 'Name the unfairness', emoji: '⚖️'),
      _ChoiceOption(value: 'Write a letter you don\'t send', label: "Don't-send letter", emoji: '✉️'),
      _ChoiceOption(value: 'Physical release', label: 'Physical release', emoji: '🏃'),
    ],
    'Envious': [
      _ChoiceOption(value: 'Notice what you have', label: 'Notice your own', emoji: '🔍'),
      _ChoiceOption(value: 'Let it be information', label: 'Use it as data', emoji: '📊'),
      _ChoiceOption(value: 'Talk about it honestly', label: 'Honest talk', emoji: '🗣️'),
    ],
    'Restless': [
      _ChoiceOption(value: 'Move your body', label: 'Move your body', emoji: '🏃'),
      _ChoiceOption(value: 'Narrow your focus', label: 'Narrow focus', emoji: '🎯'),
      _ChoiceOption(value: 'Write it down', label: 'Write it down', emoji: '📝'),
    ],
    'Hopeful': [
      _ChoiceOption(value: 'Stay with it', label: 'Stay with it', emoji: '🌅'),
      _ChoiceOption(value: 'Take one small step', label: 'One small step', emoji: '👣'),
      _ChoiceOption(value: 'Share the feeling', label: 'Share it', emoji: '💬'),
    ],
    'Melancholy': [
      _ChoiceOption(value: 'Sit with it a while', label: 'Sit with it', emoji: '🌧️'),
      _ChoiceOption(value: 'Create something', label: 'Make something', emoji: '🎨'),
      _ChoiceOption(value: 'Reach out gently', label: 'Reach out gently', emoji: '🤝'),
    ],
    'Contentment': [
      _ChoiceOption(value: 'Savour the moment', label: 'Savour it', emoji: '☀️'),
      _ChoiceOption(value: 'Express gratitude', label: 'Express gratitude', emoji: '🙏'),
      _ChoiceOption(value: 'Share it with someone', label: 'Share it', emoji: '💛'),
    ],
    'Indignation': [
      _ChoiceOption(value: 'Speak the truth clearly', label: 'Speak clearly', emoji: '🗣️'),
      _ChoiceOption(value: 'Channel it into action', label: 'Act on it', emoji: '⚡'),
      _ChoiceOption(value: 'Write your perspective', label: 'Write it down', emoji: '✍️'),
    ],
    'Dread': [
      _ChoiceOption(value: 'Name the specific fear', label: 'Name the fear', emoji: '🔦'),
      _ChoiceOption(value: 'Stay in the present', label: 'Stay present', emoji: '🍃'),
      _ChoiceOption(value: 'Talk to someone trusted', label: 'Trusted person', emoji: '🤝'),
    ],
    'Anticipation': [
      _ChoiceOption(value: 'Breathe and ground yourself', label: 'Ground yourself', emoji: '🌬️'),
      _ChoiceOption(value: 'Prepare what you can', label: 'Prepare', emoji: '📋'),
      _ChoiceOption(value: 'Lean into the uncertainty', label: 'Lean in', emoji: '🌊'),
    ],
  };

  int _step = 0;
  String? _feeling;
  String? _trigger;
  String? _bodySignal;
  String? _copingTool; // held temporarily while journal step is shown
  bool _showAllFeelings = false;
  String? _outlineSelectedZone; // tracks tapped zone in body-outline step

  late final TextEditingController _journalController;

  bool get _isCreatorBand =>
      ageBandFromAge(widget.childAge) == AgeBand.creator;

  @override
  void initState() {
    super.initState();
    _journalController = TextEditingController();
  }

  @override
  void dispose() {
    _journalController.dispose();
    super.dispose();
  }

  bool get _isSproutBand => ageBandFromAge(widget.childAge) == AgeBand.sprout;
  bool get _isAdventurerBand =>
      ageBandFromAge(widget.childAge) == AgeBand.adventurer;

  // Physiological body signal hooks shown at step 2 for Adventurer+ bands.
  static const _physiologicalHooks = <String, String>{
    'Happy':
        'Dopamine floods your brain\'s reward centre — your body wants to share the good feeling.',
    'Sad':
        'Your brain releases stress hormones that make everything feel heavier and slower.',
    'Mad':
        'Your amygdala triggers a fight response — adrenaline heats your muscles and sharpens your focus.',
    'Scared':
        'Your amygdala sends a danger signal — cortisol spikes so your body is ready to run or freeze.',
    'Worried':
        'Your nervous system stays on high alert, scanning for threats even when you\'re safe.',
    'Excited':
        'Adrenaline and dopamine fire together — your heart races and your mind speeds up.',
    'Frustrated':
        'Your brain registers a blocked goal, flooding your body with tension-building energy.',
    'Embarrassed':
        'Blood rushes to your face as your brain tries to repair its social connection.',
    'Lonely':
        'The same brain region that processes physical pain activates when you feel left out.',
    'Overwhelmed':
        'Too many signals at once overload your prefrontal cortex, making it hard to think clearly.',
    'Nervous':
        'Your body can\'t tell the difference between excitement and nerves — only you can decide which it is.',
    'Confused':
        'Your brain signals uncertainty by slowing decision-making until more information arrives.',
  };

  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    if (_step == 4) {
      // Back from journal step → back to coping tool step
      setState(() {
        _step = 3;
        _copingTool = null;
        _journalController.clear();
      });
      return;
    }
    if (_step == 5) {
      // Back from quest bridge → back to feeling selection
      setState(() => _step = 0);
      return;
    }
    // Sprout: only 2 steps — feeling → coping tool, so back always goes to step 0
    setState(() {
      _step = _isSproutBand ? 0 : _step - 1;
      if (_step == 0) _showAllFeelings = false;
      if (_step == 2) _outlineSelectedZone = null;
    });
  }

  void _selectFeeling(String feeling) {
    // Sprout (3-5) finishes the flow as soon as a feeling is picked. The
    // therapeutic coping tools are already woven into the Life Quest stories
    // themselves ("take a big breath", "find a grown-up"), so a separate
    // coping-tool step inside the story-creation wizard breaks the kid's
    // mental model — they think they're making a story, not doing therapy.
    if (_isSproutBand) {
      setState(() {
        _feeling = feeling;
        _trigger = null;
        _bodySignal = null;
      });
      _finishFlow('');
      return;
    }
    setState(() {
      _feeling = feeling;
      _trigger = null;
      _bodySignal = null;
      // Adventurer band gets the quest bridge interstitial (step 5).
      _step = _isAdventurerBand ? 5 : 1;
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
    if (_isCreatorBand) {
      // Advance to optional journal step for Creator band
      setState(() {
        _copingTool = copingTool;
        _step = 4;
      });
    } else {
      _finishFlow(copingTool, journalEntry: null);
    }
  }

  void _finishFlow(String copingTool, {String? journalEntry}) {
    Navigator.of(context).pop(
      BigFeelingsFlowResult(
        feeling: _feeling!,
        trigger: _trigger ?? '',
        bodySignal: _bodySignal ?? '',
        copingTool: copingTool,
        journalEntry: journalEntry,
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
    final band = themeForAge(widget.childAge);

    // Step 4: Creator band journal — completely different UI
    if (_step == 4) return _buildJournalStep(band);

    final options = switch (_step) {
      0 => _feelingsForBand(ageBandFromAge(widget.childAge)),
      1 => _triggerOptions[_feeling] ?? const <_ChoiceOption>[],
      2 => _bodyOptions[_feeling] ?? const <_ChoiceOption>[],
      5 => const <_ChoiceOption>[], // quest bridge — rendered separately
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
                      tooltip: _step == 0 ? 'Close' : 'Back',
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
                // Quest bridge — Adventurer band interstitial after feeling selection
                if (_step == 5) ...[
                  Expanded(
                    child: _QuestBridgeView(
                      feeling: _feeling ?? '',
                      bandFontFamily: band.uiFontFamily,
                      onYes: () {
                        Navigator.of(context).pop(BigFeelingsFlowResult(
                          feeling: _feeling!,
                          trigger: '',
                          bodySignal: '',
                          copingTool: '',
                          bridgeToScenario: true,
                        ));
                      },
                      onNo: () => setState(() => _step = 1),
                    ),
                  ),
                ] else if (_step == 2 && !_isSproutBand)
                  // Body outline replaces the text-list grid for body signal step
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: BodyOutlineWidget(
                            ageBand: band.band,
                            highlightColor: band.accent,
                            selectedZone: _outlineSelectedZone,
                            onZoneSelected: (zoneId) {
                              final opts = _bodyOptions[_feeling] ?? [];
                              final signal = body_map.bodyZoneToSignal(
                                  zoneId,
                                  opts
                                      .map((o) => o.value)
                                      .toList());
                              setState(() => _outlineSelectedZone = zoneId);
                              _selectBodySignal(signal);
                            },
                          ),
                        ),
                        if (_outlineSelectedZone != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _outlineSelectedZone!
                                .replaceAll('_', ' ')
                                .split(' ')
                                .map((w) => w.isEmpty
                                    ? ''
                                    : w[0].toUpperCase() + w.substring(1))
                                .join(' '),
                            style: GoogleFonts.getFont(
                              band.uiFontFamily,
                              color: band.accent,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  )
                else
                Expanded(
                  child: GridView.builder(
                    itemCount: (_step == 0 && !_isSproutBand && !_showAllFeelings && options.length > 8)
                        ? 9 // 8 core + 1 expand button
                        : options.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      // Progressive disclosure: show "More feelings…" at slot 8
                      final showExpand = _step == 0 &&
                          !_isSproutBand &&
                          !_showAllFeelings &&
                          options.length > 8 &&
                          index == 8;
                      if (showExpand) {
                        return GestureDetector(
                          onTap: () => setState(() => _showAllFeelings = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: band.accent.withValues(alpha: 0.6),
                                width: 2,
                                strokeAlign: BorderSide.strokeAlignInside,
                              ),
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline,
                                    color: band.accent, size: 28),
                                const SizedBox(height: 6),
                                Text(
                                  'More\nfeelings…',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.getFont(
                                    band.uiFontFamily,
                                    color: band.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final option = options[index];
                      // Sprout step 0: animated feeling faces with TTS labels.
                      if (_isSproutBand && _step == 0) {
                        return _SproutFeelingCard(
                          option: option,
                          bandFolder: _bandFolder(),
                          ageBand: band.band,
                          onConfirm: () => _selectFeeling(option.value),
                        );
                      }
                      // Sprout step 3 (coping tools): animated technique cards.
                      if (_isSproutBand && _step == 3) {
                        return _SproutCopingCard(
                          option: option,
                          fontFamily: band.uiFontFamily,
                          onTap: () => _selectCopingTool(option.value),
                        );
                      }
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
      return _step == 0 ? 'How do you feel?' : 'What could help?';
    }
    if (_isCreatorBand) {
      switch (_step) {
        case 0:
          return "What's the mood?";
        case 1:
          return 'What triggered it?';
        case 2:
          return 'Where do you feel it?';
        default:
          return 'What might help?';
      }
    }
    switch (_step) {
      case 0:
        return "What's going on?";
      case 1:
        return 'What happened?';
      case 2:
        return 'What does the body say?';
      case 5:
        return 'Ready for a Quest?';
      default:
        return 'Pick a helper';
    }
  }

  String _subtitleForStep() {
    if (_isSproutBand) {
      return _step == 0 ? 'Tap the feeling.' : 'Tap something to try!';
    }
    if (_step == 5) return '';
    if (_isCreatorBand) {
      switch (_step) {
        case 0:
          return 'Choose what fits right now.';
        case 1:
          return 'What was going on when this started?';
        case 2:
          return 'What does your body tell you?';
        default:
          return 'Pick what could help right now.';
      }
    }
    if (_step == 2 && _feeling != null) {
      final hook = _physiologicalHooks[_feeling!];
      if (hook != null && ageBandFromAge(widget.childAge).index >= AgeBand.adventurer.index) {
        return hook;
      }
    }
    switch (_step) {
      case 0:
        return 'Life throws curveballs. Pick what fits.';
      case 1:
        return 'Pick the part that fits best.';
      case 2:
        return 'What does it feel like inside?';
      default:
        return 'Pick what could help right now.';
    }
  }

  /// Step 4 (Creator band only): optional one-sentence journal reflection.
  Widget _buildJournalStep(AgeBandThemeData band) {
    const creatorAccent = Color(0xFF7C4DFF);
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
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white),
                    ),
                    const Spacer(),
                  ],
                ),
                const Spacer(),
                Text(
                  'One more thing...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bitter(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Write one sentence about what's behind this feeling.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sourceSans3(
                    color: Colors.white60,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  label: 'Write one sentence about what is behind this feeling',
                  textField: true,
                  child: TextField(
                  controller: _journalController,
                  autofocus: true,
                  style: GoogleFonts.sourceSans3(
                      color: Colors.white, fontSize: 16),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'e.g. "I feel this way when..."',
                    hintStyle: GoogleFonts.sourceSans3(
                        color: Colors.white30, fontSize: 14),
                    filled: true,
                    fillColor: Colors.white.withAlpha(12),
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: creatorAccent, width: 2),
                    ),
                  ),
                ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () =>
                            _finishFlow(_copingTool!, journalEntry: null),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.sourceSans3(
                              color: Colors.white54, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          final entry = _journalController.text.trim();
                          _finishFlow(_copingTool!,
                              journalEntry: entry.isEmpty ? null : entry);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: creatorAccent,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Done',
                          style: GoogleFonts.sourceSans3(
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Adventurer-band interstitial shown after feeling selection (step 5).
/// Asks the child whether they want to go on a quest about that feeling.
class _QuestBridgeView extends StatelessWidget {
  final String feeling;
  final String bandFontFamily;
  final VoidCallback onYes;
  final VoidCallback onNo;

  const _QuestBridgeView({
    required this.feeling,
    required this.bandFontFamily,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'You\'re feeling $feeling.',
          textAlign: TextAlign.center,
          style: GoogleFonts.bitter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D2B).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF80CBC4).withValues(alpha: 0.6), width: 1),
          ),
          child: Column(
            children: [
              const Icon(Icons.explore_rounded,
                  size: 40, color: Color(0xFF80CBC4)),
              const SizedBox(height: 12),
              Text(
                'Want to go on a quest that\nexplores this feeling?',
                textAlign: TextAlign.center,
                style: GoogleFonts.bitter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your story will be shaped around what you\'re feeling right now.',
                textAlign: TextAlign.center,
                style: GoogleFonts.bitter(
                  fontSize: 13,
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: onYes,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF80CBC4),
            foregroundColor: const Color(0xFF0D0D2B),
            padding:
                const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            'Yes, take me there!',
            style: GoogleFonts.bitter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onNo,
          child: Text(
            'No, just tell me more',
            style: GoogleFonts.bitter(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
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

  /// True for Creator+ bands (age 13+), where mature labels are shown.
  static bool _isMatureBand(AgeBand? band) =>
      band != null &&
      (band == AgeBand.creator ||
       band == AgeBand.adolescent ||
       band == AgeBand.adult);

  /// Resolve feeling face image in order:
  ///   1. age_band_assets/{band}/feelings/{id}.png  (per-band artwork)
  ///   2. assets/images/feelings/{bandFolder}/{id}.png  (gendered folders)
  ///   3. assets/feelings_faces/{id}.png  (flat library — 100+ faces)
  ///   4. emoji fallback
  Widget _feelingImage(String id) {
    final lId = id.toLowerCase();
    final bandFolder = this.bandFolder;
    return _TieredFeelingImage(
      bandPath: ageBand != null
          ? AgeBandAssetResolver.feelingPath(ageBand!, lId)
          : null,
      genderedPath: 'assets/images/feelings/$bandFolder/$lId.webp',
      flatPath: 'assets/feelings_faces/$lId.webp',
      emoji: option.emoji,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mature = _isMatureBand(ageBand);
    final displayLabel = mature ? (option.matureLabel ?? option.label) : option.label;
    final displaySubtitle = mature ? (option.matureSubtitle ?? option.subtitle) : option.subtitle;

    return Semantics(
      button: true,
      label: displayLabel,
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
                    _feelingImage(option.value)
                  else
                    Text(option.emoji, style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    displayLabel,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.getFont(
                      fontFamily,
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (displaySubtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      displaySubtitle,
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

/// Tries up to three asset paths in order, falling back to an emoji on all failures.
class _TieredFeelingImage extends StatelessWidget {
  const _TieredFeelingImage({
    required this.bandPath,
    required this.genderedPath,
    required this.flatPath,
    required this.emoji,
    this.fillHeight = false,
  });

  final String? bandPath;
  final String genderedPath;
  final String flatPath;
  final String emoji;
  /// When true the image expands to fill the parent (used by _SproutFeelingCard).
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final paths = [
      if (bandPath != null) bandPath!,
      genderedPath,
      flatPath,
    ];
    return _AssetImageWithFallback(
      paths: paths,
      emoji: emoji,
      fillHeight: fillHeight,
    );
  }
}

/// Iterates through [paths] in order; shows the first that loads.
/// Falls back to [emoji] Text if none load.
class _AssetImageWithFallback extends StatefulWidget {
  const _AssetImageWithFallback({
    required this.paths,
    required this.emoji,
    this.fillHeight = false,
  });
  final List<String> paths;
  final String emoji;
  final bool fillHeight;

  @override
  State<_AssetImageWithFallback> createState() => _AssetImageWithFallbackState();
}

class _AssetImageWithFallbackState extends State<_AssetImageWithFallback> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.paths.length) {
      return Text(widget.emoji,
          style: TextStyle(fontSize: widget.fillHeight ? 64 : 40));
    }
    if (widget.fillHeight) {
      return Image.asset(
        widget.paths[_index],
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index++);
          });
          return const SizedBox.expand();
        },
      );
    }
    return Image.asset(
      widget.paths[_index],
      width: 48,
      height: 48,
      errorBuilder: (_, __, ___) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _index++);
        });
        return const SizedBox(width: 48, height: 48);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SproutFeelingCard
// Sprout-only: squircle card with per-feeling tinted gradient, soft shadow,
// and a gentle "breathe" scale on the character. Label sits below the card
// (always visible). Tap speaks the feeling name and auto-confirms after 300ms.
// ─────────────────────────────────────────────────────────────────────────────

class _SproutFeelingCard extends StatefulWidget {
  const _SproutFeelingCard({
    required this.option,
    required this.onConfirm,
    required this.bandFolder,
    required this.ageBand,
  });

  final _ChoiceOption option;
  final VoidCallback onConfirm;
  final String bandFolder;
  final AgeBand ageBand;

  @override
  State<_SproutFeelingCard> createState() => _SproutFeelingCardState();
}

class _SproutFeelingCardState extends State<_SproutFeelingCard>
    with SingleTickerProviderStateMixin {
  bool _tapped = false;
  Timer? _confirmTimer;
  late final AnimationController _breatheCtrl;
  late final Animation<double> _breatheScale;

  @override
  void initState() {
    super.initState();
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _breatheScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _confirmTimer?.cancel();
    _breatheCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_tapped) return; // prevent double-fire
    _tapped = true;
    // Speak the feeling name immediately so the audio cue lands during the
    // tap-bounce animation; confirm after a short 300ms beat so preschoolers
    // perceive the selection without thinking the app stalled.
    AppTtsService.instance.speak(widget.option.label, rateScale: 0.8);
    _confirmTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) widget.onConfirm();
    });
  }

  Widget _feelingImage() {
    final lId = widget.option.value.toLowerCase();
    return _TieredFeelingImage(
      bandPath: AgeBandAssetResolver.feelingPath(widget.ageBand, lId),
      genderedPath:
          'assets/images/feelings/${widget.bandFolder}/$lId.webp',
      flatPath: 'assets/feelings_faces/$lId.webp',
      emoji: widget.option.emoji,
      fillHeight: true,
    );
  }

  /// Per-feeling base tint. Inside-Out trained kids expect:
  ///   yellow=happy, blue=sad, red=mad, purple=scared.
  /// Other feelings fall back to a warm neutral.
  Color _baseTint() {
    switch (widget.option.value.toLowerCase()) {
      case 'happy':
        return const Color(0xFFFFD23F); // sunny yellow
      case 'sad':
        return const Color(0xFF4A90E2); // calm blue
      case 'mad':
      case 'angry':
        return const Color(0xFFE74C3C); // warm red
      case 'scared':
      case 'afraid':
        return const Color(0xFF9B59B6); // soft purple
      default:
        return const Color(0xFFB59B6E); // warm neutral
    }
  }

  /// Desaturate [c] toward grey by [amount] (0=no change, 1=fully grey),
  /// then optionally shift lightness by [lightnessDelta] in HSL space.
  Color _toned(Color c, {double saturation = 0.4, double lightnessDelta = 0}) {
    final hsl = HSLColor.fromColor(c);
    final s = (hsl.saturation * saturation).clamp(0.0, 1.0);
    final l = (hsl.lightness + lightnessDelta).clamp(0.0, 1.0);
    return hsl.withSaturation(s).withLightness(l).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final base = _baseTint();
    // Subtle top-to-bottom gradient: top is slightly lighter, bottom is the
    // tinted base. Both are pulled to ~40% saturation so the color reads as a
    // mood cue without competing with the character art.
    final top = _toned(base, saturation: 0.4, lightnessDelta: 0.10);
    final bottom = _toned(base, saturation: 0.4, lightnessDelta: -0.02);

    return Semantics(
      button: true,
      label: widget.option.label,
      child: BounceOnTapWidget(
        onTap: _handleTap,
        scaleTo: 0.95,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Squircle card (image only — no label inside).
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [top, bottom],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.30),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                        color: Colors.black.withAlpha(40),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Padding(
                      // Character occupies ~70% of card height; padding is
                      // the remaining ~15% per side so the art breathes.
                      padding: const EdgeInsets.all(12),
                      child: Center(
                        child: FractionallySizedBox(
                          heightFactor: 0.92,
                          widthFactor: 0.92,
                          child: ScaleTransition(
                            scale: _breatheScale,
                            child: _feelingImage(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Label always visible below the card.
            SizedBox(
              height: 24,
              child: Text(
                widget.option.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.fredoka(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SproutCopingCard
// Sprout-only: coping tool card with a technique-specific mini animation.
// ─────────────────────────────────────────────────────────────────────────────

class _SproutCopingCard extends StatelessWidget {
  const _SproutCopingCard({
    required this.option,
    required this.onTap,
    required this.fontFamily,
  });

  final _ChoiceOption option;
  final VoidCallback onTap;
  final String fontFamily;

  Widget _animationForCoping() {
    final v = option.value.toLowerCase();
    if (v.contains('breath') || v.contains('dragon') || v.contains('breathe')) {
      return const DragonBreathAnimation(size: 52);
    }
    if (v.contains('shake') || v.contains('wiggle') || v.contains('jump')) {
      return WiggleWidget(
        repeat: true,
        angle: 0.12,
        child: Text(option.emoji, style: const TextStyle(fontSize: 44)),
      );
    }
    if (v.contains('count')) {
      return const CountToFiveAnimation(size: 48);
    }
    // Default: gentle pulse on emoji.
    return FeelingPulseWidget(
      feelingId: 'happy',
      child: Text(option.emoji, style: const TextStyle(fontSize: 44)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: option.label,
      child: BounceOnTapWidget(
        onTap: () {
          AppTtsService.instance.speak(option.label, rateScale: 0.8);
          onTap();
        },
        child: Container(
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
                _animationForCoping(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  option.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.getFont(
                    fontFamily,
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
    this.matureLabel,
    this.matureSubtitle,
  });

  final String value;
  final String label;
  final String emoji;
  final String? subtitle;
  /// Shown instead of [label] for Creator+ bands (ages 13+).
  final String? matureLabel;
  /// Shown instead of [subtitle] for Creator+ bands (ages 13+).
  final String? matureSubtitle;
}

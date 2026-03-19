import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../theme/age_band_theme.dart';

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
  const BigFeelingsFlowScreen({super.key, this.childAge = 5});
  final int childAge;

  static Future<BigFeelingsFlowResult?> show(BuildContext context, {int childAge = 5}) {
    return Navigator.of(context, rootNavigator: true)
        .push<BigFeelingsFlowResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BigFeelingsFlowScreen(childAge: childAge),
      ),
    );
  }

  @override
  State<BigFeelingsFlowScreen> createState() => _BigFeelingsFlowScreenState();
}

class _BigFeelingsFlowScreenState extends State<BigFeelingsFlowScreen> {
  static const _feelings = [
    _ChoiceOption(
      value: 'Mad',
      label: 'Mad',
      emoji: '😠',
      subtitle: 'Big fire feeling',
    ),
    _ChoiceOption(
      value: 'Sad',
      label: 'Sad',
      emoji: '😢',
      subtitle: 'Heavy, teary feeling',
    ),
    _ChoiceOption(
      value: 'Scared',
      label: 'Scared',
      emoji: '😨',
      subtitle: 'Uh-oh feeling',
    ),
    _ChoiceOption(
      value: 'Happy',
      label: 'Happy',
      emoji: '😊',
      subtitle: 'Big smile feeling',
    ),
    _ChoiceOption(
      value: 'Excited',
      label: 'Excited',
      emoji: '🤩',
      subtitle: 'Bouncy, can\'t-wait feeling',
    ),
  ];

  static const _triggerOptions = {
    'Mad': [
      _ChoiceOption(value: 'Had to wait', label: 'Wait', emoji: '⏳'),
      _ChoiceOption(value: 'Someone said no', label: 'No', emoji: '🙅'),
      _ChoiceOption(value: 'Something broke', label: 'Broken', emoji: '🧩'),
    ],
    'Sad': [
      _ChoiceOption(value: 'Lost something', label: 'Lost', emoji: '🧸'),
      _ChoiceOption(value: 'Miss someone', label: 'Miss', emoji: '💭'),
      _ChoiceOption(value: 'Felt left out', label: 'Left out', emoji: '🫧'),
    ],
    'Scared': [
      _ChoiceOption(value: 'It was dark', label: 'Dark', emoji: '🌙'),
      _ChoiceOption(value: 'It was loud', label: 'Loud', emoji: '🔊'),
      _ChoiceOption(value: 'Something was new', label: 'New', emoji: '✨'),
    ],
    'Happy': [
      _ChoiceOption(value: 'Did something fun', label: 'Fun', emoji: '🎉'),
      _ChoiceOption(value: 'Made a friend', label: 'Friend', emoji: '🤝'),
      _ChoiceOption(value: 'Got a surprise', label: 'Surprise', emoji: '🎁'),
    ],
    'Excited': [
      _ChoiceOption(value: 'Something is coming', label: 'Coming', emoji: '⏰'),
      _ChoiceOption(value: 'Going somewhere', label: 'Going', emoji: '✈️'),
      _ChoiceOption(value: 'Trying something new', label: 'New', emoji: '🌟'),
    ],
  };

  static const _bodyOptions = {
    'Mad': [
      _ChoiceOption(value: 'Hot face', label: 'Hot face', emoji: '🥵'),
      _ChoiceOption(value: 'Tight tummy', label: 'Tight tummy', emoji: '🫄'),
      _ChoiceOption(value: 'Stompy feet', label: 'Stompy feet', emoji: '🦶'),
    ],
    'Sad': [
      _ChoiceOption(value: 'Tears', label: 'Tears', emoji: '💧'),
      _ChoiceOption(value: 'Heavy tummy', label: 'Heavy tummy', emoji: '🫶'),
      _ChoiceOption(value: 'Droopy body', label: 'Droopy body', emoji: '🫠'),
    ],
    'Scared': [
      _ChoiceOption(value: 'Fast heart', label: 'Fast heart', emoji: '💓'),
      _ChoiceOption(value: 'Shaky hands', label: 'Shaky hands', emoji: '🫳'),
      _ChoiceOption(value: 'Hide close', label: 'Hide close', emoji: '🤗'),
    ],
    'Happy': [
      _ChoiceOption(value: 'Big smiles', label: 'Big smiles', emoji: '😁'),
      _ChoiceOption(value: 'Warm chest', label: 'Warm chest', emoji: '💛'),
      _ChoiceOption(value: 'Bouncy feet', label: 'Bouncy feet', emoji: '🦶'),
    ],
    'Excited': [
      _ChoiceOption(value: 'Butterflies', label: 'Butterflies', emoji: '🦋'),
      _ChoiceOption(value: 'Fast talking', label: 'Fast talking', emoji: '💬'),
      _ChoiceOption(value: 'Wiggly body', label: 'Wiggly body', emoji: '🕺'),
    ],
  };

  static const _helperOptions = {
    'Mad': [
      _ChoiceOption(
          value: 'Take a dragon breath', label: 'Dragon breaths', emoji: '🐉'),
      _ChoiceOption(value: 'Ask for help', label: 'Ask for help', emoji: '🙋'),
      _ChoiceOption(value: 'Use gentle words', label: 'Use words', emoji: '💬'),
    ],
    'Sad': [
      _ChoiceOption(value: 'Get a hug', label: 'Squeeze hug', emoji: '🤍'),
      _ChoiceOption(value: 'Ask for help', label: 'Ask for help', emoji: '🙋'),
      _ChoiceOption(
          value: 'Take a quiet breath', label: 'Quiet breath', emoji: '🌬️'),
    ],
    'Scared': [
      _ChoiceOption(
          value: 'Hold a grown-up hand', label: 'Hold hands', emoji: '🫱'),
      _ChoiceOption(
          value: 'Take a slow breath', label: 'Slow breath', emoji: '🌬️'),
      _ChoiceOption(value: 'Ask for help', label: 'Ask for help', emoji: '🙋'),
    ],
    'Happy': [
      _ChoiceOption(value: 'Share the joy', label: 'Share it', emoji: '💝'),
      _ChoiceOption(value: 'Do a happy dance', label: 'Dance', emoji: '💃'),
      _ChoiceOption(value: 'Draw the feeling', label: 'Draw it', emoji: '🖍️'),
    ],
    'Excited': [
      _ChoiceOption(value: 'Take a deep breath', label: 'Deep breath', emoji: '🌬️'),
      _ChoiceOption(value: 'Tell someone', label: 'Tell someone', emoji: '🗣️'),
      _ChoiceOption(value: 'Count to ten', label: 'Count', emoji: '🔢'),
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

  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step -= 1);
  }

  void _selectFeeling(String feeling) {
    setState(() {
      _feeling = feeling;
      _trigger = null;
      _bodySignal = null;
      _step = 1;
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
        trigger: _trigger!,
        bodySignal: _bodySignal!,
        copingTool: copingTool,
      ),
    );
  }

  String _bandFolder() {
    if (widget.childAge <= 5) return 'sprout';
    if (widget.childAge <= 8) return 'explorer';
    if (widget.childAge <= 11) return 'adventurer';
    if (widget.childAge <= 14) return 'creator';
    if (widget.childAge <= 17) return 'adolescent';
    return 'adult';
  }

  @override
  Widget build(BuildContext context) {
    final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final options = switch (_step) {
      0 => _feelings,
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
  });

  final _ChoiceOption option;
  final VoidCallback onTap;
  final bool isFirstStep;
  final String bandFolder;
  final String fontFamily;

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
                      'assets/images/feelings/$bandFolder/${option.value.toLowerCase()}.png',
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

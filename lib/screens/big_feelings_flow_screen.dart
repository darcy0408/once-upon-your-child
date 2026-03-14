import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class BigFeelingsFlowResult {
  const BigFeelingsFlowResult({
    required this.feeling,
    required this.trigger,
    required this.bodySignal,
    required this.copingTool,
    this.parentHiddenContext,
    this.repairGoal,
  });

  final String feeling;
  final String trigger;
  final String bodySignal;
  final String copingTool;
  final String? parentHiddenContext;
  final String? repairGoal;
}

class BigFeelingsFlowScreen extends StatefulWidget {
  const BigFeelingsFlowScreen({
    super.key,
    this.initialParentHiddenContext,
    this.initialRepairGoal,
  });

  final String? initialParentHiddenContext;
  final String? initialRepairGoal;

  static Future<BigFeelingsFlowResult?> show(
    BuildContext context, {
    String? initialParentHiddenContext,
    String? initialRepairGoal,
  }) {
    return Navigator.of(context, rootNavigator: true)
        .push<BigFeelingsFlowResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BigFeelingsFlowScreen(
          initialParentHiddenContext: initialParentHiddenContext,
          initialRepairGoal: initialRepairGoal,
        ),
      ),
    );
  }

  @override
  State<BigFeelingsFlowScreen> createState() => _BigFeelingsFlowScreenState();
}

class _BigFeelingsFlowScreenState extends State<BigFeelingsFlowScreen> {
  static const _parentHiddenContextPrefsKey =
      'big_feelings_parent_hidden_context';
  static const _repairGoalPrefsKey = 'big_feelings_repair_goal';
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
  };

  static const _realLifeStruggleOptions = [
    _ChoiceOption(
      value: 'trouble hearing no',
      label: 'Trouble hearing no',
      emoji: '🚫',
    ),
    _ChoiceOption(
      value: 'friendship hurt',
      label: 'Friendship hurt',
      emoji: '💔',
    ),
    _ChoiceOption(
      value: 'bedtime worry',
      label: 'Bedtime worry',
      emoji: '🌙',
    ),
    _ChoiceOption(
      value: 'sibling conflict',
      label: 'Sibling conflict',
      emoji: '🧒',
    ),
    _ChoiceOption(
      value: 'hard transitions',
      label: 'Hard transitions',
      emoji: '🔄',
    ),
    _ChoiceOption(
      value: 'meltdown when stuck',
      label: 'Meltdown when stuck',
      emoji: '🧩',
    ),
  ];

  static const _repairGoalOptions = [
    _ChoiceOption(value: 'Say sorry', label: 'Say sorry', emoji: '🫶'),
    _ChoiceOption(value: 'Help fix it', label: 'Help fix', emoji: '🛠️'),
    _ChoiceOption(
        value: 'Use gentle words', label: 'Gentle words', emoji: '💬'),
    _ChoiceOption(value: 'Try again', label: 'Try again', emoji: '🔁'),
  ];

  int _step = 0;
  String? _feeling;
  String? _trigger;
  String? _bodySignal;
  bool _showParentControls = false;
  String? _parentHiddenContext;
  String? _repairGoal;

  @override
  void initState() {
    super.initState();
    _loadParentHiddenContext();
    _loadRepairGoal();
  }

  Future<void> _loadParentHiddenContext() async {
    final prefs = await SharedPreferences.getInstance();
    final persistedValue = prefs.getString(_parentHiddenContextPrefsKey);
    final initialValue = widget.initialParentHiddenContext;
    final resolvedValue =
        (initialValue != null && initialValue.trim().isNotEmpty)
            ? initialValue.trim()
            : persistedValue;
    if (!mounted || resolvedValue == null || resolvedValue.isEmpty) {
      return;
    }
    setState(() => _parentHiddenContext = resolvedValue);
  }

  Future<void> _persistParentHiddenContext(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(_parentHiddenContextPrefsKey);
      return;
    }
    await prefs.setString(_parentHiddenContextPrefsKey, value.trim());
  }

  Future<void> _loadRepairGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final persistedValue = prefs.getString(_repairGoalPrefsKey);
    final initialValue = widget.initialRepairGoal;
    final resolvedValue =
        (initialValue != null && initialValue.trim().isNotEmpty)
            ? initialValue.trim()
            : persistedValue;
    if (!mounted || resolvedValue == null || resolvedValue.isEmpty) {
      return;
    }
    setState(() => _repairGoal = resolvedValue);
  }

  Future<void> _persistRepairGoal(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(_repairGoalPrefsKey);
      return;
    }
    await prefs.setString(_repairGoalPrefsKey, value.trim());
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
        parentHiddenContext: _parentHiddenContext,
        repairGoal: _repairGoal,
      ),
    );
  }

  void _toggleParentControls() {
    setState(() => _showParentControls = !_showParentControls);
  }

  Future<void> _selectParentHiddenContext(String? value) async {
    setState(() => _parentHiddenContext = value);
    await _persistParentHiddenContext(value);
  }

  Future<void> _selectRepairGoal(String? value) async {
    setState(() => _repairGoal = value);
    await _persistRepairGoal(value);
  }

  @override
  Widget build(BuildContext context) {
    final options = switch (_step) {
      0 => _feelings,
      1 => _triggerOptions[_feeling] ?? const <_ChoiceOption>[],
      2 => _bodyOptions[_feeling] ?? const <_ChoiceOption>[],
      _ => _helperOptions[_feeling] ?? const <_ChoiceOption>[],
    };
    final subtitleSpacing = _showParentControls ? AppSpacing.sm : AppSpacing.md;
    final gridTopSpacing = _showParentControls ? AppSpacing.lg : AppSpacing.xl;

    return Scaffold(
      backgroundColor: const Color(0xFF1A0E3A),
      body: SafeArea(
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
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleParentControls,
                    tooltip: 'Parent context',
                    icon: Icon(
                      _showParentControls
                          ? Icons.shield
                          : Icons.shield_outlined,
                      color: _parentHiddenContext != null
                          ? const Color(0xFFFFD76A)
                          : Colors.white70,
                    ),
                  ),
                ],
              ),
              SizedBox(height: subtitleSpacing),
              Text(
                _subtitleForStep(),
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: _ParentHiddenContextCard(
                    contextOptions: _realLifeStruggleOptions,
                    selectedContextValue: _parentHiddenContext,
                    onContextSelected: _selectParentHiddenContext,
                    repairOptions: _repairGoalOptions,
                    selectedRepairValue: _repairGoal,
                    onRepairSelected: _selectRepairGoal,
                  ),
                ),
                crossFadeState: _showParentControls
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 180),
              ),
              SizedBox(height: gridTopSpacing),
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

class _ParentHiddenContextCard extends StatelessWidget {
  const _ParentHiddenContextCard({
    required this.contextOptions,
    required this.selectedContextValue,
    required this.onContextSelected,
    required this.repairOptions,
    required this.selectedRepairValue,
    required this.onRepairSelected,
  });

  final List<_ChoiceOption> contextOptions;
  final String? selectedContextValue;
  final ValueChanged<String?> onContextSelected;
  final List<_ChoiceOption> repairOptions;
  final String? selectedRepairValue;
  final ValueChanged<String?> onRepairSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parent hidden context',
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Real-life struggle',
            style: GoogleFonts.fredoka(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final option in contextOptions)
                ChoiceChip(
                  key: ValueKey('big_feelings_parent_context_${option.value}'),
                  avatar: Text(option.emoji),
                  label: Text(option.label),
                  selected: selectedContextValue == option.value,
                  selectedColor: const Color(0xFFFFD76A),
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selectedContextValue == option.value
                        ? const Color(0xFF1A0E3A)
                        : const Color(0xFF2E2158),
                    fontWeight: selectedContextValue == option.value
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                  onSelected: (_) => onContextSelected(
                    selectedContextValue == option.value ? null : option.value,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Repair goal',
            style: GoogleFonts.fredoka(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final option in repairOptions)
                ChoiceChip(
                  key: ValueKey('big_feelings_repair_goal_${option.value}'),
                  avatar: Text(option.emoji),
                  label: Text(option.label),
                  selected: selectedRepairValue == option.value,
                  selectedColor: const Color(0xFFFFD76A),
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selectedRepairValue == option.value
                        ? const Color(0xFF1A0E3A)
                        : const Color(0xFF2E2158),
                    fontWeight: selectedRepairValue == option.value
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                  onSelected: (_) => onRepairSelected(
                    selectedRepairValue == option.value ? null : option.value,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigFeelingsChoiceCard extends StatelessWidget {
  const _BigFeelingsChoiceCard({
    required this.option,
    required this.onTap,
  });

  final _ChoiceOption option;
  final VoidCallback onTap;

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
                  Text(option.emoji, style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    option.label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.fredoka(
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
                      style: GoogleFonts.fredoka(
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

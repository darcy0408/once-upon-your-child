// lib/feelings_wheel_screen.dart
// Interactive Feelings picker with age-aware depth.
//
// MT-176 (2026-05-20): The original geometric wheel image
// `assets/images/FeelingsWheel.png` was never bundled and the
// `SafeAssetImage` placeholder rendered as empty space, leaving the
// screen visually broken. The list-based picker (originally the
// "Use list instead" fallback) is now the sole UI. The geometric
// tap handler, wheel keys, and image references were removed.

import 'package:flutter/material.dart';
import 'feelings_wheel_data.dart';
import 'sunset_jungle_theme.dart';

class FeelingsWheelScreen extends StatefulWidget {
  final SelectedFeeling? currentFeeling;
  final ValueChanged<SelectedFeeling>? onFeelingSelected;
  final int? ageYears;

  const FeelingsWheelScreen({
    super.key,
    this.currentFeeling,
    this.onFeelingSelected,
    this.ageYears,
  });

  @override
  State<FeelingsWheelScreen> createState() => _FeelingsWheelScreenState();
}

class _FeelingsWheelScreenState extends State<FeelingsWheelScreen> {
  CoreEmotion? _selectedCore;
  SecondaryFeeling? _selectedSecondary;
  late final List<_SecondaryOption> _secondaryOptions;

  @override
  void initState() {
    super.initState();
    _secondaryOptions = FeelingsWheelData.coreEmotions
        .expand(
          (core) => core.secondary.map(
            (secondary) => _SecondaryOption(core: core, secondary: secondary),
          ),
        )
        .toList();
    _bootstrapFromCurrent(widget.currentFeeling);
  }

  @override
  void didUpdateWidget(covariant FeelingsWheelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentFeeling?.tertiary != oldWidget.currentFeeling?.tertiary) {
      setState(() {
        _bootstrapFromCurrent(widget.currentFeeling);
      });
    }
  }

  void _bootstrapFromCurrent(SelectedFeeling? feeling) {
    if (feeling == null) return;

    CoreEmotion? core;
    SecondaryFeeling? secondary;

    for (final option in _secondaryOptions) {
      if (option.core.name.toLowerCase() == feeling.core.toLowerCase()) {
        core ??= option.core;
      }
      if (option.secondary.name.toLowerCase() == feeling.secondary.toLowerCase()) {
        core ??= option.core;
        secondary ??= option.secondary;
      }
    }

    _selectedCore = core;
    _selectedSecondary = secondary;
  }

  @override
  Widget build(BuildContext context) {
    final age = widget.ageYears;
    final maxDepth = _maxDepthForAge(age);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGuidanceCard(maxDepth, age),
        const SizedBox(height: 14),
        _buildSelectionSummary(),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedCore = null;
                _selectedSecondary = null;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Start over'),
          ),
        ),
        const SizedBox(height: 8),
        _buildGuidedSelector(maxDepth),
      ],
    );
  }

  int _maxDepthForAge(int? age) {
    if (age == null) return 3;
    if (age <= 6) return 1; // core only
    if (age <= 9) return 2; // core + secondary
    return 3; // full depth
  }

  String _ageGuidanceText(int depth) {
    switch (depth) {
      case 1:
        return 'For younger readers: pick the big feeling.';
      case 2:
        return 'Pick the big feeling, then a simple feeling under it.';
      default:
        return 'Explore the wheel to find the exact feeling.';
    }
  }

  Widget _buildGuidanceCard(int maxDepth, int? age) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SunsetJungleTheme.creamLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SunsetJungleTheme.jungleMint, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pick the feeling that fits',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start with the big feeling family, then drill down to the word that fits best.',
            style: TextStyle(fontFamily: 'Quicksand'),
          ),
          if (maxDepth > 1) ...const [
            SizedBox(height: 8),
            Text(
              'Keep tapping the bright chips until you land on the exact word.',
              style: TextStyle(fontFamily: 'Quicksand'),
            ),
          ],
          if (age != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _ageGuidanceText(maxDepth),
                style: const TextStyle(fontFamily: 'Quicksand', fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGuidedSelector(int maxDepth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageCard(
          title: '1. Core feelings',
          subtitle: 'Tap the big feeling family first.',
          accent: _selectedCore?.color ?? SunsetJungleTheme.jungleMint,
          isLocked: false,
          child: _buildCoreChoices(maxDepth),
        ),
        if (maxDepth > 1)
          _buildStageCard(
            title: '2. Next feelings',
            subtitle: _selectedCore == null
                ? 'Pick a core feeling to unlock these.'
                : 'Select the feeling that best matches ${_selectedCore!.name}.',
            accent: _selectedCore?.color ?? SunsetJungleTheme.jungleMint,
            isLocked: _selectedCore == null,
            child: _buildSecondaryChoices(maxDepth),
          ),
        if (maxDepth > 2)
          _buildStageCard(
            title: '3. Exact feelings',
            subtitle: _selectedSecondary == null
                ? 'Choose a feeling above to see the exact words.'
                : 'Pick the word that fits best.',
            accent: _selectedCore?.color ?? SunsetJungleTheme.jungleMint,
            isLocked: _selectedSecondary == null,
            child: _buildTertiaryChoices(),
          ),
      ],
    );
  }

  Widget _buildCoreChoices(int maxDepth) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FeelingsWheelData.coreEmotions.map((emotion) {
        final selected = _selectedCore?.id == emotion.id;
        final dimmed = _selectedCore != null && !selected;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: dimmed ? 0.35 : 1.0,
      child: ChoiceChip(
        label: Text(emotion.name),
        avatar: Text(emotion.emoji),
        selected: selected,
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: emotion.color ?? SunsetJungleTheme.sunsetPeach,
            onSelected: (_) {
              if (maxDepth == 1) {
                _notifySelection(
              SelectedFeeling(
                    core: emotion.name,
                    secondary: '',
                    tertiary: emotion.name,
                    emoji: emotion.emoji,
                    eyeType: emotion.eyeType,
                    mouthType: emotion.mouthType,
                    color: emotion.color ?? SunsetJungleTheme.sunsetPeach,
                  ),
                );
              } else {
                setState(() {
                  _selectedCore = emotion;
                  _selectedSecondary = null;
                });
              }
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSecondaryChoices(int maxDepth) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _secondaryOptions.map((option) {
        final inFamily = _selectedCore?.id == option.core.id;
        final selected = _selectedSecondary?.id == option.secondary.id;
        final enabled = _selectedCore != null && inFamily;
        final opacity = _selectedCore == null
            ? 0.3
            : inFamily
                ? 1.0
                : 0.18;

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: opacity,
          child: ChoiceChip(
            label: Text(option.secondary.name),
            avatar: Text(option.secondary.emoji),
            selected: selected,
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: option.core.color ?? SunsetJungleTheme.sunsetPeach,
            onSelected: enabled
                ? (_) {
                    if (maxDepth == 2) {
                      final feeling = SelectedFeeling(
                        core: option.core.name,
                        secondary: option.secondary.name,
                        tertiary: option.secondary.name,
                        emoji: option.secondary.emoji,
                        eyeType: option.secondary.eyeType,
                        mouthType: option.secondary.mouthType,
                        color: option.core.color ?? SunsetJungleTheme.sunsetPeach,
                      );
                      setState(() {
                        _selectedCore = option.core;
                        _selectedSecondary = option.secondary;
                      });
                      _notifySelection(feeling);
                    } else {
                      setState(() {
                        _selectedCore = option.core;
                        _selectedSecondary = option.secondary;
                      });
                    }
                  }
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTertiaryChoices() {
    final tertiaryFeelings = _selectedSecondary?.tertiary ?? [];
    final isLocked = _selectedSecondary == null;

    if (tertiaryFeelings.isEmpty) {
      return Text(
        'Choose a feeling above to see more specific options.',
        style: TextStyle(color: Colors.grey[700]),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tertiaryFeelings.map((feelingName) {
        final emoji =
            FeelingsEmojiLookup.emojiFor(feelingName) ?? _selectedSecondary!.emoji;
        final selectedTertiary = widget.currentFeeling?.tertiary;
        final isSelected = selectedTertiary != null &&
            selectedTertiary.toLowerCase() == feelingName.toLowerCase();
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: isLocked ? 0.25 : 1.0,
          child: ChoiceChip(
            label: Text(feelingName),
            avatar: Text(emoji),
            selected: isSelected,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: _selectedCore?.color ?? SunsetJungleTheme.sunsetPeach,
            onSelected: isLocked
                ? null
                : (_) {
                    _notifySelection(
                      SelectedFeeling(
                        core: _selectedCore!.name,
                        secondary: _selectedSecondary!.name,
                        tertiary: feelingName,
                        emoji: emoji,
                        eyeType: _selectedSecondary!.eyeType,
                        mouthType: _selectedSecondary!.mouthType,
                        color: _selectedCore!.color ?? SunsetJungleTheme.sunsetPeach,
                      ),
                    );
                  },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStageCard({
    required String title,
    required String subtitle,
    required Widget child,
    required Color accent,
    bool isLocked = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: isLocked ? 0.4 : 0.9),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Quicksand',
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 10),
          IgnorePointer(
            ignoring: isLocked,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: isLocked ? 0.35 : 1.0,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  void _notifySelection(SelectedFeeling feeling) {
    widget.onFeelingSelected?.call(feeling);
  }

  Widget _buildSelectionSummary() {
    if (_selectedCore == null) {
      return const Text(
        'Tap anywhere on the wheel to choose your core feeling.',
        style: TextStyle(fontFamily: 'Quicksand'),
      );
    }

    final chips = <Widget>[
      Chip(
        label: Text(_selectedCore!.name),
        avatar: Text(_selectedCore!.emoji),
        backgroundColor: _selectedCore!.color?.withValues(alpha: 0.25),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ];

    if (_selectedSecondary != null) {
      chips.add(
        Chip(
          label: Text(_selectedSecondary!.name),
          avatar: Text(_selectedSecondary!.emoji),
          backgroundColor: _selectedCore!.color?.withValues(alpha: 0.18),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    if (widget.currentFeeling?.tertiary.isNotEmpty == true) {
      chips.add(
        Chip(
          label: Text(widget.currentFeeling!.tertiary),
          avatar: Text(widget.currentFeeling!.emoji),
          backgroundColor: _selectedCore!.color?.withValues(alpha: 0.15),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips,
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                'Feeling selected!',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Quicksand',
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }
}

class _SecondaryOption {
  final CoreEmotion core;
  final SecondaryFeeling secondary;

  const _SecondaryOption({
    required this.core,
    required this.secondary,
  });
}

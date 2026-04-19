// lib/feelings_wheel_screen.dart
// Interactive Feelings Wheel with age-aware depth and optional reference image

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'feelings_wheel_data.dart';
import 'sunset_jungle_theme.dart';
import 'widgets/safe_asset_image.dart';

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
  final GlobalKey _wheelKey = GlobalKey();
  final GlobalKey _dialogWheelKey = GlobalKey();
  bool _useListPicker = false;

  // Order of core emotions as they appear clockwise on the wheel image, starting at 12 o'clock.
  // Adjust here if the asset changes.
  final List<String> _wheelOrder = const [
    'happy',
    'surprised',
    'scared',
    'sad',
    'disgusted',
    'angry',
  ];

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
        _buildWheelImage(),
        const SizedBox(height: 8),
        _buildGuidanceCard(maxDepth, age),
        const SizedBox(height: 14),
        _buildSelectionSummary(),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedCore = null;
                  _selectedSecondary = null;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Start over'),
            ),
            TextButton(
              onPressed: () => setState(() => _useListPicker = !_useListPicker),
              child: Text(_useListPicker ? 'Hide list picker' : 'Use list instead'),
            ),
          ],
        ),
        if (_useListPicker) ...[
          const SizedBox(height: 8),
          _buildGuidedSelector(maxDepth),
        ],
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

  Widget _buildWheelImage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: 'Feelings wheel - tap the colors to pick feelings',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  key: _wheelKey,
                  aspectRatio: 1.1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      SafeAssetImage(
                        'assets/images/FeelingsWheel.png',
                        fit: BoxFit.cover,
                        placeholder: const SizedBox.shrink(),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapDown: (details) => _handleWheelTap(details),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => Dialog(
                      child: LayoutBuilder(
                        builder: (ctx, dialogConstraints) {
                          return InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 3.0,
                            child: AspectRatio(
                              key: _dialogWheelKey,
                              aspectRatio: 1.1,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  SafeAssetImage(
                                    'assets/images/FeelingsWheel.png',
                                    fit: BoxFit.contain,
                                  ),
                                  GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTapDown: (details) => _handleWheelTap(
                                      details,
                                      boxOverride: _dialogWheelKey.currentContext
                                          ?.findRenderObject() as RenderBox?,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.fullscreen),
                label: const Text('Open & tap the wheel'),
              ),
            ),
          ],
        );
      },
    );
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
            'Tap the wheel to pick feelings',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap the colored wheel itself. It dims non-relevant slices and lights up the next level as you drill down.',
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
        const Text(
          'List picker (optional)',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
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

  void _handleWheelTap(TapDownDetails details, {RenderBox? boxOverride}) {
    final box = boxOverride ?? _wheelKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final size = box.size;
    final local = box.globalToLocal(details.globalPosition);
    final center = Offset(size.width / 2, size.height / 2);
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    final radius = math.sqrt(dx * dx + dy * dy);
    final maxRadius = math.min(size.width, size.height) / 2;

    if (radius > maxRadius) return; // tapped outside the wheel

    // Align 0° to the top of the wheel (12 o'clock) to match the graphic.
    const double startAngleOffset = -math.pi / 2;
    final angle = (math.atan2(dy, dx) + startAngleOffset + 2 * math.pi) % (2 * math.pi);
    final ringRatio = radius / maxRadius;
    const coreThreshold = 0.33;
    const secondaryThreshold = 0.66;

    final sectorCount = _wheelOrder.length;
    final sectorAngle = (2 * math.pi) / sectorCount;
    final sectorIndex = (angle / sectorAngle).floor() % sectorCount;
    final coreId = _wheelOrder[sectorIndex];
    final core = FeelingsWheelData.coreEmotions.firstWhere(
      (c) => c.id == coreId,
      orElse: () => FeelingsWheelData.coreEmotions.first,
    );
    final localAngle = (angle - (sectorIndex * sectorAngle)) % sectorAngle;
    final localFraction = localAngle / sectorAngle;
    final maxDepth = _maxDepthForAge(widget.ageYears);

    if (ringRatio <= coreThreshold) {
      // Core ring
      if (maxDepth == 1) {
        _notifySelection(
          SelectedFeeling(
            core: core.name,
            secondary: '',
            tertiary: core.name,
            emoji: core.emoji,
            eyeType: core.eyeType,
            mouthType: core.mouthType,
            color: core.color ?? SunsetJungleTheme.sunsetPeach,
          ),
        );
      } else {
        setState(() {
          _selectedCore = core;
          _selectedSecondary = null;
        });
      }
      return;
    }

    final secondaryList = core.secondary;
    if (secondaryList.isEmpty) return;

    final secondaryIndex = (localFraction * secondaryList.length)
        .floor()
        .clamp(0, secondaryList.length - 1);
    final secondary = secondaryList[secondaryIndex];

    if (ringRatio <= secondaryThreshold) {
      // Secondary ring
      if (maxDepth <= 2) {
        final feeling = SelectedFeeling(
          core: core.name,
          secondary: secondary.name,
          tertiary: secondary.name,
          emoji: secondary.emoji,
          eyeType: secondary.eyeType,
          mouthType: secondary.mouthType,
          color: core.color ?? SunsetJungleTheme.sunsetPeach,
        );
        setState(() {
          _selectedCore = core;
          _selectedSecondary = secondary;
        });
        _notifySelection(feeling);
      } else {
        setState(() {
          _selectedCore = core;
          _selectedSecondary = secondary;
        });
      }
      return;
    }

    // Tertiary ring
    if (secondary.tertiary.isEmpty) return;
    final tertiaryIndex = (localFraction * secondary.tertiary.length)
        .floor()
        .clamp(0, secondary.tertiary.length - 1);
    final tertiary = secondary.tertiary[tertiaryIndex];

    final emoji = FeelingsEmojiLookup.emojiFor(tertiary) ?? secondary.emoji;
    setState(() {
      _selectedCore = core;
      _selectedSecondary = secondary;
    });
    _notifySelection(
      SelectedFeeling(
        core: core.name,
        secondary: secondary.name,
        tertiary: tertiary,
        emoji: emoji,
        eyeType: secondary.eyeType,
        mouthType: secondary.mouthType,
        color: core.color ?? SunsetJungleTheme.sunsetPeach,
      ),
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

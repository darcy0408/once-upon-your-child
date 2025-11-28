// lib/feelings_wheel_screen.dart
// Interactive Feelings Wheel with age-aware depth and optional reference image

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

  @override
  Widget build(BuildContext context) {
    final age = widget.ageYears;
    final maxDepth = _maxDepthForAge(age);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildWheelImage(),
        Container(
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
                'Step 1: Pick a core emotion',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (maxDepth > 1) ...const [
                SizedBox(height: 4),
                Text(
                  'Step 2: Choose a more specific feeling',
                  style: TextStyle(fontFamily: 'Quicksand'),
                ),
              ],
              if (maxDepth > 2) ...const [
                SizedBox(height: 2),
                Text(
                  'Step 3: Tap the exact feeling that fits',
                  style: TextStyle(fontFamily: 'Quicksand'),
                ),
              ],
              if (age != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _ageGuidanceText(maxDepth),
                    style: const TextStyle(fontFamily: 'Quicksand', fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildActiveLevel(maxDepth),
        ),
        if (_selectedCore != null)
          Align(
            alignment: Alignment.centerRight,
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
    return Semantics(
      label: 'Feelings wheel reference image',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/images/FeelingsWheel.png',
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildActiveLevel(int maxDepth) {
    if (_selectedCore == null) {
      return _buildCoreLevel(maxDepth);
    }
    if (maxDepth == 1) {
      return _buildCoreFinal();
    }
    if (_selectedSecondary == null) {
      return _buildSecondaryLevel(maxDepth);
    }
    if (maxDepth == 2) {
      return _buildSecondaryFinal();
    }
    return _buildTertiaryLevel();
  }

  Widget _buildCoreLevel(int maxDepth) {
    return Column(
      key: const ValueKey('core'),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: FeelingsWheelData.coreEmotions.length,
          itemBuilder: (context, index) {
            final emotion = FeelingsWheelData.coreEmotions[index];
            return _buildFeelingButton(
              emoji: emotion.emoji,
              name: emotion.name,
              color: emotion.color!,
              onTap: () {
                if (maxDepth == 1) {
                  _notifySelection(
                    SelectedFeeling(
                      core: emotion.name,
                      secondary: '',
                      tertiary: emotion.name,
                      emoji: emotion.emoji,
                      eyeType: emotion.eyeType,
                      mouthType: emotion.mouthType,
                      color: emotion.color ?? SunsetJungleTheme.sunsetPink,
                    ),
                  );
                } else {
                  setState(() {
                    _selectedCore = emotion;
                    _selectedSecondary = null;
                  });
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCoreFinal() {
    return const SizedBox.shrink();
  }

  Widget _buildSecondaryLevel(int maxDepth) {
    return Column(
      key: const ValueKey('secondary'),
      children: [
        _buildBreadcrumb(
          text: '${_selectedCore!.emoji} ${_selectedCore!.name}',
          onBack: () {
            setState(() {
              _selectedCore = null;
              _selectedSecondary = null;
            });
          },
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
          ),
          itemCount: _selectedCore!.secondary.length,
          itemBuilder: (context, index) {
            final emotion = _selectedCore!.secondary[index];
            return _buildFeelingButton(
              emoji: emotion.emoji,
              name: emotion.name,
              color: _selectedCore!.color!.withOpacity(0.8),
              onTap: () {
                if (maxDepth == 2) {
                  _notifySelection(
                    SelectedFeeling(
                      core: _selectedCore!.name,
                      secondary: emotion.name,
                      tertiary: emotion.name,
                      emoji: emotion.emoji,
                      eyeType: emotion.eyeType,
                      mouthType: emotion.mouthType,
                      color: _selectedCore!.color ?? SunsetJungleTheme.sunsetPink,
                    ),
                  );
                } else {
                  setState(() {
                    _selectedSecondary = emotion;
                  });
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSecondaryFinal() {
    return const SizedBox.shrink();
  }

  Widget _buildTertiaryLevel() {
    return Column(
      key: const ValueKey('tertiary'),
      children: [
        _buildBreadcrumb(
          text:
              '${_selectedCore!.emoji} ${_selectedCore!.name} → ${_selectedSecondary!.emoji} ${_selectedSecondary!.name}',
          onBack: () {
            setState(() {
              _selectedSecondary = null;
            });
          },
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
          ),
          itemCount: _selectedSecondary!.tertiary.length,
          itemBuilder: (context, index) {
            final feelingName = _selectedSecondary!.tertiary[index];
            final emoji =
                FeelingsEmojiLookup.emojiFor(feelingName) ?? _selectedSecondary!.emoji;
            final isSelected =
                widget.currentFeeling?.tertiary == feelingName;
            return _buildFeelingButton(
              emoji: emoji,
              name: feelingName,
              color: _selectedCore!.color!.withOpacity(0.7),
              isSelected: isSelected,
              onTap: () {
                _notifySelection(
                  SelectedFeeling(
                    core: _selectedCore!.name,
                    secondary: _selectedSecondary!.name,
                    tertiary: feelingName,
                    emoji: emoji,
                    eyeType: _selectedSecondary!.eyeType,
                    mouthType: _selectedSecondary!.mouthType,
                    color: _selectedCore!.color ?? SunsetJungleTheme.sunsetPink,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _notifySelection(SelectedFeeling feeling) {
    widget.onFeelingSelected?.call(feeling);
  }

  Widget _buildBreadcrumb({
    required String text,
    required VoidCallback onBack,
  }) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeelingButton({
    required String emoji,
    required String name,
    required Color color,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Semantics(
      button: true,
      label: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.3) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.4),
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 8),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

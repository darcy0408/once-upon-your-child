// lib/feelings_wheel_screen.dart
// Interactive Feelings Wheel for therapeutic emotional learning
// Matching React web app functionality

import 'package:flutter/material.dart';
import 'feelings_wheel_data.dart';
import 'sunset_jungle_theme.dart';

class FeelingsWheelScreen extends StatefulWidget {
  final SelectedFeeling? currentFeeling;
  final ValueChanged<SelectedFeeling>? onFeelingSelected;

  const FeelingsWheelScreen({
    super.key,
    this.currentFeeling,
    this.onFeelingSelected,
  });

  @override
  State<FeelingsWheelScreen> createState() => _FeelingsWheelScreenState();
}

class _FeelingsWheelScreenState extends State<FeelingsWheelScreen> {
  CoreEmotion? _selectedCore;
  SecondaryFeeling? _selectedSecondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SunsetJungleTheme.creamLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SunsetJungleTheme.jungleMint, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Step 1: Pick a core emotion',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Step 2: Choose a more specific feeling',
                style: TextStyle(fontFamily: 'Quicksand'),
              ),
              SizedBox(height: 2),
              Text(
                'Step 3: Tap the exact feeling that fits',
                style: TextStyle(fontFamily: 'Quicksand'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildActiveLevel(),
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

  Widget _buildActiveLevel() {
    if (_selectedCore == null) {
      return _buildCoreLevel();
    }
    if (_selectedSecondary == null) {
      return _buildSecondaryLevel();
    }
    return _buildTertiaryLevel();
  }




  Widget _buildCoreLevel() {
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
                setState(() {
                  _selectedCore = emotion;
                  _selectedSecondary = null;
                });
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSecondaryLevel() {
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
                setState(() {
                  _selectedSecondary = emotion;
                });
              },
            );
          },
        ),
      ],
    );
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
            final isSelected =
                widget.currentFeeling?.tertiary == feelingName;
            return _buildFeelingButton(
              name: feelingName,
              color: _selectedCore!.color!.withOpacity(0.6),
              isSelected: isSelected,
              onTap: () {
                final selectedFeeling = SelectedFeeling(
                  core: _selectedCore!.name,
                  secondary: _selectedSecondary!.name,
                  tertiary: feelingName,
                  emoji: _selectedSecondary!.emoji,
                  eyeType: _selectedSecondary!.eyeType,
                  mouthType: _selectedSecondary!.mouthType,
                  color: _selectedCore!.color!,
                );
                widget.onFeelingSelected?.call(selectedFeeling);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeelingButton({
    String? emoji,
    required String name,
    required Color color,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Material(
      color: isSelected ? color.darken() : color,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (emoji != null)
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 40),
                ),
              if (emoji != null) const SizedBox(height: 8),
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 4,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (isSelected) ...[
                const SizedBox(height: 6),
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumb({
    required String text,
    required VoidCallback onBack,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SunsetJungleTheme.sandWarm,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ElevatedButton(
            onPressed: onBack,
            style: ElevatedButton.styleFrom(
              backgroundColor: SunsetJungleTheme.sunsetCoral,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              '← Back',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: SunsetJungleTheme.jungleDeepGreen,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }


}

extension on Color {
  Color darken([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final adjusted =
        hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return adjusted.toColor();
  }
}

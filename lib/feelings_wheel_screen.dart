// lib/feelings_wheel_screen.dart
// Interactive Feelings Wheel for therapeutic emotional learning
// Matching React web app functionality

import 'package:flutter/material.dart';
import 'feelings_wheel_data.dart';
import 'sunset_jungle_theme.dart';

class FeelingsWheelScreen extends StatefulWidget {
  final SelectedFeeling? currentFeeling;

  const FeelingsWheelScreen({
    super.key,
    this.currentFeeling,
  });

  @override
  State<FeelingsWheelScreen> createState() => _FeelingsWheelScreenState();
}

class _FeelingsWheelScreenState extends State<FeelingsWheelScreen> {
  CoreEmotion? _selectedCore;
  SecondaryFeeling? _selectedSecondary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🌈 How Are You Feeling?'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: SunsetJungleTheme.headerGradient,
          ),
        ),
      ),
      backgroundColor: SunsetJungleTheme.creamLight,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 20),

              // Current Feeling Display
              if (widget.currentFeeling != null) _buildCurrentFeeling(),

              // Core Level
              if (_selectedCore == null) _buildCoreLevel(),

              // Secondary Level
              if (_selectedCore != null && _selectedSecondary == null)
                _buildSecondaryLevel(),

              // Tertiary Level
              if (_selectedSecondary != null) _buildTertiaryLevel(),

              const SizedBox(height: 20),

              // Footer
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String subtitle;
    if (_selectedCore == null) {
      subtitle = "Pick a feeling to start";
    } else if (_selectedSecondary == null) {
      subtitle = "Now, be more specific...";
    } else {
      subtitle = "Choose the word that fits best";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: SunsetJungleTheme.jungleDeepGreen.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            subtitle,
            style: SunsetJungleTheme.sectionTitleStyle.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentFeeling() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: SunsetJungleTheme.mintCreamGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SunsetJungleTheme.jungleSage, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.currentFeeling!.emoji,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'Currently feeling: ${widget.currentFeeling!.tertiary}',
              style: const TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: SunsetJungleTheme.jungleForest,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoreLevel() {
    return Column(
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
            return _buildFeelingButton(
              name: feelingName,
              color: _selectedCore!.color!.withOpacity(0.6),
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
                Navigator.of(context).pop(selectedFeeling);
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
  }) {
    return Material(
      color: color,
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

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: SunsetJungleTheme.jungleMint,
            width: 2,
          ),
        ),
      ),
      child: const Text(
        "✨ It's okay to feel any feeling! Feelings help us understand ourselves.",
        style: TextStyle(
          fontFamily: 'Quicksand',
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: SunsetJungleTheme.jungleOlive,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

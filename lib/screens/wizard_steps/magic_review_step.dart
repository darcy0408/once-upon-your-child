import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/make_magic_button.dart';
import '../../widgets/character_preview.dart';
import '../wizard_story_screen.dart';

/// Step 4: Magic Review & Launch
///
/// Layout:
/// - Character preview at top
/// - Summary cards showing selections
/// - Big "Make Magic" button
/// - Actually triggers story generation
class MagicReviewStep extends StatefulWidget {
  final WizardData wizardData;

  const MagicReviewStep({
    super.key,
    required this.wizardData,
  });

  @override
  State<MagicReviewStep> createState() => _MagicReviewStepState();
}

class _MagicReviewStepState extends State<MagicReviewStep> {
  bool _isGenerating = false;

  void _launchStoryCreation() async {
    if (!widget.wizardData.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all steps first!'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // TODO: Integrate with actual story generation API
      // For now, just show the data we collected
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      if (mounted) {
        // Navigate to story result or show success
        // TODO: Navigate to StoryResultScreen with generated story
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story generation started! 🎉'),
            backgroundColor: AppColors.success,
          ),
        );

        // Pop back to main screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.wizardData;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              'Ready for Magic?',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Subtitle
            Text(
              'Review your story setup',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textDark.withAlpha(179), // 70% opacity
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Character preview (smaller version)
            SizedBox(
              height: 200,
              child: CharacterPreview(
                placeholderEmoji: _getCharacterEmoji(),
                showSparkles: true,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Summary cards
            _SummaryCard(
              icon: '🦸',
              title: 'Your Hero',
              value: data.selectedArchetypeId ?? 'Not selected',
            ),
            const SizedBox(height: AppSpacing.md),

            if (data.selectedScenario != null)
              _SummaryCard(
                icon: '📖',
                title: 'Story Theme',
                value: _formatScenario(data.selectedScenario!),
              ),
            if (data.selectedEmotionChips.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _SummaryCard(
                icon: '💫',
                title: 'Feelings',
                value: data.selectedEmotionChips.join(', '),
              ),
            ],
            if (data.selectedCompanion != null) ...[
              const SizedBox(height: AppSpacing.md),
              _SummaryCard(
                icon: '🐾',
                title: 'Companion',
                value: data.companionName ?? data.selectedCompanion!,
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),

            // Big "Make Magic" button
            Center(
              child: _isGenerating
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    )
                  : MakeMagicButton(
                      onTap: _launchStoryCreation,
                      isEnabled: !_isGenerating && data.isComplete,
                    ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Debug info (can be removed later)
            if (false) // Set to true for debugging
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(26), // 10% opacity
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  'Debug: ${data.toJson()}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: AppColors.textDark,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getCharacterEmoji() {
    // Map archetype to emoji
    final archetype = widget.wizardData.selectedArchetypeId ?? '';
    if (archetype.contains('Adventurer')) return '🗺️';
    if (archetype.contains('Thinker')) return '💭';
    if (archetype.contains('Artist')) return '🎨';
    if (archetype.contains('Helper')) return '🤝';
    if (archetype.contains('Athlete')) return '⚡';
    if (archetype.contains('Shy')) return '😊';
    return '👧';
  }

  String _formatScenario(String scenarioId) {
    // Convert scenario ID to display name
    return scenarioId
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

class _SummaryCard extends StatelessWidget {
  final String icon;
  final String title;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.gold.withAlpha(128), // 50% opacity
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldLight.withAlpha(51), // 20% opacity
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Text(
            icon,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: AppSpacing.md),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textDark.withAlpha(179), // 70% opacity
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

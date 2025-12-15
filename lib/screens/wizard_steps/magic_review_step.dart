import 'package:flutter/material.dart';
import '../../services/api_service_manager.dart';
import '../../services/achievement_service.dart';
import '../../story_result_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/make_magic_button.dart';
import '../../widgets/character_preview.dart';
import '../wizard_story_screen.dart';
import 'wizard_data_mapper.dart';

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

  // Import for json/http/env
  bool _isSaving = false;

  void _launchStoryCreation() async {
    debugPrint('🎯 MagicReviewStep: _launchStoryCreation called');
    debugPrint('📊 WizardData.isComplete: ${widget.wizardData.isComplete}');
    debugPrint('📊 Step1Complete: ${widget.wizardData.isStep1Complete}');
    debugPrint('📊 Step2Complete: ${widget.wizardData.isStep2Complete}');
    debugPrint('📊 Step3Complete: ${widget.wizardData.isStep3Complete}');
    debugPrint('📊 WizardData: ${widget.wizardData.toJson()}');

    if (!widget.wizardData.isComplete) {
      debugPrint('⚠️ Wizard data not complete!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all steps first!'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    debugPrint('✅ Wizard data complete, starting story generation');
    setState(() => _isGenerating = true);

    try {
      // 1. Save Character if needed
      debugPrint('💾 Saving character if needed...');
      await _saveCharacterIfNeeded();

      // Prepared payload using the mapper
      debugPrint('🗺️ Mapping wizard data to story request...');
      final requestData = WizardDataMapper.mapToStoryRequest(widget.wizardData);
      debugPrint('📦 Request data: $requestData');

      // Call the API
      debugPrint('🔮 Calling ApiServiceManager.generateStory...');
      debugPrint('  📷 Include Illustrations: ${widget.wizardData.includeIllustrations}');
      debugPrint('  🎵 Rhyme Time Mode: ${widget.wizardData.rhymeTimeMode}');
      debugPrint('  📚 Learning to Read Mode: ${widget.wizardData.learningToReadMode}');
      debugPrint('  🎮 Interactive Mode: ${widget.wizardData.interactiveMode}');

      final result = await ApiServiceManager.generateStory(
        characterName: requestData['characterName'],
        age: requestData['age'],
        theme: requestData['theme'],
        companion: (requestData['companions'] as List?)?.isNotEmpty == true
            ? (requestData['companions'] as List).join(', ')
            : null,
        characterDetails: requestData['characterDetails'],
        currentFeeling: requestData['currentFeeling'],
        additionalCharacters: requestData['additionalCharacters'],
        // Story modes from wizard
        includeIllustrations: widget.wizardData.includeIllustrations,
        rhymeTimeMode: widget.wizardData.rhymeTimeMode,
        learningToReadMode: widget.wizardData.learningToReadMode,
      );
      debugPrint('✨ Story generation complete: ${result.storyText.substring(0, 100)}...');

      if (mounted) {
        // Navigate to result
        debugPrint('🚀 MagicReviewStep: Navigating to StoryResultScreen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => StoryResultScreen(
              title: result.title ?? 'My Magical Story',
              storyText: result.storyText,
              wisdomGem: result.wisdomGem ?? 'You are magic!',
              characterName: requestData['characterName'],
              theme: requestData['theme'],
              characterAge: requestData['age'],
              // Track this as a new story
              trackStoryCreation: true,
              trackAnalytics: true,
              achievementsService: AchievementService(),
              storyCreatedAt: DateTime.now(),
            ),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Error generating story: $e');
      debugPrint('📚 Stack trace: $stack');

      // Parse error for better user message
      String userMessage = 'Magic needed a recharge';
      if (e.toString().contains('500')) {
        userMessage = 'Server error (500). The backend had trouble generating your story.';
        debugPrint('🔍 This is a server-side error. Check backend logs for details.');
      } else if (e.toString().contains('timeout')) {
        userMessage = 'Story generation timed out. Please try again.';
      } else if (e.toString().contains('Cannot connect')) {
        userMessage = 'Cannot connect to server. Is the backend running?';
      }

      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userMessage\n\nTechnical: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _launchStoryCreation,
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveCharacterIfNeeded() async {
    // If we already have an ID (e.g. from existing character), skip
    if (widget.wizardData.characterId != null) return;

    setState(() => _isSaving = true);
    
    try {
      // Extract details mapped from archetype
      final characterDetails = WizardDataMapper.mapToStoryRequest(widget.wizardData)['characterDetails'] as Map<String, dynamic>;
      
      // Construct simple payload for backend
      final body = {
        'name': widget.wizardData.characterName,
        'age': widget.wizardData.characterAge,
        'gender': widget.wizardData.characterGender,
        'character_type': 'Everyday Kid',
        'character_style': 'Regular Kid', 
        'likes': characterDetails['interests'] ?? [],
        'strengths': characterDetails['strengths'] ?? [],
        'avatar': { // Minimal avatar payload if none custom
          'hairColor': 'Brown',
          'skinTone': 'Light',
        }
      };

      // We need to use http package directly or via ApiServiceManager if it exposed generic post
      // Re-using ApiServiceManager helper if available, otherwise direct http
      // Assuming we can use ApiServiceManager().post which I saw in the file (lines 26-67)
      
      final api = ApiServiceManager(); 
      final response = await api.post('/create-character', body);
      
      if (response.containsKey('character_id')) { // Adjust key based on backend response
         widget.wizardData.characterId = response['character_id']?.toString();
         debugPrint('✅ Character saved with ID: ${widget.wizardData.characterId}');
      } else if (response.containsKey('id')) {
         widget.wizardData.characterId = response['id']?.toString();
      }

    } catch (e) {
      debugPrint('⚠️ Valid warning: Character save failed ($e), but proceeding with temporary character for story.');
      // We don't block story generation, just warn console
    } finally {
      setState(() => _isSaving = false);
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

            // Story Settings Section
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.primary.withAlpha(128),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚙️ Story Settings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Include Illustrations toggle
                  CheckboxListTile(
                    title: const Text('✨ Include Illustrations'),
                    subtitle: const Text('Add beautiful images to your story'),
                    value: data.includeIllustrations,
                    onChanged: (value) {
                      setState(() => data.includeIllustrations = value ?? true);
                    },
                    activeColor: AppColors.primary,
                  ),

                  // Rhyme Time Mode toggle
                  CheckboxListTile(
                    title: const Text('🎵 Rhyme Time Mode'),
                    subtitle: const Text('Story told in fun rhymes'),
                    value: data.rhymeTimeMode,
                    onChanged: (value) {
                      setState(() => data.rhymeTimeMode = value ?? false);
                    },
                    activeColor: AppColors.primary,
                  ),

                  // Learning to Read Mode toggle
                  CheckboxListTile(
                    title: const Text('📚 Learning to Read Mode'),
                    subtitle: const Text('Simple words for early readers'),
                    value: data.learningToReadMode,
                    onChanged: (value) {
                      setState(() => data.learningToReadMode = value ?? false);
                    },
                    activeColor: AppColors.primary,
                  ),

                  // Interactive Story Mode toggle
                  CheckboxListTile(
                    title: const Text('🎮 Interactive Story Mode'),
                    subtitle: const Text('Make choices as the story unfolds'),
                    value: data.interactiveMode,
                    onChanged: (value) {
                      setState(() => data.interactiveMode = value ?? false);
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Summary cards
            Text(
              '📋 Story Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),

            _SummaryCard(
              icon: '🦸',
              title: 'Your Hero',
              value: '${data.characterName} (${data.selectedArchetypeId})',
            ),
            const SizedBox(height: AppSpacing.md),

            _SummaryCard(
              icon: '🎂',
              title: 'Age',
              value: '${data.characterAge} years old',
            ),
            const SizedBox(height: AppSpacing.md),

            if (data.pets.isNotEmpty || data.additionalCharacters.isNotEmpty) ...[
              _SummaryCard(
                icon: '👨‍👩‍👧‍👦',
                title: 'Friends & Family',
                value: [
                  ...data.additionalCharacters,
                  ...data.pets.map((p) => '${p['name']} (${p['species']})')
                ].join(', '),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

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
            if (data.selectedCompanions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _SummaryCard(
                icon: '🐾',
                title: 'Companions',
                value: data.companionNames.isNotEmpty 
                    ? data.companionNames.join(', ')
                    : data.selectedCompanions.join(', '),
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

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
  bool _isSaving = false;

  void _launchStoryCreation() async {
    debugPrint('🎯 MagicReviewStep: _launchStoryCreation called');

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
      await _saveCharacterIfNeeded();

      // Prepared payload using the mapper
      final requestData = WizardDataMapper.mapToStoryRequest(widget.wizardData);

      final result = await ApiServiceManager.generateStory(
        characterName: requestData['characterName'],
        age: requestData['age'],
        theme: requestData['theme'],
        companion: requestData['companion'],
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

      String userMessage = 'Magic needed a recharge';
      if (e.toString().contains('500')) {
        userMessage = 'Server error (500). The backend had trouble generating your story.';
      } else if (e.toString().contains('timeout')) {
        userMessage = 'Story generation timed out. Please try again.';
      } else if (e.toString().contains('Cannot connect') || e.toString().contains('XMLHttpRequest')) {
         // "failed to fetch" often comes up as XMLHttpRequest error in Flutter Web
        userMessage = 'Cannot connect to server. Please check your internet or try again.';
      }

      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userMessage\n\n${e.toString().length > 100 ? e.toString().substring(0, 100) + '...' : e.toString()}'),
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
      final characterDetails = WizardDataMapper.mapToStoryRequest(widget.wizardData)['characterDetails'] as Map<String, dynamic>;
      
      final body = {
        'name': widget.wizardData.characterName,
        'age': widget.wizardData.characterAge,
        'gender': widget.wizardData.characterGender,
        'character_type': 'Everyday Kid',
        'character_style': 'Regular Kid', 
        'likes': characterDetails['interests'] ?? [],
        'strengths': characterDetails['strengths'] ?? [],
        'avatar': { 
          'hairColor': 'Brown',
          'skinTone': 'Light',
        }
      };

      final api = ApiServiceManager();
      final response = await api.post('/create-character', body);

      if (response.containsKey('character_id')) {
         widget.wizardData.characterId = response['character_id']?.toString();
      } else if (response.containsKey('id')) {
         widget.wizardData.characterId = response['id']?.toString();
      }

    } catch (e) {
      debugPrint('⚠️ Character save failed: $e');
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
                    color: AppColors.textDark.withAlpha(179),
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

            // Story Settings Section (Magical Card)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                // Gradient background instead of solid white
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    AppColors.primary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('⚙️', style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Story Settings',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: AppSpacing.sm),

                  _buildSwitchTile(
                    '✨ Include Illustrations',
                    'Add beautiful images',
                    data.includeIllustrations,
                    (v) => setState(() => data.includeIllustrations = v),
                  ),
                  _buildSwitchTile(
                    '🎵 Rhyme Time Mode',
                    'Story told in fun rhymes',
                    data.rhymeTimeMode,
                    (v) => setState(() => data.rhymeTimeMode = v),
                  ),
                  _buildSwitchTile(
                    '📚 Learning to Read',
                    'Simple words for early readers',
                    data.learningToReadMode,
                    (v) => setState(() => data.learningToReadMode = v),
                  ),
                  _buildSwitchTile(
                    '🎮 Interactive Mode',
                    'Make choices as you go',
                    data.interactiveMode,
                    (v) => setState(() => data.interactiveMode = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Summary cards header
             Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                '📋 Story Summary',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            _SummaryCard(
              icon: '🦸',
              title: 'Your Hero',
              value: data.characterName.isEmpty 
                  ? 'MISSING NAME (Go back to Step 1)' 
                  : '${data.characterName} (${data.selectedArchetypeId})',
              isError: data.characterName.isEmpty,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.md),

            _SummaryCard(
              icon: '🎂',
              title: 'Age',
              value: '${data.characterAge} years old',
              color: Colors.orange,
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
                color: Colors.green,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            if (data.selectedScenario != null)
              _SummaryCard(
                icon: '📖',
                title: 'Story Theme',
                value: _formatScenario(data.selectedScenario!),
                color: Colors.blue,
              ),
            if (data.selectedEmotionChips.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _SummaryCard(
                icon: '💫',
                title: 'Feelings',
                value: data.selectedEmotionChips.join(', '),
                color: Colors.purple,
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
                color: Colors.brown,
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
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  String _getCharacterEmoji() {
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
  final bool isError;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    this.isError = false,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg), // Improved Radius
        border: Border.all(
          color: isError ? AppColors.error : color.withOpacity(0.3),
          width: 2, // Thicker border
        ),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
             // Subtle tint based on the category color
             color.withOpacity(0.05),
             Colors.white,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isError ? AppColors.error.withOpacity(0.1) : color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              icon,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isError ? AppColors.error : AppColors.textDark,
                        fontWeight: isError ? FontWeight.bold : FontWeight.w600,
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

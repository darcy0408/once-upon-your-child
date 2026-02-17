import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show cos, sin;
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/achievement_service.dart';
import 'package:story_weaver_app/story_result_screen.dart';
import 'package:story_weaver_app/story_illustration_service.dart';
import 'package:story_weaver_app/pick_a_path_adventure_screen.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/theme/app_theme.dart';
import 'package:story_weaver_app/widgets/magic_orb.dart';
import 'package:story_weaver_app/widgets/magical_loading_view.dart';
import 'package:story_weaver_app/widgets/image_progress_orb.dart';
import 'package:story_weaver_app/widgets/image_mode_orb.dart';
import 'package:story_weaver_app/widgets/image_crystal_formation.dart';
import 'package:story_weaver_app/widgets/image_make_magic_button.dart';
import 'package:story_weaver_app/data/scenario_data.dart';
import 'package:story_weaver_app/data/companion_data.dart';
import 'wizard_data_mapper.dart';

/// Step 4: Magic Review & Launch (Vision Orb Edition)
///
/// Design:
/// - "Vision Orb" centering the experience
/// - Floating elements for Hero and Companion
/// - Settings as magical toggles
/// - "Whisper" input for custom ideas
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
  String _loadingStatus = 'Creating your story...';
  final StoryIllustrationService _illustrationService =
      StoryIllustrationService();

  // Helper to get scenario image
  String get _scenarioImage {
    if (widget.wizardData.selectedScenario != null) {
      final scenario =
          ScenarioData.getById(widget.wizardData.selectedScenario!);
      if (scenario != null) {
        // Ensure path has assets/ prefix if missing
        if (!scenario.illustration.startsWith('assets/')) {
          return 'assets/${scenario.illustration}';
        }
        return scenario.illustration;
      }
    }
    return 'assets/images/scenarios/magic_door.png'; // Fallback
  }

  // Helper to get companion image
  String? get _companionImage {
    if (widget.wizardData.selectedCompanions.isNotEmpty) {
      // Prioritize the first selected companion
      final firstComp = widget.wizardData.selectedCompanions.first;
      // Check if it's a magical companion
      try {
        final magicComp = magicCompanions.firstWhere((c) => c.id == firstComp);
        // Map ID to asset path (assuming convention or look up if path added to data)
        // Since companion_data doesn't have imagePath in this version of the file I read,
        // I'll map it manually based on known assets.
        return 'assets/images/companions/${magicComp.id}.jpg';
      } catch (_) {
        // Not a magic companion, might be a pet or friend
        // Return null to show emoji fallback
        return null;
      }
    }
    return null;
  }

  // Helper to get scenario name
  String get _scenarioLabel {
    if (widget.wizardData.selectedScenario != null) {
      final scenario =
          ScenarioData.getById(widget.wizardData.selectedScenario!);
      if (scenario != null) return scenario.title;
    }
    return 'Magical Adventure';
  }

  void _launchStoryCreation() async {
    debugPrint('🎯 MagicReviewStep: _launchStoryCreation called');

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
    // Give Flutter a frame to paint the loading UI before starting network work.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    try {
      // 1. Save Character if needed
      await _saveCharacterIfNeeded();

      // Prepared payload using the mapper
      final requestData = WizardDataMapper.mapToStoryRequest(widget.wizardData);

      // 2. CHECK MODE: If Pick-A-Path, skip standard generation
      if (widget.wizardData.interactiveMode) {
        if (mounted) {
          // Create a Character object from wizard data
          final character = Character(
            id: widget.wizardData.characterId ??
                'temp-${DateTime.now().millisecondsSinceEpoch}',
            name: widget.wizardData.characterName,
            age: widget.wizardData.characterAge,
            role: widget.wizardData.selectedArchetypeId ?? 'Adventurer',
            gender: widget.wizardData.characterGender,
            personalitySliders: widget.wizardData.personalitySliders,
          );

          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PickAPathAdventureScreen(
                userId: 'guest',
                character: character,
                theme: requestData['theme'] ?? 'Adventure',
                tone: 'whimsical',
                length: _mapStoryLength(widget.wizardData.storyLength),
                interests: widget.wizardData.selectedEmotionChips.isNotEmpty
                    ? widget.wizardData.selectedEmotionChips
                    : null,
                mustInclude: widget.wizardData.customElements.isNotEmpty
                    ? [widget.wizardData.customElements]
                    : null,
                avoid: widget.wizardData.fears.isNotEmpty
                    ? widget.wizardData.fears
                    : null,
                lifeChallenge: widget.wizardData.lifeChallenge,
                personalitySliders: widget.wizardData.personalitySliders,
              ),
            ),
          );
        }
      } else {
        // 3. STANDARD MODE: Generate story
        final result = await ApiServiceManager.generateStory(
          characterName: requestData['character'] ?? 'Hero',
          age: requestData['age'] ?? 5,
          theme: requestData['theme'] ?? 'Magical Adventure',
          companion: requestData['companion'] ?? '',
          characterDetails: requestData['characterDetails'],
          currentFeeling: requestData['currentFeeling'],
          additionalCharacters: requestData['additionalCharacters'],
          includeIllustrations: widget.wizardData.includeIllustrations,
          rhymeTimeMode: widget.wizardData.rhymeTimeMode,
          learningToReadMode: widget.wizardData.learningToReadMode,
          companionPets: requestData['companion_pets'],
          companionCharacters: requestData['companion_characters'],
          storyLength: requestData['storyLength'] ?? 'standard',
          customElements: requestData['customElements'] ?? '',
          onProgress: (status) {
            if (mounted) setState(() => _loadingStatus = status);
          },
        );

        // Inject custom avatar base64 into characterDetails for illustration use
        if (widget.wizardData.customAvatarPath != null) {
          try {
            final avatarFile = File(widget.wizardData.customAvatarPath!);
            if (await avatarFile.exists()) {
              final avatarBytes = await avatarFile.readAsBytes();
              final avatarBase64 = base64Encode(avatarBytes);
              final charDetails = requestData['characterDetails'];
              if (charDetails is Map<String, dynamic>) {
                charDetails['custom_avatar_base64'] = avatarBase64;
              }
            }
          } catch (e) {
            debugPrint('⚠️ Could not load custom avatar for illustration: $e');
          }
        }

        List<Map<String, dynamic>> inlineIllustrations = result.illustrations;
        if (widget.wizardData.includeIllustrations &&
            inlineIllustrations.isEmpty) {
          if (mounted) {
            setState(
                () => _loadingStatus = 'Painting magical illustrations...');
          }
          inlineIllustrations = await _generateInlineIllustrations(
            storyText: result.storyText,
            storyTitle: result.title ?? 'My Magical Story',
            requestData: requestData,
          );
        }

        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => StoryResultScreen(
                title: result.title ?? 'My Magical Story',
                storyText: result.storyText,
                wisdomGem: result.wisdomGem ?? 'You are magic!',
                characterName: requestData['characterName'] ??
                    widget.wizardData.characterName,
                theme: requestData['theme'],
                characterAge: requestData['age'],
                pages: result.pages,
                adventureSteps: result.adventureSteps,
                storyLengthHint: requestData['storyLength']?.toString() ??
                    widget.wizardData.storyLength,
                trackStoryCreation: true,
                trackAnalytics: true,
                achievementsService: AchievementService(),
                storyCreatedAt: DateTime.now(),
                isRhyming: widget.wizardData.rhymeTimeMode,
                isLearningToReadMode: widget.wizardData.learningToReadMode,
                backendIllustrations: inlineIllustrations,
                asyncIllustrations: result.asyncIllustrations,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error generating story: $e');
      String userMessage = 'Magic needed a recharge';
      if (e.toString().contains('500')) {
        userMessage = 'Server error. The magic faded.';
      } else if (e.toString().contains('timeout')) {
        userMessage = 'Story took too long.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userMessage\nTry again?'),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _launchStoryCreation),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<List<Map<String, dynamic>>> _generateInlineIllustrations({
    required String storyText,
    required String storyTitle,
    required Map<String, dynamic> requestData,
  }) async {
    try {
      final generated = await _illustrationService.generateIllustrations(
        storyText: storyText,
        storyTitle: storyTitle,
        characterName:
            requestData['character']?.toString() ?? widget.wizardData.characterName,
        theme: requestData['theme']?.toString(),
        numberOfImages: 1,
        age: requestData['age'] as int? ?? widget.wizardData.characterAge,
        characterAppearance:
            requestData['characterDetails'] as Map<String, dynamic>?,
      );

      return generated
          .map((illustration) {
            final url = illustration.imageUrl;
            if (url.startsWith('data:image/') && url.contains(',')) {
              final commaIndex = url.indexOf(',');
              if (commaIndex < 0 || commaIndex + 1 >= url.length) {
                return null;
              }
              return {
                'id': illustration.id,
                'prompt': illustration.prompt,
                'image_data': url.substring(commaIndex + 1),
              };
            }
            return null;
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('⚠️ Illustration generation failed: $e');
      return const [];
    }
  }

  Future<void> _saveCharacterIfNeeded() async {
    try {
      final characterDetails = WizardDataMapper.mapToStoryRequest(
          widget.wizardData)['characterDetails'] as Map<String, dynamic>;
      final body = {
        'name': widget.wizardData.characterName,
        'age': widget.wizardData.characterAge,
        'gender': widget.wizardData.characterGender,
        'role': widget.wizardData.selectedArchetypeId,
        'character_type': 'Everyday Kid',
        'character_style': 'Regular Kid',
        'likes': characterDetails['interests'] ?? [],
        'strengths': characterDetails['strengths'] ?? [],
        'pets': widget.wizardData.pets,
        'friends': widget.wizardData.additionalCharacters,
        'avatar': {'hairColor': 'Brown', 'skinTone': 'Light'},
        if (widget.wizardData.generatedAvatar != null)
          'avatar_data': widget.wizardData.generatedAvatar!.toJson(),
      };

      final api = ApiServiceManager();
      if (widget.wizardData.characterId != null) {
        await api.patch('/characters/${widget.wizardData.characterId}', body);
      } else {
        final response = await api.post('/create-character', body);
        if (response.containsKey('character_id')) {
          widget.wizardData.characterId = response['character_id']?.toString();
        } else if (response.containsKey('id')) {
          widget.wizardData.characterId = response['id']?.toString();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Character save failed: $e');
    }
  }

  String _mapStoryLength(String wizardLength) {
    switch (wizardLength) {
      case 'quick':
        return 'short';
      case 'epic':
        return 'long';
      default:
        return 'medium';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.wizardData;
    final screenWidth = MediaQuery.of(context).size.width;
    final orbSize = (screenWidth - 64).clamp(180.0, 250.0);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
        child: Column(
          children: [
            // 1. Image-based crystal ball progress indicators (3 steps now)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  ImageProgressOrb(icon: Icons.check_rounded, showStand: false),
                  SizedBox(width: 12),
                  ImageProgressOrb(icon: Icons.check_rounded, showStand: false),
                  SizedBox(width: 12),
                  ImageProgressOrb(icon: Icons.auto_awesome, showStand: false),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Vision Orb + circular side avatars
            SizedBox(
              height: 340, // Increased height for better spacing
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Adjust orbSize to be slightly more compact to avoid crowding
                  // final orbSize = (screenWidth - 80).clamp(160.0, 220.0);

                  // Enhanced outer aura with multiple layers
                  Container(
                    width: orbSize + 50,
                    height: orbSize + 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFEEA8).withValues(alpha: 0.4),
                          const Color(0xFFE985FF).withValues(alpha: 0.3),
                          const Color(0xFFB5F7FF).withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 0.7, 1.0],
                      ),
                    ),
                  ),

                  // Center crystal orb (Hero focus)
                  MagicOrbWidget(
                    imagePath: _scenarioImage,
                    size: orbSize * 0.95, // Slightly smaller hero orb
                    glowColor: AppColors.gold,
                    topLabel: _scenarioLabel,
                    label: data.characterName.isNotEmpty
                        ? data.characterName
                        : 'Your Hero',
                    childScale: 0.92,
                    child: _HeroAvatar(
                      generatedAvatar: data.generatedAvatar,
                      characterName: data.characterName,
                      role: data.selectedArchetypeId,
                    ),
                  ),

                  // Setting (Scenario) bubble - Moved to BOTTOM LEFT
                  Positioned(
                    left: 5,
                    bottom: 10,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FloatingBubble(
                          delay: 0,
                          child: _AuraCircle(
                            size: 84, // Slightly smaller side bubbles
                            auraColor: const Color(0xFFFFD9A6),
                            child: ClipOval(
                              child: Image.asset(
                                _scenarioImage,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1),
                          ),
                          child: Text(
                            _scenarioLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Companion avatar - Moved to BOTTOM RIGHT
                  if (data.selectedCompanions.isNotEmpty)
                    Positioned(
                      right: 5,
                      bottom: 10,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _FloatingBubble(
                            delay: 1.4,
                            child: _AuraCircle(
                              size: 84,
                              auraColor: const Color(0xFFF3AEFF),
                              child: _CompanionAvatar(
                                companionImage: _companionImage,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Companion',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Image-based mode orbs with magical effects
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 12,
              children: [
                ImageModeOrb(
                  modeType: 'tales',
                  label: 'Tales',
                  isActive: data.includeIllustrations,
                  onTap: () => setState(() =>
                      data.includeIllustrations = !data.includeIllustrations),
                  primaryColor: const Color(0xFFAA88FF), // Purple
                  secondaryColor: const Color(0xFFE28EFF), // Magenta
                ),
                ImageModeOrb(
                  modeType: 'rhyme',
                  label: 'Rhyme',
                  isActive: data.rhymeTimeMode,
                  onTap: () => setState(() {
                    data.rhymeTimeMode = !data.rhymeTimeMode;
                    if (data.rhymeTimeMode) {
                      data.learningToReadMode = false;
                      data.interactiveMode = false;
                    }
                  }),
                  primaryColor: const Color(0xFF00D4DD), // Cyan
                  secondaryColor: const Color(0xFF7FDDFF), // Light cyan
                ),
                ImageModeOrb(
                  modeType: 'reading',
                  label: 'Read-Along',
                  isActive: data.learningToReadMode,
                  onTap: () => setState(() {
                    data.learningToReadMode = !data.learningToReadMode;
                    if (data.learningToReadMode) {
                      data.rhymeTimeMode = false;
                      data.interactiveMode = false;
                    }
                  }),
                  primaryColor: const Color(0xFFB88AFF), // Light purple
                  secondaryColor: const Color(0xFFFF9ECC), // Pink
                ),
                ImageModeOrb(
                  modeType: 'pickpath',
                  label: 'Pick Your Path',
                  isActive: data.interactiveMode,
                  onTap: () => setState(() {
                    data.interactiveMode = !data.interactiveMode;
                    if (data.interactiveMode) {
                      data.rhymeTimeMode = false;
                      data.learningToReadMode = false;
                    }
                  }),
                  primaryColor: const Color(0xFF9E6CFF), // Purple
                  secondaryColor: const Color(0xFFFFB3E6), // Multi-color pink
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // 4. Image-based story-length crystals
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: ImageCrystalFormation(
                        type: 'quick',
                        label: 'Quick',
                        isSelected: data.storyLength == 'quick',
                        onTap: () => setState(() => data.storyLength = 'quick'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: ImageCrystalFormation(
                        type: 'classic',
                        label: 'Classic',
                        isSelected: data.storyLength == 'standard',
                        onTap: () =>
                            setState(() => data.storyLength = 'standard'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: ImageCrystalFormation(
                        type: 'epic',
                        label: 'Epic',
                        isSelected: data.storyLength == 'epic',
                        onTap: () => setState(() => data.storyLength = 'epic'),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            // 5. Whisper Input (Custom)
            Stack(
              children: [
                TextField(
                  maxLines: 3,
                  onChanged: (value) =>
                      setState(() => data.customElements = value),
                  decoration: InputDecoration(
                    hintText:
                        'I want to ride a magic carpet and learn to make friends',
                    hintStyle: TextStyle(
                      color: AppColors.textDark.withValues(alpha: 0.4),
                      fontStyle: FontStyle.italic,
                    ),
                    filled: true,
                    fillColor: AppColors.primary.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(20),
                  ),
                ),
                const Positioned(
                  right: 12,
                  bottom: 12,
                  child:
                      Icon(Icons.auto_awesome, color: AppColors.gold, size: 20),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),

            // 6. Image-based Make Magic Button
            Center(
              child: _isGenerating
                  ? MagicalLoadingView(
                      status: _loadingStatus,
                      onCancel: () => setState(() => _isGenerating = false),
                    )
                  : _PulsingCastSpellFrame(
                      isReady: !_isGenerating && data.isComplete,
                      child: ImageMakeMagicButton(
                        onTap: _launchStoryCreation,
                        isEnabled: !_isGenerating && data.isComplete,
                        label: 'MAKE MAGIC', // Updated label to match image
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// --- Helper Widgets ---

class _FloatingBubble extends StatefulWidget {
  final Widget child;
  final double delay;

  const _FloatingBubble({required this.child, this.delay = 0});

  @override
  State<_FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<_FloatingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4), // Slower float
      vsync: this,
    );

    // Offset each avatar on the animation curve so both bubbles don't move in lockstep.
    final phaseOffset = ((widget.delay * 1000).toInt() % 4000) / 4000.0;
    _controller.value = phaseOffset;
    _controller.repeat(reverse: true);

    _animation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: widget.child,
        );
      },
    );
  }
}

class _AuraCircle extends StatelessWidget {
  final double size;
  final Color auraColor;
  final Widget child;

  const _AuraCircle({
    required this.size,
    required this.auraColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outermost ethereal halo (third layer)
        Container(
          width: size + 50,
          height: size + 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                auraColor.withValues(alpha: 0.4),
                auraColor.withValues(alpha: 0.2),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Middle magical glow (second layer)
        Container(
          width: size + 32,
          height: size + 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                auraColor.withValues(alpha: 0.7),
                auraColor.withValues(alpha: 0.4),
                auraColor.withValues(alpha: 0.2),
                Colors.transparent,
              ],
              stops: const [0.0, 0.4, 0.7, 1.0],
            ),
          ),
        ),
        // Main avatar container with intensified multi-layer glow
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              // Bright inner glow
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.8),
                blurRadius: 16,
                spreadRadius: -2,
              ),
              // Intensified main aura glow
              BoxShadow(
                color: auraColor.withValues(alpha: 0.9),
                blurRadius: 50,
                spreadRadius: 6,
              ),
              // Secondary gold glow
              BoxShadow(
                color: const Color(0xFFFFE4B8).withValues(alpha: 0.7),
                blurRadius: 30,
                spreadRadius: 2,
              ),
              // Ethereal white outer glow (fourth shadow layer)
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.4),
                blurRadius: 60,
                spreadRadius: 10,
              ),
            ],
            // Removed white border for cleaner look
          ),
          child: child,
        ),
      ],
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  final GeneratedAvatar? generatedAvatar;
  final String characterName;
  final String? role;

  const _HeroAvatar({
    required this.generatedAvatar,
    required this.characterName,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    if (generatedAvatar == null) {
      return _GradientSphereFallback(
        child: _HeroFallbackIdentity(
          name: characterName,
          role: role,
        ),
      );
    }

    final imageData = generatedAvatar!.imageBase64;
    final isUrl =
        imageData.startsWith('http://') || imageData.startsWith('https://');
    final isAsset = imageData.startsWith('assets/');
    final isDataUri = imageData.startsWith('data:image');

    if (isAsset) {
      return ClipOval(
        child: Image.asset(
          imageData,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _GradientSphereFallback(
            child: _HeroFallbackIdentity(name: characterName, role: role),
          ),
        ),
      );
    }

    if (isUrl) {
      return ClipOval(
        child: Image.network(
          imageData,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _GradientSphereFallback(
            child: _HeroFallbackIdentity(name: characterName, role: role),
          ),
        ),
      );
    }

    // Support both full data URIs and raw base64 strings.
    final normalizedBase64 = isDataUri || imageData.contains(',')
        ? imageData.split(',').last
        : imageData;
    try {
      return ClipOval(
        child: Image.memory(
          base64Decode(normalizedBase64),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _GradientSphereFallback(
            child: _HeroFallbackIdentity(name: characterName, role: role),
          ),
        ),
      );
    } catch (_) {
      return _GradientSphereFallback(
        child: _HeroFallbackIdentity(name: characterName, role: role),
      );
    }
  }
}

class _HeroFallbackIdentity extends StatelessWidget {
  final String name;
  final String? role;

  const _HeroFallbackIdentity({
    required this.name,
    required this.role,
  });

  String get _initial {
    if (name.trim().isEmpty) return 'H';
    return name.trim().substring(0, 1).toUpperCase();
  }

  IconData get _roleIcon {
    final normalized = (role ?? '').toLowerCase();
    if (normalized.contains('artist')) return Icons.palette_rounded;
    if (normalized.contains('athlete')) return Icons.bolt_rounded;
    if (normalized.contains('helper')) return Icons.volunteer_activism_rounded;
    if (normalized.contains('thinker')) return Icons.psychology_alt_rounded;
    if (normalized.contains('advent')) return Icons.explore_rounded;
    return Icons.face_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(_roleIcon, color: Colors.white.withValues(alpha: 0.95), size: 42),
        const SizedBox(height: 8),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.22),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.45), width: 1.2),
          ),
          child: Center(
            child: Text(
              _initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompanionAvatar extends StatelessWidget {
  final String? companionImage;

  const _CompanionAvatar({
    required this.companionImage,
  });

  @override
  Widget build(BuildContext context) {
    if (companionImage == null) {
      return const _GradientSphereFallback(
        child: Icon(Icons.pets_rounded, color: Colors.white, size: 48),
      );
    }

    return ClipOval(
      child: Image.asset(
        companionImage!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _GradientSphereFallback(
          child: Icon(Icons.pets_rounded, color: Colors.white, size: 48),
        ),
      ),
    );
  }
}

class _GradientSphereFallback extends StatelessWidget {
  final Widget child;

  const _GradientSphereFallback({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0xFFFFF3D6), Color(0xFFEAA6FF), Color(0xFFAA7CEB)],
          stops: [0.1, 0.6, 1.0],
        ),
      ),
      child: Center(child: child),
    );
  }
}

// Animated sparkle decoration
class _SparkleIcon extends StatefulWidget {
  const _SparkleIcon();

  @override
  State<_SparkleIcon> createState() => _SparkleIconState();
}

class _SparkleIconState extends State<_SparkleIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.4), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Icon(
              Icons.auto_awesome,
              color: const Color(0xFFFFD478),
              size: 16,
              shadows: const [
                Shadow(
                  color: Color(0x88FFD478),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PulsingCastSpellFrame extends StatefulWidget {
  final bool isReady;
  final Widget child;

  const _PulsingCastSpellFrame({
    required this.isReady,
    required this.child,
  });

  @override
  State<_PulsingCastSpellFrame> createState() => _PulsingCastSpellFrameState();
}

class _PulsingCastSpellFrameState extends State<_PulsingCastSpellFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _syncPulseState();
  }

  @override
  void didUpdateWidget(covariant _PulsingCastSpellFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isReady != widget.isReady) {
      _syncPulseState();
    }
  }

  void _syncPulseState() {
    if (widget.isReady) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glowStrength =
            widget.isReady ? (0.35 + (_pulse.value * 0.35)) : 0.2;
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: RadialGradient(
              colors: [
                Color.lerp(const Color(0xFFB565FF), const Color(0xFFFFD478),
                        _pulse.value)!
                    .withValues(alpha: glowStrength),
                Colors.transparent,
              ],
              stops: const [0.2, 1.0],
            ),
            boxShadow: widget.isReady
                ? [
                    BoxShadow(
                      color: Color.lerp(const Color(0xFF9E6CFF),
                              const Color(0xFFFFD478), _pulse.value)!
                          .withValues(alpha: 0.45),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _OrbParticleTrail extends StatefulWidget {
  final Color baseColor;

  const _OrbParticleTrail({required this.baseColor});

  @override
  State<_OrbParticleTrail> createState() => _OrbParticleTrailState();
}

class _OrbParticleTrailState extends State<_OrbParticleTrail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _OrbParticleTrailPainter(
            progress: _controller.value,
            baseColor: widget.baseColor,
          ),
        );
      },
    );
  }
}

class _OrbParticleTrailPainter extends CustomPainter {
  final double progress;
  final Color baseColor;

  _OrbParticleTrailPainter({
    required this.progress,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = (size.shortestSide / 2) - 20;
    const particleCount = 24;

    for (var i = 0; i < particleCount; i++) {
      final phase = ((i / particleCount) + progress) % 1.0;
      final angle = phase * 6.28318530718;
      final drift = 8 + (phase * 16);
      final opacity = (1.0 - phase).clamp(0.0, 1.0);
      final particleRadius = 1.4 + ((1.0 - phase) * 1.8);
      final x = center.dx + (ringRadius + drift) * cos(angle);
      final y = center.dy + (ringRadius + drift) * sin(angle);

      final paint = Paint()
        ..color = Color.lerp(baseColor, Colors.white, 0.5)!
            .withValues(alpha: 0.10 + (opacity * 0.45))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);

      canvas.drawCircle(Offset(x, y), particleRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbParticleTrailPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.baseColor != baseColor;
  }
}

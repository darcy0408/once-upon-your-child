import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' show cos, sin;
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/achievement_service.dart';
import 'package:story_weaver_app/story_result_screen.dart';
import 'package:story_weaver_app/pick_a_path_adventure_screen.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/theme/app_theme.dart';
import 'package:story_weaver_app/widgets/make_magic_button.dart';
import 'package:story_weaver_app/widgets/magic_orb.dart';
import 'package:story_weaver_app/widgets/magical_loading_view.dart';
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

  // Helper to get scenario image
  String get _scenarioImage {
    if (widget.wizardData.selectedScenario != null) {
      final scenario = ScenarioData.getById(widget.wizardData.selectedScenario!);
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
      final scenario = ScenarioData.getById(widget.wizardData.selectedScenario!);
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
            id: widget.wizardData.characterId ?? 'temp-${DateTime.now().millisecondsSinceEpoch}',
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

        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => StoryResultScreen(
                title: result.title ?? 'My Magical Story',
                storyText: result.storyText,
                wisdomGem: result.wisdomGem ?? 'You are magic!',
                characterName: requestData['characterName'] ?? widget.wizardData.characterName,
                theme: requestData['theme'],
                characterAge: requestData['age'],
                pages: result.pages,
                adventureSteps: result.adventureSteps,
                trackStoryCreation: true,
                trackAnalytics: true,
                achievementsService: AchievementService(),
                storyCreatedAt: DateTime.now(),
                isRhyming: widget.wizardData.rhymeTimeMode,
                isLearningToReadMode: widget.wizardData.learningToReadMode,
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
            action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: _launchStoryCreation),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _saveCharacterIfNeeded() async {
    try {
      final characterDetails = WizardDataMapper.mapToStoryRequest(widget.wizardData)['characterDetails'] as Map<String, dynamic>;
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
      case 'quick': return 'short';
      case 'epic': return 'long';
      default: return 'medium';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.wizardData;
    final screenWidth = MediaQuery.of(context).size.width;
    final orbSize = (screenWidth - 64).clamp(180.0, 250.0);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
        child: Column(
          children: [
            // 1. Crystal progress orbs
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _ProgressCrystal(icon: Icons.check_rounded),
                  SizedBox(width: 10),
                  _ProgressCrystal(icon: Icons.check_rounded),
                  SizedBox(width: 10),
                  _ProgressCrystal(icon: Icons.check_rounded),
                  SizedBox(width: 10),
                  _ProgressCrystal(icon: Icons.auto_awesome),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. Vision Orb + circular side avatars
            SizedBox(
              height: 290,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Enhanced outer aura with multiple layers
                  Container(
                    width: orbSize + 40,
                    height: orbSize + 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFEEA8).withValues(alpha: 0.35),
                          const Color(0xFFE985FF).withValues(alpha: 0.25),
                          const Color(0xFFB5F7FF).withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 0.7, 1.0],
                      ),
                    ),
                  ),
                  // Mid aura layer
                  Container(
                    width: orbSize + 20,
                    height: orbSize + 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFD9A6).withValues(alpha: 0.3),
                          const Color(0xFFF3AEFF).withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),

                  // Sparkle decorations around orb
                  ...List.generate(6, (index) {
                    final angle = (index * 60) * 3.14159 / 180;
                    final radius = (orbSize / 2) + 30;
                    return Positioned(
                      left: MediaQuery.of(context).size.width / 2 + (radius * cos(angle)) - 8,
                      top: 145 + (radius * sin(angle)) - 8,
                      child: _SparkleIcon(delay: index * 0.3),
                    );
                  }),

                  // Center crystal orb
                  MagicOrbWidget(
                    imagePath: _scenarioImage,
                    size: orbSize,
                    glowColor: AppColors.gold,
                    label: _scenarioLabel,
                  ),

                  // Hero avatar
                  Positioned(
                    left: 10,
                    bottom: 30,
                    child: _FloatingBubble(
                      delay: 0,
                      child: _AuraCircle(
                        size: 88,
                        auraColor: const Color(0xFFFFD9A6),
                        child: _HeroAvatar(generatedAvatar: data.generatedAvatar),
                      ),
                    ),
                  ),

                  // Companion avatar
                  if (data.selectedCompanions.isNotEmpty)
                    Positioned(
                      right: 10,
                      bottom: 30,
                      child: _FloatingBubble(
                        delay: 1.4,
                        child: _AuraCircle(
                          size: 88,
                          auraColor: const Color(0xFFF3AEFF),
                          child: _CompanionAvatar(
                            companionImage: _companionImage,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 3. Crystal mode orbs
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 12,
              children: [
                _CrystalModeOrb(
                  icon: Icons.auto_stories_rounded,
                  label: 'Tales',
                  isActive: data.includeIllustrations,
                  onTap: () => setState(() => data.includeIllustrations = !data.includeIllustrations),
                ),
                _CrystalModeOrb(
                  icon: Icons.music_note_rounded,
                  label: 'Rhyme',
                  isActive: data.rhymeTimeMode,
                  onTap: () => setState(() {
                    data.rhymeTimeMode = !data.rhymeTimeMode;
                    if (data.rhymeTimeMode) {
                      data.learningToReadMode = false;
                      data.interactiveMode = false;
                    }
                  }),
                ),
                _CrystalModeOrb(
                  icon: Icons.menu_book_rounded,
                  label: 'Spellbound Reading',
                  isActive: data.learningToReadMode,
                  onTap: () => setState(() {
                    data.learningToReadMode = !data.learningToReadMode;
                    if (data.learningToReadMode) {
                      data.rhymeTimeMode = false;
                      data.interactiveMode = false;
                    }
                  }),
                ),
                _CrystalModeOrb(
                  icon: Icons.alt_route_rounded,
                  label: 'Pick Your Path',
                  isActive: data.interactiveMode,
                  onTap: () => setState(() {
                    data.interactiveMode = !data.interactiveMode;
                    if (data.interactiveMode) {
                      data.rhymeTimeMode = false;
                      data.learningToReadMode = false;
                    }
                  }),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // 4. Floating story-length crystals (fixed responsive layout)
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: _LengthCrystal(
                        label: 'Quick',
                        val: 'quick',
                        current: data.storyLength,
                        onTap: (v) => setState(() => data.storyLength = v),
                        crystalColors: const [Color(0xFF8EEDFF), Color(0xFFB5F7FF), Color(0xFFE8FEFF)],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: _LengthCrystal(
                        label: 'Classic',
                        val: 'standard',
                        current: data.storyLength,
                        onTap: (v) => setState(() => data.storyLength = v),
                        crystalColors: const [Color(0xFFFFD65C), Color(0xFFFFEBA5), Color(0xFFFFF7D6)],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: _LengthCrystal(
                        label: 'Epic',
                        val: 'epic',
                        current: data.storyLength,
                        onTap: (v) => setState(() => data.storyLength = v),
                        crystalColors: const [Color(0xFF9E6CFF), Color(0xFFCBB1FF), Color(0xFFE5DAFF)],
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
                  onChanged: (value) => setState(() => data.customElements = value),
                  decoration: InputDecoration(
                    hintText: 'Whisper a wish to the orb...\n(e.g., "I want to ride a giant eagle")',
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
                  child: Icon(Icons.auto_awesome, color: AppColors.gold, size: 20),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),

            // 6. Cast Spell Button
            Center(
              child: _isGenerating
                  ? MagicalLoadingView(
                      status: _loadingStatus,
                      onCancel: () => setState(() => _isGenerating = false),
                    )
                  : MakeMagicButton(
                      onTap: _launchStoryCreation,
                      isEnabled: !_isGenerating && data.isComplete,
                      label: 'Make Magic ✨', // Thematic label
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

class _FloatingBubbleState extends State<_FloatingBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    // Add delay by starting at different value if needed, or using a listener
    // Simple offset logic:
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) _controller.forward(); 
    });

    _animation = Tween<double>(begin: -5.0, end: 5.0).animate(
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

class _ProgressCrystal extends StatelessWidget {
  final IconData icon;

  const _ProgressCrystal({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Outer magical aura
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFA65BFF).withValues(alpha: 0.6),
                    const Color(0xFFE8A4FF).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Crystal ball with depth
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.3, -0.4),
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFF5E8FF),
                    Color(0xFFD5B8FF),
                    Color(0xFF9E75E0),
                    Color(0xFF6A3AA9),
                  ],
                  stops: [0.0, 0.15, 0.4, 0.75, 1.0],
                ),
                border: Border.all(
                  color: const Color(0xFFFFE8F0).withValues(alpha: 0.8),
                  width: 2.2,
                ),
                boxShadow: const [
                  // Bright highlight
                  BoxShadow(
                    color: Color(0xDDFFFFFF),
                    blurRadius: 12,
                    spreadRadius: -6,
                    offset: Offset(-2, -4),
                  ),
                  // Purple glow
                  BoxShadow(
                    color: Color(0x99A65BFF),
                    blurRadius: 22,
                    spreadRadius: 3,
                  ),
                  // Gold shimmer
                  BoxShadow(
                    color: Color(0x77FFD878),
                    blurRadius: 16,
                    spreadRadius: -1,
                  ),
                  // Depth shadow
                  BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 24,
                color: Colors.white,
                shadows: const [
                  Shadow(color: Color(0x66000000), blurRadius: 4),
                ],
              ),
            ),
          ],
        ),
        // Crystal ball stand/base
        const SizedBox(height: 2),
        Container(
          width: 38,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF8B7BA8),
                Color(0xFF5D4A7A),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
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
        // Outer magical glow
        Container(
          width: size + 24,
          height: size + 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                auraColor.withValues(alpha: 0.5),
                auraColor.withValues(alpha: 0.25),
                Colors.transparent,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        ),
        // Main avatar container with enhanced glow
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              // Bright inner glow
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.6),
                blurRadius: 12,
                spreadRadius: -2,
              ),
              // Main aura glow
              BoxShadow(
                color: auraColor.withValues(alpha: 0.7),
                blurRadius: 32,
                spreadRadius: 3,
              ),
              // Secondary gold glow
              BoxShadow(
                color: const Color(0xFFFFE4B8).withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: -2,
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  final GeneratedAvatar? generatedAvatar;

  const _HeroAvatar({required this.generatedAvatar});

  @override
  Widget build(BuildContext context) {
    if (generatedAvatar == null) {
      return const _GradientSphereFallback(
        child: Icon(Icons.face_rounded, color: Colors.white, size: 32),
      );
    }

    final imageData = generatedAvatar!.imageBase64;
    final isUrl = imageData.startsWith('http://') || imageData.startsWith('https://');
    final isAsset = imageData.startsWith('assets/');

    return ClipOval(
      child: isAsset
          ? Image.asset(
              imageData,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _GradientSphereFallback(
                child: Icon(Icons.face_rounded, color: Colors.white, size: 32),
              ),
            )
          : isUrl
              ? Image.network(
                  imageData,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _GradientSphereFallback(
                    child: Icon(Icons.face_rounded, color: Colors.white, size: 32),
                  ),
                )
              : Image.memory(
                  base64Decode(imageData.split(',').last),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _GradientSphereFallback(
                    child: Icon(Icons.face_rounded, color: Colors.white, size: 32),
                  ),
                ),
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
        child: Icon(Icons.pets_rounded, color: Colors.white, size: 30),
      );
    }

    return ClipOval(
      child: Image.asset(
        companionImage!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _GradientSphereFallback(
          child: Icon(Icons.pets_rounded, color: Colors.white, size: 30),
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

class _CrystalModeOrb extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _CrystalModeOrb({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const inactiveText = Color(0xFF2F2748);
    final activeGlow = const Color(0xFFE28EFF);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 220),
              scale: isActive ? 1.12 : 1.0,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow aura for active state
                  if (isActive)
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            activeGlow.withValues(alpha: 0.4),
                            activeGlow.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                  // Main crystal orb
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: isActive
                            ? [
                                const Color(0xFFFFFFFF),
                                const Color(0xFFE8DAFF),
                                const Color(0xFFA884FF),
                                const Color(0xFF7A5CC8),
                              ]
                            : [
                                const Color(0xFFF8F4FF),
                                const Color(0xFFD4C8F0),
                                const Color(0xFF9E8DD8),
                                const Color(0xFF7565A8),
                              ],
                        stops: const [0.0, 0.3, 0.7, 1.0],
                      ),
                      border: Border.all(
                        color: isActive ? const Color(0xFFFFE8A0) : const Color(0xFFE0D4FF),
                        width: isActive ? 2.5 : 1.5,
                      ),
                      boxShadow: [
                        // Inner glow
                        BoxShadow(
                          color: Colors.white.withValues(alpha: isActive ? 0.6 : 0.3),
                          blurRadius: isActive ? 20 : 10,
                          spreadRadius: isActive ? -4 : -6,
                        ),
                        // Main glow
                        BoxShadow(
                          color: (isActive ? activeGlow : const Color(0xFF9D8CEB)).withValues(alpha: 0.7),
                          blurRadius: isActive ? 28 : 16,
                          spreadRadius: isActive ? 4 : 1,
                        ),
                        // Gold accent glow for active
                        if (isActive)
                          BoxShadow(
                            color: const Color(0xFFFFD478).withValues(alpha: 0.5),
                            blurRadius: 22,
                            spreadRadius: -2,
                          ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: isActive ? Colors.white : inactiveText,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                height: 1.1,
                color: const Color(0xFF2D2148),
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                shadows: isActive
                    ? [
                        const Shadow(
                          color: Color(0x33E28EFF),
                          blurRadius: 4,
                        )
                      ]
                    : null,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _LengthCrystal extends StatelessWidget {
  final String label;
  final String val;
  final String current;
  final Function(String) onTap;
  final List<Color> crystalColors;

  const _LengthCrystal({
    required this.label,
    required this.val,
    required this.current,
    required this.onTap,
    required this.crystalColors,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = val == current;
    // Responsive sizing based on available space
    final screenWidth = MediaQuery.of(context).size.width;
    final crystalWidth = (screenWidth / 3.5).clamp(85.0, 100.0);
    final crystalHeight = (crystalWidth * 0.82).clamp(70.0, 82.0);

    return GestureDetector(
      onTap: () => onTap(val),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 250),
        scale: isSelected ? 1.12 : 1.0,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer magical glow aura
            if (isSelected)
              Container(
                width: crystalWidth + 15,
                height: crystalHeight + 13,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  gradient: RadialGradient(
                    colors: [
                      crystalColors[0].withValues(alpha: 0.5),
                      crystalColors[0].withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            // Main crystal gemstone
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: crystalWidth,
              height: crystalHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: isSelected ? 0.95 : 0.85),
                    crystalColors[0].withValues(alpha: 0.9),
                    crystalColors[0],
                    crystalColors[1],
                    crystalColors[2],
                  ],
                  stops: const [0.0, 0.15, 0.35, 0.7, 1.0],
                ),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: isSelected ? Colors.white.withValues(alpha: 0.9) : crystalColors[2].withValues(alpha: 0.7),
                  width: isSelected ? 3.0 : 1.8,
                ),
                boxShadow: [
                  // Bright inner highlight for glass effect
                  BoxShadow(
                    color: Colors.white.withValues(alpha: isSelected ? 0.9 : 0.6),
                    blurRadius: isSelected ? 18 : 10,
                    spreadRadius: isSelected ? -6 : -8,
                    offset: const Offset(-2, -6),
                  ),
                  // Main crystal glow
                  BoxShadow(
                    color: crystalColors[0].withValues(alpha: isSelected ? 0.85 : 0.5),
                    blurRadius: isSelected ? 35 : 16,
                    spreadRadius: isSelected ? 8 : 2,
                  ),
                  // Mid-tone glow
                  BoxShadow(
                    color: crystalColors[1].withValues(alpha: isSelected ? 0.7 : 0.4),
                    blurRadius: isSelected ? 24 : 12,
                    spreadRadius: isSelected ? 2 : 0,
                  ),
                  // Deep shadow for depth
                  BoxShadow(
                    color: crystalColors[2].withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Multiple facet shine effects for gem-like appearance
                  Positioned(
                    top: crystalHeight * 0.12,
                    left: crystalWidth * 0.18,
                    child: Container(
                      width: crystalWidth * 0.35,
                      height: crystalHeight * 0.28,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: isSelected ? 0.85 : 0.6),
                            Colors.white.withValues(alpha: isSelected ? 0.4 : 0.2),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  // Secondary sparkle highlight
                  if (isSelected)
                    Positioned(
                      top: crystalHeight * 0.25,
                      right: crystalWidth * 0.22,
                      child: Container(
                        width: crystalWidth * 0.15,
                        height: crystalHeight * 0.15,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.9),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Label text
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF2A2040),
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                      fontSize: 19,
                      shadows: isSelected
                          ? const [
                              Shadow(
                                color: Color(0x88FFFFFF),
                                blurRadius: 12,
                              ),
                              Shadow(
                                color: Color(0x44FFFFFF),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ]
                          : [
                              const Shadow(
                                color: Color(0x33FFFFFF),
                                blurRadius: 4,
                              ),
                            ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Animated sparkle decoration
class _SparkleIcon extends StatefulWidget {
  final double delay;

  const _SparkleIcon({this.delay = 0});

  @override
  State<_SparkleIcon> createState() => _SparkleIconState();
}

class _SparkleIconState extends State<_SparkleIcon> with SingleTickerProviderStateMixin {
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

    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) {
        _controller.repeat();
      }
    });
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

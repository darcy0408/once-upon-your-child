import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:io';
import 'package:story_weaver_app/services/feelings_ambient_service.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/achievement_service.dart';
import 'package:story_weaver_app/story_result_screen.dart';
import 'package:story_weaver_app/story_illustration_service.dart';
import 'package:story_weaver_app/pick_a_path_adventure_screen.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/theme/app_theme.dart';
import 'package:story_weaver_app/widgets/magic_orb.dart';
import 'package:story_weaver_app/widgets/magical_loading_view.dart';
import 'package:story_weaver_app/widgets/image_make_magic_button.dart';
import 'package:story_weaver_app/data/scenario_data.dart';
import 'package:story_weaver_app/data/companion_data.dart';
import 'package:story_weaver_app/widgets/magical_float.dart';
import 'package:story_weaver_app/providers/subscription_provider.dart';
import 'package:story_weaver_app/subscription_models.dart';
import 'wizard_data_mapper.dart';
import '../../widgets/magic_ear_button.dart';

/// Step 4: Magic Review & Launch
/// Updated with audio prompts and consistent magical typography.
class MagicReviewStep extends ConsumerStatefulWidget {
  final WizardData wizardData;
  final VoidCallback? onGoBack;
  const MagicReviewStep({super.key, required this.wizardData, this.onGoBack});
  @override
  ConsumerState<MagicReviewStep> createState() => _MagicReviewStepState();
}

class _MagicReviewStepState extends ConsumerState<MagicReviewStep> {
  bool _isGenerating = false;
  late String _loadingStatus;
  final StoryIllustrationService _illustrationService =
      StoryIllustrationService();
  @override
  void initState() {
    super.initState();
    if (widget.wizardData.characterAge >= 10) {
      _loadingStatus = 'Your adventure is being written...';
    } else if (widget.wizardData.characterAge >= 7) {
      _loadingStatus = 'Your story is coming to life!';
    } else {
      _loadingStatus = 'Making your story! 🌟';
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  String get _scenarioImage {
    if (widget.wizardData.selectedScenario != null) {
      final scenario =
          ScenarioData.getById(widget.wizardData.selectedScenario!);
      if (scenario != null) {
        return scenario.illustration.startsWith('assets/')
            ? scenario.illustration
            : 'assets/${scenario.illustration}';
      }
    }
    return 'assets/images/scenarios/magic_door.png';
  }

  String? get _companionImage {
    if (widget.wizardData.selectedCompanions.isNotEmpty) {
      final firstComp = widget.wizardData.selectedCompanions.first;
      try {
        final magicComp = magicCompanions.firstWhere((c) => c.id == firstComp);
        return 'assets/images/companions/${magicComp.id}.jpg';
      } catch (_) {
        // If it's a custom companion/photo (e.g. my_pet), fall through.
      }
    }
    if (widget.wizardData.companionNames.isNotEmpty &&
        widget.wizardData.petPhotos.isNotEmpty) {
      final petName = widget.wizardData.companionNames.firstWhere(
        (name) => widget.wizardData.petPhotos.containsKey(name),
        orElse: () => '',
      );
      if (petName.isNotEmpty) {
        return widget.wizardData.petPhotos[petName];
      }
    }
    return null;
  }

  String get _scenarioLabel => widget.wizardData.selectedScenario != null
      ? (ScenarioData.getById(widget.wizardData.selectedScenario!)?.title ??
          'Magical Adventure')
      : 'Magical Adventure';

  void _launchStoryCreation() async {
    if (!widget.wizardData.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please complete all steps first!'),
          backgroundColor: AppColors.warning));
      return;
    }
    if (!mounted) return;
    // Silently check for a recent feelings journal entry (last 24 h) BEFORE showing the loader
    final currentFeeling = await FeelingsAmbientService.getRecentFeeling();

    // Get subscription status and BYOK status
    final subState = ref.read(subscriptionProvider);
    final isPremium = subState.tier == 'premium' || subState.tier == 'family';
    final subscription = UserSubscription(
      tier: subState.tier == 'premium'
          ? SubscriptionTier.premium
          : (subState.tier == 'family'
              ? SubscriptionTier.family
              : SubscriptionTier.free),
      isActive: subState.status == 'active',
    );
    final isUsingOwnKey = await ApiServiceManager.isUsingOwnApiKey();
    final canGetIllustrations = isPremium || isUsingOwnKey;

    setState(() => _isGenerating = true);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    try {
      await _saveCharacterIfNeeded();
      final requestData = WizardDataMapper.mapToStoryRequest(widget.wizardData);
      if (currentFeeling != null) {
        requestData['currentFeeling'] = currentFeeling.toJson();
      }
      if (widget.wizardData.interactiveMode) {
        if (mounted) {
          final character = Character(
              id: widget.wizardData.characterId ??
                  'temp-${DateTime.now().millisecondsSinceEpoch}',
              name: widget.wizardData.characterName,
              age: widget.wizardData.characterAge,
              role: widget.wizardData.selectedArchetypeId ?? 'Adventurer',
              gender: widget.wizardData.characterGender,
              personalitySliders: widget.wizardData.personalitySliders);
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => PickAPathAdventureScreen(
                      userId: 'guest',
                      character: character,
                      theme: requestData['theme'] ?? 'Adventure',
                      tone: 'whimsical',
                      length: _mapStoryLength(widget.wizardData.storyLength),
                      interests:
                          widget.wizardData.selectedEmotionChips.isNotEmpty
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
                      bigFeelingsContext: {
                        if (requestData['currentFeeling'] != null)
                          'current_feeling': requestData['currentFeeling'],
                        if (requestData['feelingTrigger'] != null)
                          'trigger': requestData['feelingTrigger'],
                        if (requestData['bodySignal'] != null)
                          'body_signal': requestData['bodySignal'],
                        if (requestData['copingTool'] != null)
                          'coping_tool': requestData['copingTool'],
                        if (requestData['repairGoal'] != null)
                          'repair_goal': requestData['repairGoal'],
                        if (requestData['parentHiddenContext'] != null)
                          'parent_hidden_context':
                              requestData['parentHiddenContext'],
                      })));
        }
      } else {
        // Only request illustrations from backend if user is premium/BYOK
        final shouldRequestIllustrations =
            widget.wizardData.includeIllustrations && canGetIllustrations;

        final result = await ApiServiceManager.generateStory(
            characterName: requestData['character'] ?? 'Hero',
            age: requestData['age'] ?? 5,
            theme: requestData['theme'] ?? 'Magical Adventure',
            companion: requestData['companion'] ?? '',
            characterDetails: requestData['characterDetails'],
            currentFeeling: requestData['currentFeeling'],
            feelingTrigger: requestData['feelingTrigger'],
            bodySignal: requestData['bodySignal'],
            copingTool: requestData['copingTool'],
            repairGoal: requestData['repairGoal'],
            parentHiddenContext: requestData['parentHiddenContext'],
            additionalCharacters: requestData['additionalCharacters'],
            includeIllustrations: shouldRequestIllustrations,
            rhymeTimeMode: widget.wizardData.rhymeTimeMode,
            learningToReadMode: widget.wizardData.learningToReadMode,
            companionPets: requestData['companion_pets'],
            companionCharacters: requestData['companion_characters'],
            storyLength: requestData['storyLength'] ?? 'standard',
            customElements: requestData['customElements'] ?? '',
            subscriptionTier: subscription.tier.name,
            onProgress: (status) {
              if (mounted) {
                setState(() => _loadingStatus = status);
              }
            });

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
        // Only try to generate inline illustrations if user is premium/BYOK
        if (widget.wizardData.includeIllustrations &&
            canGetIllustrations &&
            inlineIllustrations.isEmpty) {
          if (mounted) {
            setState(
                () => _loadingStatus = 'Painting magical illustrations...');
          }
          inlineIllustrations = await _generateInlineIllustrations(
              storyText: result.storyText,
              storyTitle: result.title ?? 'My Magical Story',
              requestData: requestData);
        }

        if (mounted) {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => StoryResultScreen(
                  title: result.title ?? 'My Magical Story',
                  storyText: result.storyText,
                  wisdomGem: result.wisdomGem ?? 'You are magic!',
                  characterName: widget.wizardData.characterName,
                  theme: widget.wizardData.selectedScenario != null
                      ? ScenarioData.getById(
                              widget.wizardData.selectedScenario!)
                          ?.title
                      : 'Adventure',
                  characterAge:
                      requestData['age'] ?? widget.wizardData.characterAge,
                  characterId: widget.wizardData.characterId,
                  isInteractive: false,
                  isRhyming: widget.wizardData.rhymeTimeMode,
                  isLearningToReadMode: widget.wizardData.learningToReadMode,
                  achievementsService: AchievementService(),
                  storyCreatedAt: DateTime.now(),
                  trackStoryCreation: true,
                  backendIllustrations: inlineIllustrations,
                  subscription: subscription,
                  asyncIllustrations: result.asyncIllustrations,
                  pages: result.pages,
                  adventureSteps: result.adventureSteps,
                  storyLengthHint: requestData['storyLength']?.toString() ??
                      widget.wizardData.storyLength,
                  companionAvatars: widget.wizardData.petAvatars)));
          if (mounted) {
            setState(() => _isGenerating = false);
          }
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
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$userMessage\nTry again?'),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _launchStoryCreation)));
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _generateInlineIllustrations(
      {required String storyText,
      required String storyTitle,
      required Map<String, dynamic> requestData}) async {
    try {
      final generated = await _illustrationService.generateIllustrations(
          storyText: storyText,
          storyTitle: storyTitle,
          characterName: requestData['character']?.toString() ??
              widget.wizardData.characterName,
          theme: requestData['theme']?.toString(),
          numberOfImages: 1,
          age: requestData['age'] as int? ?? widget.wizardData.characterAge,
          characterAppearance:
              requestData['characterDetails'] as Map<String, dynamic>?);
      return generated
          .map((illustration) {
            final url = illustration.imageUrl;
            if (url.startsWith('data:image/') && url.contains(',')) {
              final commaIndex = url.indexOf(',');
              if (commaIndex < 0 || commaIndex + 1 >= url.length) return null;
              return {
                'id': illustration.id,
                'prompt': illustration.prompt,
                'image_data': url.substring(commaIndex + 1)
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
          'avatar_data': widget.wizardData.generatedAvatar!.toJson()
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

  String _mapStoryLength(String wizardLength) => wizardLength == 'quick'
      ? 'short'
      : (wizardLength == 'epic' ? 'long' : 'medium');

  String _storyTypeLabel(WizardData data, AgeBandThemeData band) {
    if (data.interactiveMode) {
      return band.band == AgeBand.sprout
          ? 'Pick a Path'
          : 'Pick a Path adventure';
    }
    if (data.rhymeTimeMode) {
      if (data.characterAge >= 11) {
        return 'Poetry';
      }
      return band.band == AgeBand.sprout ? 'Rhyme story' : 'Rhyme Time story';
    }
    if (data.learningToReadMode) {
      switch (band.band) {
        case AgeBand.sprout:
          return 'Easy reader';
        case AgeBand.explorer:
        case AgeBand.adventurer:
          return 'Limerick Laughs story';
        case AgeBand.creator:
          return 'First Chapter';
      }
    }
    if (data.includeIllustrations) {
      return band.band == AgeBand.creator
          ? 'Illustrated story'
          : 'Picture tale';
    }
    return band.band == AgeBand.creator ? 'Story draft' : 'Magical story';
  }

  String _storyLengthLabel(String length) {
    switch (length) {
      case 'quick':
        return 'Quick read';
      case 'epic':
        return 'Epic adventure';
      default:
        return 'Classic length';
    }
  }

  String _buildReviewSpokenText() {
    final wd = widget.wizardData;
    final hero = wd.characterName.isEmpty ? 'your hero' : wd.characterName;
    final scenario = wd.selectedScenario ?? 'a magical place';
    final companions = wd.companionNames.isEmpty
        ? 'no companions yet'
        : wd.companionNames.join(' and ');
    return 'Here is your story recipe! $hero is adventuring in $scenario with $companions. Check everything looks right, then tap Make Magic to start!';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.wizardData;
    final screenWidth = MediaQuery.of(context).size.width;
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final orbSize =
        (screenWidth - band.space(64)).clamp(180.0, 220.0).toDouble();
    final heroFallback = band.heroLabel;
    final sideCircleSize = band.touchTarget(88).clamp(72.0, 112.0).toDouble();
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: band.space(AppSpacing.lg),
            vertical: band.space(AppSpacing.xl)),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MagicEarButton(
                  spokenText: _buildReviewSpokenText(),
                  size: 32,
                ),
                const SizedBox(width: 8),
                Text(
                  band.band == AgeBand.creator
                      ? "Review Your Story Brief"
                      : band.band == AgeBand.adventurer
                          ? "Review Your Adventure"
                          : "Your Adventure Awaits!",
                  textAlign: TextAlign.center,
                  style: (band.band == AgeBand.creator)
                      ? GoogleFonts.sourceSans3(
                          color: const Color(0xFFFFD700),
                          fontSize: band.heading(22),
                          fontWeight: FontWeight.bold,
                        )
                      : (band.band == AgeBand.adventurer)
                          ? GoogleFonts.bitter(
                              color: const Color(0xFFFFD700),
                              fontSize: band.heading(22),
                              fontWeight: FontWeight.bold,
                            )
                          : GoogleFonts.cinzelDecorative(
                              color: const Color(0xFFFFD700),
                              fontSize: band.heading(22),
                              fontWeight: FontWeight.bold,
                            ),
                ),
              ],
            ),
            SizedBox(height: band.space(24)),
            // ── Hero orb (avatar only, no overlapping circles) ───────────────
            SizedBox(
              height: orbSize + 50,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: orbSize + 50,
                  height: orbSize + 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFFFFEEA8).withValues(alpha: 0.45),
                      const Color(0xFFE985FF).withValues(alpha: 0.3),
                      const Color(0xFFB5F7FF).withValues(alpha: 0.2),
                      Colors.transparent,
                    ], stops: const [
                      0.0,
                      0.4,
                      0.7,
                      1.0
                    ]),
                  ),
                ),
                MagicOrbWidget(
                  imagePath: _scenarioImage,
                  size: orbSize * 0.95,
                  glowColor: AppColors.gold,
                  topLabel: _scenarioLabel,
                  label: data.characterName.isNotEmpty
                      ? data.characterName
                      : heroFallback,
                  childScale: 0.92,
                  child: _HeroAvatar(
                    generatedAvatar: data.generatedAvatar,
                    characterName: data.characterName,
                    role: data.selectedArchetypeId,
                  ),
                ),
              ]),
            ),
            SizedBox(height: band.space(8)),
            if (data.characterName.isNotEmpty) ...[
              Text(
                data.characterName,
                style: (band.band == AgeBand.creator)
                    ? GoogleFonts.sourceSans3(
                        color: const Color(0xFFFFD700),
                        fontSize: band.heading(16),
                        fontWeight: FontWeight.bold,
                      )
                    : (band.band == AgeBand.adventurer)
                        ? GoogleFonts.bitter(
                            color: const Color(0xFFFFD700),
                            fontSize: band.heading(16),
                            fontWeight: FontWeight.bold,
                          )
                        : GoogleFonts.cinzelDecorative(
                            color: const Color(0xFFFFD700),
                            fontSize: band.heading(16),
                            fontWeight: FontWeight.bold,
                          ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: band.space(12)),
            ],
            // ── Setting + companion — below the orb so nothing overlaps ──────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Setting
                Flexible(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    MagicalFloat(
                      distance: 6.0,
                      duration: const Duration(seconds: 4),
                      delay: 100,
                      child: _AuraCircle(
                        size: sideCircleSize,
                        auraColor: const Color(0xFFFFD9A6),
                        child: ClipOval(
                            child:
                                Image.asset(_scenarioImage, fit: BoxFit.cover)),
                      ),
                    ),
                    SizedBox(height: band.space(6)),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: band.space(10), vertical: band.space(4)),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1),
                      ),
                      child: Text(_scenarioLabel,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: band.body(12),
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
                // Companion (only if selected)
                if (data.selectedCompanions.isNotEmpty) ...[
                  SizedBox(width: band.space(24)),
                  Flexible(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      MagicalFloat(
                        distance: 6.0,
                        duration: const Duration(seconds: 4),
                        delay: 500,
                        child: _AuraCircle(
                          size: sideCircleSize,
                          auraColor: const Color(0xFFF3AEFF),
                          child:
                              _CompanionAvatar(companionImage: _companionImage),
                        ),
                      ),
                      SizedBox(height: band.space(6)),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: band.space(10),
                            vertical: band.space(4)),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          data.companionNames.isNotEmpty
                              ? data.companionNames.first
                              : 'Companion',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: band.body(12),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
            SizedBox(height: band.space(24)),
            // ── Read-only story summary ──────────────────────────────────────
            _StaggeredReveal(
                index: 0,
                child: _SummaryRow(
                    icon: Icons.auto_stories,
                    label: _storyTypeLabel(data, band),
                    band: band,
                    onTap: widget.onGoBack,
                    colorAccent: const Color(0xFF9C4DCC))),
            SizedBox(height: band.space(8)),
            _StaggeredReveal(
                index: 1,
                child: _SummaryRow(
                    icon: Icons.timer,
                    band: band,
                    label: _storyLengthLabel(data.storyLength),
                    onTap: widget.onGoBack,
                    colorAccent: const Color(0xFF4DB6AC))),
            if (data.customElements.isNotEmpty) ...[
              SizedBox(height: band.space(8)),
              _StaggeredReveal(
                  index: 2,
                  child: _SummaryRow(
                      icon: Icons.auto_awesome,
                      band: band,
                      label: '"${data.customElements}"',
                      onTap: widget.onGoBack,
                      colorAccent: const Color(0xFFFFD54F),
                      isShimmering: true)),
            ],
            if (data.companionNames.isNotEmpty) ...[
              SizedBox(height: band.space(8)),
              _StaggeredReveal(
                  index: 3,
                  child: _SummaryRow(
                    icon: Icons.favorite,
                    band: band,
                    label: data.companionNames.join(', '),
                    onTap: widget.onGoBack,
                    colorAccent: const Color(0xFFF06292),
                    leadingAvatar:
                        _CompanionAvatar(companionImage: _companionImage),
                  )),
            ],
            SizedBox(height: band.space(AppSpacing.xxl)),
            Center(
                child: _isGenerating
                    ? MagicalLoadingView(
                        status: _loadingStatus,
                        onCancel: () => setState(() => _isGenerating = false))
                    : _PulsingCastSpellFrame(
                        isReady: !_isGenerating && data.isComplete,
                        child: ImageMakeMagicButton(
                            onTap: _launchStoryCreation,
                            isEnabled: !_isGenerating && data.isComplete,
                            label: band.band == AgeBand.creator
                                ? 'CREATE STORY'
                                : band.band == AgeBand.adventurer
                                    ? 'START ADVENTURE'
                                    : 'MAKE MAGIC'))),
            SizedBox(height: band.space(AppSpacing.xl)),
          ],
        ),
      ),
    );
  }
}

class _AuraCircle extends StatelessWidget {
  final double size;
  final Color auraColor;
  final Widget child;
  const _AuraCircle(
      {required this.size, required this.auraColor, required this.child});
  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      Container(
          width: size + 50,
          height: size + 50,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                auraColor.withValues(alpha: 0.4),
                auraColor.withValues(alpha: 0.2),
                Colors.transparent
              ], stops: const [
                0.0,
                0.5,
                1.0
              ]))),
      Container(
          width: size + 32,
          height: size + 32,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                auraColor.withValues(alpha: 0.7),
                auraColor.withValues(alpha: 0.4),
                auraColor.withValues(alpha: 0.2),
                Colors.transparent
              ], stops: const [
                0.0,
                0.4,
                0.7,
                1.0
              ]))),
      Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
            BoxShadow(
                color: Colors.white.withValues(alpha: 0.8),
                blurRadius: 16,
                spreadRadius: -2),
            BoxShadow(
                color: auraColor.withValues(alpha: 0.9),
                blurRadius: 50,
                spreadRadius: 6),
            BoxShadow(
                color: const Color(0xFFFFE4B8).withValues(alpha: 0.7),
                blurRadius: 30,
                spreadRadius: 2),
            BoxShadow(
                color: Colors.white.withValues(alpha: 0.4),
                blurRadius: 60,
                spreadRadius: 10)
          ]),
          child: child),
    ]);
  }
}

class _HeroAvatar extends StatelessWidget {
  final GeneratedAvatar? generatedAvatar;
  final String characterName;
  final String? role;
  const _HeroAvatar(
      {required this.generatedAvatar,
      required this.characterName,
      required this.role});
  @override
  Widget build(BuildContext context) {
    if (generatedAvatar == null) {
      return _GradientSphereFallback(
          child: _HeroFallbackIdentity(name: characterName, role: role));
    }
    final data = generatedAvatar!.imageBase64;
    Widget img;
    if (data.startsWith('assets/')) {
      img = Image.asset(data, fit: BoxFit.cover);
    } else if (data.startsWith('http')) {
      img = Image.network(data, fit: BoxFit.cover);
    } else {
      try {
        img =
            Image.memory(base64Decode(data.split(',').last), fit: BoxFit.cover);
      } catch (_) {
        return _GradientSphereFallback(
            child: _HeroFallbackIdentity(name: characterName, role: role));
      }
    }
    // Crystal-ball glow: brighten the image + add a white radial highlight
    return ClipOval(
      child: Stack(fit: StackFit.expand, children: [
        ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            1.15,
            0,
            0,
            0,
            15,
            0,
            1.15,
            0,
            0,
            15,
            0,
            0,
            1.15,
            0,
            15,
            0,
            0,
            0,
            1,
            0,
          ]),
          child: img,
        ),
        // Radial white glow from the centre — like light through a crystal
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withAlpha(55),
                Colors.white.withAlpha(20),
                Colors.transparent,
              ],
              stops: const [0.0, 0.45, 0.9],
            ),
          ),
        ),
      ]),
    );
  }
}

class _HeroFallbackIdentity extends StatelessWidget {
  final String name;
  final String? role;
  const _HeroFallbackIdentity({required this.name, required this.role});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(
          role?.toLowerCase().contains('artist') == true
              ? Icons.palette
              : (role?.toLowerCase().contains('athlete') == true
                  ? Icons.bolt
                  : Icons.face),
          color: Colors.white,
          size: 42),
      const SizedBox(height: 8),
      Text(name.isNotEmpty ? name[0].toUpperCase() : 'H',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
    ]);
  }
}

class _CompanionAvatar extends StatelessWidget {
  final String? companionImage;
  const _CompanionAvatar({required this.companionImage});
  @override
  Widget build(BuildContext context) {
    if (companionImage == null) {
      return const _GradientSphereFallback(
          child: Icon(Icons.pets, color: Colors.white, size: 48));
    }
    if (companionImage!.startsWith('assets/')) {
      return ClipOval(
        clipBehavior: Clip.antiAlias,
        child: Image.asset(companionImage!, fit: BoxFit.cover),
      );
    }
    if (companionImage!.startsWith('http')) {
      return ClipOval(
        clipBehavior: Clip.antiAlias,
        child: Image.network(companionImage!, fit: BoxFit.cover),
      );
    }
    try {
      final normalized = companionImage!.contains(',')
          ? companionImage!.split(',').last
          : companionImage!;
      return ClipOval(
        clipBehavior: Clip.antiAlias,
        child: Image.memory(base64Decode(normalized), fit: BoxFit.cover),
      );
    } catch (_) {
      return const _GradientSphereFallback(
          child: Icon(Icons.pets, color: Colors.white, size: 48));
    }
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
            gradient: RadialGradient(colors: [
              Color(0xFFFFF3D6),
              Color(0xFFEAA6FF),
              Color(0xFFAA7CEB)
            ], stops: [
              0.1,
              0.6,
              1.0
            ])),
        child: Center(child: child));
  }
}

class _PulsingCastSpellFrame extends StatefulWidget {
  final bool isReady;
  final Widget child;
  const _PulsingCastSpellFrame({required this.isReady, required this.child});
  @override
  State<_PulsingCastSpellFrame> createState() => _PulsingCastSpellFrameState();
}

class _PulsingCastSpellFrameState extends State<_PulsingCastSpellFrame>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    if (widget.isReady) _ctrl.repeat(reverse: true);
  }

  @override
  didUpdateWidget(old) {
    super.didUpdateWidget(old);
    if (widget.isReady != old.isReady) {
      if (widget.isReady) {
        _ctrl.repeat(reverse: true);
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, child) =>
            Padding(padding: const EdgeInsets.all(8), child: child),
        child: widget.child);
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final AgeBandThemeData band;
  final VoidCallback? onTap;
  final Color? colorAccent;
  final Widget? leadingAvatar;
  final bool isShimmering;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.band,
    this.onTap,
    this.colorAccent,
    this.leadingAvatar,
    this.isShimmering = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Semantics(
        button: true,
        label: 'Summary item: $label. Double tap to go back and edit.',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(band.radiusMd),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: band.space(16),
                vertical: band.space(14),
              ),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(35),
                borderRadius: BorderRadius.circular(band.radiusMd),
                border:
                    Border.all(color: const Color(0xFFD4A0FF).withAlpha(80)),
              ),
              child: Row(
                children: [
                  // Left accent bar
                  if (colorAccent != null)
                    Container(
                      width: band.space(4),
                      height: band.touchTarget(24),
                      margin: EdgeInsets.only(right: band.space(12)),
                      decoration: BoxDecoration(
                        color: colorAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                  // Leading Avatar or Icon
                  if (leadingAvatar != null) ...[
                    SizedBox(
                      width: band.touchTarget(32),
                      height: band.touchTarget(32),
                      child: leadingAvatar!,
                    ),
                    SizedBox(width: band.space(12)),
                  ] else ...[
                    Icon(
                      icon,
                      color: const Color(0xFFFFD700),
                      size: band.body(24),
                    ),
                    SizedBox(width: band.space(12)),
                  ],

                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                          color: Colors.white, fontSize: band.body(16)),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  if (onTap != null) ...[
                    SizedBox(width: band.space(8)),
                    Icon(Icons.edit_outlined,
                        color: const Color(0xFFD4A0FF), size: band.body(18)),
                  ],
                ],
              ),
            ),
          ),
        ));

    if (isShimmering) {
      return _ShimmerWrapper(child: content);
    }
    return content;
  }
}

class _ShimmerWrapper extends StatefulWidget {
  final Widget child;
  const _ShimmerWrapper({required this.child});
  @override
  State<_ShimmerWrapper> createState() => _ShimmerWrapperState();
}

class _ShimmerWrapperState extends State<_ShimmerWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  @override
  void initState() {
    super.initState();
    _shimmerController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ageBand = Theme.of(context).extension<AgeBandThemeData>();
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return (ageBand?.accentShimmer ??
                    const LinearGradient(
                        colors: [Colors.white24, Colors.white, Colors.white24]))
                .createShader(
              Rect.fromLTWH(
                -bounds.width + (bounds.width * 2 * _shimmerController.value),
                0,
                bounds.width,
                bounds.height,
              ),
            );
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _StaggeredReveal extends StatefulWidget {
  final Widget child;
  final int index;
  const _StaggeredReveal({required this.child, required this.index});
  @override
  State<_StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<_StaggeredReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  Timer? _staggerTimer;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _opacity = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutBack));
    _staggerTimer = Timer(Duration(milliseconds: 100 * widget.index), () {
      if (mounted) _anim.forward();
    });
  }

  @override
  void dispose() {
    _staggerTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _slide, child: widget.child));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../services/app_tts_service.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import '../../models.dart';
import '../../avatar_models.dart';
import '../../custom_avatar_screen.dart';
import '../../utils/motion_utils.dart';
import '../../theme/age_band_theme.dart';
import '../../theme/app_theme.dart';
import '../../widgets/archetype_card.dart';
import '../../widgets/magic_star_cursor.dart';
import '../../services/api_service_manager.dart';
import '../../services/avatar_generation_state.dart';
import '../../services/firebase_analytics_service.dart';
import '../../services/audio_ambience_service.dart';
import '../../config/environment.dart';
import '../../widgets/avatar_gallery_selector.dart';
import '../../widgets/image_mode_orb.dart';
import '../../data/scenario_data.dart';
import '../../character_traits_data.dart';
import '../../widgets/feelings_quest_modal.dart';
import '../../widgets/breathing_avatar.dart';
import '../../widgets/magic_ear_button.dart';
import '../../widgets/sprout_animations.dart';

// ---------------------------------------------------------------------------
class _PetAvatarGenerationResult {
  final String? message;
  final bool isError;

  const _PetAvatarGenerationResult.success([this.message]) : isError = false;
  const _PetAvatarGenerationResult.error(this.message) : isError = true;
}

/// Hero Creator — Step 1 of the story wizard.
/// Restructured as a guided multi-page wizard (progressive disclosure).
class HeroCreatorStep extends StatefulWidget {
  final WizardData wizardData;
  final VoidCallback onNext;
  final List<Character> availableCharacters;
  final int? requestedSubStep;
  final int subStepRequestNonce;
  final void Function(int subStep)? onSubStepChange;
  final void Function(int age)? onAgeChanged;

  const HeroCreatorStep({
    super.key,
    required this.wizardData,
    required this.onNext,
    this.availableCharacters = const [],
    this.requestedSubStep,
    this.subStepRequestNonce = 0,
    this.onSubStepChange,
    this.onAgeChanged,
  });

  @override
  State<HeroCreatorStep> createState() => _HeroCreatorStepState();
}

class _HeroCreatorStepState extends State<HeroCreatorStep>
    with TickerProviderStateMixin {
  // ─── Assets ─────────────────────────────────────────────────────────────────

  // ─── State ──────────────────────────────────────────────────────────────────
  late PageController _heroPageController;
  late PageController _sproutCarouselController;
  int _heroPage = 0;
  String? _selectedArchetypeId;
  late TextEditingController _nameController;
  final FocusNode _nameFocusNode = FocusNode();
  Character? _selectedExistingCharacter;
  bool _isCreatingNew = true;
  GeneratedAvatar? _generatedAvatar;
  String? _customAvatarFilePath;
  bool _isPremium = false;
  // ─── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _sparkleCtrl;

  late TextEditingController _imagineItController;

  // ─── Voice & Audio ───────────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  String _listeningFor = '';
  /// Debounce timer for TTS name echo (Sprout band only).
  Timer? _nameEchoTimer;
  late TextEditingController _superpowerController;
  late TextEditingController _questController;
  late TextEditingController _wishController;
  late TextEditingController _characterDesireController;
  bool _isPetAvatarGenerating = false;
  String? _petAvatarStatusMessage;
  late TextEditingController _friendNameController;
  // Sprout band: pet card is hidden until a grown-up reveals it
  bool _showPetCardForSprout = false;

  // ─── Analytics Helpers ──────────────────────────────────────────────────────
  void _logPageView(int pageIndex) {
    FirebaseAnalyticsService.logEvent('hero_creator_page_view', {
      'page_number': pageIndex,
      'is_creating_new': _isCreatingNew,
      'character_name_length': widget.wizardData.characterName.length,
      'has_archetype': _selectedArchetypeId != null,
      'has_avatar': _hasAvatar,
    });
  }

  // ─── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Determine initial page
    if (widget.availableCharacters.isNotEmpty) {
      _heroPage = 0;
    } else {
      // Always start at page 1 (name + character/gender carousel) for new
      // characters, even if onboarding pre-filled the name. The character
      // picker on page 1 sets gender, which must not be silently skipped.
      _heroPage = 1;
    }
    _heroPageController = PageController(initialPage: _heroPage);
    _logPageView(_heroPage);

    _sproutCarouselController = PageController(viewportFraction: 0.75);

    if (widget.wizardData.characterAge < 3 ||
        widget.wizardData.characterAge > 99) {
      widget.wizardData.characterAge = 7;
    }
    if (widget.wizardData.characterGender.isEmpty) {
      widget.wizardData.characterGender = 'Girl';
    }
    _hydrateAgeFromSavedPreference();
    _nameController = TextEditingController(
      text: widget.wizardData.characterName,
    );
    _superpowerController = TextEditingController(
      text: widget.wizardData.heroSuperpower ?? '',
    );
    _questController = TextEditingController(
      text: widget.wizardData.heroQuest ?? '',
    );
    _wishController = TextEditingController(
      text: widget.wizardData.customElements,
    );
    _imagineItController = TextEditingController(
      text: widget.wizardData.customElements,
    );
    _friendNameController = TextEditingController();
    _characterDesireController = TextEditingController(
      text: widget.wizardData.characterDesire ?? '',
    );
    // ── Animation controllers ──────────────────────────────────────────────────
    _sparkleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));

    // ── Speech & TTS ──────────────────────────────────────────────────────────
    _speech.initialize().then((available) {
      if (mounted) setState(() => _speechAvailable = available);
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _speakPagePrompt(_heroPage));

    AvatarGenerationState().addListener(_onAvatarStateChanged);
    ApiServiceManager.hasPremiumAccess().then((premium) {
      if (mounted) setState(() => _isPremium = premium);
    });
    if (widget.wizardData.characterId != null &&
        widget.availableCharacters.isNotEmpty) {
      _selectedExistingCharacter = widget.availableCharacters.firstWhere(
        (c) => c.id == widget.wizardData.characterId,
        orElse: () => widget.availableCharacters.first,
      );
      if (_selectedExistingCharacter != null) {
        _isCreatingNew = false;
        _loadExistingCharacter(_selectedExistingCharacter!);
      }
    }
  }

  Future<void> _hydrateAgeFromSavedPreference() async {
    // Keep new character age in sync with age-gate selection (e.g. 4 stays 4).
    if (widget.wizardData.characterId != null) return;
    final prefs = await SharedPreferences.getInstance();
    final savedAge = prefs.getInt('user_age');
    if (savedAge == null || savedAge < 3 || savedAge > 99) return;
    if (!mounted) return;
    setState(() {
      widget.wizardData.characterAge = savedAge;
    });
  }

  @override
  void dispose() {
    _nameEchoTimer?.cancel();
    _nameController.dispose();
    _nameFocusNode.dispose();
    _superpowerController.dispose();
    _questController.dispose();
    _characterDesireController.dispose();
    _wishController.dispose();
    _imagineItController.dispose();
    _friendNameController.dispose();

    _sparkleCtrl.dispose();
    _speech.stop();
    AppTtsService.instance.stop();
    _heroPageController.dispose();
    _sproutCarouselController.dispose();
    AvatarGenerationState().removeListener(_onAvatarStateChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HeroCreatorStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_nameController.text.trim().isEmpty &&
        widget.wizardData.characterName.trim().isNotEmpty) {
      _nameController.text = widget.wizardData.characterName;
    }
    // Only auto-advance past the name/gender page for *existing* characters
    // (characterId is set). New characters must visit page 1 so the user can
    // enter their name and pick boy/girl before proceeding.
    if (_heroPage == 1 &&
        !_isCreatingNew &&
        widget.wizardData.characterId != null &&
        widget.wizardData.characterName.trim().isNotEmpty &&
        widget.wizardData.characterAge >= 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _heroPage != 1) return;
        _jumpToSubStep(2);
      });
    }
    if (widget.requestedSubStep != null &&
        widget.subStepRequestNonce != oldWidget.subStepRequestNonce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.requestedSubStep == null) return;
        _jumpToSubStep(widget.requestedSubStep!);
      });
    }
  }

  // ─── Avatar state listener ───────────────────────────────────────────────────
  void _onAvatarStateChanged() {
    final state = AvatarGenerationState();
    if (state.completedAvatar != null && _generatedAvatar == null) {
      if (mounted) {
        setState(() {
          _generatedAvatar = state.completedAvatar;
          widget.wizardData.generatedAvatar = state.completedAvatar;
        });
        _maybeAdvanceFromStylePage();
        _sparkleCtrl.forward(from: 0);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✨ Your avatar is ready!'),
          backgroundColor: Color(0xFF4CAF50),
          duration: Duration(seconds: 3),
        ));
      }
      state.consumeAvatar();
    }
  }

  // ─── Navigation Helpers ──────────────────────────────────────────────────────
  void _notifySubStep() {
    final int step;
    if (_heroPage < 4) {
      step = 0; // Create Hero (pages 0–3)
    } else if (_heroPage == 4) {
      step = 1; // Pick Team
    } else if (_heroPage == 5) {
      step = 2; // Pick Place
    } else {
      step = 3; // Make Magic
    }
    final onSubStepChange = widget.onSubStepChange;
    if (onSubStepChange == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      onSubStepChange(step);
    });
  }

  Future<void> _openFeelingsQuest() async {
    final age = widget.wizardData.characterAge <= 0
        ? 8
        : widget.wizardData.characterAge;
    final usesAges6To8Vocabulary = age >= 6 && age <= 8;
    final result = await FeelingsQuestModal.show(context, childAge: age);
    if (result != null && mounted) {
      setState(() {
        widget.wizardData.selectedEmotionChips = result;
        if (usesAges6To8Vocabulary && result.isNotEmpty) {
          widget.wizardData.selectedFeeling = result.last;
        }
        widget.wizardData.selectedScenario = 'big_feelings_quest';
      });
    }
  }

  void _onSceneTap(String id) {
    if (id == 'big_feelings_quest') {
      _openFeelingsQuest();
    } else {
      setState(() => widget.wizardData.selectedScenario = id);
    }
    final label = _sceneLabel(id);
    if (label != null) unawaited(_speakForSprout(label));
  }

  void _heroNextPage() {
    if (_heroPage < 6) {
      _triggerPageCelebration();
      _heroPageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _heroPage++);
      _logPageView(_heroPage);
      _notifySubStep();
      // Delay voice prompt so it plays after the chime finishes (~800ms),
      // preventing simultaneous audio on page transition.
      Future.delayed(const Duration(milliseconds: 850), () {
        if (mounted) unawaited(_speakPagePrompt(_heroPage));
      });
    }
  }

  /// Plays shimmer chime + shows a brief star-burst particle overlay.
  void _triggerPageCelebration() {
    final age = widget.wizardData.characterAge;
    if (age >= 9) return; // Only for Sprout/Explorer
    AudioAmbienceService().playSfx('sounds/magical_shimmer.mp3');
    _showStarBurst();
  }

  void _showStarBurst() {
    final showParticles = MotionPrefs.showParticles(context);
    if (!showParticles) return;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _StarBurstOverlay(
        onComplete: () {
          entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }

  void _heroPrevPage() {
    if (_heroPage > 0) {
      _heroPageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _heroPage--);
      _logPageView(_heroPage);
      _notifySubStep();
    }
  }

  void _jumpToSubStep(int subStep) {
    final targetPage = switch (subStep) {
      0 => 1, // Create Hero
      1 => 4, // Pick Team
      2 => 5, // Pick Place
      _ => 6, // Make Magic
    };
    if (!_heroPageController.hasClients) return;
    final clampedTarget = targetPage.clamp(0, 6);
    _heroPageController.animateToPage(
      clampedTarget,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
    setState(() => _heroPage = clampedTarget);
    _logPageView(_heroPage);
    _notifySubStep();
  }

  // ─── Character helpers ────────────────────────────────────────────────────────
  void _loadExistingCharacter(Character character) {
    try {
      FirebaseAnalyticsService.logEvent('hero_creator_select_character', {
        'character_id': character.id,
        'character_role': character.role,
        'character_age': character.age,
      });
      setState(() {
        _isCreatingNew = false;
        _selectedExistingCharacter = character;
        widget.wizardData.characterId = character.id;
        widget.wizardData.characterName = character.name;
        widget.wizardData.characterAge = character.age;
        widget.wizardData.characterGender = character.gender ?? 'Girl';
        widget.wizardData.selectedArchetypeId = character.role;
        _selectedArchetypeId = character.role;
        _nameController.text = character.name;
        _generatedAvatar = character.generatedAvatar;
        widget.wizardData.generatedAvatar = character.generatedAvatar;
        if (character.pets != null) {
          final safePets = <Map<String, String>>[];
          for (final p in character.pets!) {
            try {
              safePets.add(Map<String, String>.from(p));
            } catch (_) {}
          }
          widget.wizardData.pets = safePets;
        }
        if (character.friends != null) {
          widget.wizardData.additionalCharacters = [...character.friends!];
        }
        if (character.personalitySliders != null) {
          widget.wizardData.personalitySliders =
              Map<String, int>.from(character.personalitySliders!);
        }
      });
    } catch (e, stack) {
      debugPrint('❌ Error loading character: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not load character: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _switchToNewCharacter() {
    FirebaseAnalyticsService.logEvent('hero_creator_create_new', {});
    setState(() {
      _isCreatingNew = true;
      _selectedExistingCharacter = null;
      _generatedAvatar = null;
      widget.wizardData.generatedAvatar = null;
      widget.wizardData.characterId = null;
      widget.wizardData.characterName = '';
      widget.wizardData.characterAge = 7;
      _selectedArchetypeId = null;
      _nameController.clear();
      widget.wizardData.pets = [];
      widget.wizardData.additionalCharacters = [];
      // Reset personality to defaults
      widget.wizardData.personalitySliders = {
        'energy': 50,
        'sociability': 50,
        'creativity': 50,
        'confidence': 50,
        'empathy': 50,
        'adventurousness': 50,
      };
    });
    _heroNextPage();
  }

  void _selectArchetype(ArchetypeData archetype) {
    setState(() {
      _selectedArchetypeId = archetype.name;
      widget.wizardData.selectedArchetypeId = archetype.name;
      widget.wizardData.personalitySliders =
          Map<String, int>.from(archetype.attributes);
      // Auto-set superpower from archetype's special ability
      widget.wizardData.heroSuperpower = archetype.specialAbility;
      if (widget.wizardData.characterAge < 1) {
        widget.wizardData.characterAge = 5;
      }
    });
    // Read the archetype name aloud for young children.
    unawaited(_speakForSprout(archetype.nameForAge(widget.wizardData.characterAge)));

    // Page 3 is archetype-only — auto-advance once an archetype is chosen.
    if (_heroPage != 3) return;
    _heroNextPage();
  }

  void _maybeAdvanceFromStylePage() {
    // Page 2 is avatar-only — auto-advance once the avatar is chosen.
    if (!mounted || _heroPage != 2) return;
    if (_hasAvatar) {
      _heroNextPage();
    }
  }

  Future<bool> _saveCharacterDraft() async {
    if (!_isCreatingNew) return true;
    try {
      final body = {
        'name': widget.wizardData.characterName,
        'age': widget.wizardData.characterAge,
        'gender': widget.wizardData.characterGender,
        'role': widget.wizardData.selectedArchetypeId,
        'character_type': 'Everyday Kid',
        'character_style': 'Regular Kid',
        'pets': widget.wizardData.pets,
        'friends': widget.wizardData.additionalCharacters,
        'avatar': {'hairColor': 'Brown', 'skinTone': 'Light'},
        'personality_sliders': widget.wizardData.personalitySliders,
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
      return true;
    } catch (e) {
      debugPrint('⚠️ Character save failed: $e');
      final isLocal = e.toString().contains('Cannot reach the local backend');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isLocal
              ? 'Avatar selected. Could not sync right now.'
              : 'Could not save character: $e'),
          backgroundColor: isLocal ? AppColors.gold : AppColors.error,
        ));
      }
      return isLocal;
    }
  }

  Future<void> _handleContinue() async {
    final ok = await _saveCharacterDraft();
    if (ok) {
      FirebaseAnalyticsService.logEvent('hero_creator_complete', {
        'is_creating_new': _isCreatingNew,
        'has_avatar': _hasAvatar,
        'archetype': _selectedArchetypeId,
      });
      widget.onNext();
    }
  }

  // ─── Age-Band Title Style ────────────────────────────────────────────────────
  TextStyle _bandTitleStyle(AgeBandThemeData band, {double baseFontSize = 24}) {
    if (band.band.isMature) {
      return GoogleFonts.sourceSans3(
        color: const Color(0xFFFFD700),
        fontSize: baseFontSize * band.headingScale,
        fontWeight: FontWeight.bold,
      );
    } else if (band.band == AgeBand.adventurer) {
      return GoogleFonts.bitter(
        color: const Color(0xFFFFD700),
        fontSize: baseFontSize * band.headingScale,
        fontWeight: FontWeight.bold,
      );
    }
    return GoogleFonts.cinzelDecorative(
      color: const Color(0xFFFFD700),
      fontSize: baseFontSize,
      fontWeight: FontWeight.bold,
    );
  }

  // ─── Page Builders ──────────────────────────────────────────────────────────

  // Page 0: Welcome / Returning User Choice
  Widget _buildPage0() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final ageBand = band.band;
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          ageBand == AgeBand.creator ? "Welcome back" : "Welcome back!",
          textAlign: TextAlign.center,
          style: _bandTitleStyle(band, baseFontSize: 28),
        ),
        const SizedBox(height: 6),
        Text(
          "Tap your character to continue.",
          style: GoogleFonts.fredoka(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 30),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: widget.availableCharacters.length,
            itemBuilder: (context, index) {
              final char = widget.availableCharacters[index];
              return _CharacterChoiceCard(
                character: char,
                getAvatarProvider: _getAvatarProvider,
                onTap: () {
                  _loadExistingCharacter(char);
                  _handleContinue();
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildCreateNewHeroButton(),
        ),
      ],
    );
  }

  Widget _buildCreateNewHeroButton() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final ageBand = band.band;
    return ElevatedButton(
      onPressed: _switchToNewCharacter,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF9B3FD8),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 8,
        shadowColor: const Color(0xFFFFD700).withAlpha(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_circle_outline, size: 24),
          const SizedBox(width: 12),
          Text(
            ageBand == AgeBand.creator
                ? "Create a New Hero"
                : "Create a New Hero!",
            style: _bandTitleStyle(band, baseFontSize: 18),
          ),
        ],
      ),
    );
  }

  // Page 1: "Who is your hero?"
  Widget _buildPage1() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final ageBand = band.band;
    return Stack(
      children: [
        // Ambient floating sparkles behind the content
        const Positioned.fill(child: _AmbientSparkleLayer()),
        SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: band.space(24)),
          child: Column(
            children: [
              SizedBox(height: band.space(10)),
              if (!(widget.wizardData.characterAge <= 4 &&
                  ageBand == AgeBand.sprout))
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const MagicEarButton(
                      spokenText:
                          "What is your hero's name? You can type it or tap the microphone to say it!",
                      size: 32,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      band.createCharacterLabel,
                      textAlign: TextAlign.center,
                      style: _bandTitleStyle(band, baseFontSize: 24),
                    ),
                  ],
                ),
              // Sprout: big colourful prompt to reinforce what to do
              if (ageBand == AgeBand.sprout) ...[
                SizedBox(height: band.space(8)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const MagicEarButton(
                      spokenText:
                          "What is your hero's name? You can type it or tap the microphone to say it!",
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "What is your hero's name?",
                        textAlign: TextAlign.left,
                        style: GoogleFonts.fredoka(
                          fontSize: band.heading(28),
                          color: const Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(color: Color(0xFFFF6B35), blurRadius: 12)
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: band.space(20)),
              _buildNameScrollInput(),
              SizedBox(height: band.space(24)),
              _buildGenderPicker(),
            ],
          ),
        ),
      ],
    );
  }

  // Page 2: "Pick your hero style!" — archetype selection
  // Page 2: Choose your look (avatar only)
  Widget _buildPage2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final band = Theme.of(context).extension<AgeBandThemeData>() ??
                  explorerTheme;
              final isCreator = band.band == AgeBand.creator;
              final title = isCreator ? 'Design your character' : 'Pick your hero\'s look!';
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MagicEarButton(
                    spokenText:
                        "Pick your hero's look! Tap the button to choose one.",
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: _bandTitleStyle(band, baseFontSize: 22)),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _buildAvatarLookCard(),
          const SizedBox(height: 20),
          Builder(builder: (context) {
            final b = Theme.of(context).extension<AgeBandThemeData>() ??
                explorerTheme;
            if (b.band == AgeBand.sprout) return const SizedBox.shrink();
            return Text(
              _hasAvatar
                  ? 'Great! Tap Next to pick your hero style.'
                  : 'Choose a look before you continue.',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            );
          }),
          const SizedBox(height: 16),
          _buildNextArrowButton(
            enabled: _hasAvatar,
            onTap: _heroNextPage,
            hint: 'Next: Pick Hero Style',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Page 3: Pick your hero style (archetype only)
  Widget _buildPage3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final band = Theme.of(context).extension<AgeBandThemeData>() ??
                  explorerTheme;
              final title = band.band == AgeBand.creator
                  ? 'Character archetype'
                  : band.band == AgeBand.adventurer
                      ? 'Choose your hero type'
                      : 'Pick your hero style!';
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MagicEarButton(
                    spokenText:
                        "Pick your hero's style! Swipe through the pictures and tap the one you like.",
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: _bandTitleStyle(band, baseFontSize: 22)),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _buildArchetypeCards(),
          const SizedBox(height: 20),
          Builder(builder: (context) {
            final b = Theme.of(context).extension<AgeBandThemeData>() ??
                explorerTheme;
            if (b.band == AgeBand.sprout) return const SizedBox.shrink();
            return Text(
              _selectedArchetypeId != null
                  ? 'You\'re all set! Tap Next to continue.'
                  : 'Tap a hero style to continue.',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            );
          }),
          const SizedBox(height: 16),
          _buildNextArrowButton(
            enabled: _selectedArchetypeId != null,
            onTap: _heroNextPage,
            hint: 'Next: Pick Your Team',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Page 4: "Who's coming with you?" (Adventure Team — companions + pets)
  Widget _buildPage4Companions() {
    return _buildAdventureTeamPage();
  }

  /// Shows selected companions as glowing portrait orbs above the selection grid.
  /// Empty slots show a dashed placeholder. Tapping a filled orb deselects it.
  Widget _buildCompanionShowcase() {
    // Include both general and Sprout-specific companions in the search.
    final allKnownCompanions = [..._companions, ..._sproutCompanions];

    // Collect selected named companions in order — use ID as source of truth.
    final selectedNamed = allKnownCompanions
        .where((c) => widget.wizardData.selectedCompanions.contains(c.id))
        .toList();

    // Collect selected saved-character friends (not magic companions, not pets)
    final magicAndPetNames = {
      ...allKnownCompanions.map((c) => c.name),
      ...widget.wizardData.pets.map((p) => p['name'] ?? ''),
    };
    final selectedFriends = widget.availableCharacters
        .where((c) =>
            widget.wizardData.companionNames.contains(c.name) &&
            !magicAndPetNames.contains(c.name))
        .toList();

    // Build slot list: magic companions, then saved friends, then pet, then empty
    final slots = <_ShowcaseSlot>[];
    for (final c in selectedNamed) {
      slots.add(_ShowcaseSlot(
        id: c.id,
        imagePath: c.imagePath,
        name: c.name,
      ));
    }
    for (final friend in selectedFriends) {
      slots.add(_ShowcaseSlot(
        id: friend.id,
        photoBase64: friend.generatedAvatar?.imageBase64,
        name: friend.name,
        isFriend: true,
      ));
    }
    for (int i = 0; i < widget.wizardData.pets.length; i++) {
      final pet = widget.wizardData.pets[i];
      final petName = (pet['name'] ?? '').trim().isEmpty
          ? 'My Pet ${i + 1}'
          : pet['name']!;
      if (widget.wizardData.companionNames.contains(petName)) {
        slots.add(_ShowcaseSlot(
          id: 'my_pet_$i',
          photoBase64: widget.wizardData.petAvatars[petName]?.imageBase64 ??
              widget.wizardData.petPhotos[petName],
          name: petName,
        ));
      }
    }
    // Sprouts travel with 1 buddy; all other bands get up to 3 companions.
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final maxSlots = band.band == AgeBand.sprout ? 1 : 3;
    final emptyCount = (maxSlots - slots.length).clamp(0, maxSlots);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Filled slots
            for (int i = 0; i < slots.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              _GlowingCompanionOrb(
                slot: slots[i],
                onTap: () => setState(() {
                  final slot = slots[i];
                  widget.wizardData.companionNames.remove(slot.name);
                  if (slot.id != null) {
                    widget.wizardData.selectedCompanions.remove(slot.id);
                  }
                }),
              ),
            ],
            // Empty placeholder slots
            for (int i = 0; i < emptyCount; i++) ...[
              if (slots.isNotEmpty || i > 0) const SizedBox(width: 16),
              const _GlowingCompanionOrb(slot: null),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          slots.isEmpty
              ? (maxSlots == 1
                  ? 'Tap a buddy to bring along!'
                  : 'Tap a companion below to add them')
              : slots.length == 1
                  ? '${slots[0].name} is ready!'
                  : 'Your team is set!',
          style: TextStyle(
            color: slots.isEmpty ? Colors.white38 : const Color(0xFFFFD700),
            fontSize: 12,
            fontStyle: slots.isEmpty ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }

  /// Temporary adventure team placeholder — replaced when companion grid is built.
  Widget _buildAdventureTeamPage() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final companionTitle = band.band == AgeBand.sprout
        ? 'Pick your buddies!'
        : band.band == AgeBand.explorer
            ? 'Pick your friends!'
            : band.band == AgeBand.adventurer
                ? 'Choose your companions'
                : 'Choose Your Companions';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            companionTitle,
            textAlign: TextAlign.center,
            style: _bandTitleStyle(band, baseFontSize: 22),
          ),
          const SizedBox(height: 16),
          _buildCompanionShowcase(),
          const SizedBox(height: 20),
          // Companion grid will go here (Task B)
          _buildCompanionGrid(),
          const SizedBox(height: 40),
          _buildNextArrowButton(
              enabled: true,
              onTap: _heroNextPage,
              hint: 'Next: Choose Your Scene'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Companion selection grid — 7 magical creatures + saved friends + pet management.
  Widget _buildCompanionGrid() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (band.band != AgeBand.sprout) ...[
          Text(
            band.band == AgeBand.creator
                ? 'Select your adventure team'
                : 'Pick your adventure team:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontFamily: band.uiFontFamily,
            ),
          ),
          const SizedBox(height: 12),
        ],
        // ── Saved characters as friends ──────────────────────────────────────
        if (widget.availableCharacters.isNotEmpty) ...[
          const Text(
            'Your Friends:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.availableCharacters
                .where((c) => c.name != widget.wizardData.characterName)
                .map((c) {
              final isSelected =
                  widget.wizardData.selectedCompanions.contains(c.id);
              return _FriendChipButton(
                character: c,
                isSelected: isSelected,
                onTap: () => setState(() {
                  if (isSelected) {
                    widget.wizardData.companionNames.remove(c.name);
                    widget.wizardData.selectedCompanions.remove(c.id);
                  } else {
                    widget.wizardData.companionNames.add(c.name);
                    widget.wizardData.selectedCompanions.add(c.id);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        // ── Image-based companion grid ────────────────────────────────────────
        _CompanionImageGrid(
          wizardData: widget.wizardData,
          onChanged: () => setState(() {}),
          onCompanionTapped: widget.wizardData.characterAge <= 5
              ? (name) => _speakForSprout(name)
              : null,
          maxCompanions: band.band == AgeBand.sprout ? 1 : 3,
        ),
        const SizedBox(height: 16),
        // ── Bring a friend by name — hidden for Sprout band ────────────────────
        if (band.band != AgeBand.sprout) ...[
          Row(
            children: [
              const Expanded(child: Divider(color: Colors.white24)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '...or bring someone along',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
              const Expanded(child: Divider(color: Colors.white24)),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Type a friend\'s name and they\'ll be part of your story.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _friendNameController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Friend\'s name...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white12,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _addFriendByName(),
                ),
              ),
              const SizedBox(width: 8),
              if (_speechAvailable)
                IconButton(
                  tooltip: 'Say a friend\'s name',
                  icon: Icon(
                    _listeningFor == 'friend' ? Icons.mic : Icons.mic_none,
                    color: _listeningFor == 'friend'
                        ? Colors.yellow
                        : Colors.white70,
                  ),
                  onPressed: () => _toggleListening('friend'),
                ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: _addFriendByName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          if (widget.wizardData.additionalCharacters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: widget.wizardData.additionalCharacters.map((name) {
                return Chip(
                  label: Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: const Color(0xFF7C4DFF).withValues(alpha: 0.6),
                  deleteIconColor: Colors.white70,
                  onDeleted: () => setState(() {
                    widget.wizardData.additionalCharacters.remove(name);
                  }),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
        ],
        // ── Pet card (photo + name/species/color) ──────────────────────────────
        if (band.band == AgeBand.sprout) ...[
          // Sprout: show a simple grown-up prompt instead of the full pet card
          if (!_showPetCardForSprout)
            GestureDetector(
              onTap: () => setState(() => _showPetCardForSprout = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🐾', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Ask a grown-up to add your real pet!',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _PetCard(
              wizardData: widget.wizardData,
              onPickPhoto: ({int? petIndex}) => _pickPetPhoto(petIndex: petIndex),
              onChanged: () => setState(() {}),
            ),
        ] else
          _PetCard(
            wizardData: widget.wizardData,
            onPickPhoto: ({int? petIndex}) => _pickPetPhoto(petIndex: petIndex),
            onChanged: () => setState(() {}),
          ),
        const SizedBox(height: 8),
        if (_isPetAvatarGenerating)
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFFD700),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Transforming your pet into magical Pixar style...',
                  style: TextStyle(color: Color(0xFFFFD700), fontSize: 12),
                  softWrap: true,
                ),
              ),
            ],
          )
        else if (_petAvatarStatusMessage != null)
          Text(
            _petAvatarStatusMessage!,
            style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12),
          ),
        const SizedBox(height: 12),
        // Go Solo option
        TextButton.icon(
          onPressed: () => setState(() {
            widget.wizardData.companionNames.clear();
            widget.wizardData.selectedCompanions.clear();
          }),
          icon: const Icon(Icons.person, color: Colors.white54, size: 18),
          label: const Text(
            'Go Solo — no companions',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
      ],
    );
  }

  void _addFriendByName() {
    final name = _friendNameController.text.trim();
    if (name.isEmpty) return;
    if (widget.wizardData.additionalCharacters.contains(name)) return;
    setState(() {
      widget.wizardData.additionalCharacters.add(name);
      _friendNameController.clear();
    });
  }

  String _defaultPetNameForIndex(int index) =>
      index == 0 ? 'My Pet' : 'My Pet ${index + 1}';

  Future<void> _pickPetPhoto({int? petIndex}) async {
    final source = await _showPhotoSourceDialog();
    if (source == null || !mounted) return;
    final picker = ImagePicker();
    final XFile? file =
        await picker.pickImage(source: source, maxWidth: 800, imageQuality: 75);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    setState(() {
      int targetIndex = petIndex ?? 0;
      if (targetIndex < 0) targetIndex = 0;

      while (widget.wizardData.pets.length <= targetIndex) {
        final idx = widget.wizardData.pets.length;
        widget.wizardData.pets.add({
          'name': _defaultPetNameForIndex(idx),
          'species': 'Dog',
          'color': '',
          'personality': '',
        });
      }

      final existingName =
          (widget.wizardData.pets[targetIndex]['name'] ?? '').trim().isNotEmpty
              ? widget.wizardData.pets[targetIndex]['name']!
              : _defaultPetNameForIndex(targetIndex);
      widget.wizardData.pets[targetIndex]['name'] = existingName;
      // Store photo keyed by name in petPhotos (not petAvatars)
      widget.wizardData.petPhotos[existingName] = b64;
      widget.wizardData.petAvatars.remove(existingName);
      // Auto-select the pet as a companion
      final petId = 'my_pet_$targetIndex';
      if (!widget.wizardData.companionNames.contains(existingName)) {
        widget.wizardData.companionNames.add(existingName);
      }
      if (!widget.wizardData.selectedCompanions.contains(petId)) {
        widget.wizardData.selectedCompanions.add(petId);
      }
    });

    final targetIndex =
        (petIndex ?? 0).clamp(0, widget.wizardData.pets.length - 1);
    final pet = widget.wizardData.pets[targetIndex];

    if (mounted) {
      setState(() {
        _isPetAvatarGenerating = true;
        _petAvatarStatusMessage = null;
      });
    }

    final petAvatarResult = await _generateMagicalPetAvatar(
      petName: pet['name'] ?? _defaultPetNameForIndex(targetIndex),
      species: pet['species'] ?? 'Dog',
      looksDescription: pet['color'] ?? 'cute and friendly',
      photoBytes: bytes,
      filename: file.name.isNotEmpty ? file.name : 'pet_photo.jpg',
    );

    if (!mounted) return;
    final success = !petAvatarResult.isError;
    setState(() {
      _isPetAvatarGenerating = false;
      _petAvatarStatusMessage = petAvatarResult.message ??
          (success
              ? '✨ Magical pet avatar ready!'
              : "Oops! Magic isn't working on that picture. Want to pick a buddy instead?");
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_petAvatarStatusMessage!),
        backgroundColor:
            success ? const Color(0xFF4CAF50) : const Color(0xFF6D4C41),
      ),
    );
  }

  Future<_PetAvatarGenerationResult> _generateMagicalPetAvatar({
    required String petName,
    required String species,
    required String looksDescription,
    required List<int> photoBytes,
    required String filename,
  }) async {
    try {
      final url =
          Uri.parse('${Environment.backendUrl}/avatar/generate-pet-avatar');
      final request = http.MultipartRequest('POST', url);
      request.files.add(http.MultipartFile.fromBytes(
        'photo',
        photoBytes,
        filename: filename,
      ));
      request.fields['pet_name'] = petName;
      request.fields['species'] = species;
      request.fields['breed_description'] =
          looksDescription.trim().isEmpty ? species : looksDescription;
      request.fields['owner_favorite_color'] =
          widget.wizardData.favoriteColor.toLowerCase();
      request.fields['owner_age'] =
          widget.wizardData.characterAge.toString();

      final headers = await ApiServiceManager.authHeaders();
      headers.forEach((key, value) {
        if (key.toLowerCase() != 'content-type') {
          request.headers[key] = value;
        }
      });

      final streamed = await request.send().timeout(const Duration(minutes: 3));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200 && response.statusCode != 206) {
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final message = body['message']?.toString().trim();
          if (message != null && message.isNotEmpty) {
            return _PetAvatarGenerationResult.error(message);
          }
        } catch (_) {}
        return const _PetAvatarGenerationResult.error(
          "Oops! Magic isn't working on that picture. Want to pick a buddy instead?",
        );
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != 'success') {
        final message = body['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return _PetAvatarGenerationResult.error(message);
        }
        return const _PetAvatarGenerationResult.error(
          "Oops! Magic isn't working on that picture. Want to pick a buddy instead?",
        );
      }
      final avatarJson = body['avatar'] as Map<String, dynamic>?;
      if (avatarJson == null) {
        return const _PetAvatarGenerationResult.error(
          'Photo saved, but pet avatar generation returned no image.',
        );
      }

      final generated = GeneratedAvatar.fromJson(avatarJson);
      if (!mounted) return const _PetAvatarGenerationResult.success();
      setState(() {
        widget.wizardData.petAvatars[petName] = generated;
      });
      if (response.statusCode == 206) {
        return const _PetAvatarGenerationResult.success(
          "Oops! Magic isn't working on that picture right now. Your buddy's photo is saved!",
        );
      }
      return const _PetAvatarGenerationResult.success();
    } catch (e) {
      // Keep raw pet photo fallback if generation is unavailable.
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      if (message.isNotEmpty) {
        return _PetAvatarGenerationResult.error(message);
      }
      return const _PetAvatarGenerationResult.error(
        "Oops! Magic isn't working on that picture. Want to pick a buddy instead?",
      );
    }
  }

  Future<ImageSource?> _showPhotoSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C1B47),
        title: const Text('Add Your Companion',
            style: TextStyle(color: Color(0xFFFFD700))),
        content: const Text('How would you like to add your companion?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            icon: const Icon(Icons.camera_alt, color: Color(0xFFD4A0FF)),
            label: const Text('Take Photo',
                style: TextStyle(color: Color(0xFFD4A0FF))),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            icon: const Icon(Icons.photo_library, color: Color(0xFFD4A0FF)),
            label: const Text('Choose from Gallery',
                style: TextStyle(color: Color(0xFFD4A0FF))),
          ),
        ],
      ),
    );
  }

  // Page 5: "Where will your adventure happen?" (Scene selection)

  Widget _buildPage5() {
    final age = widget.wizardData.characterAge;
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final placeTitle = band.band == AgeBand.creator
        ? 'Setting'
        : band.band == AgeBand.adventurer
            ? 'Choose your setting'
            : band.band == AgeBand.sprout
                ? 'Where should we go?'
                : 'Where to adventure?';
    final isImagineItSelected =
        widget.wizardData.selectedScenario == 'safe_space';

    final isCreator = band.band == AgeBand.creator;

    // The 4 featured scene buttons with their image assets.
    // For Creator band, populate thematicQuestion from ScenarioData.
    ScenarioCard? scenarioById(String id) {
      try {
        return ScenarioData.all.firstWhere((s) => s.id == id);
      } catch (_) {
        return null;
      }
    }

    final featuredButtons = [
      _SceneButtonData(
        id: 'vanishing_colors',
        label: scenarioById('vanishing_colors')?.titleForAge(age) ?? 'Vanishing Colors',
        normalAsset: 'assets/images/scenarios/rainbow_land_btn.png',
        pressedAsset: 'assets/images/scenarios/rainbow_land_btn_pressed.png',
        thematicQuestion: scenarioById('vanishing_colors')?.creatorThematicQuestion,
      ),
      _SceneButtonData(
        id: 'crystal_cavern',
        label: scenarioById('crystal_cavern')?.titleForAge(age) ?? 'Crystal Cavern',
        normalAsset: 'assets/images/scenarios/crystal_cave_btn.png',
        pressedAsset: 'assets/images/scenarios/crystal_cave_btn_pressed.png',
        thematicQuestion: scenarioById('crystal_cavern')?.creatorThematicQuestion,
      ),
      _SceneButtonData(
        id: 'volcano_dragons',
        label: scenarioById('volcano_dragons')?.titleForAge(age) ?? 'Volcano Dragons',
        normalAsset: 'assets/images/scenarios/dragon_friends_btn.png',
        pressedAsset: 'assets/images/scenarios/dragon_friends_btn_pressed.png',
        thematicQuestion: scenarioById('volcano_dragons')?.creatorThematicQuestion,
      ),
      _SceneButtonData(
        id: 'big_feelings_quest',
        label: scenarioById('big_feelings_quest')?.titleForAge(age) ?? 'Big Feelings Quest',
        normalAsset: 'assets/images/scenarios/my_big_feelings_btn.png',
        pressedAsset: 'assets/images/scenarios/my_big_feelings_btn_pressed.png',
        thematicQuestion: scenarioById('big_feelings_quest')?.creatorThematicQuestion,
      ),
    ];

    final displayButtons = featuredButtons;

    final labelFontSize =
        band.band == AgeBand.sprout || band.band == AgeBand.explorer
            ? 14.0
            : 12.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            placeTitle,
            textAlign: TextAlign.center,
            style: _bandTitleStyle(band, baseFontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            band.band == AgeBand.sprout
                ? 'Tap a picture to pick where the story goes!'
                : band.band == AgeBand.explorer
                    ? 'Pick a world or make your own!'
                    : band.band == AgeBand.creator
                        ? 'Start from your imagination — or choose a world below'
                        : 'Create your own world — or choose one below!',
            style: GoogleFonts.sourceSans3(color: Colors.white60, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),

          // ── Imagine It spotlight (Creator band: shown FIRST above preset grid) ──
          if (isCreator) ...[
            _ImagineItHeroCard(
              isSelected: isImagineItSelected,
              onTap: () {
                setState(() {
                  widget.wizardData.selectedScenario =
                      isImagineItSelected ? null : 'safe_space';
                  if (isImagineItSelected) widget.wizardData.customElements = '';
                });
              },
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 280),
              crossFadeState: isImagineItSelected
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: _buildImagineItInput(),
              secondChild: const SizedBox.shrink(),
            ),
            const SizedBox(height: 14),
          ],

          // ── 2-column grid of preset scene buttons ──────────────────────────
          // When the count is even, use a simple 2-column GridView.
          // When odd (e.g. Sprout hides volcano_dragons), the last card spans
          // the full width so nothing looks orphaned.
          if (displayButtons.length.isOdd) ...[
            for (int i = 0; i < displayButtons.length - 1; i += 2) ...[
              if (i > 0) const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 360 / 220,
                      child: _SceneImageButton(
                        data: displayButtons[i],
                        isSelected: widget.wizardData.selectedScenario ==
                            displayButtons[i].id,
                        labelFontSize: labelFontSize,
                        showThematicQuestion: isCreator,
                        onTap: () => _onSceneTap(displayButtons[i].id),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 360 / 220,
                      child: _SceneImageButton(
                        data: displayButtons[i + 1],
                        isSelected: widget.wizardData.selectedScenario ==
                            displayButtons[i + 1].id,
                        labelFontSize: labelFontSize,
                        showThematicQuestion: isCreator,
                        onTap: () => _onSceneTap(displayButtons[i + 1].id),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Last item spans full width when count is odd
            AspectRatio(
              aspectRatio: 360 / 110, // half the height for a wide banner feel
              child: _SceneImageButton(
                data: displayButtons.last,
                isSelected: widget.wizardData.selectedScenario ==
                    displayButtons.last.id,
                labelFontSize: labelFontSize,
                showThematicQuestion: isCreator,
                onTap: () => _onSceneTap(displayButtons.last.id),
              ),
            ),
          ] else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              // Natural image ratio: 360×220 = 1.636 — childAspectRatio = w/h
              childAspectRatio: 360 / 220,
              children: displayButtons
                  .map((btn) => _SceneImageButton(
                        data: btn,
                        isSelected:
                            widget.wizardData.selectedScenario == btn.id,
                        labelFontSize: labelFontSize,
                        showThematicQuestion: isCreator,
                        onTap: () => _onSceneTap(btn.id),
                      ))
                  .toList(),
            ),

          const SizedBox(height: 20),

          // ── Make One Up — shown below preset scenes (non-Creator bands only;
          //    Creator band shows it above the grid as a spotlight) ──
          if (!isCreator) ...[
            _ImagineItHeroCard(
              isSelected: isImagineItSelected,
              onTap: () {
                final b = Theme.of(context).extension<AgeBandThemeData>() ??
                    explorerTheme;
                setState(() {
                  widget.wizardData.selectedScenario =
                      isImagineItSelected ? null : 'safe_space';
                  if (isImagineItSelected) widget.wizardData.customElements = '';
                });
                if (b.band == AgeBand.sprout && !isImagineItSelected) {
                  unawaited(_speakForSprout('Tap a picture to pick your world!'));
                }
              },
            ),
            // Inline input — expands when Make One Up is selected
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 280),
              crossFadeState: isImagineItSelected
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: _buildImagineItInput(),
              secondChild: const SizedBox.shrink(),
            ),
          ],

          const SizedBox(height: 24),
          _buildNextArrowButton(
              enabled: true, onTap: _heroNextPage, hint: 'Next: Story Style'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildImagineItInput() {
    final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    if (band.band == AgeBand.sprout) return _buildSproutWorldTiles();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD700), width: 2),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C1B47), Color(0xFF1A0E36)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withAlpha(50),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Where will your adventure take place?',
                    style: GoogleFonts.fredoka(
                      color: const Color(0xFFFFD700),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _imagineItController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText:
                          'e.g. a floating cloud city, deep inside a volcano, underwater palace…',
                      hintStyle: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 13,
                          fontStyle: FontStyle.italic),
                      filled: true,
                      fillColor: Colors.white.withAlpha(18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: const Color(0xFFFFD700).withAlpha(100)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFFFFD700), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: const Color(0xFFFFD700).withAlpha(120)),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    onChanged: (value) {
                      widget.wizardData.customElements = value;
                      _wishController.text = value;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: _speechAvailable
                      ? 'Speak your setting idea'
                      : 'Mic unavailable',
                  icon: Icon(
                    _listeningFor == 'imagine' ? Icons.mic : Icons.mic_none,
                    color: _speechAvailable
                        ? (_listeningFor == 'imagine'
                            ? Colors.yellow
                            : Colors.white)
                        : Colors.white38,
                  ),
                  onPressed: _speechAvailable
                      ? () => _toggleListening('imagine')
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _speechAvailable
                  ? '🎤 Tap the mic and say your idea out loud.'
                  : '✍️ Type your idea here. Mic is unavailable on this device.',
              style: TextStyle(
                color: Colors.white.withAlpha(170),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '✦ The more you describe, the more magical your story becomes!',
              style: TextStyle(
                  color: const Color(0xFFFFD700).withAlpha(180),
                  fontSize: 11,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  // Four illustrated world-choice tiles shown for Sprouts (age 3-5) instead
  // of the free-text field — tapping a tile speaks the label and sets
  // customElements to a rich world description the backend can use.
  Widget _buildSproutWorldTiles() {
    const tiles = [
      (emoji: '🌊', label: 'Under the Sea', value: 'a magical underwater kingdom with friendly sea creatures and colorful fish'),
      (emoji: '🌲', label: 'Magic Forest', value: 'a sparkling enchanted forest with talking animals and glowing fairy lights'),
      (emoji: '☁️', label: 'Up in the Clouds', value: 'a fluffy cloud kingdom high in the sky with rainbow bridges and sky castles'),
      (emoji: '🏰', label: 'Magic Castle', value: 'a glittering magical castle with a friendly dragon guardian and hidden treasure rooms'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where should your story go? ✨',
            style: GoogleFonts.fredoka(
                color: const Color(0xFFFFD700),
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: tiles.map((t) {
              final isSelected = widget.wizardData.customElements == t.value;
              return GestureDetector(
                onTap: () {
                  setState(() => widget.wizardData.customElements = t.value);
                  unawaited(_speakForSprout(t.label));
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFFD700)
                          : Colors.white24,
                      width: isSelected ? 3 : 1,
                    ),
                    color: isSelected
                        ? const Color(0xFF2C1B47)
                        : Colors.white.withAlpha(15),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t.emoji,
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(
                        t.label,
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 2),
                        const Icon(Icons.check_circle,
                            color: Color(0xFFFFD700), size: 16),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getReadingLabel(AgeBand band) {
    switch (band) {
      case AgeBand.sprout:
        return 'Listen & Learn'; // Dr. Seuss style, auto-plays
      case AgeBand.explorer:
        return 'Easy Reader';
      case AgeBand.adventurer:
        return 'Chapter Reader';
      case AgeBand.creator:
      case AgeBand.adolescent:
      case AgeBand.adult:
        return 'First Chapter';
    }
  }

  // Page 6: "What kind of story?"
  Widget _buildPage6() {
    final data = widget.wizardData;
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final isCreator = band.band.isMature;
    String selectedMode = 'tales';
    if (data.interactiveMode) {
      selectedMode = 'pickpath';
    } else if (data.learningToReadMode) {
      selectedMode = 'reading';
    } else if (data.rhymeTimeMode) {
      selectedMode = 'rhyme';
    }

    void setStoryMode(String mode) {
      data.includeIllustrations = mode == 'tales';
      data.rhymeTimeMode = mode == 'rhyme';
      data.learningToReadMode = mode == 'reading';
      data.interactiveMode = mode == 'pickpath';
    }

    final storyTitle = band.band == AgeBand.sprout
        ? 'What story do you want?'
        : band.band == AgeBand.adventurer
            ? 'Choose your story type'
            : isCreator
                ? 'Story type'
                : 'What kind of story?';
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: band.space(24)),
      child: Column(
        children: [
          SizedBox(height: band.space(10)),
          Text(
            storyTitle,
            textAlign: TextAlign.center,
            style: _bandTitleStyle(band, baseFontSize: 24),
          ),
          SizedBox(height: band.space(24)),
          // Story mode selection — 2 orbs for Sprouts; 2×2 grid for older bands
          Text(
            band.band == AgeBand.sprout
                ? 'How should we tell it?'
                : 'Pick your story style',
            style: GoogleFonts.fredoka(
              color: Colors.white.withAlpha(200),
              fontSize: band.body(16),
            ),
          ),
          SizedBox(height: band.space(16)),
          if (band.band == AgeBand.sprout)
            // Sprouts: 2 full-width illustrated scene thumbnails side by side
            Row(
              children: [
                Expanded(
                  child: ImageModeOrb(
                    modeType: 'tales',
                    label: 'Story Quest',
                    subtitle: 'A story with pictures',
                    isActive: selectedMode == 'tales',
                    onTap: () => setState(() => setStoryMode('tales')),
                    primaryColor: const Color(0xFFAA88FF),
                    secondaryColor: const Color(0xFFE28EFF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ImageModeOrb(
                    modeType: 'reading',
                    label: 'Listen & Learn',
                    subtitle: 'Easy words to read along',
                    isActive: selectedMode == 'reading',
                    onTap: () => setState(() => setStoryMode('reading')),
                    primaryColor: const Color(0xFFB88AFF),
                    secondaryColor: const Color(0xFFFF9ECC),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ImageModeOrb(
                        modeType: 'tales',
                        label: isCreator ? 'Story' : 'Story Quest',
                        subtitle: isCreator
                            ? 'Illustrated narrative'
                            : 'An illustrated adventure',
                        isActive: selectedMode == 'tales',
                        onTap: () => setState(() => setStoryMode('tales')),
                        primaryColor: const Color(0xFFAA88FF),
                        secondaryColor: const Color(0xFFE28EFF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ImageModeOrb(
                        modeType: 'rhyme',
                        label: data.characterAge >= 11 ? 'Poetry' : 'Rhyme Time',
                        subtitle: isCreator
                            ? 'Verse and rhythm'
                            : 'A story in rhymes',
                        isActive: selectedMode == 'rhyme',
                        onTap: () => setState(() => setStoryMode('rhyme')),
                        primaryColor: const Color(0xFF00D4DD),
                        secondaryColor: const Color(0xFF7FDDFF),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: band.space(12)),
                Row(
                  children: [
                    Expanded(
                      child: ImageModeOrb(
                        modeType: 'pickpath',
                        label: isCreator ? 'Choose Your Path' : 'Pick a Path',
                        subtitle: isCreator
                            ? 'Branch the narrative'
                            : 'You choose what happens!',
                        isActive: selectedMode == 'pickpath',
                        onTap: () => setState(() => setStoryMode('pickpath')),
                        primaryColor: const Color(0xFF9E6CFF),
                        secondaryColor: const Color(0xFFFFB3E6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (data.characterAge < 9)
                      Expanded(
                        child: ImageModeOrb(
                          modeType: 'reading',
                          label: _getReadingLabel(band.band),
                          subtitle: 'Chapter-style reading',
                          isActive: selectedMode == 'reading',
                          onTap: () => setState(() => setStoryMode('reading')),
                          primaryColor: const Color(0xFFB88AFF),
                          secondaryColor: const Color(0xFFFF9ECC),
                        ),
                      )
                    else
                      // Spacer so the single card in row 2 only takes half the width
                      const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ],
            ),
          SizedBox(height: band.space(28)),
          // Genre tags — Adventurer+ only
          if (band.band == AgeBand.adventurer ||
              band.band == AgeBand.creator) ...[
            const SizedBox(height: 4),
            Text(
              "Add a genre twist (optional)",
              style: GoogleFonts.fredoka(
                color: Colors.white.withAlpha(200),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _GenreChip(
                    label: '🔍 Mystery',
                    value: 'mystery',
                    selected: widget.wizardData.selectedGenre == 'mystery',
                    onTap: () => setState(() =>
                        widget.wizardData.selectedGenre =
                            widget.wizardData.selectedGenre == 'mystery'
                                ? null
                                : 'mystery')),
                _GenreChip(
                    label: '😂 Comedy',
                    value: 'comedy',
                    selected: widget.wizardData.selectedGenre == 'comedy',
                    onTap: () => setState(() =>
                        widget.wizardData.selectedGenre =
                            widget.wizardData.selectedGenre == 'comedy'
                                ? null
                                : 'comedy')),
                _GenreChip(
                    label: '🚀 Sci-Fi',
                    value: 'sci-fi',
                    selected: widget.wizardData.selectedGenre == 'sci-fi',
                    onTap: () => setState(() =>
                        widget.wizardData.selectedGenre =
                            widget.wizardData.selectedGenre == 'sci-fi'
                                ? null
                                : 'sci-fi')),
                _GenreChip(
                    label: '⚔️ Action',
                    value: 'action',
                    selected: widget.wizardData.selectedGenre == 'action',
                    onTap: () => setState(() =>
                        widget.wizardData.selectedGenre =
                            widget.wizardData.selectedGenre == 'action'
                                ? null
                                : 'action')),
                _GenreChip(
                    label: '👻 Spooky',
                    value: 'spooky',
                    selected: widget.wizardData.selectedGenre == 'spooky',
                    onTap: () => setState(() =>
                        widget.wizardData.selectedGenre =
                            widget.wizardData.selectedGenre == 'spooky'
                                ? null
                                : 'spooky')),
                _GenreChip(
                    label: '💕 Romance',
                    value: 'romance',
                    selected: widget.wizardData.selectedGenre == 'romance',
                    onTap: () => setState(() =>
                        widget.wizardData.selectedGenre =
                            widget.wizardData.selectedGenre == 'romance'
                                ? null
                                : 'romance')),
              ],
            ),
            const SizedBox(height: 24),
          ],
          if (band.band == AgeBand.explorer)
            _buildWishPromptButtons(band)
          else if (band.band != AgeBand.sprout)
            _buildWishTextInput(band),
          SizedBox(height: band.space(32)),
          _buildNextArrowButton(
              enabled: true,
              onTap: widget.onNext,
              hint: band.wizardNextHint),
          SizedBox(height: band.space(20)),
        ],
      ),
    );
  }

  Widget _buildWishPromptButtons(AgeBandThemeData band) {
    final prompts = <(String emoji, String label, String value)>[
      ('🧚', 'Magic friend', 'A friendly fairy helps on the journey.'),
      ('🐉', 'Dragon helper', 'A kind dragon becomes my helper.'),
      ('🗺️', 'Treasure quest', 'Find a hidden treasure map adventure.'),
      ('🌈', 'Rainbow world', 'A magical rainbow world appears.'),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: band.space(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Pick something special!",
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: band.body(16),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: band.space(10)),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: prompts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
            ),
            itemBuilder: (context, index) {
              final prompt = prompts[index];
              final selected = widget.wizardData.customElements == prompt.$3;
              return InkWell(
                borderRadius: BorderRadius.circular(band.radiusMd),
                onTap: () {
                  setState(() {
                    widget.wizardData.customElements = prompt.$3;
                    _wishController.text = prompt.$3;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  constraints: BoxConstraints(minHeight: band.touchTarget(72)),
                  padding: EdgeInsets.symmetric(
                    horizontal: band.space(10),
                    vertical: band.space(10),
                  ),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF7C4DFF) : Colors.white10,
                    borderRadius: BorderRadius.circular(band.radiusMd),
                    border: Border.all(
                      color:
                          selected ? const Color(0xFFFFD700) : Colors.white24,
                      width: selected ? 2 : 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(prompt.$1,
                          style: TextStyle(fontSize: band.body(22))),
                      SizedBox(width: band.space(8)),
                      Expanded(
                        child: Text(
                          prompt.$2,
                          style: GoogleFonts.fredoka(
                            color: Colors.white,
                            fontSize: band.body(13),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWishTextInput(AgeBandThemeData band) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: band.space(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Anything special you want?",
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: band.body(16),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: band.space(8)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wishController,
                  style:
                      TextStyle(color: Colors.white, fontSize: band.body(14)),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'I want to ride a magic carpet…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withAlpha(20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(band.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: band.space(12),
                      vertical: band.space(10),
                    ),
                  ),
                  onChanged: (v) => widget.wizardData.customElements = v,
                ),
              ),
              SizedBox(width: band.space(8)),
              IconButton(
                iconSize: band.body(24),
                constraints: BoxConstraints(
                  minWidth: band.touchTarget(48),
                  minHeight: band.touchTarget(48),
                ),
                icon: Icon(
                  _listeningFor == 'wish' ? Icons.mic : Icons.mic_none,
                  color: _listeningFor == 'wish' ? Colors.yellow : Colors.white,
                ),
                onPressed: () => _toggleListening('wish'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextArrowButton(
      {required bool enabled, required VoidCallback onTap, String? hint}) {
    return _PressableArrowButton(enabled: enabled, onTap: onTap, hint: hint);
  }

  Widget _buildAvatarLookCard() {
    final imageData = _generatedAvatar?.imageBase64;
    final avatarProvider =
        imageData == null ? null : _getImageProviderFromString(imageData);
    final isCreator =
        ageBandFromAge(widget.wizardData.characterAge) == AgeBand.creator;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withAlpha(90)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF3A2363),
            backgroundImage: avatarProvider,
            child: avatarProvider == null
                ? Icon(
                    isCreator ? Icons.draw_outlined : Icons.face_retouching_natural,
                    color: const Color(0xFFFFD700),
                    size: 30,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCreator
                      ? (_hasAvatar ? 'Character visual ready' : 'Design your character')
                      : (_hasAvatar ? 'Your hero look is ready' : 'Pick what your hero looks like'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCreator
                      ? (_hasAvatar ? 'You can redesign anytime.' : 'Create a visual for your character.')
                      : (_hasAvatar ? 'You can change it anytime.' : 'Choose a look before you continue.'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _openAvatarGallery,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7E57C2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: Text(isCreator
                ? (_hasAvatar ? 'Redesign' : 'Open Designer')
                : (_hasAvatar ? 'Change Look' : 'Choose Look')),
          ),
        ],
      ),
    );
  }

  Future<void> _openAvatarCreationOptions() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2C1B47),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose Your Avatar',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pick a pre-made look or create a magical AI avatar from a photo.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading:
                    const Icon(Icons.auto_awesome, color: Color(0xFFFFD700)),
                title: const Text('Gallery Avatar',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Quick pick from magical presets',
                    style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openAvatarGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: Color(0xFFFFD700)),
                title: const Text('Take/Upload Photo → AI Avatar',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                    'Creates a Pixar-style hero from your child photo',
                    style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openCustomAvatarScreen();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAvatarGallery() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AvatarGallerySelector(
        isPremium: _isPremium,
        onCancel: () => Navigator.of(ctx).pop(),
        onAvatarSelected: (avatar) {
          if (!mounted) return;
          setState(() {
            _generatedAvatar = avatar;
            _customAvatarFilePath = null;
            widget.wizardData.generatedAvatar = avatar;
          });
          Navigator.of(ctx).pop();
          _maybeAdvanceFromStylePage();
        },
      ),
    );
  }

  Future<void> _openCustomAvatarScreen() async {
    if (!mounted) return;
    final result = await Navigator.of(context).push<CharacterAvatar>(
      MaterialPageRoute(
        builder: (_) => CustomAvatarScreen(
          initialName: widget.wizardData.characterName,
          initialAge: widget.wizardData.characterAge,
          // Sprout welcome screen: "Pick a ready hero" routes here instead
          onOpenGallery: _openAvatarGallery,
        ),
        fullscreenDialog: true,
      ),
    );

    final dataUri = result?.customImagePath;
    if (!mounted || dataUri == null || dataUri.isEmpty) return;

    final generated = GeneratedAvatar(
      id: 'custom_photo_${DateTime.now().millisecondsSinceEpoch}',
      imageBase64: dataUri,
      seed: 'custom_photo',
      style: 'pixar',
      attributes: const {'source': 'custom_photo'},
      generatedAt: DateTime.now(),
    );

    setState(() {
      _generatedAvatar = generated;
      _customAvatarFilePath = null;
      widget.wizardData.generatedAvatar = generated;
      widget.wizardData.customAvatarPath = null;
    });
    _maybeAdvanceFromStylePage();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✨ Custom avatar ready!'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  // ─── Avatar, Age, Gender, Name, Archetype, Superpower, Continue logic ──────────

  bool get _hasAvatar =>
      _generatedAvatar != null || _customAvatarFilePath != null;

  ImageProvider<Object> _getImageProviderFromString(String imageData) {
    if (imageData.startsWith('assets/')) {
      return AssetImage(imageData);
    }
    if (imageData.startsWith('http')) {
      return NetworkImage(imageData);
    }
    final normalized =
        imageData.contains(',') ? imageData.split(',').last : imageData;
    return MemoryImage(base64Decode(normalized));
  }

  Widget _buildGenderPicker() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final ageBand = band.band;

    final String boyAsset;
    final String girlAsset;
    switch (ageBand) {
      case AgeBand.sprout:
        boyAsset = 'assets/images/ui/sprout/boy_character.png';
        girlAsset = 'assets/images/ui/sprout/girl_character.png';
        break;
      case AgeBand.adventurer:
        boyAsset = 'assets/images/ui/adventurer/hero_white.png';
        girlAsset = 'assets/images/ui/adventurer/hero_white.png';
        break;
      case AgeBand.explorer:
      default:
        boyAsset = 'assets/images/ui/explorer/boy_character_white.png';
        girlAsset = 'assets/images/ui/explorer/girl_character_white.png';
    }

    final gender = widget.wizardData.characterGender;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _GenderImageButton(
          gender: 'Boy',
          assetPath: boyAsset,
          isSelected: gender == 'Boy',
          width: 140,
          height: 180,
          onTap: () => _handleGenderSelection('Boy'),
        ),
        SizedBox(width: band.space(32)),
        _GenderImageButton(
          gender: 'Girl',
          assetPath: girlAsset,
          isSelected: gender == 'Girl',
          width: 140,
          height: 180,
          onTap: () => _handleGenderSelection('Girl'),
        ),
      ],
    );
  }

  void _handleGenderSelection(String gender) {
    setState(() => widget.wizardData.characterGender = gender);
    _heroNextPage();
  }

  Widget _buildNameScrollInput() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final nameFontSize = band.headingScale * 20;
    final isSproutFour = widget.wizardData.characterAge <= 4;

    if (band.band.isMature) {
      return TextField(
        controller: _nameController,
        focusNode: _nameFocusNode,
        textAlign: TextAlign.center,
        style: GoogleFonts.sourceSans3(
          fontSize: nameFontSize,
          color: Colors.white70,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Character name',
          hintStyle: const TextStyle(color: Colors.white30),
          filled: true,
          fillColor: Colors.white.withAlpha(10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(band.buttonRadiusBase),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(band.buttonRadiusBase),
            borderSide: const BorderSide(color: Color(0xFF7C4DFF)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (v) =>
            setState(() => widget.wizardData.characterName = v.trim()),
      );
    }

    if (isSproutFour) {
      final isListening = _listeningFor == 'name';
      final typedName = widget.wizardData.characterName;
      return Column(
        children: [
          // ── Mascot + speech bubble (echo's the name) ───────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BreathingAvatar(
                period: const Duration(milliseconds: 2800),
                glowColor: const Color(0xFFFFD54F),
                child: Image.asset(
                  'assets/images/ui/sprout/girl_character.png',
                  height: 90,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.face_rounded,
                    size: 70,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey(
                        typedName.isEmpty ? '__prompt__' : typedName),
                    constraints: const BoxConstraints(maxWidth: 160),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD54F),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                        bottomLeft: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(38),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      typedName.isEmpty ? "What's your name?" : typedName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: typedName.isEmpty ? 13 : 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF3E2723),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Big mic button — primary input for sprouts
          GestureDetector(
            onTap: () => _toggleListening('name'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isListening
                    ? const Color(0xFFFFD700)
                    : const Color(0xFF7C3FC8),
                boxShadow: [
                  BoxShadow(
                    color: isListening
                        ? const Color(0xFFFFD700).withAlpha(160)
                        : const Color(0xFF9E6CFF).withAlpha(120),
                    blurRadius: isListening ? 28 : 16,
                    spreadRadius: isListening ? 6 : 2,
                  ),
                ],
              ),
              child: Icon(
                isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                size: 44,
                color: isListening ? const Color(0xFF3D0080) : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isListening ? 'Listening…' : 'Tap to say your name!',
            style: GoogleFonts.fredoka(
              color: isListening
                  ? const Color(0xFFFFD700)
                  : Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          // Secondary text field
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF5C1A8C).withAlpha(180),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFFD54F).withAlpha(100),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'or type it here',
                  hintStyle: GoogleFonts.fredoka(
                    color: Colors.white38,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onChanged: (v) {
                  setState(() => widget.wizardData.characterName = v.trim());
                  // Debounced TTS echo: speak the name 600 ms after last keystroke.
                  _nameEchoTimer?.cancel();
                  if (v.trim().isNotEmpty) {
                    _nameEchoTimer = Timer(
                      const Duration(milliseconds: 600),
                      () {
                        if (mounted) {
                          AppTtsService.instance
                              .speak(v.trim(), rateScale: 0.8);
                        }
                      },
                    );
                  }
                },
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          widget.wizardData.characterName.isNotEmpty
              ? "Hi ${widget.wizardData.characterName}!"
              : "Your Hero",
          style: (band.band == AgeBand.creator)
              ? GoogleFonts.sourceSans3(
                  color: const Color(0xFFFFE082).withAlpha(200),
                  fontSize: 14,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                )
              : (band.band == AgeBand.adventurer)
                  ? GoogleFonts.bitter(
                      color: const Color(0xFFFFE082).withAlpha(200),
                      fontSize: 14,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    )
                  : GoogleFonts.cinzelDecorative(
                      color: const Color(0xFFFFE082).withAlpha(200),
                      fontSize: 14,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w600,
                    ),
        ),
        const SizedBox(height: 6),
        _ThemedNameInput(
          controller: _nameController,
          focusNode: _nameFocusNode,
          fontSize: nameFontSize,
          height: 60,
          onChanged: (v) =>
              setState(() => widget.wizardData.characterName = v.trim()),
        ),
      ],
    );
  }

  Widget _buildArchetypeCards() {
    final ageBand = ageBandFromAge(widget.wizardData.characterAge);
    // Sprout/Explorer see 4 age-appropriate archetypes; older bands get all 6.
    final archetypes = CharacterArchetypes.forBand(ageBand);

    // Sprout: 3-card row — one choice per personality type, less overwhelming.
    // Explorer: 2-column grid (has more archetypes).
    if (ageBand == AgeBand.sprout) {
      return Row(
        children: List.generate(archetypes.length, (index) {
          final a = archetypes[index];
          final isSelected = _selectedArchetypeId == a.name;

          Widget card = Semantics(
            button: true,
            selected: isSelected,
            label: 'Role: ${a.name}',
            hint: isSelected
                ? 'Currently selected. Double tap to keep this role.'
                : 'Double tap to select this role for your hero.',
            child: AspectRatio(
              aspectRatio: 0.85,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFFD700) : Colors.white24,
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: const Color(0xFFFFD700).withAlpha(100), blurRadius: 12)]
                      : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: const Color(0xFF1A0A2E)),
                      if (a.imagePathForBand(ageBand) != null)
                        Image.asset(a.imagePathForBand(ageBand)!, fit: BoxFit.cover, alignment: Alignment.topCenter)
                      else
                        Icon(Icons.star, color: const Color(0xFFFFD700), size: 40),
                      Positioned(
                        bottom: 4, left: 4, right: 4,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(150),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              a.nameForAge(widget.wizardData.characterAge),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.fredoka(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          card = BounceOnTapWidget(
            onTap: () => _selectArchetype(a),
            child: isSelected
                ? card
                : WiggleWidget(
                    repeat: true,
                    angle: 0.04,
                    duration: const Duration(milliseconds: 700),
                    delayMs: index * 300,
                    child: card,
                  ),
          );

          return index == 0
              ? Expanded(child: card)
              : Expanded(child: Padding(padding: const EdgeInsets.only(left: 10), child: card));
        }),
      );
    }

    if (ageBand == AgeBand.explorer) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: archetypes.length,
        itemBuilder: (context, index) {
          final a = archetypes[index];
          final isSelected = _selectedArchetypeId == a.name;
          const isSprout = false;

          Widget card = Semantics(
            button: true,
            selected: isSelected,
            label: 'Role: ${a.name}',
            hint: isSelected
                ? 'Currently selected. Double tap to keep this role.'
                : 'Double tap to select this role for your hero.',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color:
                      isSelected ? const Color(0xFFFFD700) : Colors.white24,
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: const Color(0xFFFFD700).withAlpha(100),
                            blurRadius: 12)
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background + illustration fills the whole card.
                    Container(color: const Color(0xFF1A0A2E)),
                    if (a.imagePathForBand(ageBand) != null)
                      Image.asset(
                        a.imagePathForBand(ageBand)!,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                      )
                    else
                      Center(
                        child: Text(
                          a.icon ?? '✨',
                          style: const TextStyle(fontSize: 72),
                        ),
                      ),
                    // Selection checkmark.
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFD700),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(Icons.check,
                              size: 16, color: Colors.black),
                        ),
                      ),
                    // Small pill label at bottom — overlay, not separate bar.
                    Positioned(
                      bottom: 4,
                      left: 6,
                      right: 6,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(140),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            a.nameForAge(widget.wizardData.characterAge),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.fredoka(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          card = GestureDetector(onTap: () => _selectArchetype(a), child: card);

          return card;
        },
      );
    }

    // Adventurer & Creator: horizontal list — image-dominant cards with name overlay.
    final showDescriptions =
        ageBand == AgeBand.adventurer || ageBand == AgeBand.creator;
    const cardWidth = 165.0;
    const cardHeight = 220.0;
    final selectedIndex =
        archetypes.indexWhere((a) => a.name == _selectedArchetypeId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
      SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: archetypes.length,
        itemBuilder: (context, index) {
          final a = archetypes[index];
          final isSelected = _selectedArchetypeId == a.name;
          return Semantics(
            button: true,
            selected: isSelected,
            label: 'Role: ${a.name}',
            hint: isSelected
                ? 'Currently selected. Double tap to keep this role.'
                : 'Double tap to select this role for your hero.',
            child: GestureDetector(
              onTap: () => _selectArchetype(a),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: cardWidth,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color:
                        isSelected ? const Color(0xFFFFD700) : Colors.white24,
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: const Color(0xFFFFD700).withAlpha(100),
                              blurRadius: 12)
                        ]
                      : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: const Color(0xFF1A0A2E)),
                      if (a.imagePathForBand(ageBand) != null)
                        Image.asset(a.imagePathForBand(ageBand)!,
                            fit: BoxFit.contain, alignment: Alignment.center)
                      else
                        Container(
                          color: Colors.white10,
                          child: Center(
                              child: Text(a.icon ?? '✨',
                                  style: const TextStyle(fontSize: 64))),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withAlpha(210),
                                Colors.transparent
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                a.nameForAge(widget.wizardData.characterAge),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.fredoka(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold),
                              ),
                              if (showDescriptions) ...[
                                const SizedBox(height: 2),
                                Text(
                                  a.descriptionForAge(widget.wizardData.characterAge),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFD700),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(3),
                            child: const Icon(Icons.check,
                                size: 16, color: Colors.black),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(archetypes.length, (i) {
          final isActive = i == selectedIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFFFD700)
                  : Colors.white30,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
      ],
    );
  }

  void _toggleListening(String field) async {
    if (!_speechAvailable) {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listeningFor = '');
          }
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => _listeningFor = '');
        },
      );
      if (!mounted) return;
      setState(() => _speechAvailable = available);
      if (!available) {
        if (field == 'imagine') {
          unawaited(AppTtsService.instance
              .speak('Microphone is unavailable. Please type your idea.'));
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Microphone unavailable on this device')),
        );
        return;
      }
    }

    if (_listeningFor == field) {
      await _speech.stop();
      setState(() => _listeningFor = '');
      return;
    }

    if (field == 'imagine') {
      unawaited(AppTtsService.instance
          .speak('Tell me where your adventure takes place.'));
    } else if (field == 'name') {
      final name = widget.wizardData.characterName;
      if (name.isNotEmpty) {
        unawaited(
            AppTtsService.instance.speak('What is the hero name for $name?'));
      } else {
        unawaited(AppTtsService.instance.speak("What is your hero's name?"));
      }
    }

    setState(() => _listeningFor = field);
    await _speech.listen(
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (result) {
        if (!mounted) return;
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;
        setState(() {
          if (field == 'name') {
            _nameController.text = words;
            widget.wizardData.characterName = words;
          } else if (field == 'superpower') {
            _superpowerController.text = words;
            widget.wizardData.heroSuperpower = words;
          } else if (field == 'imagine') {
            _imagineItController.text = words;
            _wishController.text = words;
            widget.wizardData.customElements = words;
          } else if (field == 'wish') {
            _wishController.text = words;
            _imagineItController.text = words;
            widget.wizardData.customElements = words;
          } else if (field == 'friend') {
            _friendNameController.text = words;
            if (result.finalResult && words.isNotEmpty) _addFriendByName();
          } else {
            _questController.text = words;
            widget.wizardData.heroQuest = words;
          }
          if (result.finalResult) {
          _listeningFor = '';
          // Sprout: read back the name so young kids hear confirmation
          if (field == 'name' && words.isNotEmpty) {
            final bandData = Theme.of(context).extension<AgeBandThemeData>();
            if (bandData?.band == AgeBand.sprout) {
              final firstName = words.split(' ').first;
              unawaited(AppTtsService.instance
                  .speak('Hi $firstName! That\'s a lovely name!'));
            }
          }
        }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bandData =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final isTeen = bandData.band.isMature;

    final showMagicCursor =
        bandData.band == AgeBand.sprout || bandData.band == AgeBand.explorer;

    Widget content = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF120226), Color(0xFF3D1166), Color(0xFF120226)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            if (isTeen)
              _buildCreativeBrief()
            else
              PageView(
                controller: _heroPageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPage0(),
                  _buildPage1(),
                  _buildPage2(),
                  _buildPage3(),
                  _buildPage4Companions(),
                  _buildPage5(),
                  _buildPage6(),
                ],
              ),
            if (!isTeen && _heroPage > 0)
              Positioned(
                top: 10,
                left: 10,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                  onPressed: _heroPrevPage,
                ),
              ),
          ],
        ),
      ),
    );

    if (showMagicCursor) {
      return MagicStarCursor(child: content);
    }
    return content;
  }

  // ─── Creative Brief (Teen Flow) ─────────────────────────────────────────────

  Widget _buildCreativeBrief() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBriefHeader(band),
          const SizedBox(height: 16),
          _buildRestoreCharacterSection(),
          const SizedBox(height: 16),
          _buildBriefSection(
              'Character & Role', _buildBriefIdentityInputs(),
              initiallyExpanded: true),
          _buildBriefSection(
              'Personality', _buildBriefPersonalitySliders()),
          _buildBriefSection(
              'World & Setting', _buildBriefWorldInputs()),
          _buildBriefSection('Story Options', _buildBriefConfigInputs()),
          const SizedBox(height: 48),
          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
                child: Text(
                  'Create Story',
                  style: GoogleFonts.sourceSans3(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBriefHeader(AgeBandThemeData band) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Build Your Story',
          style: GoogleFonts.sourceSans3(
            color: const Color(0xFFFFD700),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 4.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Define the parameters of your experience.',
          style: GoogleFonts.sourceSans3(
            color: Colors.white70,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        const Divider(color: Color(0xFFFFD700), thickness: 2, endIndent: 200),
      ],
    );
  }

  Widget _buildBriefSection(String title, Widget content,
      {bool initiallyExpanded = false}) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 16),
        title: Text(
          title.toUpperCase(),
          style: GoogleFonts.sourceSans3(
            color: const Color(0xFFFFD700).withAlpha(180),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        iconColor: const Color(0xFFFFD700),
        collapsedIconColor: Colors.white30,
        children: [content],
      ),
    );
  }

  Widget _buildRestoreCharacterSection() {
    if (widget.availableCharacters.isEmpty) return const SizedBox.shrink();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          'RESTORE PREVIOUS CHARACTER',
          style: GoogleFonts.sourceSans3(
            color: const Color(0xFFFFD700),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        subtitle: Text('Load an existing hero profile',
            style: TextStyle(
                color: Colors.white.withAlpha(80), fontSize: 10, height: 1.5)),
        iconColor: const Color(0xFFFFD700),
        collapsedIconColor: const Color(0xFFFFD700),
        children: widget.availableCharacters.map((char) {
          final avatarData = char.generatedAvatar?.imageBase64;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF3A2363),
              backgroundImage: avatarData != null
                  ? _getAvatarProvider(avatarData)
                  : const AssetImage('assets/images/hero_placeholder.jpg')
                      as ImageProvider,
            ),
            title: Text(char.name,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text(char.role,
                style: TextStyle(
                    color: Colors.white.withAlpha(100), fontSize: 11)),
            trailing: const Icon(Icons.file_upload_outlined,
                color: Color(0xFFFFD700), size: 18),
            onTap: () {
              setState(() {
                _loadExistingCharacter(char);
                _nameController.text = char.name;
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBriefGenderSelector() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final ageBand = band.band;

    final String boyAsset;
    final String girlAsset;
    switch (ageBand) {
      case AgeBand.adolescent:
        boyAsset = 'assets/images/ui/adolescent/boy_character.png';
        girlAsset = 'assets/images/ui/adolescent/girl_character.png';
        break;
      case AgeBand.adult:
        boyAsset = 'assets/images/ui/adult/man_character_white.png';
        girlAsset = 'assets/images/ui/adult/woman_character_white.png';
        break;
      default:
        boyAsset = 'assets/images/ui/creator/creator_white.png';
        girlAsset = 'assets/images/ui/creator/creator_white.png';
    }

    final gender = widget.wizardData.characterGender;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHARACTER GENDER',
          style: GoogleFonts.sourceSans3(
            color: Colors.white.withAlpha(100),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GenderImageButton(
              gender: 'Boy',
              assetPath: boyAsset,
              isSelected: gender == 'Boy',
              width: 110,
              height: 140,
              onTap: () =>
                  setState(() => widget.wizardData.characterGender = 'Boy'),
            ),
            const SizedBox(width: 32),
            _GenderImageButton(
              gender: 'Girl',
              assetPath: girlAsset,
              isSelected: gender == 'Girl',
              width: 110,
              height: 140,
              onTap: () =>
                  setState(() => widget.wizardData.characterGender = 'Girl'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBriefIdentityInputs() {
    final isCreator =
        ageBandFromAge(widget.wizardData.characterAge) == AgeBand.creator;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          style: GoogleFonts.sourceSans3(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            labelText: 'PROTAGONIST NAME',
            labelStyle: GoogleFonts.sourceSans3(
                color: const Color(0xFFFFD700), fontSize: 10),
            hintText: 'Enter name...',
            hintStyle: TextStyle(color: Colors.white.withAlpha(40)),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withAlpha(40))),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFFFD700))),
          ),
          onChanged: (v) => widget.wizardData.characterName = v,
        ),
        // Creator band: identity reflection prompt
        if (isCreator) ...[
          const SizedBox(height: 20),
          Text(
            'What does your character want more than anything?',
            style: GoogleFonts.bitter(
              color: Colors.white54,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _characterDesireController,
            style: GoogleFonts.sourceSans3(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Optional — adds depth to your story',
              hintStyle: TextStyle(color: Colors.white.withAlpha(35), fontSize: 14),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withAlpha(30))),
              focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF7C4DFF))),
            ),
            onChanged: (v) => widget.wizardData.characterDesire = v.trim().isEmpty ? null : v,
          ),
        ],
        const SizedBox(height: 24),
        _buildBriefGenderSelector(),
        const SizedBox(height: 24),
        Text(
          'CORE ARCHETYPE',
          style: GoogleFonts.sourceSans3(
              color: Colors.white.withAlpha(100),
              fontSize: 10,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Wrap FilterChips in a Theme override so they render with dark
        // backgrounds — the global ThemeData.light() base would otherwise
        // produce light chip backgrounds with invisible white label text.
        // labelStyle is intentionally omitted: setting it in ChipThemeData
        // overrides the explicit Text(style:) inside each chip's label,
        // producing white-on-white invisible text. Text styling is handled
        // entirely by the Text widget inside each FilterChip.label.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CharacterArchetypes.forBand(ageBandFromAge(widget.wizardData.characterAge)).map((archetype) {
            final isSelected = _selectedArchetypeId == archetype.name;
            return FilterChip(
              label: Text(
                archetype.nameForAge(widget.wizardData.characterAge).toUpperCase(),
                style: GoogleFonts.sourceSans3(
                  color: isSelected ? const Color(0xFFFFD700) : Colors.white70,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => _selectArchetype(archetype),
              // M3 ignores backgroundColor in ChipThemeData; set color directly.
              color: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFFFFD700).withAlpha(50);
                }
                return const Color(0xFF1A0A2E);
              }),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                    color: isSelected
                        ? const Color(0xFFFFD700)
                        : Colors.white.withAlpha(60)),
              ),
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBriefPersonalitySliders() {
    final sliders = widget.wizardData.personalitySliders;
    final age = widget.wizardData.characterAge;

    // Helper to find the definition from our central data store
    PersonalitySliderDefinition def(String key) =>
        CharacterTraitsData.personalitySliders.firstWhere(
          (s) => s.key == key,
          orElse: () => CharacterTraitsData.personalitySliders.first,
        );

    return Column(
      children: [
        _buildBriefSlider(
          'Energy Level',
          def('expressiveness').leftLabelForAge(age),
          def('expressiveness').rightLabelForAge(age),
          'expressiveness',
          sliders,
        ),
        _buildBriefSlider(
          'Social Style',
          def('sociability').leftLabelForAge(age),
          def('sociability').rightLabelForAge(age),
          'sociability',
          sliders,
        ),
        _buildBriefSlider(
          'CONSTRUCTIVE LOGIC',
          def('problem_solving').leftLabelForAge(age),
          def('problem_solving').rightLabelForAge(age),
          'problem_solving',
          sliders,
        ),
        _buildBriefSlider(
          'ADVENTURE TOLERANCE',
          def('adventure').leftLabelForAge(age),
          def('adventure').rightLabelForAge(age),
          'adventure',
          sliders,
        ),
      ],
    );
  }

  Widget _buildBriefSlider(String label, String left, String right, String key,
      Map<String, int> sliders) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.sourceSans3(
                  color: Colors.white.withAlpha(80),
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
          Row(
            children: [
              Text(left,
                  style: GoogleFonts.sourceSans3(
                      color: Colors.white70, fontSize: 10)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFFFD700),
                    inactiveTrackColor: Colors.white12,
                    thumbColor: const Color(0xFFFFD700),
                    overlayColor: const Color(0xFFFFD700).withAlpha(32),
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: (sliders[key] ?? 50).toDouble(),
                    min: 0,
                    max: 100,
                    onChanged: (v) => setState(() => sliders[key] = v.round()),
                  ),
                ),
              ),
              Text(right,
                  style: GoogleFonts.sourceSans3(
                      color: Colors.white70, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBriefWorldInputs() {
    final scenarios =
        ScenarioData.all.where((s) => s.id != 'safe_space').toList();
    final isCustom = widget.wizardData.selectedScenario == 'safe_space';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRIMARY SETTING',
          style: GoogleFonts.sourceSans3(
              color: Colors.white.withAlpha(100),
              fontSize: 10,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...scenarios.map((s) {
              final isSelected = widget.wizardData.selectedScenario == s.id;
              return ChoiceChip(
                label: Text(s.titleForAge(15).toUpperCase()),
                selected: isSelected,
                onSelected: (v) => setState(
                    () => widget.wizardData.selectedScenario = v ? s.id : null),
                // M3 ignores backgroundColor; use color with WidgetStateProperty.
                color: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFFFFD700).withAlpha(40);
                  }
                  return const Color(0xFF1A0A2E);
                }),
                labelStyle: GoogleFonts.sourceSans3(
                  color: isSelected ? const Color(0xFFFFD700) : Colors.white70,
                  fontSize: 10,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                        color: isSelected
                            ? const Color(0xFFFFD700)
                            : Colors.white.withAlpha(40))),
              );
            }),
            ChoiceChip(
              label: Text('CUSTOM PREMISE',
                  style: GoogleFonts.sourceSans3(
                    color: isCustom ? const Color(0xFFFFD700) : Colors.white70,
                    fontSize: 10,
                  )),
              selected: isCustom,
              onSelected: (v) => setState(() =>
                  widget.wizardData.selectedScenario = v ? 'safe_space' : null),
              color: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFFFFD700).withAlpha(40);
                }
                return const Color(0xFF1A0A2E);
              }),
              labelStyle: GoogleFonts.sourceSans3(
                color: isCustom ? const Color(0xFFFFD700) : Colors.white70,
                fontSize: 10,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                      color: isCustom
                          ? const Color(0xFFFFD700)
                          : Colors.white.withAlpha(40))),
            ),
          ],
        ),
        if (isCustom) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _imagineItController,
            maxLines: 2,
            style: GoogleFonts.sourceSans3(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Describe your world or premise...',
              hintStyle: TextStyle(
                  color: Colors.white.withAlpha(40),
                  fontStyle: FontStyle.italic),
              filled: true,
              fillColor: Colors.white.withAlpha(10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            onChanged: (v) {
              widget.wizardData.customElements = v;
              _wishController.text = v;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildBriefConfigInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildBriefDropdown(
                'NARRATIVE MODE',
                widget.wizardData.interactiveMode
                    ? 'Interactive'
                    : (widget.wizardData.rhymeTimeMode
                        ? 'Poetry'
                        : 'Standard View'),
                ['Standard View', 'Interactive', 'Poetry'],
                (v) {
                  setState(() {
                    widget.wizardData.interactiveMode = v == 'Interactive';
                    widget.wizardData.rhymeTimeMode = v == 'Poetry';
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildBriefDropdown(
                'TARGET DURATION',
                widget.wizardData.storyLength.toUpperCase(),
                ['SHORT', 'MEDIUM', 'LONG'],
                (v) => setState(
                    () => widget.wizardData.storyLength = v!.toLowerCase()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBriefDropdown(String label, String value, List<String> options,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.sourceSans3(
                color: Colors.white.withAlpha(80),
                fontSize: 9,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.contains(value) ? value : options.first,
              dropdownColor: const Color(0xFF2C1B47),
              isExpanded: true,
              style: GoogleFonts.sourceSans3(color: Colors.white, fontSize: 12),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Color(0xFFFFD700), size: 18),
              onChanged: onChanged,
              items: options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  ImageProvider<Object> _getAvatarProvider(String imageBase64) {
    if (imageBase64.startsWith('assets/')) {
      return AssetImage(imageBase64);
    }
    if (imageBase64.startsWith('http')) {
      return NetworkImage(imageBase64);
    }
    try {
      final normalized =
          imageBase64.contains(',') ? imageBase64.split(',').last : imageBase64;
      return MemoryImage(base64Decode(normalized));
    } catch (_) {
      return const AssetImage('assets/images/hero_placeholder.jpg');
    }
  }

  // ─── Sprout TTS helpers ───────────────────────────────────────────────────

  /// Speaks a prompt only for young children (age ≤ 5 / sprout band).
  Future<void> _speakForSprout(String text) async {
    if (widget.wizardData.characterAge > 5) return;
    // Cancel any in-flight audio before starting a new clip.
    await AppTtsService.instance.stop();
    if (!mounted) return;
    unawaited(AppTtsService.instance.speak(text, rateScale: 0.8));
  }

  Future<void> _speakPagePrompt(int page) async {
    final age = widget.wizardData.characterAge;
    if (age <= 5) {
      // Sprout — full guided TTS on every page
      final prompt = switch (page) {
        1 => "What is your hero's name? Tap the microphone to say it!",
        2 => "Pick your hero's look! Tap Choose Look to pick one.",
        3 => "Who is your hero? Tap the one you like!",
        4 => "Tap your buddies to bring them along!",
        5 => "Where should we go? Tap the picture you want.",
        6 => "You are all set! Tap Make Magic!",
        _ => null,
      };
      if (prompt != null) await _speakForSprout(prompt);
    } else {
      // Older bands — warm narrator voice on archetype + companion pages only
      final prompt = switch (page) {
        3 => "Choose your hero's path!",
        4 => "Who will join you on your quest?",
        _ => null,
      };
      if (prompt != null) {
        await AppTtsService.instance.stop();
        if (mounted) {
          unawaited(AppTtsService.instance.speak(prompt));
        }
      }
    }
  }

  String? _sceneLabel(String id) => switch (id) {
        'safe_space' || 'imagine_it' => 'Make One Up!',
        'vanishing_colors' => 'Rainbow World!',
        'crystal_cavern' => 'Cave Full of Crystals!',
        'volcano_dragons' => 'Friendly Dragons!',
        'big_feelings_quest' => 'Big Feelings!',
        _ => null,
      };
}

// ─── Support Widgets ──────────────────────────────────────────────────────────

class _CharacterChoiceCard extends StatelessWidget {
  final Character character;
  final VoidCallback onTap;
  final ImageProvider<Object> Function(String) getAvatarProvider;

  const _CharacterChoiceCard(
      {required this.character,
      required this.onTap,
      required this.getAvatarProvider});

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final avatarData = character.generatedAvatar?.imageBase64;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD4A0FF).withAlpha(100)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: const Color(0xFF3A2363),
              backgroundImage: avatarData != null
                  ? getAvatarProvider(avatarData)
                  : const AssetImage('assets/images/hero_placeholder.jpg')
                      as ImageProvider,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Is this ${character.name}?",
                    style: GoogleFonts.fredoka(
                      color: const Color(0xFFFFD700),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    character.name,
                    style: band.band == AgeBand.creator
                        ? GoogleFonts.sourceSans3(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)
                        : band.band == AgeBand.adventurer
                            ? GoogleFonts.bitter(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)
                            : GoogleFonts.cinzelDecorative(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                  ),
                  Text("${character.age} years old • ${character.role}",
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.play_circle_fill_rounded,
                color: Color(0xFFFFD700), size: 40),
          ],
        ),
      ),
    );
  }
}

// ─── Section Classes (Move static data here) ──────────────────────────────────
class HeroCreatorStepData {
  static const superpowers = [
    ('⚡ Brave Heart', 'Brave Heart'),
    ('💛 Kindness Magic', 'Kindness Magic'),
    ('🧠 Problem-Solver Brain', 'Problem-Solver Brain'),
    ('🤝 Helping Hands', 'Helping Hands'),
    ('🌟 Creative Spark', 'Creative Spark'),
    ('👂 Super Listener', 'Super Listener'),
  ];
  static const quests = [
    ('🤝 Making new friends', 'Making new friends'),
    ('🌊 Taming big feelings', 'Taming big feelings'),
    ('🦁 Being brave when scared', 'Being brave when scared'),
    ('🎁 Sharing and taking turns', 'Sharing and taking turns'),
    ('🌱 Trying something new', 'Trying something new'),
    ("🦸 Standing up for what's right", "Standing up for what's right"),
  ];
}

// ── Companion Image Grid ─────────────────────────────────────────────────────

// Each companion has a fixed personality that stays consistent across stories.
class _CompanionData {
  final String id;
  final String name;
  final String tagline;
  final String personality; // Sent to AI prompt so quirks stay consistent
  /// Explicit asset path — bypasses the `_normal.jpg` convention.
  /// Required for companions whose assets don't follow the standard naming.
  final String? imagePathOverride;
  /// Background colour shown inside the circle behind the companion image.
  final Color? backgroundColor;
  const _CompanionData({
    required this.id,
    required this.name,
    required this.tagline,
    this.personality = '',
    this.imagePathOverride,
    this.backgroundColor,
  });

  String get imagePath =>
      imagePathOverride ?? 'assets/images/companions/${id}_normal.jpg';
}

/// Data carrier for a showcase orb slot.
class _ShowcaseSlot {
  final String? id;
  final String? imagePath;
  final String? photoBase64;
  final String name;
  final bool isFriend; // true = saved character (not a magic companion or pet)
  const _ShowcaseSlot({
    this.id,
    this.imagePath,
    this.photoBase64,
    required this.name,
    this.isFriend = false,
  });
}

/// A large glowing circle that shows a companion portrait (or empty placeholder).
class _GlowingCompanionOrb extends StatelessWidget {
  final _ShowcaseSlot? slot;
  final VoidCallback? onTap;

  const _GlowingCompanionOrb({this.slot, this.onTap});

  static const double _size = 90.0;

  @override
  Widget build(BuildContext context) {
    final filled = slot != null;

    Widget inner;
    if (!filled) {
      inner = const Icon(Icons.add_rounded, color: Colors.white24, size: 32);
    } else if (slot!.photoBase64 != null && slot!.photoBase64!.isNotEmpty) {
      // Pet photo or friend avatar (base64)
      final raw = slot!.photoBase64!;
      final bytes = base64Decode(raw.contains(',') ? raw.split(',').last : raw);
      inner =
          Image.memory(bytes, width: _size, height: _size, fit: BoxFit.cover);
    } else if (slot!.isFriend) {
      // Saved character with no avatar image yet — use a person placeholder
      inner = const Icon(Icons.person_rounded, color: Colors.white70, size: 44);
    } else {
      inner = Image.asset(
        slot!.imagePath ?? '',
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.pets, color: Colors.white54, size: 36),
      );
    }

    return GestureDetector(
      onTap: filled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: _size + 12,
        height: _size + 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: filled ? const Color(0xFFFFD700) : Colors.white24,
            width: filled ? 3 : 2,
          ),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withAlpha(160),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFFD700).withAlpha(60),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ]
              : [],
          color: filled ? null : Colors.white.withAlpha(8),
        ),
        child: ClipOval(
          clipBehavior: Clip.antiAlias,
          child: filled
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    inner,
                    // Subtle gold overlay tint
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.transparent,
                            const Color(0xFFFFD700).withAlpha(30),
                          ],
                        ),
                      ),
                    ),
                    // "Tap to remove" hint on top-right
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFD700),
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.black, size: 12),
                      ),
                    ),
                  ],
                )
              : Center(child: inner),
        ),
      ),
    );
  }
}

/// Sprouts (3–5) see only 4 age-appropriate companions with band-specific images.
const _sproutCompanions = [
  _CompanionData(
    id: 'sprout/fluffy_dragon',
    name: 'Fluffy Dragon',
    tagline: 'Brave hugs and sparkly sneezes.',
    imagePathOverride: 'assets/images/companions/sprout/fluffy_dragon.png',
    backgroundColor: Color(0xFF7E57C2), // soft purple
  ),
  _CompanionData(
    id: 'sprout/magic_bunny',
    name: 'Magic Bunny',
    tagline: 'Boing! Your silly, soft best friend.',
    imagePathOverride: 'assets/images/companions/sprout/magic_bunny.png',
    backgroundColor: Color(0xFFEC407A), // soft pink
  ),
  _CompanionData(
    id: 'sprout/shining_puppy',
    name: 'Shining Puppy',
    tagline: 'Glowy tail. Always there for you.',
    imagePathOverride: 'assets/images/companions/sprout/shining_puppy.png',
    backgroundColor: Color(0xFFF9A825), // warm gold
  ),
  _CompanionData(
    id: 'sprout/robin',
    name: 'Robin',
    tagline: 'Tiny bird, very loud love.',
    imagePathOverride: 'assets/images/companions/sprout/robin.png',
    backgroundColor: Color(0xFF388E3C), // forest green
  ),
];

const _companions = [
  _CompanionData(
    id: 'dragon',
    name: 'Dragon',
    tagline: 'Big courage. Bigger heart.',
    personality:
        'Dragon (Brave Protector) stands between you and danger, voice steady and brave. She turns fear into a plan and protects you without making you feel small. Gets extra polite right before getting fierce. Hoards tiny treasures like pebbles and buttons as if they\'re priceless. Catchphrases: "Behind me." / "We\'ve got this."',
  ),
  _CompanionData(
    id: 'owl',
    name: 'Wise Owl',
    tagline: 'Quiet mind, clear sight.',
    personality:
        'Wise Owl (Pattern Seer) watches silently, then names what matters. She spots patterns others miss and offers one clear, calm next step. Speaks in short verdicts — "Noted." "Risky." "Better." Will not be rushed; slows the scene down when emotions spike. Catchphrases: "Look again." / "Follow the pattern."',
  ),
  _CompanionData(
    id: 'cat',
    name: 'Shadow Cat',
    tagline: 'Soft paws. Strong boundaries.',
    personality:
        'Shadow Cat (Boundary Guardian) keeps you calm and untangled. She helps you say no, spot pressure, and choose the cleanest way out. Appears exactly when someone is being manipulative. Purrs like a reset button — breathing steadies when she purrs. Disappears mid-drama, then reappears with the perfect exit route. Catchphrases: "No is complete." / "We leave—now."',
  ),
  _CompanionData(
    id: 'dog',
    name: 'Star Dog',
    tagline: 'Light up. Keep going.',
    personality:
        'Star Dog (Hope Engine) stays close and lifts your mood fast. He guides you with sparkle-trails and helps you take the next step even when you\'re scared. Sniffs out the most trustworthy person in a room and stands by them. If you freeze, he does something goofy to break the spell of fear. Catchphrases: "One more step!" / "I\'m right here!"',
  ),
  _CompanionData(
    id: 'unicorn',
    name: 'Unicorn',
    tagline: 'Kindness that makes you stronger.',
    personality:
        'Unicorn (Gentle Healer) brings calm, warmth, and healing. She helps you breathe, name feelings gently, and rebuild confidence without pressure. Horn glow tunes to emotion — soft light for sadness, bright for courage. Refuses shame stories and rewrites self-talk in simple words. Catchphrases: "You are safe." / "You are not broken."',
  ),
  _CompanionData(
    id: 'fox',
    name: 'Clever Fox',
    tagline: 'Smart paths, sneaky wins.',
    personality:
        'Clever Fox (Strategic Trickster) finds the loophole, the shortcut, the trick that stays fair. He turns obstacles into puzzles and makes you feel capable. Treats problems like games and always offers two clever options. Loves codes, riddles, hidden doors, and rules-lawyering bad guys. Catchphrases: "Watch this." / "Rules didn\'t say I can\'t."',
  ),
  _CompanionData(
    id: 'robin',
    name: 'Robin',
    tagline: 'Overprotective. Loud about it. Loves you completely.',
    personality:
        'Robin (Guardian) is overprotective and not remotely sorry about it. She scouts ahead of every step, physically bats away anything she decides is a threat — which is often — and is extremely loud when alarmed. Three sharp chirps: stop. One long note: safe. She has been wrong before and does not slow down. Through all the shrieking and wing-flapping it is completely obvious how much she loves the hero. She brings small gifts when things calm down: a bright berry, a warm feather from her own chest. Her protectiveness is not performance. It is love at full volume. Catchphrases: "NO. Back. NOW." / "I handled it." / "(soft) You\'re okay. I\'ve got you."',
  ),
];

class _CompanionImageGrid extends StatelessWidget {
  final WizardData wizardData;
  final VoidCallback onChanged;
  final void Function(String name)? onCompanionTapped;
  /// Maximum companions selectable at once. Sprout = 1, others = 3.
  final int maxCompanions;

  const _CompanionImageGrid({
    required this.wizardData,
    required this.onChanged,
    this.onCompanionTapped,
    this.maxCompanions = 3,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final band =
          Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
      final naturalSize = (band.touchTargetMin / 64.0 * 100).roundToDouble();

      // Calculate the size that fits perRow items without overflow.
      // Each button renders at (size + 8) and each item is wrapped in
      // horizontal padding of hSpacing / 2 on both sides.
      const perRow = 4;
      const hSpacing = 8.0;
      const buttonWidthExtra = 8.0;
      final itemSize = ((constraints.maxWidth -
                  perRow * buttonWidthExtra -
                  perRow * hSpacing) /
              perRow)
          .floorToDouble()
          .clamp(40.0, naturalSize);

      // Sprouts see only their 4 age-appropriate companions; all other bands
      // see the full general companion roster.
      final companionList = band.band == AgeBand.sprout
          ? _sproutCompanions
          : _companions;

      // Build companion buttons with a uniform, pre-calculated size.
      List<Widget> buttons = companionList.map((c) {
        final isSelected = wizardData.companionNames.contains(c.name) ||
            wizardData.selectedCompanions.contains(c.id);
        return _CompanionImageButton(
          id: c.id,
          name: c.name,
          tagline: c.tagline,
          isSelected: isSelected,
          size: itemSize,
          imagePath: c.imagePath,
          backgroundColor: c.backgroundColor,
          onTap: () {
            if (isSelected) {
              wizardData.companionNames.remove(c.name);
              wizardData.selectedCompanions.remove(c.id);
            } else {
              if (maxCompanions == 1) {
                // Radio-button behaviour: replace the existing pick instantly
                wizardData.companionNames.clear();
                wizardData.selectedCompanions.clear();
              }
              if (wizardData.companionNames.length < maxCompanions) {
                wizardData.companionNames.add(c.name);
                wizardData.selectedCompanions.add(c.id);
                onCompanionTapped?.call(c.name);
              }
            }
            onChanged();
          },
        );
      }).toList();

      // Add saved pets as selectable companion buttons.
      for (int i = 0; i < wizardData.pets.length; i++) {
        final petEntry = wizardData.pets[i];
        final petName = (petEntry['name'] ?? '').trim().isEmpty
            ? 'My Pet ${i + 1}'
            : petEntry['name']!;
        final petId = 'my_pet_$i';
        final isSelected = wizardData.companionNames.contains(petName);
        buttons.add(_CompanionImageButton(
          id: petId,
          name: petName,
          tagline: '${petEntry['color'] ?? ''} ${petEntry['species'] ?? 'pet'}'
              .trim(),
          isSelected: isSelected,
          photoBase64: wizardData.petAvatars[petName]?.imageBase64 ??
              wizardData.petPhotos[petName],
          size: itemSize,
          onTap: () {
            if (isSelected) {
              wizardData.companionNames.remove(petName);
              wizardData.selectedCompanions.remove(petId);
            } else {
              wizardData.companionNames.add(petName);
              if (!wizardData.selectedCompanions.contains(petId)) {
                wizardData.selectedCompanions.add(petId);
              }
              onCompanionTapped?.call(petName);
            }
            onChanged();
          },
        ));
      }

      // Pyramid layout: rows of perRow, remainder centered.
      // All items use the same calculated size so every row is consistent.
      final rows = <Widget>[];
      for (int i = 0; i < buttons.length; i += perRow) {
        final rowItems = buttons.sublist(
            i, (i + perRow) > buttons.length ? buttons.length : i + perRow);
        rows.add(Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: rowItems
              .map((b) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: hSpacing / 2),
                    child: b,
                  ))
              .toList(),
        ));
        if (i + perRow < buttons.length) rows.add(const SizedBox(height: 12));
      }

      return Column(children: rows);
    });
  }
}

class _CompanionImageButton extends StatefulWidget {
  final String id;
  final String name;
  final String tagline;
  final bool isSelected;
  final VoidCallback onTap;
  final String? photoBase64; // Real pet photo (base64 data URI)
  final double? size; // Override theme-derived size
  /// Override the default image path (used for band-specific companion assets).
  final String? imagePath;
  /// Background colour rendered inside the circle behind the companion image.
  final Color? backgroundColor;

  const _CompanionImageButton({
    required this.id,
    required this.name,
    required this.tagline,
    required this.isSelected,
    required this.onTap,
    this.photoBase64,
    this.size,
    this.imagePath,
    this.backgroundColor,
  });

  @override
  State<_CompanionImageButton> createState() => _CompanionImageButtonState();
}

class _CompanionImageButtonState extends State<_CompanionImageButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  String get _normalImage =>
      widget.imagePath ?? 'assets/images/companions/${widget.id}_normal.jpg';
  // Companions with an explicit imagePath override have no pressed variant — fall back to normal.
  String get _pressedImage =>
      widget.imagePath ?? 'assets/images/companions/${widget.id}_pressed.jpg';

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    // Stagger each companion's float phase using its id hash so they don't
    // all bob in sync.
    _floatCtrl.forward(from: (widget.id.hashCode.abs() % 100) / 100.0);
    _floatAnim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.photoBase64 == null) {
      precacheImage(AssetImage(_normalImage), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final size =
        widget.size ?? (band.touchTargetMin / 64.0 * 100).roundToDouble();

    Widget imageWidget;
    if (widget.photoBase64 != null && widget.photoBase64!.isNotEmpty) {
      // Real pet photo — fill the circle
      final bytes = base64Decode(
          widget.photoBase64!.replaceFirst(RegExp(r'data:[^,]+,'), ''));
      imageWidget =
          Image.memory(bytes, width: size, height: size, fit: BoxFit.cover);
    } else {
      // Use BoxFit.contain when a backgroundColor is set (PNG companions with
      // their own background) so the circle bg shows through transparent edges.
      // Fall back to BoxFit.cover for legacy _normal.jpg companions designed to
      // fill the circle.
      final fit = widget.backgroundColor != null ? BoxFit.contain : BoxFit.cover;
      imageWidget = Image.asset(
        _pressed ? _pressedImage : _normalImage,
        width: size,
        height: size,
        fit: fit,
        frameBuilder: (ctx, child, frame, _) =>
            frame == null ? SizedBox(width: size, height: size) : child,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: const Color(0xFF3A2363),
          child: const Icon(Icons.pets, color: Colors.white54, size: 40),
        ),
      );
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: size + 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _floatAnim,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, widget.isSelected ? 0 : _floatAnim.value),
                  child: child,
                ),
                child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? const Color(0xFF3A2363),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isSelected
                        ? const Color(0xFFFFD700)
                        : Colors.white24,
                    width: widget.isSelected ? 3 : 1.5,
                  ),
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withAlpha(120),
                            blurRadius: 16,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
                child: Stack(
                  children: [
                    ClipOval(clipBehavior: Clip.antiAlias, child: imageWidget),
                    if (widget.isSelected)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFFD700),
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.black, size: 14),
                        ),
                      ),
                  ],
                ),
              ), // AnimatedContainer
              ), // AnimatedBuilder
              const SizedBox(height: 5),
              Text(
                widget.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: widget.isSelected
                      ? const Color(0xFFFFD700)
                      : Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.tagline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: widget.isSelected
                      ? const Color(0xFFFFD700).withAlpha(200)
                      : Colors.white54,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add Pet Photo Button ─────────────────────────────────────────────────────

/// Full pet card — shows "Add Your Pet" prompt when no pet added,
/// or shows the photo + editable name/species/color fields once added.
class _PetCard extends StatefulWidget {
  final WizardData wizardData;
  final Future<void> Function({int? petIndex}) onPickPhoto;
  final VoidCallback onChanged;

  const _PetCard({
    required this.wizardData,
    required this.onPickPhoto,
    required this.onChanged,
  });

  @override
  State<_PetCard> createState() => _PetCardState();
}

class _PetCardState extends State<_PetCard> {
  late TextEditingController _nameCtrl;
  late TextEditingController _colorCtrl;
  String _species = 'Dog';
  int _selectedPetIndex = -1;
  bool _isEditing = false;
  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  String _listeningField = '';

  static const _speciesOptions = [
    'Human',
    'Dog',
    'Cat',
    'Bird',
    'Rabbit',
    'Hamster',
    'Fish',
    'Turtle',
    'Snake',
    'Horse',
    'Guinea Pig',
    'Other',
  ];

  Map<String, String>? get _pet {
    if (_selectedPetIndex < 0 ||
        _selectedPetIndex >= widget.wizardData.pets.length) {
      return null;
    }
    return widget.wizardData.pets[_selectedPetIndex];
  }

  String? get _photo {
    final name = _pet?['name'] ?? 'My Pet';
    return widget.wizardData.petAvatars[name]?.imageBase64 ??
        widget.wizardData.petPhotos[name];
  }

  @override
  void initState() {
    super.initState();
    if (widget.wizardData.pets.isNotEmpty) {
      _selectedPetIndex = 0;
    }
    _nameCtrl = TextEditingController();
    _colorCtrl = TextEditingController();
    _loadFromSelectedPet();
    _initVoiceHelpers();
  }

  @override
  void didUpdateWidget(covariant _PetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedPetIndex >= widget.wizardData.pets.length) {
      _selectedPetIndex = widget.wizardData.pets.isEmpty
          ? -1
          : widget.wizardData.pets.length - 1;
      _loadFromSelectedPet();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _initVoiceHelpers() async {
    _speechReady = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _listeningField = '');
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _listeningField = '');
      },
    );
  }

  Future<void> _speakPrompt(String text) async {
    unawaited(AppTtsService.instance.speak(text));
  }

  Future<void> _toggleVoiceInput({
    required String fieldKey,
    required TextEditingController controller,
    required String prompt,
  }) async {
    if (!_speechReady) {
      unawaited(
          AppTtsService.instance.speak('Microphone is unavailable right now.'));
      return;
    }
    if (_listeningField == fieldKey) {
      await _speech.stop();
      if (mounted) setState(() => _listeningField = '');
      return;
    }

    unawaited(AppTtsService.instance.speak(prompt));
    if (mounted) setState(() => _listeningField = fieldKey);

    await _speech.listen(
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 2),
      onResult: (result) {
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;
        if (mounted) {
          setState(() {
            controller.text = words;
          });
          _updatePet();
        }
        if (result.finalResult) {
          _speech.stop();
          if (mounted) setState(() => _listeningField = '');
        }
      },
    );
  }

  Widget _buildVoiceField({
    required TextEditingController controller,
    required String hint,
    required String fieldKey,
    required String speakPrompt,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _petFieldDecoration(hint),
            onChanged: (_) => _updatePet(),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Read prompt aloud',
          icon: const Icon(Icons.volume_up_rounded,
              color: Color(0xFFFFD700), size: 20),
          onPressed: () => _speakPrompt(speakPrompt),
        ),
        IconButton(
          tooltip: _speechReady ? 'Tap and speak' : 'Mic unavailable',
          icon: Icon(
            _listeningField == fieldKey ? Icons.mic : Icons.mic_none,
            color: _speechReady
                ? (_listeningField == fieldKey
                    ? const Color(0xFFFFD700)
                    : Colors.white70)
                : Colors.white38,
            size: 20,
          ),
          onPressed: () => _toggleVoiceInput(
            fieldKey: fieldKey,
            controller: controller,
            prompt: speakPrompt,
          ),
        ),
      ],
    );
  }

  void _updatePet() {
    if (_selectedPetIndex < 0 ||
        _selectedPetIndex >= widget.wizardData.pets.length) {
      return;
    }
    final oldName = _pet?['name'] ?? 'My Pet';
    final newName = _nameCtrl.text.trim().isEmpty
        ? 'My Pet ${_selectedPetIndex + 1}'
        : _nameCtrl.text.trim();
    final photo = widget.wizardData.petPhotos[oldName];
    widget.wizardData.pets[_selectedPetIndex] = {
      'name': newName,
      'species': _species,
      'color': _colorCtrl.text.trim(),
      'personality': '',
    };
    // Rename photo key if name changed
    if (photo != null && oldName != newName) {
      widget.wizardData.petPhotos.remove(oldName);
      widget.wizardData.petPhotos[newName] = photo;
    }
    final generated = widget.wizardData.petAvatars[oldName];
    if (generated != null && oldName != newName) {
      widget.wizardData.petAvatars.remove(oldName);
      widget.wizardData.petAvatars[newName] = generated;
    }
    // Keep companionNames in sync
    if (widget.wizardData.companionNames.contains(oldName) &&
        oldName != newName) {
      widget.wizardData.companionNames.remove(oldName);
      widget.wizardData.companionNames.add(newName);
    }
    widget.onChanged();
  }

  void _loadFromSelectedPet() {
    final pet = _pet;
    _nameCtrl.text = pet?['name'] ?? '';
    _colorCtrl.text = pet?['color'] ?? '';
    _species = pet?['species'] ?? 'Dog';
  }

  void _selectPet(int index, {bool edit = false}) {
    if (index < 0 || index >= widget.wizardData.pets.length) return;
    setState(() {
      _selectedPetIndex = index;
      _isEditing = edit;
      _loadFromSelectedPet();
    });
  }

  void _addAnotherPet() {
    final nextIndex = widget.wizardData.pets.length;
    final name = nextIndex == 0 ? 'My Pet' : 'My Pet ${nextIndex + 1}';
    widget.wizardData.pets.add({
      'name': name,
      'species': 'Dog',
      'color': '',
      'personality': '',
    });
    if (!widget.wizardData.companionNames.contains(name)) {
      widget.wizardData.companionNames.add(name);
    }
    final petId = 'my_pet_$nextIndex';
    if (!widget.wizardData.selectedCompanions.contains(petId)) {
      widget.wizardData.selectedCompanions.add(petId);
    }
    widget.onChanged();
    _selectPet(nextIndex, edit: true);
  }

  @override
  Widget build(BuildContext context) {
    final hasPet = widget.wizardData.pets.isNotEmpty;
    final photo = _photo;

    if (!hasPet) {
      // "Add Your Companion" prompt
      return GestureDetector(
        onTap: () async {
          await widget.onPickPhoto(petIndex: 0);
          if (!mounted) return;
          setState(() {
            if (widget.wizardData.pets.isNotEmpty) {
              _selectedPetIndex = 0;
              _isEditing = true;
              _loadFromSelectedPet();
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFFD700).withAlpha(160),
              width: 2,
            ),
            gradient: LinearGradient(
              colors: [const Color(0xFF2C1B47), const Color(0xFF1A0E36)],
            ),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFFFD700).withAlpha(35), blurRadius: 12),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD700).withAlpha(40),
                ),
                child: const Icon(Icons.add_a_photo_rounded,
                    color: Color(0xFFFFD700), size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bring Your Companion!',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        )),
                    SizedBox(height: 3),
                    Text(
                      'Add a photo and we\'ll put them in the story',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedPetIndex == -1) {
      _selectedPetIndex = 0;
      _loadFromSelectedPet();
    }

    if (!_isEditing) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFFFFD700).withAlpha(150), width: 1.5),
          color: const Color(0xFF2C1B47),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < widget.wizardData.pets.length; i++)
                  ChoiceChip(
                    label: Text(
                        widget.wizardData.pets[i]['name'] ?? 'Pet ${i + 1}'),
                    selected: i == _selectedPetIndex,
                    selectedColor: const Color(0xFFFFD700).withAlpha(40),
                    labelStyle: TextStyle(
                      color: i == _selectedPetIndex
                          ? const Color(0xFFFFD700)
                          : Colors.white70,
                      fontSize: 12,
                    ),
                    onSelected: (_) => _selectPet(i),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF3A2363),
                  backgroundImage: photo != null && photo.isNotEmpty
                      ? MemoryImage(base64Decode(
                          photo.replaceFirst(RegExp(r'data:[^,]+,'), '')))
                      : null,
                  child: photo == null || photo.isEmpty
                      ? const Icon(Icons.pets, color: Colors.white70)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your buddy is ready! 🌟',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _isEditing = true),
                  child: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _addAnotherPet,
                  icon: const Icon(Icons.add),
                  label: const Text('Add another pet'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      widget.onPickPhoto(petIndex: _selectedPetIndex),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Change photo'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Companion editor card
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFFFFD700).withAlpha(180), width: 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF2C1B47), const Color(0xFF1A0E36)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withAlpha(40),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Photo circle (tap to change)
              GestureDetector(
                onTap: () => widget.onPickPhoto(petIndex: _selectedPetIndex),
                child: Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFFFD700), width: 2),
                        color: const Color(0xFF3A2363),
                      ),
                      child: ClipOval(
                        child: photo != null && photo.isNotEmpty
                            ? Image.memory(
                                base64Decode(photo.replaceFirst(
                                    RegExp(r'data:[^,]+,'), '')),
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.pets,
                                color: Colors.white70, size: 36),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFD700),
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.black, size: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    // Name field
                    _buildVoiceField(
                      controller: _nameCtrl,
                      hint: 'Companion name (e.g. Alex)',
                      fieldKey: 'pet_name',
                      speakPrompt:
                          'Say your companion name. For example, Whiskers.',
                    ),
                    const SizedBox(height: 8),
                    // Looks field (stored in legacy `color` key for compatibility)
                    _buildVoiceField(
                      controller: _colorCtrl,
                      hint: 'Looks (e.g. blond hair, glasses, golden fur)',
                      fieldKey: 'pet_looks',
                      speakPrompt: 'Describe what your companion looks like.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Companion type dropdown
          DropdownButtonFormField<String>(
            initialValue: _species,
            dropdownColor: const Color(0xFF2C1B47),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _petFieldDecoration('Companion type'),
            items: _speciesOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _species = v);
                _updatePet();
              }
            },
          ),
          const SizedBox(height: 6),
          Text(
            '✨ Bring your companion on your magical adventure!',
            style: TextStyle(
                color: const Color(0xFFFFD700).withAlpha(200),
                fontSize: 11,
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                _updatePet();
                setState(() => _isEditing = false);
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save Companion'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _petFieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFFFD700), fontSize: 13),
        filled: true,
        fillColor: Colors.white.withAlpha(18),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFFFD700).withAlpha(100)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFFFD700).withAlpha(120)),
        ),
      );
}

// ── Friend Chip Button ────────────────────────────────────────────────────────

class _FriendChipButton extends StatefulWidget {
  final Character character;
  final bool isSelected;
  final VoidCallback onTap;

  const _FriendChipButton({
    required this.character,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FriendChipButton> createState() => _FriendChipButtonState();
}

class _FriendChipButtonState extends State<_FriendChipButton> {
  ImageProvider<Object>? _getAvatarProvider() {
    final img = widget.character.generatedAvatar?.imageBase64;
    if (img == null) return null;
    if (img.startsWith('assets/')) return AssetImage(img);
    if (img.startsWith('http')) return NetworkImage(img);
    try {
      final normalized = img.contains(',') ? img.split(',').last : img;
      return MemoryImage(base64Decode(normalized));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarProvider = _getAvatarProvider();
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: widget.isSelected ? const Color(0xFFFFD700) : Colors.white30,
            width: widget.isSelected ? 2 : 1,
          ),
          color: widget.isSelected
              ? const Color(0xFFFFD700).withAlpha(20)
              : Colors.white10,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF3A2363),
              backgroundImage: avatarProvider,
              child: avatarProvider == null
                  ? Text(
                      widget.character.name.isNotEmpty
                          ? widget.character.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              widget.character.name,
              style: TextStyle(
                color:
                    widget.isSelected ? const Color(0xFFFFD700) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarBurstOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const _StarBurstOverlay({required this.onComplete});

  @override
  State<_StarBurstOverlay> createState() => _StarBurstOverlayState();
}

class _StarBurstOverlayState extends State<_StarBurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_StarParticle> _particles;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward().then((_) => widget.onComplete());

    _particles = List.generate(22, (_) => _StarParticle(_rng));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Stack(
            children: _particles.map((p) {
              final t = _ctrl.value;
              final x = size.width / 2 + p.dx * t * 220;
              final y = size.height / 2 + p.dy * t * 260 + 120 * t * t;
              final opacity = (1.0 - t * 1.4).clamp(0.0, 1.0);
              final scale = (1.0 - t * 0.6).clamp(0.1, 1.0);
              return Positioned(
                left: x - 10,
                top: y - 10,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Text(
                      p.emoji,
                      style: TextStyle(fontSize: 18 + p.size),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _StarParticle {
  final double dx;
  final double dy;
  final double size;
  final String emoji;

  static const _emojis = ['⭐', '✨', '🌟', '💫', '🔮', '🪄', '💜', '⚡'];

  _StarParticle(math.Random rng)
      : dx = (rng.nextDouble() * 2 - 1),
        dy = (rng.nextDouble() * 2 - 1),
        size = rng.nextDouble() * 8,
        emoji = _emojis[rng.nextInt(_emojis.length)];
}

// ---------------------------------------------------------------------------
// Gender image button — shows artwork image with press/select animation
// ---------------------------------------------------------------------------
class _GenderImageButton extends StatefulWidget {
  const _GenderImageButton({
    required this.gender,
    required this.assetPath,
    required this.isSelected,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final String gender;
  final String assetPath;
  final bool isSelected;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  State<_GenderImageButton> createState() => _GenderImageButtonState();
}

class _GenderImageButtonState extends State<_GenderImageButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final bool useDecorative = band.band == AgeBand.explorer;
    final imageWidget = Image.asset(
      widget.assetPath,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.cover,
    );

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: _pressed ? 0.92 : (_hovered ? 1.04 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withAlpha(160),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withAlpha(80),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                  border: Border.all(
                    color: widget.isSelected
                        ? const Color(0xFFFFD700)
                        : _hovered
                            ? const Color(0xFFFFD700).withAlpha(100)
                            : Colors.white30,
                    width: widget.isSelected ? 3.5 : 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: _pressed
                      ? ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                              Color(0x55000000), BlendMode.darken),
                          child: imageWidget,
                        )
                      : imageWidget,
                ),
              ),
              const SizedBox(height: 10),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: useDecorative
                    ? GoogleFonts.cinzelDecorative(
                        color: widget.isSelected
                            ? const Color(0xFFFFD700)
                            : Colors.white70,
                        fontSize: 15,
                        fontWeight: widget.isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        shadows: widget.isSelected
                            ? [
                                const Shadow(
                                    color: Color(0xFFFFD700), blurRadius: 10)
                              ]
                            : null,
                      )
                    : GoogleFonts.sourceSans3(
                        color: widget.isSelected
                            ? const Color(0xFFFFD700)
                            : Colors.white70,
                        fontSize: 15,
                        fontWeight: widget.isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                child: Text(widget.gender),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Themed name input — coded gold/purple field replacing scroll PNG
// ---------------------------------------------------------------------------
class _ThemedNameInput extends StatefulWidget {
  const _ThemedNameInput({
    required this.controller,
    required this.focusNode,
    required this.fontSize,
    required this.height,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final double fontSize;
  final double height;
  final ValueChanged<String> onChanged;

  @override
  State<_ThemedNameInput> createState() => _ThemedNameInputState();
}

class _ThemedNameInputState extends State<_ThemedNameInput>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _focused = widget.focusNode.hasFocus);
    if (_focused) {
      _glowCtrl.repeat(reverse: true);
    } else {
      _glowCtrl.stop();
      _glowCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final bool useDecorative = band.band == AgeBand.explorer;
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) {
        final g = _focused ? _glowAnim.value : 0.0;
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            // Lighter, more opaque purple so it reads against the dark background
            color: const Color(0xFF5C1A8C).withAlpha(200),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _focused
                  ? Color.fromARGB(
                      (180 + (g * 75).round()).clamp(0, 255), 0xFF, 0xD5, 0x4F)
                  : const Color(0xFFFFD54F).withAlpha(130),
              width: _focused ? 2.0 : 1.5,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color:
                          const Color(0xFFFFD54F).withAlpha((80 * g).round()),
                      blurRadius: 18 * g,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(60),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                textAlign: TextAlign.center,
                style: useDecorative
                    ? GoogleFonts.cinzelDecorative(
                        fontSize: widget.fontSize,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(color: Color(0xFFFFD54F), blurRadius: 6)
                        ],
                      )
                    : GoogleFonts.sourceSans3(
                        fontSize: widget.fontSize,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                decoration: InputDecoration(
                  hintText: "Type your hero's name...",
                  hintStyle: useDecorative
                      ? GoogleFonts.cinzelDecorative(
                          color: const Color(0xFFFFE082).withAlpha(180),
                          fontSize: widget.fontSize * 0.85,
                          fontWeight: FontWeight.w400,
                        )
                      : TextStyle(
                          color: Colors.white30,
                          fontSize: widget.fontSize * 0.85,
                        ),
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: widget.onChanged,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A stateful arrow button with clear press feedback:
/// shrinks to 86% + brightens gradient + amplifies glow on tap-down.
class _PressableArrowButton extends StatefulWidget {
  const _PressableArrowButton({
    required this.enabled,
    required this.onTap,
    this.hint,
  });
  final bool enabled;
  final VoidCallback onTap;
  final String? hint;

  @override
  State<_PressableArrowButton> createState() => _PressableArrowButtonState();
}

class _PressableArrowButtonState extends State<_PressableArrowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final btnSize = (band.touchTargetMin / 64.0 * 80).roundToDouble();
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTapDown:
                widget.enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp:
                widget.enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.enabled ? widget.onTap : null,
            child: AnimatedScale(
              scale: _pressed ? 0.86 : 1.0,
              duration: const Duration(milliseconds: 80),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: btnSize,
                height: btnSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _pressed
                        ? [const Color(0xFFD070FF), const Color(0xFF8B4FD8)]
                        : [const Color(0xFF9B3FD8), const Color(0xFF5B1BAA)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700)
                          .withAlpha(_pressed ? 200 : 100),
                      blurRadius: _pressed ? 32 : 20,
                      spreadRadius: _pressed ? 4 : 0,
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: btnSize * 0.5),
              ),
            ),
          ),
          if (widget.hint != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.hint!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Scene Image Button helpers ──────────────────────────────────────────────

// ── Imagine It Hero Card ───────────────────────────────────────────────────────

class _ImagineItHeroCard extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;
  const _ImagineItHeroCard({required this.isSelected, required this.onTap});

  @override
  State<_ImagineItHeroCard> createState() => _ImagineItHeroCardState();
}

class _ImagineItHeroCardState extends State<_ImagineItHeroCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final isSprout = band.band == AgeBand.sprout;
    final asset = _pressed
        ? 'assets/images/scenarios/imagine_it_btn_pressed.png'
        : 'assets/images/scenarios/imagine_it_btn.png';

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: isSprout ? 'Make one up' : 'Imagine It — create your own world',
      hint: widget.isSelected
          ? 'Currently selected. Double tap to close the text field.'
          : isSprout
              ? 'Double tap to tell us your own place.'
              : 'Double tap to open a text box and type your own scene idea.',
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.mediumImpact();
          setState(() => _pressed = true);
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedBuilder(
          animation: _glowAnim,
          builder: (context, child) {
            return AnimatedScale(
              scale: _pressed ? 0.96 : 1.0,
              duration: const Duration(milliseconds: 80),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.isSelected
                        ? const Color(0xFFFFD700)
                        : const Color(0xFFFFD700)
                            .withAlpha((_glowAnim.value * 160).round()),
                    width: widget.isSelected ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withAlpha(
                          ((_glowAnim.value) * (widget.isSelected ? 120 : 80))
                              .round()),
                      blurRadius: widget.isSelected ? 22 : 16,
                      spreadRadius: widget.isSelected ? 3 : 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      // Full image at natural 360×220 ratio — no cropping
                      AspectRatio(
                        aspectRatio: 360 / 220,
                        child: Image.asset(
                          asset,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF2C1B47),
                            child: Center(
                              child: Text(
                                isSprout ? 'Make One Up! ✨' : 'Imagine It ✨',
                                style: GoogleFonts.fredoka(
                                    color: const Color(0xFFFFD700),
                                    fontSize: 22),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Bottom gradient label
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color(0xEE0D0020), Color(0x00000000)],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isSprout ? '✨  Make One Up!' : '✨  Imagine It',
                                style: GoogleFonts.fredoka(
                                  color: const Color(0xFFFFD700),
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  shadows: const [
                                    Shadow(
                                        color: Colors.black,
                                        blurRadius: 6,
                                        offset: Offset(0, 1))
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isSprout
                                    ? 'Tell us a place you want to visit'
                                    : 'Describe any world you can dream up',
                                style: GoogleFonts.fredoka(
                                  color: Colors.white.withAlpha(210),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Selected checkmark
                      if (widget.isSelected)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFD700),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                color: Colors.black, size: 16),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SceneButtonData {
  final String id;
  final String label;
  final String normalAsset;
  final String pressedAsset;
  /// Creator band: evocative psychological hook shown below the title.
  final String? thematicQuestion;

  const _SceneButtonData({
    required this.id,
    required this.label,
    required this.normalAsset,
    required this.pressedAsset,
    this.thematicQuestion,
  });
}

class _SceneImageButton extends StatefulWidget {
  final _SceneButtonData data;
  final bool isSelected;
  final double labelFontSize;
  final VoidCallback onTap;
  /// When true, shows `data.thematicQuestion` (if present) in the label overlay.
  final bool showThematicQuestion;

  const _SceneImageButton({
    required this.data,
    required this.isSelected,
    required this.onTap,
    this.labelFontSize = 13.0,
    this.showThematicQuestion = false,
  });

  @override
  State<_SceneImageButton> createState() => _SceneImageButtonState();
}

class _SceneImageButtonState extends State<_SceneImageButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final asset = _pressed ? widget.data.pressedAsset : widget.data.normalAsset;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: 'Scene: ${widget.data.label}',
      hint: widget.isSelected
          ? 'Currently selected. Double tap to keep this scene.'
          : 'Double tap to choose this scene for your adventure.',
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _pressed = true);
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Container(
            width: null,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isSelected
                    ? const Color(0xFFFFD700)
                    : Colors.transparent,
                width: widget.isSelected ? 3 : 0,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withAlpha(120),
                        blurRadius: 16,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  // Image at natural 360×220 ratio — no cropping
                  AspectRatio(
                    aspectRatio: 360 / 220,
                    child: Image.asset(
                      asset,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF3A1070),
                        child: Center(
                          child: Text(widget.data.label,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                        ),
                      ),
                    ),
                  ),
                  // Label overlay at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xCC1A0040)],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.data.label,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: widget.labelFontSize,
                              fontWeight: FontWeight.bold,
                              shadows: const [
                                Shadow(
                                    color: Colors.black,
                                    blurRadius: 4,
                                    offset: Offset(0, 1))
                              ],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.showThematicQuestion &&
                              widget.data.thematicQuestion != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.data.thematicQuestion!,
                              style: GoogleFonts.bitter(
                                color: Colors.white70,
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Checkmark overlay when selected
                  if (widget.isSelected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFD700),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.black, size: 14),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _GenreChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF9E6CFF).withAlpha(230)
              : Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? const Color(0xFFE28EFF) : Colors.white24,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: const Color(0xFF9E6CFF).withAlpha(100),
                      blurRadius: 8,
                      spreadRadius: 1)
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: 15,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero portal placeholder — magical summoning circle, no image asset needed
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Hero Spirit placeholder — glowing crowned silhouette waiting to come to life
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Ambient sparkle layer — 12 gold particles slowly drifting upward
// ---------------------------------------------------------------------------
class _AmbientSparkleLayer extends StatefulWidget {
  const _AmbientSparkleLayer();

  @override
  State<_AmbientSparkleLayer> createState() => _AmbientSparkleLayerState();
}

class _AmbientSparkleLayerState extends State<_AmbientSparkleLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_AmbientParticle> _particles;
  final _rng = math.Random(42);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _particles = List.generate(14, (_) => _AmbientParticle(_rng));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!MotionPrefs.showParticles(context)) {
      return const SizedBox.expand();
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _AmbientSparklePainter(
            particles: _particles,
            progress: _ctrl.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _AmbientParticle {
  final double xFraction; // 0-1, horizontal position as fraction of width
  final double phase; // 0-1, offset in the animation cycle
  final double speed; // relative speed multiplier
  final double size; // star radius
  final double drift; // horizontal drift amount

  _AmbientParticle(math.Random rng)
      : xFraction = rng.nextDouble(),
        phase = rng.nextDouble(),
        speed = 0.4 + rng.nextDouble() * 0.6,
        size = 2.0 + rng.nextDouble() * 3.0,
        drift = (rng.nextDouble() - 0.5) * 20;
}

class _AmbientSparklePainter extends CustomPainter {
  final List<_AmbientParticle> particles;
  final double progress;

  const _AmbientSparklePainter(
      {required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Each particle has its own phase offset; cycles continuously
      final t = ((progress * p.speed + p.phase) % 1.0);
      // y goes from bottom (1.0) to top (0.0)
      final y = size.height * (1.0 - t);
      final x = size.width * p.xFraction + p.drift * math.sin(t * math.pi * 2);

      // Fade in from bottom, fade out near top
      final opacity = t < 0.15
          ? t / 0.15
          : t > 0.75
              ? (1.0 - t) / 0.25
              : 1.0;

      final paint = Paint()
        ..color = const Color(0xFFFFE082).withAlpha((60 * opacity).round())
        ..style = PaintingStyle.fill;

      // Draw a tiny 4-pointed star
      _drawTinyStar(canvas, Offset(x, y), p.size, paint);
    }
  }

  void _drawTinyStar(Canvas canvas, Offset center, double r, Paint paint) {
    final inner = r * 0.38;
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - math.pi / 2;
      final radius = i.isEven ? r : inner;
      final px = center.dx + radius * math.cos(angle);
      final py = center.dy + radius * math.sin(angle);
      i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_AmbientSparklePainter old) => old.progress != progress;
}

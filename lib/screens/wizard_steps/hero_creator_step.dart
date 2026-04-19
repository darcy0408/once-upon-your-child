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
import '../../widgets/hero_creator/avatar_choice_cards.dart';
import '../../widgets/hero_creator/companion_widgets.dart';
import '../../widgets/hero_creator/pet_card.dart';
import '../../widgets/hero_creator/scene_widgets.dart';
import '../../widgets/hero_creator/hero_input_widgets.dart';
import '../../widgets/hero_creator/hero_effects.dart';
import '../../widgets/hero_creator/genre_chip.dart';
import '../../widgets/safe_asset_image.dart';

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
  String _petAvatarGeneratingSpecies = 'Dog'; // tracks species being generated for display text
  late TextEditingController _friendNameController;

  // ─── Creative Brief scroll anchors (mature bands) ────────────────────────────
  final ScrollController _briefScrollController = ScrollController();
  final _briefCharacterKey = GlobalKey();
  final _briefCompanionsKey = GlobalKey();
  final _briefWorldKey = GlobalKey();
  final _briefConfigKey = GlobalKey();
  // Sprout band: pet card is hidden until a grown-up reveals it
  bool _showPetCardForSprout = false;
  // Pending companion species — set by "Add a Friend" / "Add My Pet" buttons,
  // consumed by the _PetCard to create the entry and open the editor.
  String? _pendingCompanionSpecies;
  int _pendingCompanionToken = 0; // increments to distinguish repeated adds of same species

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
    _briefScrollController.dispose();
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
      builder: (_) => StarBurstOverlay(
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
    final bandData =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    if (bandData.band.isMature) {
      // Creative Brief (accordion) — scroll to the relevant section.
      final key = switch (subStep) {
        0 => _briefCharacterKey,
        1 => _briefCompanionsKey,
        2 => _briefWorldKey,
        _ => _briefConfigKey,
      };
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = key.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            alignment: 0.0,
          );
        }
      });
      return;
    }

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
    // Gate: archetype is required for new characters
    if (_isCreatingNew && _selectedArchetypeId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a core archetype to continue'),
          backgroundColor: Color(0xFFFF6B6B),
          behavior: SnackBarBehavior.floating,
        ));
        final keyContext = _briefCharacterKey.currentContext;
        if (keyContext != null) {
          Scrollable.ensureVisible(keyContext,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut);
        }
      }
      return;
    }
    // Gate: character look must be chosen for new characters
    if (_isCreatingNew && !_hasAvatar) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please choose a look for your character first'),
          backgroundColor: Color(0xFFFF6B6B),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
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
              return HeroCharacterChoiceCard(
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
        const Positioned.fill(child: AmbientSparkleLayer()),
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

  // Page 2: Choose how to build your avatar
  Widget _buildPage2() {
    return Builder(builder: (context) {
      final band =
          Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
      final isCreator = band.band == AgeBand.creator;
      final title = isCreator
          ? 'How do you want to design your character?'
          : 'How do you want to build your hero?';
      return Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MagicEarButton(spokenText: title, size: 32),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: _bandTitleStyle(band, baseFontSize: 20),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: HeroAvatarChoiceCard(
                    icon: Icons.auto_awesome,
                    title: 'Gallery Avatar',
                    subtitle: 'Pick from magical presets',
                    onTap: _openAvatarGallery,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: HeroAvatarChoiceCard(
                    icon: Icons.camera_alt_rounded,
                    title: 'AI Avatar',
                    subtitle: 'Create from a photo',
                    onTap: _openCustomAvatarScreen,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (_hasAvatar) ...[
            Text(
              'Great! Tap Next to pick your hero style.',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
          _buildNextArrowButton(
            enabled: _hasAvatar,
            onTap: _heroNextPage,
            hint: 'Next: Pick Hero Style',
          ),
          const SizedBox(height: 24),
        ],
      );
    });
  }

  // Page 3: Pick your archetype
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
                      ? 'Choose your archetype'
                      : 'Pick your archetype!';
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MagicEarButton(
                    spokenText:
                        "Pick your archetype! Swipe through the pictures and tap the one you like.",
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
    // Include companions from all bands so the showcase can resolve any
    // selection regardless of which band is currently active.
    final allKnownCompanions = [
      ..._sproutCompanions,
      ..._explorerCompanions,
      ..._adventurerCompanions,
      ..._creatorCompanions,
      ..._adolescentCompanions,
      ..._adultCompanions,
    ];

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
    final slots = <ShowcaseSlot>[];
    for (final c in selectedNamed) {
      slots.add(ShowcaseSlot(
        id: c.id,
        imagePath: c.imagePath,
        name: c.name,
      ));
    }
    for (final friend in selectedFriends) {
      slots.add(ShowcaseSlot(
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
        slots.add(ShowcaseSlot(
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
              GlowingCompanionOrb(
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
              const GlowingCompanionOrb(slot: null),
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
              return FriendChipButton(
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
        CompanionImageGrid(
          wizardData: widget.wizardData,
          onChanged: () => setState(() {}),
          onCompanionTapped: widget.wizardData.characterAge <= 5
              ? (name) => _speakForSprout(name)
              : null,
          maxCompanions: band.band == AgeBand.sprout ? 1 : 3,
        ),
        const SizedBox(height: 16),
        // ── Add a friend or pet — hidden for Sprout band ────────────────────
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _pendingCompanionSpecies = 'Human';
                    _pendingCompanionToken++;
                  }),
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Add a Friend'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF7C4DFF)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _pendingCompanionSpecies = 'Dog';
                    _pendingCompanionToken++;
                  }),
                  icon: const Icon(Icons.pets_rounded, size: 18),
                  label: const Text('Add My Pet'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFFFD700)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
            HeroPetCard(
              wizardData: widget.wizardData,
              onPickPhoto: ({int? petIndex}) => _pickPetPhoto(petIndex: petIndex),
              onChanged: () => setState(() {}),
              onSaveCompanion: ({required int petIndex, required String name, required String species, required String description}) =>
                  _onSaveCompanion(petIndex: petIndex, name: name, species: species, description: description),
            ),
        ] else
          HeroPetCard(
            wizardData: widget.wizardData,
            onPickPhoto: ({int? petIndex}) => _pickPetPhoto(petIndex: petIndex),
            onChanged: () => setState(() {}),
            onSaveCompanion: ({required int petIndex, required String name, required String species, required String description}) =>
                _onSaveCompanion(petIndex: petIndex, name: name, species: species, description: description),
            pendingNewSpecies: _pendingCompanionSpecies != null
                ? '$_pendingCompanionSpecies:$_pendingCompanionToken'
                : null,
            onPendingConsumed: () => setState(() => _pendingCompanionSpecies = null),
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
              Expanded(
                child: Text(
                  _petAvatarGeneratingSpecies == 'Human'
                      ? 'Bringing them into the story as a character...'
                      : 'Transforming your pet into magical Pixar style...',
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12),
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

    // Photo stored — generation deferred until the user fills in name/species/description and taps Save.
    if (mounted) setState(() => _petAvatarStatusMessage = null);
  }

  /// Called when the user taps "Save Companion" in the pet card.
  /// Fires avatar generation only at this point, after name/species/description are known.
  Future<void> _onSaveCompanion({
    required int petIndex,
    required String name,
    required String species,
    required String description,
  }) async {
    // Only generate if there's a photo to transform.
    final photo = widget.wizardData.petPhotos[name];
    if (photo == null || photo.isEmpty) return;

    // Decode the stored base64 photo back to bytes.
    final b64Data = photo.replaceFirst(RegExp(r'data:[^,]+,'), '');
    final List<int> photoBytes = base64Decode(b64Data);

    if (mounted) {
      setState(() {
        _isPetAvatarGenerating = true;
        _petAvatarGeneratingSpecies = species;
        _petAvatarStatusMessage = null;
      });
    }

    final result = await _generateMagicalPetAvatar(
      petName: name,
      species: species,
      looksDescription: description.isEmpty ? (species == 'Human' ? name : species) : description,
      photoBytes: photoBytes,
      filename: 'companion_photo.jpg',
    );

    if (!mounted) return;
    final success = !result.isError;
    final message = result.message ??
        (success
            ? (species == 'Human' ? '✨ ${name} is ready for the adventure!' : '✨ Magical pet avatar ready!')
            : "Oops! Magic isn't working on that picture. Want to pick a companion instead?");
    setState(() {
      _isPetAvatarGenerating = false;
      _petAvatarStatusMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF4CAF50) : const Color(0xFF6D4C41),
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
      if (species == 'Human') {
        request.fields['companion_type'] = 'human';
      }

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
          "Oops! Magic isn't working on that picture. Want to pick a companion instead?",
        );
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != 'success') {
        final message = body['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return _PetAvatarGenerationResult.error(message);
        }
        return const _PetAvatarGenerationResult.error(
          "Oops! Magic isn't working on that picture. Want to pick a companion instead?",
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
          "Oops! Magic isn't working on that picture right now. Your companion's photo is saved!",
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
        "Oops! Magic isn't working on that picture. Want to pick a companion instead?",
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
    final isAdult = band.band == AgeBand.adult;

    // The 4 featured scene buttons with their image assets.
    // For Creator band, populate thematicQuestion from ScenarioData.
    // For Adult band, use adultThematicQuestion instead.
    ScenarioCard? scenarioById(String id) {
      try {
        return ScenarioData.all.firstWhere((s) => s.id == id);
      } catch (_) {
        return null;
      }
    }

    String? thematicQuestionFor(String id) {
      final s = scenarioById(id);
      if (isAdult) return s?.adultThematicQuestion;
      if (isCreator) return s?.creatorThematicQuestion;
      return null;
    }

    final featuredButtons = [
      SceneButtonData(
        id: 'vanishing_colors',
        label: scenarioById('vanishing_colors')?.titleForAge(age) ?? 'Vanishing Colors',
        normalAsset: 'assets/images/scenarios/rainbow_land_btn.png',
        pressedAsset: 'assets/images/scenarios/rainbow_land_btn_pressed.png',
        thematicQuestion: thematicQuestionFor('vanishing_colors'),
      ),
      SceneButtonData(
        id: 'crystal_cavern',
        label: scenarioById('crystal_cavern')?.titleForAge(age) ?? 'Crystal Cavern',
        normalAsset: 'assets/images/scenarios/crystal_cave_btn.png',
        pressedAsset: 'assets/images/scenarios/crystal_cave_btn_pressed.png',
        thematicQuestion: thematicQuestionFor('crystal_cavern'),
      ),
      SceneButtonData(
        id: 'volcano_dragons',
        label: scenarioById('volcano_dragons')?.titleForAge(age) ?? 'Volcano Dragons',
        normalAsset: 'assets/images/scenarios/dragon_friends_btn.png',
        pressedAsset: 'assets/images/scenarios/dragon_friends_btn_pressed.png',
        thematicQuestion: thematicQuestionFor('volcano_dragons'),
      ),
      SceneButtonData(
        id: 'big_feelings_quest',
        label: scenarioById('big_feelings_quest')?.titleForAge(age) ?? 'Life Quest',
        normalAsset: 'assets/images/scenarios/my_big_feelings_btn.png',
        pressedAsset: 'assets/images/scenarios/my_big_feelings_btn_pressed.png',
        thematicQuestion: thematicQuestionFor('big_feelings_quest'),
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
            ImagineItHeroCard(
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
                      child: SceneImageButton(
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
                      child: SceneImageButton(
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
              child: SceneImageButton(
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
                  .map((btn) => SceneImageButton(
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
            ImagineItHeroCard(
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
                GenreChip(
                    label: '🔍 Mystery',
                    value: 'mystery',
                    selected: widget.wizardData.selectedGenre == 'mystery',
                    onTap: () => setState(() =>
                        widget.wizardData.selectedGenre =
                            widget.wizardData.selectedGenre == 'mystery'
                                ? null
                                : 'mystery')),
                GenreChip(
                    label: '😂 Comedy',
                    value: 'comedy',
                    selected: widget.wizardData.selectedGenre == 'comedy',
                    onTap: () => setState(() =>
                        widget.wizardData.selectedGenre =
                            widget.wizardData.selectedGenre == 'comedy'
                                ? null
                                : 'comedy')),
                GenreChip(
                    label: '🚀 Sci-Fi',
                    value: 'sci-fi',
                    selected: widget.wizardData.selectedGenre == 'sci-fi',
                    onTap: () => setState(() =>
                        widget.wizardData.selectedGenre =
                            widget.wizardData.selectedGenre == 'sci-fi'
                                ? null
                                : 'sci-fi')),
                GenreChip(
                    label: '⚔️ Action',
                    value: 'action',
                    selected: widget.wizardData.selectedGenre == 'action',
                    onTap: () => setState(() =>
                        widget.wizardData.selectedGenre =
                            widget.wizardData.selectedGenre == 'action'
                                ? null
                                : 'action')),
                GenreChip(
                    label: '👻 Spooky',
                    value: 'spooky',
                    selected: widget.wizardData.selectedGenre == 'spooky',
                    onTap: () => setState(() =>
                        widget.wizardData.selectedGenre =
                            widget.wizardData.selectedGenre == 'spooky'
                                ? null
                                : 'spooky')),
                GenreChip(
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
    return PressableArrowButton(enabled: enabled, onTap: onTap, hint: hint);
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
          initialGender: widget.wizardData.characterGender,
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

  String? get _avatarImageData {
    if (_generatedAvatar != null && _generatedAvatar!.imageBase64.isNotEmpty) {
      return _generatedAvatar!.imageBase64;
    }
    // Fall back to selected character asset path (pre-made silhouette)
    return widget.wizardData.selectedCharacterAssetPath;
  }

  Widget _buildArchetypeSceneImage(ArchetypeData archetype, AgeBand ageBand) {
    final imagePath = archetype.imagePathForBand(ageBand);
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF1A0A2E)),
        if (imagePath != null)
          SafeAssetImage(
            imagePath,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            placeholder: Center(child: Text(archetype.icon ?? '✨',
                style: const TextStyle(fontSize: 64))),
          )
        else
          Center(child: Text(archetype.icon ?? '✨',
              style: const TextStyle(fontSize: 72))),
      ],
    );
  }

  Widget _buildGenderPicker() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final ageBand = band.band;

    final String boyAsset;
    final String girlAsset;
    switch (ageBand) {
      case AgeBand.sprout:
        boyAsset = 'assets/images/ui/gender/gender_sprout_boy.png';
        girlAsset = 'assets/images/ui/gender/gender_sprout_girl.png';
      case AgeBand.explorer:
        boyAsset = 'assets/images/ui/gender/gender_explorer_boy.png';
        girlAsset = 'assets/images/ui/gender/gender_explorer_girl.png';
      case AgeBand.adventurer:
        boyAsset = 'assets/images/ui/gender/gender_adventurer_boy.png';
        girlAsset = 'assets/images/ui/gender/gender_adventurer_girl.png';
      case AgeBand.creator:
        boyAsset = 'assets/images/ui/gender/gender_creator_boy.png';
        girlAsset = 'assets/images/ui/gender/gender_creator_girl.png';
      case AgeBand.adolescent:
        boyAsset = 'assets/images/ui/gender/gender_adolescent_boy.png';
        girlAsset = 'assets/images/ui/gender/gender_adolescent_girl.png';
      case AgeBand.adult:
        boyAsset = 'assets/images/ui/gender/gender_adult_boy.png';
        girlAsset = 'assets/images/ui/gender/gender_adult_girl.png';
    }

    final gender = widget.wizardData.characterGender;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GenderImageButton(
          gender: 'Boy',
          assetPath: boyAsset,
          isSelected: gender == 'Boy',
          width: 140,
          height: 180,
          onTap: () => _handleGenderSelection('Boy'),
        ),
        SizedBox(width: band.space(32)),
        GenderImageButton(
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
      return Column(
        children: [
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
                  filled: true,
                  fillColor: Colors.transparent,
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
        ThemedNameInput(
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

    // Sprout & Explorer: 2×2 grid — image-dominant cards.
    if (ageBand == AgeBand.sprout || ageBand == AgeBand.explorer) {
      final isSprout = ageBand == AgeBand.sprout;
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
                    _buildArchetypeSceneImage(a, ageBand),
                    if (isSelected)
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          decoration: const BoxDecoration(color: Color(0xFFFFD700), shape: BoxShape.circle),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(Icons.check, size: 16, color: Colors.black),
                        ),
                      ),
                    Positioned(
                      bottom: 4, left: 6, right: 6,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                              fontSize: isSprout ? 13 : 12,
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

          if (isSprout) {
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
          } else {
            card = GestureDetector(onTap: () => _selectArchetype(a), child: card);
          }

          return card;
        },
      );
    }

    // Adventurer & Creator: 2×2 grid — image-dominant cards with name/description overlay.
    final showDescriptions =
        ageBand == AgeBand.adventurer || ageBand == AgeBand.creator;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
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
                    _buildArchetypeSceneImage(a, ageBand),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withAlpha(210), Colors.transparent],
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
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
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
                          child: const Icon(Icons.check, size: 16, color: Colors.black),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
      decoration: BoxDecoration(
        gradient: bandData.backgroundGradient,
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
      controller: _briefScrollController,
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
              initiallyExpanded: true, sectionKey: _briefCharacterKey),
          _buildBriefSection(
              'Personality', _buildBriefPersonalitySliders()),
          _buildBriefSection(
              'Cast & Companions', _buildBriefCompanionsInputs(),
              sectionKey: _briefCompanionsKey),
          _buildBriefSection(
              'World & Setting', _buildBriefWorldInputs(),
              sectionKey: _briefWorldKey),
          _buildBriefSection('Story Options', _buildBriefConfigInputs(),
              sectionKey: _briefConfigKey),
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
      {bool initiallyExpanded = false, Key? sectionKey}) {
    return Theme(
      key: sectionKey,
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
        // No adolescent-specific character art yet; use adventurer as stand-in.
        boyAsset = 'assets/images/ui/adventurer/boy_character.png';
        girlAsset = 'assets/images/ui/adventurer/girl_character.png';
        break;
      case AgeBand.adult:
        boyAsset = 'assets/images/ui/adult/man_character_white.png';
        girlAsset = 'assets/images/ui/adult/woman_character_white.png';
        break;
      case AgeBand.creator:
        boyAsset = 'assets/images/ui/creator/creator_white.png';
        girlAsset = 'assets/images/ui/creator/creator_white.png';
        break;
      // Young bands use _buildGenderPicker instead.
      case AgeBand.sprout:
      case AgeBand.explorer:
      case AgeBand.adventurer:
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
            GenderImageButton(
              gender: 'Boy',
              assetPath: boyAsset,
              isSelected: gender == 'Boy',
              width: 110,
              height: 140,
              onTap: () =>
                  setState(() => widget.wizardData.characterGender = 'Boy'),
            ),
            const SizedBox(width: 32),
            GenderImageButton(
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
    final band = ageBandFromAge(widget.wizardData.characterAge);
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
        // Mature bands (creator, adolescent, adult): identity reflection prompt
        if (band.isMature) ...[
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
        Text.rich(
          TextSpan(
            text: 'CORE ARCHETYPE',
            style: GoogleFonts.sourceSans3(
                color: Colors.white.withAlpha(100),
                fontSize: 10,
                fontWeight: FontWeight.bold),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 10),
              ),
            ],
          ),
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

  Widget _buildBriefCompanionsInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CAST',
          style: GoogleFonts.sourceSans3(
              color: Colors.white.withAlpha(100),
              fontSize: 10,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildCompanionShowcase(),
        const SizedBox(height: 16),
        _buildCompanionGrid(),
      ],
    );
  }

  Widget _buildBriefWorldInputs() {
    final scenarios =
        ScenarioData.all.where((s) => s.id != 'safe_space').toList();
    final isCustom = widget.wizardData.selectedScenario == 'safe_space';
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;

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
                label: Text(s.titleForBand(band.band).toUpperCase()),
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
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final showGenreChips = band.band.isMature;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Genre / tone chips — adolescent & adult get mature genre options;
        // creator band already has them in the PageView flow.
        if (showGenreChips) ...[
          Text(
            'GENRE',
            style: GoogleFonts.sourceSans3(
                color: Colors.white.withAlpha(100),
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GenreChip(
                  label: '🔍 Mystery',
                  value: 'mystery',
                  selected: widget.wizardData.selectedGenre == 'mystery',
                  onTap: () => setState(() =>
                      widget.wizardData.selectedGenre =
                          widget.wizardData.selectedGenre == 'mystery'
                              ? null
                              : 'mystery')),
              GenreChip(
                  label: '👻 Horror',
                  value: 'horror',
                  selected: widget.wizardData.selectedGenre == 'horror',
                  onTap: () => setState(() =>
                      widget.wizardData.selectedGenre =
                          widget.wizardData.selectedGenre == 'horror'
                              ? null
                              : 'horror')),
              GenreChip(
                  label: '💕 Romance',
                  value: 'romance',
                  selected: widget.wizardData.selectedGenre == 'romance',
                  onTap: () => setState(() =>
                      widget.wizardData.selectedGenre =
                          widget.wizardData.selectedGenre == 'romance'
                              ? null
                              : 'romance')),
              GenreChip(
                  label: '🚀 Sci-Fi',
                  value: 'sci-fi',
                  selected: widget.wizardData.selectedGenre == 'sci-fi',
                  onTap: () => setState(() =>
                      widget.wizardData.selectedGenre =
                          widget.wizardData.selectedGenre == 'sci-fi'
                              ? null
                              : 'sci-fi')),
              GenreChip(
                  label: '🏚️ Dystopia',
                  value: 'dystopia',
                  selected: widget.wizardData.selectedGenre == 'dystopia',
                  onTap: () => setState(() =>
                      widget.wizardData.selectedGenre =
                          widget.wizardData.selectedGenre == 'dystopia'
                              ? null
                              : 'dystopia')),
              GenreChip(
                  label: '📖 Literary',
                  value: 'literary',
                  selected: widget.wizardData.selectedGenre == 'literary',
                  onTap: () => setState(() =>
                      widget.wizardData.selectedGenre =
                          widget.wizardData.selectedGenre == 'literary'
                              ? null
                              : 'literary')),
              GenreChip(
                  label: '😂 Comedy',
                  value: 'comedy',
                  selected: widget.wizardData.selectedGenre == 'comedy',
                  onTap: () => setState(() =>
                      widget.wizardData.selectedGenre =
                          widget.wizardData.selectedGenre == 'comedy'
                              ? null
                              : 'comedy')),
              GenreChip(
                  label: '⚔️ Action',
                  value: 'action',
                  selected: widget.wizardData.selectedGenre == 'action',
                  onTap: () => setState(() =>
                      widget.wizardData.selectedGenre =
                          widget.wizardData.selectedGenre == 'action'
                              ? null
                              : 'action')),
            ],
          ),
          const SizedBox(height: 20),
        ],
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
                _lengthToLabel(widget.wizardData.storyLength),
                ['Short', 'Medium', 'Long'],
                (v) => setState(
                    () => widget.wizardData.storyLength = _labelToLength(v!)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Map WizardData storyLength ('quick'/'standard'/'epic') → display label.
  static String _lengthToLabel(String length) => switch (length) {
        'quick' => 'Short',
        'epic' => 'Long',
        _ => 'Medium',
      };

  /// Map display label back to WizardData storyLength value.
  static String _labelToLength(String label) => switch (label) {
        'Short' => 'quick',
        'Long' => 'epic',
        _ => 'standard',
      };

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
      final rate = page == 4 ? 0.60 : 0.75;
      if (prompt != null) {
        await AppTtsService.instance.stop();
        if (mounted) {
          unawaited(AppTtsService.instance.speak(prompt, rateScale: rate));
        }
      }
    }
  }

  String? _sceneLabel(String id) => switch (id) {
        'safe_space' || 'imagine_it' => 'Make One Up!',
        'vanishing_colors' => 'Rainbow World!',
        'crystal_cavern' => 'Cave Full of Crystals!',
        'volcano_dragons' => 'Friendly Dragons!',
        'big_feelings_quest' => 'Life Quest!',
        _ => null,
      };
}

// ─── Support Widgets ──────────────────────────────────────────────────────────

class _AvatarChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const HeroAvatarChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2C1B47),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD700).withAlpha(120), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFFD700), size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../services/app_tts_service.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../../models.dart';
import '../../avatar_models.dart';
import '../../custom_avatar_screen.dart';
import '../../utils/motion_utils.dart';
import '../../theme/age_band_theme.dart';
import '../../theme/app_theme.dart';
import '../../widgets/archetype_card.dart';
import '../../widgets/magic_star_cursor.dart';
import '../../services/api_service_manager.dart';
import '../../services/user_identity_service.dart';
import '../../services/isar_service.dart';
import '../../models/local/character_local.dart';
import '../../services/avatar_generation_state.dart';
import '../../services/caregiver_service.dart';
import '../../services/child_profile_service.dart';
import '../../services/firebase_analytics_service.dart';
import '../../services/audio_ambience_service.dart';
import '../../config/environment.dart';
import '../../widgets/avatar_gallery_selector.dart';
import '../../widgets/feelings_quest_modal.dart';
import '../../widgets/magic_ear_button.dart';
import '../../widgets/sprout_animations.dart';
import '../../widgets/hero_creator/avatar_choice_cards.dart';
import '../../widgets/hero_creator/companion_widgets.dart';
import '../../widgets/hero_creator/pet_card.dart';
import '../../widgets/hero_creator/hero_input_widgets.dart';
import '../../widgets/hero_creator/hero_effects.dart';
import '../../widgets/safe_asset_image.dart';
import '../../utils/paywall_gate.dart';
import '../../premium_upgrade_screen.dart';
import '../../services/parental_consent_service.dart';
import 'hero_creator_scene_page.dart';
import 'hero_creator_story_type_page.dart';
import 'superhero_entry_screen.dart';
import 'superhero_vibe_chooser_screen.dart';
import 'hero_creator_creative_brief.dart';
import '../life_quest_screen.dart';
import '../../services/offline_story_service.dart';
import '../../models/local/story_local.dart';
import '../../story_result_screen.dart';

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

  /// Guards the story-type page (Page 6) against double-advance. A Sprout may
  /// tap several mode cards in quick succession, each scheduling an
  /// auto-advance — only the first should cross into the next wizard step.
  bool _storyTypeAdvancing = false;
  String? _selectedArchetypeId;
  late TextEditingController _nameController;
  final FocusNode _nameFocusNode = FocusNode();
  Character? _selectedExistingCharacter;
  bool _isCreatingNew = true;
  GeneratedAvatar? _generatedAvatar;
  String? _customAvatarFilePath;
  bool _isPremium = false;

  /// MT-151: lifetime count of AI photo-avatars this account has generated,
  /// fetched from the backend's `feature-unlocks` endpoint. Every account gets
  /// ONE free custom avatar; after that it is premium. When a non-premium user
  /// has already used their free one, the photo-avatar card shows a "Premium"
  /// badge and routes straight to the upgrade dialog — skipping the selfie.
  int _customAvatarsUsed = 0;

  /// Premium "Whose turn is it?" feature — character_id of the last hero,
  /// loaded from SharedPreferences. Null when there's no prior story or only
  /// one kid character is saved.
  String? _lastHeroId;
  // ─── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _sparkleCtrl;

  late TextEditingController _imagineItController;

  // ─── Voice & Audio ───────────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  String _listeningFor = '';

  /// Debounce timer for TTS name echo (Sprout band only).
  Timer? _nameEchoTimer;

  /// Sprout companion auto-advance timer. Re-armed on each tap so changing
  /// minds before the delay elapses doesn't fire two advances.
  Timer? _sproutCompanionAdvanceTimer;
  late TextEditingController _superpowerController;
  late TextEditingController _questController;
  late TextEditingController _wishController;
  late TextEditingController _characterDesireController;
  bool _allowPhotoAvatar = false;
  bool _isPetAvatarGenerating = false;
  String? _petAvatarStatusMessage;
  String _petAvatarGeneratingSpecies =
      'Dog'; // tracks species being generated for display text
  late TextEditingController _friendNameController;

  // ─── Creative Brief scroll anchors (mature bands) ────────────────────────────
  final ScrollController _briefScrollController = ScrollController();
  final _briefCharacterKey = GlobalKey();
  final _briefCompanionsKey = GlobalKey();
  final _briefWorldKey = GlobalKey();
  final _briefConfigKey = GlobalKey();
  final _briefCharacterController = ExpansibleController();
  final _briefCompanionsController = ExpansibleController();
  final _briefWorldController = ExpansibleController();
  final _briefConfigController = ExpansibleController();
  // Sprout + Explorer: pet card / pet-species editor is hidden behind a single
  // "Add my pet" tap so the page doesn't open with three input fields visible.
  bool _showPetCardForSprout = false;
  bool _showPetCardForExplorer = false;
  // Pending companion species — set by "Add a Person" / "Add a Pet" buttons,
  // consumed by the HeroPetCard to create the entry and open the editor.
  String? _pendingCompanionSpecies;
  int _pendingCompanionToken =
      0; // increments to distinguish repeated adds of same species
  // For "Add a Person": the chosen relationship ("cousin", "grandma", …) and
  // whether they're a grown-up (drives the supportive-presence story framing).
  String? _pendingCompanionRelation;
  bool _pendingCompanionIsAdult = false;

  // Recent saved stories — powers the per-hero "Continue" affordance on the
  // welcome-back grid (page 0). Newest-first.
  List<StoryLocal> _recentStories = const [];

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

    // Determine initial page. If the parent wizard already knows which
    // sub-step we should land on (e.g. user just tapped Back from the review
    // screen, or tapped an "Edit X" button), honor that — otherwise fall back
    // to the character-selection / name+gender flow.
    final requested = widget.requestedSubStep;
    if (requested != null) {
      _heroPage = _pageForSubStep(requested);
    } else if (widget.availableCharacters.isNotEmpty) {
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
    _refreshPremiumStatus();
    _refreshCustomAvatarUsage();
    _loadLastHeroId();
    _loadRecentStories();
    const ParentalConsentService().getAllowPhotoAvatar().then((allow) {
      if (mounted) setState(() => _allowPhotoAvatar = allow);
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
    _sproutCompanionAdvanceTimer?.cancel();
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
        // MT-276: the no-sparkle bands (Creator/Adolescent/Adult) shouldn't get
        // the "✨ ... !" baby-talk toast — match the band's sparkle intensity.
        final hasSparkle =
            themeForAge(widget.wizardData.characterAge).sparkleIntensity > 0;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              hasSparkle ? '✨ Your avatar is ready!' : 'Your avatar is ready.'),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 3),
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
    final band = ageBandFromAge(age);

    // Sprout / Explorer / Adventurer: route the Big Feelings tile straight
    // into the rich LifeQuestScreen — same surface as the bottom-nav tab,
    // so the kid sees the Coping Toolbox, the cloud picker, and quests
    // with in-story coping breaks. This is the *practice and play* path.
    // After they exit, they land back on the scene picker (no auto-advance);
    // they can pick a different scene for an AI story or just close the
    // wizard. Older bands keep the modal-based "feeling → wizard story"
    // flow until the toolbox is reframed for them.
    if (band == AgeBand.sprout ||
        band == AgeBand.explorer ||
        band == AgeBand.adventurer) {
      final name = widget.wizardData.characterName.trim().isEmpty
          ? 'Hero'
          : widget.wizardData.characterName.trim();
      final companion = widget.wizardData.companionNames.isNotEmpty
          ? widget.wizardData.companionNames.first
          : '';
      final gender = widget.wizardData.characterGender;
      final pronoun = gender == 'Girl'
          ? 'she'
          : gender == 'Boy'
              ? 'he'
              : 'they';
      final pronounCap = gender == 'Girl'
          ? 'She'
          : gender == 'Boy'
              ? 'He'
              : 'They';
      final possessive = gender == 'Girl'
          ? 'her'
          : gender == 'Boy'
              ? 'his'
              : 'their';
      final activeId = await ChildProfileService().getActiveProfileId();
      final grownup = await CaregiverService().grownupLabelOrDefault(activeId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LifeQuestScreen(
            childAge: age,
            childName: name,
            companionName: companion,
            pronoun: pronoun,
            pronounCap: pronounCap,
            possessive: possessive,
            grownup: grownup,
          ),
        ),
      );
      return;
    }

    // Older bands (creator+, adolescent, adult): existing modal flow that
    // captures a feeling result and advances the wizard into AI generation.
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
      _heroNextPage();
    }
  }

  void _onSceneTap(String id) {
    if (id == 'big_feelings_quest') {
      _openFeelingsQuest();
    } else {
      setState(() => widget.wizardData.selectedScenario = id);
      // MT-279: auto-advance for Sprout (≤5) AND Explorer (6-8). Younger
      // children expect forward motion after a tap — a checkmark alone is too
      // subtle to notice, and making Explorer hunt for "Next" on a single-select
      // page is extra taps with no payoff. Adventurer+ (≥9) keep the explicit
      // arrow so they can browse settings before committing.
      if (widget.wizardData.characterAge <= 8) _heroNextPage();
    }
    final label = _sceneLabel(id);
    if (label != null) unawaited(_speakForSprout(label));
  }

  void _heroNextPage() {
    // Skip Page 2 when it would only show a single button — open the gallery
    // directly. _maybeAdvanceFromStylePage handles jumping from Page 1 → Page 3
    // once an avatar is chosen.
    if (_heroPage == 1 && !_shouldShowBuildHeroPage) {
      unawaited(_openAvatarGallery());
      return;
    }
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

  /// Advances out of the Hero Creator from the story-type page (Page 6).
  /// Idempotent: Sprout mode cards schedule a delayed call after each tap, so
  /// this may fire more than once — only the first crosses into the next step.
  /// Launches the Superhero Mode flow directly from the story-type picker
  /// (Explorer + Adventurer). Mirrors the entry inside [ImagineItScreen] so the
  /// feature is reachable as a first-class story type, not buried under
  /// "Imagine It". On success the superhero flow has already set
  /// `selectedScenario = 'superhero'` + `customElements`, so we just sync the
  /// wish field and advance the wizard.
  ///
  /// MT-303: [forcedMode] threads the teen "vibe":
  ///   • null (the 'superhero' scenario tile / story-type orb) → for the
  ///     Adolescent band, show the vibe chooser first (classic vs antihero);
  ///     every other band launches the existing flow directly, unchanged.
  ///   • 'antihero' (the "Live a double life" CTA) → pin heroMode and skip the
  ///     chooser, straight into the existing antihero saga.
  Future<void> _launchSuperheroFromStoryType({String? forcedMode}) async {
    final band = ageBandFromAge(widget.wizardData.characterAge);
    if (forcedMode != null) {
      widget.wizardData.heroMode = forcedMode;
    }
    // The vibe chooser is Adolescent-only: it's the only band with a real
    // antihero "double life" path to offer against the classic hero path.
    // Creator's flow has no Identity/distress step, so a "real cost" card would
    // be a false promise — Creator launches the existing flow directly.
    final useChooser = forcedMode == null && band == AgeBand.adolescent;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => useChooser
            ? SuperheroVibeChooserScreen(
                wizardData: widget.wizardData,
                band: band,
              )
            : SuperheroEntryScreen(wizardData: widget.wizardData),
      ),
    );
    if (!mounted || result != true) return;
    _wishController.text = widget.wizardData.customElements;
    setState(() {});
    _advanceFromStoryType();
  }

  /// MT-279: Express "Tell Me a Story!" lane for the Explorer band (6-8).
  /// Surfaced on the Adventure Team page, it skips the remaining optional pages
  /// (scene + story-type) and jumps straight to Magic Review with smart
  /// defaults — a surprise preset world plus the default illustrated-story mode
  /// (already the WizardData default). Younger Explorers who just want a story
  /// *now* reach it in one tap instead of hunting through three more "Next"es.
  void _expressTellMeAStory() {
    // Pick a surprise world if the child hasn't already chosen one, so the
    // generated story has a concrete setting rather than the blank "Magical
    // Adventure" fallback. These three presets are the always-available scene
    // tiles (no modal, no premium gate) shared across the young bands.
    final current = widget.wizardData.selectedScenario;
    if (current == null || current.isEmpty) {
      const surprisePresets = <String>[
        'vanishing_colors',
        'crystal_cavern',
        'volcano_dragons',
      ];
      widget.wizardData.selectedScenario =
          surprisePresets[Random().nextInt(surprisePresets.length)];
    }
    FirebaseAnalyticsService.logEvent('explorer_express_story', {
      'scenario': widget.wizardData.selectedScenario,
    });
    // Story-type defaults (illustrated 'tales' mode) already live on WizardData,
    // so no mode mutation is needed here — just advance to Magic Review. Reuses
    // the story-type latch so a double-tap can't push two steps.
    _advanceFromStoryType();
  }

  void _advanceFromStoryType() {
    if (_storyTypeAdvancing || !mounted) return;
    _storyTypeAdvancing = true;
    widget.onNext();
    // Reopen the latch once the tap-burst window has elapsed. Burst timers all
    // fire within ~700ms of their tap, so 2s safely swallows the burst while
    // still letting a later return to this page advance again.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _storyTypeAdvancing = false;
    });
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
      // Mirror the forward-skip: when Page 2 was bypassed, going back from
      // Page 3 should land on Page 1, not the empty single-button screen.
      final target =
          (_heroPage == 3 && !_shouldShowBuildHeroPage) ? 1 : _heroPage - 1;
      _heroPageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _heroPage = target);
      _logPageView(_heroPage);
      _notifySubStep();
    }
  }

  /// Maps the wizard's high-level sub-step (0=Hero, 1=Team, 2=Place, 3=Magic)
  /// to the corresponding hero-creator inner page index.
  static int _pageForSubStep(int subStep) => switch (subStep) {
        0 => 1, // Create Hero
        1 => 4, // Pick Team
        2 => 5, // Pick Place
        _ => 6, // Make Magic
      };

  void _jumpToSubStep(int subStep) {
    final bandData =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    if (bandData.band.isMature) {
      // Creative Brief (accordion) — expand the target section and scroll to it.
      final key = switch (subStep) {
        0 => _briefCharacterKey,
        1 => _briefCompanionsKey,
        2 => _briefWorldKey,
        _ => _briefConfigKey,
      };
      final controller = switch (subStep) {
        0 => _briefCharacterController,
        1 => _briefCompanionsController,
        2 => _briefWorldController,
        _ => _briefConfigController,
      };
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Collapse non-target sections so the accordion stays focused.
        for (final c in [
          _briefCharacterController,
          _briefCompanionsController,
          _briefWorldController,
          _briefConfigController,
        ]) {
          if (c != controller) {
            try {
              c.collapse();
            } catch (_) {}
          }
        }
        try {
          controller.expand();
        } catch (_) {}
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

    final targetPage = _pageForSubStep(subStep);
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

  // ─── Rotating hero (Premium "Whose turn is it?") ────────────────────────────
  static const _kLastHeroIdKey = 'last_hero_id';
  static const _kLastHeroAtKey = 'last_hero_at';

  Future<void> _loadLastHeroId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_kLastHeroIdKey);
      if (mounted) setState(() => _lastHeroId = id);
    } catch (_) {
      // SharedPreferences unavailable — silently skip the rotating-hero hint.
    }
  }

  Future<void> _saveLastHero(String characterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastHeroIdKey, characterId);
      await prefs.setString(
        _kLastHeroAtKey,
        DateTime.now().toIso8601String(),
      );
    } catch (_) {}
  }

  /// Returns the character whose turn it is *next* — the saved character that
  /// was NOT the last hero. Returns null when there are fewer than 2 kids
  /// saved or no last-hero record exists.
  Character? _suggestedNextHero() {
    if (_lastHeroId == null) return null;
    if (widget.availableCharacters.length < 2) return null;
    for (final c in widget.availableCharacters) {
      if (c.id != _lastHeroId) return c;
    }
    return null;
  }

  Character? _lastHero() {
    if (_lastHeroId == null) return null;
    for (final c in widget.availableCharacters) {
      if (c.id == _lastHeroId) return c;
    }
    return null;
  }

  // ─── Character helpers ────────────────────────────────────────────────────────
  void _loadExistingCharacter(Character character) {
    try {
      // Persist the rotating-hero pointer so next session can default the
      // suggestion to a different sibling.
      _saveLastHero(character.id);
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

  void _switchToNewCharacter() async {
    FirebaseAnalyticsService.logEvent('hero_creator_create_new', {});
    // Ask which age band the new character should be — without this the wizard
    // sticks to whatever age band the previous character used, which makes it
    // impossible to e.g. make an Explorer hero after a Sprout one (the Sprout
    // name input even hides the keyboard behind a big mic).
    final newAge = await _promptNewCharacterAge();
    if (!mounted || newAge == null) return;
    final ageChanged = newAge != widget.wizardData.characterAge;
    setState(() {
      _isCreatingNew = true;
      _selectedExistingCharacter = null;
      _generatedAvatar = null;
      widget.wizardData.generatedAvatar = null;
      widget.wizardData.characterId = null;
      widget.wizardData.characterName = '';
      widget.wizardData.characterAge = newAge;
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
    if (ageChanged) widget.onAgeChanged?.call(newAge);
    _heroNextPage();
  }

  /// Modal age picker shown when the user taps "Or create someone new".
  /// Returns the picked age (a representative age per band) or null on cancel.
  Future<int?> _promptNewCharacterAge() async {
    const options = <({String label, String sublabel, int age})>[
      (label: 'Little Sprout', sublabel: 'Ages 3–5', age: 4),
      (label: 'Explorer', sublabel: 'Ages 6–8', age: 7),
      (label: 'Adventurer', sublabel: 'Ages 9–11', age: 10),
      (label: 'Creator', sublabel: 'Ages 12–14', age: 13),
      (label: 'Adolescent', sublabel: 'Ages 15–17', age: 16),
      (label: 'Adult', sublabel: '18+', age: 21),
    ];
    final currentAge = widget.wizardData.characterAge;
    return showDialog<int>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF2C1B47),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
        ),
        title: Text(
          'How old is your new hero?',
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: const Color(0xFFFFD700),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in options)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: o.age == currentAge
                            ? const Color(0xFF7C4DFF)
                            : Colors.white.withAlpha(20),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: o.age == currentAge
                                ? const Color(0xFFFFD700)
                                : Colors.white24,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onPressed: () => Navigator.of(dialogCtx).pop(o.age),
                      child: Column(
                        children: [
                          Text(
                            o.label,
                            style: GoogleFonts.fredoka(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            o.sublabel,
                            style: GoogleFonts.fredoka(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
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
    // Read the archetype name aloud for young children. Sprout (≤5) hears the
    // name only at slow rate; Explorer (6-8) hears name + special-ability so
    // a non-reading 7yo learns what their hero can do.
    final age = widget.wizardData.characterAge;
    final spokenName = archetype.nameForAge(age);
    if (age <= 5) {
      unawaited(_speakForSprout(spokenName));
    } else if (age <= 8) {
      unawaited(
          _speakArchetypeForExplorer(spokenName, archetype.specialAbility));
    }

    // Page 3 is archetype-only — auto-advance once an archetype is chosen.
    if (_heroPage != 3) return;
    _heroNextPage();
  }

  /// Explorer (6-8) TTS readback for archetype tap. Slightly faster than
  /// Sprout's 0.65 — early readers can keep up — but slower than default so
  /// the special-ability sentence registers before auto-advance kicks in.
  Future<void> _speakArchetypeForExplorer(
    String name,
    String specialAbility,
  ) async {
    await AppTtsService.instance.stop();
    if (!mounted) return;
    unawaited(AppTtsService.instance
        .speak('$name. $specialAbility.', rateScale: 0.85));
  }

  /// Sprout (≤5) + Explorer (6-8): auto-advance from the companions page (4) to
  /// the scene page after a companion is selected (MT-279). Mirrors the
  /// auto-advance pattern already used for scene tap and gender tap — young
  /// children expect forward motion after a tap. The delay lets any TTS
  /// readback play and gives a beat for second thoughts; it is re-armed on
  /// every tap, so an Explorer adding multiple buddies advances only after
  /// their last pick, not the first.
  void _scheduleSproutCompanionAdvance() {
    _sproutCompanionAdvanceTimer?.cancel();
    _sproutCompanionAdvanceTimer = Timer(
      const Duration(milliseconds: 1400),
      () {
        if (!mounted) return;
        if (_heroPage != 4) return;
        if (widget.wizardData.companionNames.isEmpty &&
            widget.wizardData.selectedCompanions.isEmpty) {
          return;
        }
        _heroNextPage();
      },
    );
  }

  void _maybeAdvanceFromStylePage() {
    if (!mounted || !_hasAvatar) return;
    // Normal flow: Page 2 is avatar-only — auto-advance once the avatar is chosen.
    if (_heroPage == 2) {
      _heroNextPage();
      return;
    }
    // Page 1 → Page 3 once an avatar lands. Two entry points hit this:
    //   1. Gallery opens directly from Page 1 (when !_shouldShowBuildHeroPage),
    //      so Page 2 is skipped entirely.
    //   2. BYOK upgrade mid-flow: a non-premium user on Page 1 taps Next →
    //      gallery → "Create custom avatar" → BYOK wizard. The wizard flips
    //      _isPremium → true (and thus _shouldShowBuildHeroPage → true), then
    //      drops the user straight into CustomAvatarScreen. Without dropping
    //      the !_shouldShowBuildHeroPage guard, the avatar lands but no
    //      advance fires — the user is stranded on the name/gender page.
    if (_heroPage == 1) {
      _triggerPageCelebration();
      _heroPageController.animateToPage(
        3,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _heroPage = 3);
      _logPageView(_heroPage);
      _notifySubStep();
      Future.delayed(const Duration(milliseconds: 850), () {
        if (mounted) unawaited(_speakPagePrompt(_heroPage));
      });
    }
  }

  Future<bool> _saveCharacterDraft() async {
    if (!_isCreatingNew) return true;
    bool backendOk = true;
    bool isLocalBackendDown = false;
    Object? caughtError;
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
    } catch (e) {
      debugPrint('⚠️ Character save failed: $e');
      backendOk = false;
      caughtError = e;
      isLocalBackendDown =
          e.toString().contains('Cannot reach the local backend');
    }
    // Mirror to local Isar so a backend outage doesn't lose the character.
    await _persistLocalCharacter(synced: backendOk);
    if (!backendOk && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isLocalBackendDown
            ? 'Avatar selected. Could not sync right now.'
            : 'Could not save character: $caughtError'),
        backgroundColor: isLocalBackendDown ? AppColors.gold : AppColors.error,
      ));
    }
    return backendOk || isLocalBackendDown;
  }

  Future<void> _persistLocalCharacter({required bool synced}) async {
    try {
      widget.wizardData.characterId ??=
          'local_${DateTime.now().millisecondsSinceEpoch}';
      final avatar = widget.wizardData.generatedAvatar;
      final localChar = CharacterLocal()
        ..characterId = widget.wizardData.characterId!
        ..name = widget.wizardData.characterName
        ..age = widget.wizardData.characterAge
        ..avatarUrl = avatar?.imageBase64
        ..isSyncedToServer = synced
        ..createdAt = DateTime.now();
      await IsarService.saveCharacter(localChar);
    } catch (e) {
      debugPrint('⚠️ Local character save failed: $e');
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
    // Gate: character look must be chosen for new characters.
    // Mature bands skip this — CreativeBriefWidget has no avatar UI (see build() isTeen branch).
    final isMatureBand =
        Theme.of(context).extension<AgeBandThemeData>()?.band.isMature ?? false;
    if (_isCreatingNew && !_hasAvatar && !isMatureBand) {
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
        color: band.accent,
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
    final lastHero = _lastHero();
    final suggested = _suggestedNextHero();
    // Reorder so the suggested next hero appears at the top — last hero
    // moves to the bottom but is never hidden, so the user can still pick them.
    final orderedChars = (lastHero != null && suggested != null)
        ? <Character>[
            ...widget.availableCharacters.where((c) => c.id != lastHero.id),
            lastHero,
          ]
        : widget.availableCharacters;
    final showRotatingBanner = lastHero != null && suggested != null;
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          showRotatingBanner
              ? "Whose turn is it?"
              : (ageBand == AgeBand.creator ? "Welcome back" : "Welcome back!"),
          textAlign: TextAlign.center,
          style: _bandTitleStyle(band, baseFontSize: 28),
        ),
        const SizedBox(height: 8),
        Text(
          showRotatingBanner
              ? "${lastHero.name} was the hero last time. Whose turn now?"
              : "Tap your character to start a story!",
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: orderedChars.length,
            itemBuilder: (context, index) {
              final char = orderedChars[index];
              final isSuggested = showRotatingBanner && char.id == suggested.id;
              final recentForCard = _recentStoryForCharacter(char);
              return Stack(
                children: [
                  HeroCharacterChoiceCard(
                    character: char,
                    getAvatarProvider: _getAvatarProvider,
                    onTap: () {
                      if (recentForCard != null) {
                        _showContinueOrNewSheet(char, recentForCard);
                      } else {
                        _loadExistingCharacter(char);
                        _handleContinue();
                      }
                    },
                  ),
                  if (recentForCard != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C3FC7),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          '📖 Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (isSuggested)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          '🌟 Your turn!',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (showRotatingBanner)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: TextButton(
              onPressed: () {
                _loadExistingCharacter(lastHero);
                _handleContinue();
              },
              child: Text(
                'Actually, let ${lastHero.name} go again',
                style: GoogleFonts.fredoka(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white38,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
          child: _buildCreateNewHeroButton(),
        ),
      ],
    );
  }

  // MT-071(b): the "create someone new" path is the only way into the
  // photo-to-cartoon avatar flow, but as a faint underlined text link it
  // vanished under the character tiles — kids never discovered the
  // snap-a-selfie magic. Reframed as a featured tile with the 📸 → ✨ → 🦸
  // transformation preview so the capability is impossible to miss, while
  // still reading as secondary to the existing-hero tiles above it.
  Widget _buildCreateNewHeroButton() {
    return GestureDetector(
      onTap: _switchToNewCharacter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6B2FB3),
              Color(0xFFB23A8E),
              Color(0xFFFF6B35),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD700), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withAlpha(70),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            // 📸 → ✨ → 🦸 makes the photo-to-cartoon magic legible at a
            // glance, even to a pre-reader.
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('📸', style: TextStyle(fontSize: 22)),
                SizedBox(height: 2),
                Icon(Icons.arrow_downward_rounded,
                    color: Colors.white70, size: 12),
                SizedBox(height: 2),
                Text('🦸', style: TextStyle(fontSize: 22)),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Create a new hero',
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Snap a selfie — turn YOU into a cartoon hero!',
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFFFD700), size: 28),
          ],
        ),
      ),
    );
  }

  // ─── Welcome-back grid: per-hero Continue affordance ────────────────────────

  Future<void> _loadRecentStories() async {
    try {
      final stories =
          await OfflineStoryService(IsarService.instance).getAllStories();
      stories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) setState(() => _recentStories = stories);
    } catch (_) {
      // Non-fatal — the Continue affordance simply won't appear.
    }
  }

  /// Most recent saved story (within 30 days) featuring [character], matched
  /// by id first then name. The dual match matters because wizard-saved
  /// stories don't always carry a character id.
  StoryLocal? _recentStoryForCharacter(Character character) {
    final id = character.id.trim();
    final name = character.name.trim().toLowerCase();
    if (id.isEmpty && name.isEmpty) return null;
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    for (final story in _recentStories) {
      if (story.createdAt.isBefore(cutoff)) continue;
      final match = story.characters.any((c) =>
          (id.isNotEmpty && c.id.trim() == id) ||
          (name.isNotEmpty && c.name.trim().toLowerCase() == name));
      if (match) return story;
    }
    return null;
  }

  /// Re-opens a saved story; passing [storyId] makes the reader resume at the
  /// page the child last left off on.
  void _openSavedStory(StoryLocal story) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => StoryResultScreen(
            title: story.title,
            storyText: story.storyText,
            characterName: story.characters.isNotEmpty
                ? story.characters.first.name
                : null,
            storyId: story.identifier,
            persistedCoverImageBase64: story.coverImageBase64,
            persistedPageIllustrationsJson: story.pageIllustrationsJson,
          ),
        ))
        .then((_) => _loadRecentStories());
  }

  /// Tapping a hero who has a recent story offers Continue vs. start-new
  /// rather than silently launching a fresh wizard.
  void _showContinueOrNewSheet(Character character, StoryLocal recent) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${character.name}'s stories",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            _continueSheetChoice(
              icon: Icons.menu_book_rounded,
              color: const Color(0xFF6C3FC7),
              title: 'Continue',
              subtitle: recent.title,
              onTap: () {
                Navigator.pop(sheetCtx);
                _openSavedStory(recent);
              },
            ),
            _continueSheetChoice(
              icon: Icons.auto_awesome,
              color: const Color(0xFFFF8A00),
              title: 'Start a new story',
              subtitle: 'Make a brand-new adventure',
              onTap: () {
                Navigator.pop(sheetCtx);
                _loadExistingCharacter(character);
                _handleContinue();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _continueSheetChoice({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
      // MT-280 follow-up: the free-avatar signpost added ~70px beneath the
      // photo card, overflowing the fixed PageView viewport on short screens
      // (RenderFlex overflow of 64px in the 600px test surface). Wrap the
      // Spacer-centered column so it stays vertically centred when there's
      // room, but scrolls instead of overflowing when the content is taller
      // than the viewport. IntrinsicHeight lets the Spacers keep working.
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // AI photo avatar is gated on parental consent only. Every
                          // account gets ONE free custom avatar — the "magic moment" of
                          // turning a real photo into a cartoon hero. The backend
                          // enforces the 1-free limit and returns UPGRADE_REQUIRED after
                          // that. Surfaced as the featured option so kids see it first.
                          //
                          // MT-151: when a non-premium account has already used its one
                          // free custom avatar, the card carries a "Premium" badge and
                          // its tap opens the upgrade dialog directly — skipping the
                          // selfie capture so no photo is wasted on a 403.
                          if (_allowPhotoAvatar) ...[
                            HeroAvatarChoiceCard(
                              featured: true,
                              icon: Icons.camera_alt_rounded,
                              title: 'Turn YOU into a cartoon hero!',
                              subtitle:
                                  'Snap a selfie — watch the magic turn it\ninto your very own custom cartoon.',
                              badgeText:
                                  _customAvatarLocked ? '✨ Premium ✨' : null,
                              onTap: _customAvatarLocked
                                  ? _showCustomAvatarUpgradeDialog
                                  : _openCustomAvatarScreen,
                            ),
                            // MT-280: signpost the 1-free-custom-avatar limit UP FRONT
                            // (per build) so a non-premium parent isn't ambushed by the
                            // paywall on their 2nd child. Premium accounts already have
                            // unlimited custom heroes, so the caption is hidden for them.
                            if (!_isPremium) ...[
                              const SizedBox(height: 8),
                              _buildFreeAvatarSignpost(),
                            ],
                            const SizedBox(height: 18),
                            Row(
                              children: const [
                                Expanded(child: Divider(color: Colors.white24)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('or',
                                      style: TextStyle(
                                          color: Colors.white60, fontSize: 12)),
                                ),
                                Expanded(child: Divider(color: Colors.white24)),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],
                          HeroAvatarChoiceCard(
                            icon: Icons.auto_awesome,
                            title: 'Pick a magical hero',
                            subtitle: 'Choose from our gallery',
                            onTap: _openAvatarGallery,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (_hasAvatar) ...[
                      Text(
                        'Great! Tap Next to pick your hero style.',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
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
                ),
              ),
            ),
          );
        },
      );
    });
  }

  /// MT-280: the upfront caption beneath the photo-avatar card that explains
  /// the 1-free-custom-avatar limit before a non-premium parent invests effort.
  /// The quota is per ACCOUNT (not per child), so this shows on every build to
  /// pre-empt the "surprise on the 2nd child" reported in MT-280. Reuses the
  /// existing `_isPremium` / `_customAvatarLocked` tier checks rather than
  /// hardcoding any new tier logic. Once the free avatar is spent, the copy
  /// flips to explain the Premium badge now on the card.
  Widget _buildFreeAvatarSignpost() {
    final message = _customAvatarLocked
        ? "You've used your 1 free custom hero. More custom heroes are "
            'Premium — or pick a magical hero from the gallery below, always '
            'free.'
        : 'Your free plan includes 1 custom photo hero per account. Extra '
            'custom heroes (like a second one for another child) are Premium — '
            'but the magical hero gallery is always free.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
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
    // Fetch all companions across every band so we can resolve selected IDs to
    // image paths regardless of which band is currently active.
    final allKnownCompanions = allCompanionEntries();

    // Collect selected named companions in order — use ID as source of truth.
    // Companion IDs are NOT unique across bands (e.g. 'robin' is reused for
    // Explorer/Adventurer/Creator/Adolescent/Adult), so the same selected ID
    // would match in every band and render a duplicate orb per band. Keep
    // only the first match per id, preferring the active band's image.
    final activeBand = Theme.of(context).extension<AgeBandThemeData>()?.band ??
        AgeBand.explorer;
    final preferredById = <String, CompanionData>{};
    for (final c in allKnownCompanions) {
      if (!widget.wizardData.selectedCompanions.contains(c.id)) continue;
      final existing = preferredById[c.id];
      if (existing == null) {
        preferredById[c.id] = c;
      } else if (c.imagePath.contains('/${activeBand.name}/') &&
          !existing.imagePath.contains('/${activeBand.name}/')) {
        preferredById[c.id] = c;
      }
    }
    final selectedNamed = [
      for (final id in widget.wizardData.selectedCompanions)
        if (preferredById[id] != null) preferredById[id]!,
    ];

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
          ? defaultCompanionName(pet['species'], i)
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
    // One buddy is already a complete team — more is optional, up to maxSlots.
    // Rather than pre-rendering every empty seat (which read as "you must fill
    // all three"), show the child's chosen companions plus a SINGLE trailing
    // "+" orb that quietly invites another. This keeps the earned-reveal
    // delight (a fresh add-orb appears after each pick) without implying a
    // quota, and the status line celebrates any team of one or more.
    // (Founder direction 2026-06-05; supersedes the 3-empty-seat layout.)
    final hasTeam = slots.isNotEmpty;
    final showAddOrb = slots.length < maxSlots;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Chosen companions
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
            // A single optional "+" orb — an invitation to add another, not a
            // seat that must be filled. Hidden once maxSlots is reached.
            if (showAddOrb) ...[
              if (hasTeam) const SizedBox(width: 16),
              AnimatedOpacity(
                opacity: hasTeam ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 280),
                child: const GlowingCompanionOrb(slot: null),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          style: TextStyle(
            color: hasTeam ? const Color(0xFFFFE08A) : Colors.white38,
            fontSize: hasTeam ? 15 : 13,
            fontWeight: hasTeam ? FontWeight.w600 : FontWeight.w500,
            fontStyle: hasTeam ? FontStyle.normal : FontStyle.italic,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasTeam) ...[
                const Text('✨', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
              ],
              Text(
                slots.isEmpty
                    ? (maxSlots == 1
                        ? 'Tap a buddy to bring along!'
                        : 'Tap a friend below — one buddy is plenty')
                    : slots.length == 1
                        ? '${slots[0].name} is ready to join you!'
                        : slots.length == 2
                            ? '${slots[0].name} & ${slots[1].name} are with you!'
                            : 'What a team — everyone\'s here!',
              ),
              if (hasTeam) ...[
                const SizedBox(width: 6),
                const Text('✨', style: TextStyle(fontSize: 14)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// MT-279: the Explorer-only express-lane CTA. A bright, unmistakable
  /// shortcut that says "you've got a hero — I'll handle the rest". Styled to
  /// echo the welcome screen's "Create a new hero" tile so it reads as a
  /// first-class action, while the subtitle makes the surprise-world behaviour
  /// explicit so a tap never feels like a mistake.
  Widget _buildExpressStoryButton() {
    return GestureDetector(
      onTap: _expressTellMeAStory,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7C4DFF), Color(0xFFFF7043)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD700), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withAlpha(60),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('⚡', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tell Me a Story!',
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Skip ahead — we'll pick a world for you!",
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFFFD700), size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildAdventureTeamPage() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final companionTitle = band.band == AgeBand.sprout
        ? 'Pick your buddy!'
        : band.band == AgeBand.explorer
            ? 'Pick your friends!'
            : band.band == AgeBand.adventurer
                ? 'Choose your companions'
                : 'Choose Your Companions';
    final isYoung =
        band.band == AgeBand.sprout || band.band == AgeBand.explorer;
    final hasNoCompanion = widget.wizardData.companionNames.isEmpty &&
        widget.wizardData.selectedCompanions.isEmpty;
    // Page is restructured Column(Expanded(Scroll), Next) so the Next CTA
    // stays in viewport when the companion grid + custom-friend buttons
    // push past the fold — Adventurer band Choose Your Companions audit
    // C-003 (audit-reports/age-review-choose-your-companions-adventurer-20260530.md).
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
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
                // MT-279: Explorer-only express lane — once the hero is built,
                // offer a one-tap shortcut straight to the story so 6-8s aren't
                // forced through team + scene + story-type to reach a story.
                if (band.band == AgeBand.explorer) ...[
                  _buildExpressStoryButton(),
                  const SizedBox(height: 20),
                ],
                _buildCompanionShowcase(),
                const SizedBox(height: 20),
                _buildCompanionGrid(),
                const SizedBox(height: 24),
                // "Adventure alone!" exit — only surfaced for young bands and
                // only when no companion is selected. Without it, an empty
                // showcase reads as "you have to fill these orbs" to a 7yo.
                // Tapping advances the wizard the same way Next does, but the
                // labelling makes the optional nature explicit.
                if (isYoung && hasNoCompanion) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.directions_walk_rounded,
                        color: Colors.white70, size: 18),
                    label: Text(
                      'Adventure alone!',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: band.uiFontFamily,
                      ),
                    ),
                    onPressed: _heroNextPage,
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: _buildNextArrowButton(
            enabled: true,
            onTap: _heroNextPage,
            hint: 'Next: Choose Your Scene',
          ),
        ),
      ],
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
          // MT-279: auto-advance after a companion pick for Sprout (≤5) AND
          // Explorer (6-8). The advance timer is re-armed on every tap (see
          // _scheduleSproutCompanionAdvance), so an Explorer picking up to 3
          // buddies still advances only ~1.4s after their LAST pick — not after
          // the first. _speakForSprout self-gates to ≤5, so Explorer gets the
          // forward motion without the TTS name read-back.
          onCompanionTapped: widget.wizardData.characterAge <= 8
              ? (name) {
                  _speakForSprout(name);
                  _scheduleSproutCompanionAdvance();
                }
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
                  onPressed: _startAddPerson,
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Add a Person'),
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
                  label: const Text('Add a Pet'),
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
          const SizedBox(height: 10),
          // Premium signal UP FRONT — turning a photo into a magical portrait is
          // a paid feature, so non-premium users would otherwise pick a
          // relationship + take a photo only to be blocked at the end (a 403
          // that reads like "the app is broken"). Tell them before they invest,
          // and reassure that companions still join with their real photo.
          if (!_isPremium)
            InkWell(
              onTap: _showCompanionPhotoPremiumInfo,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Magical photo portraits are a Premium feature — your '
                        'companion still joins with their real photo.',
                        style: TextStyle(
                          color: const Color(0xFFE0AAFF),
                          fontSize: 11,
                          fontFamily: band.uiFontFamily,
                        ),
                      ),
                    ),
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: Color(0xFFE0AAFF)),
                  ],
                ),
              ),
            ),
          // Photo-handling reassurance — Choose Your Companions audit P1 fix.
          // Parents tapping "Add a Person" on behalf of a 9-11 child need a
          // visible signal that the photo isn't being stored.
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 14, color: Colors.white54),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Photos generate your companion\'s portrait. Not stored on our servers.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontFamily: band.uiFontFamily,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                  ],
                ),
              ),
            )
          else
            HeroPetCard(
              wizardData: widget.wizardData,
              onPickPhoto: ({int? petIndex}) =>
                  _pickPetPhoto(petIndex: petIndex),
              onChanged: () => setState(() {}),
              onSaveCompanion: (
                      {required int petIndex,
                      required String name,
                      required String species,
                      required String description}) =>
                  _onSaveCompanion(
                      petIndex: petIndex,
                      name: name,
                      species: species,
                      description: description),
            ),
        ] else if (band.band == AgeBand.explorer) ...[
          // Explorer: pet form is hidden behind a single tap so the page
          // doesn't open with photo + species + name fields all demanding
          // attention. Tap reveals the full HeroPetCard.
          if (!_showPetCardForExplorer)
            GestureDetector(
              onTap: () => setState(() => _showPetCardForExplorer = true),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🐾', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Add your real pet to the adventure!',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: Colors.white38, size: 22),
                  ],
                ),
              ),
            )
          else
            HeroPetCard(
              wizardData: widget.wizardData,
              onPickPhoto: ({int? petIndex}) =>
                  _pickPetPhoto(petIndex: petIndex),
              onChanged: () => setState(() {}),
              onSaveCompanion: (
                      {required int petIndex,
                      required String name,
                      required String species,
                      required String description}) =>
                  _onSaveCompanion(
                      petIndex: petIndex,
                      name: name,
                      species: species,
                      description: description),
              pendingNewSpecies: _pendingCompanionSpecies != null
                  ? '$_pendingCompanionSpecies:$_pendingCompanionToken'
                  : null,
              pendingRelation: _pendingCompanionRelation,
              pendingIsAdult: _pendingCompanionIsAdult,
              onPendingConsumed: _onPendingCompanionConsumed,
            ),
        ] else
          HeroPetCard(
            wizardData: widget.wizardData,
            onPickPhoto: ({int? petIndex}) => _pickPetPhoto(petIndex: petIndex),
            onChanged: () => setState(() {}),
            onSaveCompanion: (
                    {required int petIndex,
                    required String name,
                    required String species,
                    required String description}) =>
                _onSaveCompanion(
                    petIndex: petIndex,
                    name: name,
                    species: species,
                    description: description),
            pendingNewSpecies: _pendingCompanionSpecies != null
                ? '$_pendingCompanionSpecies:$_pendingCompanionToken'
                : null,
            pendingRelation: _pendingCompanionRelation,
            pendingIsAdult: _pendingCompanionIsAdult,
            onPendingConsumed: _onPendingCompanionConsumed,
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
                  style:
                      const TextStyle(color: Color(0xFFFFD700), fontSize: 12),
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

  void _onPendingCompanionConsumed() {
    setState(() {
      _pendingCompanionSpecies = null;
      _pendingCompanionRelation = null;
      _pendingCompanionIsAdult = false;
    });
  }

  /// "Add a Person" — first ask who they are (a friend/cousin, or a grown-up),
  /// then run the existing photo + name flow as a Human companion. Grown-ups are
  /// flagged so the story frames them as a supportive presence, never a villain.
  Future<void> _startAddPerson() async {
    final pick = await _showRelationshipPicker();
    if (!mounted || pick == null) return;
    setState(() {
      _pendingCompanionSpecies = 'Human';
      _pendingCompanionRelation = (pick['relation'] as String?)?.trim();
      _pendingCompanionIsAdult = pick['isAdult'] == true;
      _pendingCompanionToken++;
    });
  }

  /// Bottom sheet: pick who's joining. Returns {relation, isAdult} or null if
  /// dismissed. "Someone else" returns an empty relation (shows as "Friend").
  /// Grown-up relations reuse the adult archetypes so the story keeps the
  /// supportive-presence framing those carry.
  Future<Map<String, dynamic>?> _showRelationshipPicker() {
    const peers = [
      {'relation': 'friend', 'label': 'Friend', 'icon': '🙂'},
      {'relation': 'cousin', 'label': 'Cousin', 'icon': '🧒'},
      {'relation': 'brother', 'label': 'Brother', 'icon': '👦'},
      {'relation': 'sister', 'label': 'Sister', 'icon': '👧'},
      {'relation': 'classmate', 'label': 'Classmate', 'icon': '🎒'},
    ];
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1230),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        Widget chip(String label, String icon, String relation, bool isAdult) {
          return ActionChip(
            avatar: Text(icon, style: const TextStyle(fontSize: 16)),
            label: Text(label),
            backgroundColor: const Color(0xFF2A1F45),
            labelStyle: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
            onPressed: () => Navigator.of(sheetCtx)
                .pop({'relation': relation, 'isAdult': isAdult}),
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Who's joining the story?",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "You'll add their name and photo next.",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text(
                'Family & friends',
                style: TextStyle(
                    color: Color(0xFFD4A0FF),
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in peers)
                    chip(p['label']!, p['icon']!, p['relation']!, false),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Grown-ups',
                style: TextStyle(
                    color: Color(0xFFE0AAFF),
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'They show up as a supportive presence — never a villain.',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in CharacterArchetypes.adultArchetypes)
                    chip(a.label, a.icon, a.relation, true),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(sheetCtx)
                      .pop({'relation': '', 'isAdult': false}),
                  child: const Text('Someone else',
                      style: TextStyle(color: Colors.white70)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _defaultPetNameForIndex(int index, [String? species]) =>
      defaultCompanionName(species, index);

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
              : _defaultPetNameForIndex(
                  targetIndex, widget.wizardData.pets[targetIndex]['species']);
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
      looksDescription: description.isEmpty
          ? (species == 'Human' ? name : species)
          : description,
      photoBytes: photoBytes,
      filename: 'companion_photo.jpg',
    );

    if (!mounted) return;
    final success = !result.isError;
    final message = result.message ??
        (success
            ? (species == 'Human'
                ? '✨ $name is ready for the adventure!'
                : '✨ Magical pet avatar ready!')
            : "Oops! Magic isn't working on that picture. Want to pick a companion instead?");
    setState(() {
      _isPetAvatarGenerating = false;
      _petAvatarStatusMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
      request.fields['owner_age'] = widget.wizardData.characterAge.toString();
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
          // Premium gate: turning a photo into a story portrait is a paid
          // feature. The 403 body uses `code`/`error` (not `message`), so make
          // the denial read as an upgrade prompt, not a broken "magic" failure.
          final code = body['code']?.toString();
          if (response.statusCode == 403 || code == 'upgrade_required') {
            return const _PetAvatarGenerationResult.error(
              '✨ Photo companions are a premium feature. You can still pick a magical companion for free!',
            );
          }
          final message = (body['message'] ?? body['error'])?.toString().trim();
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

  Widget _buildNextArrowButton(
      {required bool enabled, required VoidCallback onTap, String? hint}) {
    return PressableArrowButton(enabled: enabled, onTap: onTap, hint: hint);
  }

  Future<void> _refreshPremiumStatus() async {
    final premium = await ApiServiceManager.hasPremiumAccess();
    if (!mounted) return;
    if (premium != _isPremium) {
      setState(() => _isPremium = premium);
    }
  }

  /// MT-151: pull the account's lifetime custom-avatar count (and the
  /// authoritative premium flag) from the backend so the photo-avatar card can
  /// be gated UPFRONT. Best-effort: a failure leaves [_customAvatarsUsed] at 0,
  /// so the card stays tappable and the backend still enforces the 1-free limit
  /// (the user just hits the UPGRADE_REQUIRED dialog after a selfie, as before).
  Future<void> _refreshCustomAvatarUsage() async {
    try {
      final userId = await UserIdentityService.getOrCreateUserId();
      if (userId.startsWith('anon_')) return;
      final response =
          await ApiServiceManager().get('/users/$userId/feature-unlocks');
      if (!mounted) return;
      final used = response['custom_avatars_generated'];
      final premium = response['is_premium'];
      setState(() {
        if (used is int) _customAvatarsUsed = used;
        if (premium is bool && premium) _isPremium = true;
      });
    } catch (e) {
      debugPrint('Failed to fetch custom-avatar usage: $e');
    }
  }

  /// MT-151: true when the photo-avatar card must be presented as a premium
  /// upsell — a non-premium account that has already used its one free custom
  /// avatar. Tapping the card then opens the upgrade dialog instead of the
  /// selfie flow, so no selfie is wasted.
  bool get _customAvatarLocked => !_isPremium && _customAvatarsUsed >= 1;

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
        // When a premium user taps the gallery's "Create a custom avatar
        // that looks like me!" banner, close the gallery and route into
        // the custom-avatar wizard. Without this the banner would re-show
        // the BYOK setup upsell even for users who already have a key.
        onCreateCustomAvatar: () {
          Navigator.of(ctx).pop();
          _openCustomAvatarScreen();
        },
      ),
    );
    // Gallery may have completed BYOK setup (via its own CTA or the tweak panel).
    // Re-check premium so downstream gates (build-hero page, illustrations) update.
    await _refreshPremiumStatus();
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

    // MT-129: carry the backend's appearance attributes (photo-inferred
    // hair/skin/distinguishing + wizard-entered eye/gender) onto the saved
    // avatar so story illustrations match the created character. Falls back to
    // just the source tag when the backend returned no attributes.
    final avatarAttributes = <String, String>{
      'source': 'custom_photo',
      ...?result?.generationAttributes,
    };

    final generated = GeneratedAvatar(
      id: 'custom_photo_${DateTime.now().millisecondsSinceEpoch}',
      imageBase64: dataUri,
      seed: 'custom_photo',
      style: 'pixar',
      attributes: avatarAttributes,
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

  /// MT-151: shown when a non-premium account that has already used its one
  /// free custom avatar taps the photo-avatar card. Mirrors the "Unlock more
  /// magic ✨" dialog in CustomAvatarScreen, but is reached BEFORE any selfie
  /// is captured — so the user never wastes a photo on a 403. The actionable
  /// path is to pick a ready-made hero from the gallery.
  /// Explains, before the photo flow, that photo->portrait magic is Premium —
  /// so a blocked generation never reads as a broken app.
  Future<void> _showCompanionPhotoPremiumInfo() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1060),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Photo companions are Premium ✨',
          style: GoogleFonts.nunito(
              color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Turning a real photo into a magical story portrait is a Premium '
          "feature. You can still add a companion with their real photo, and "
          'the magical creatures are always free to bring along!',
          style: GoogleFonts.quicksand(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Got it',
                style: GoogleFonts.quicksand(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5F4BDB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _openCompanionPhotoUpgrade();
            },
            child: Text('See Premium',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  /// Routes to the upgrade screen through the COPPA-safe gate (kids get the
  /// "ask a grown-up" math challenge before any pricing is shown).
  Future<void> _openCompanionPhotoUpgrade() async {
    if (!mounted) return;
    await showPaywallGated<void>(
      context: context,
      showActualPaywall: () => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const PremiumUpgradeScreen()),
      ),
    );
  }

  Future<void> _showCustomAvatarUpgradeDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1060),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Unlock more magic ✨',
          style: GoogleFonts.nunito(
              color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          "You've already created your free magic avatar! "
          'Upgrade to premium to turn more photos into cartoon heroes.',
          style: GoogleFonts.quicksand(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Maybe later',
                style: GoogleFonts.quicksand(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5F4BDB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _openAvatarGallery();
            },
            child: Text(
              'Pick a premade hero',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Avatar, Age, Gender, Name, Archetype, Superpower, Continue logic ──────────

  bool get _hasAvatar =>
      _generatedAvatar != null || _customAvatarFilePath != null;

  // Page 2 ("How do you want to build your hero?") only offers a real choice
  // when the photo-avatar option is available, which is gated on parental
  // consent alone. Every account gets one free custom avatar (the "magic
  // moment"); the backend enforces the 1-free limit thereafter.
  // Without consent it's a single-button screen, so we skip it and open the
  // gallery directly from the name/gender page.
  bool get _shouldShowBuildHeroPage => _allowPhotoAvatar;

  Widget _buildArchetypeSceneImage(ArchetypeData archetype, AgeBand ageBand) {
    final gender = widget.wizardData.characterGender;
    final imagePath = archetype.imagePathForBand(ageBand,
        gender: gender.isNotEmpty ? gender : null);
    final fallbackPath =
        gender.isNotEmpty ? archetype.imagePathForBand(ageBand) : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF1A0A2E)),
        if (imagePath != null)
          SafeAssetImage(
            imagePath,
            fallbackPath: fallbackPath,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            placeholder: Center(
                child: Text(archetype.icon ?? '✨',
                    style: const TextStyle(fontSize: 64))),
          )
        else
          Center(
              child: Text(archetype.icon ?? '✨',
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
        boyAsset = 'assets/images/ui/gender/gender_sprout_boy.webp';
        girlAsset = 'assets/images/ui/gender/gender_sprout_girl.webp';
      case AgeBand.explorer:
        boyAsset = 'assets/images/ui/gender/gender_explorer_boy.webp';
        girlAsset = 'assets/images/ui/gender/gender_explorer_girl.webp';
      case AgeBand.adventurer:
        boyAsset = 'assets/images/ui/gender/gender_adventurer_boy.jpg';
        girlAsset = 'assets/images/ui/gender/gender_adventurer_girl.jpg';
      case AgeBand.creator:
        boyAsset = 'assets/images/ui/gender/gender_creator_boy.jpg';
        girlAsset = 'assets/images/ui/gender/gender_creator_girl.jpg';
      case AgeBand.adolescent:
        boyAsset = 'assets/images/ui/gender/gender_adolescent_boy.webp';
        girlAsset = 'assets/images/ui/gender/gender_adolescent_girl.webp';
      case AgeBand.adult:
        boyAsset = 'assets/images/ui/gender/gender_adult_boy.webp';
        girlAsset = 'assets/images/ui/gender/gender_adult_girl.webp';
    }

    final gender = widget.wizardData.characterGender;
    final isAdult = ageBand == AgeBand.adult;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GenderImageButton(
          gender: 'Boy',
          label: isAdult ? 'Man' : null,
          assetPath: boyAsset,
          isSelected: gender == 'Boy',
          width: 140,
          height: 180,
          onTap: () => _handleGenderSelection('Boy'),
        ),
        SizedBox(width: band.space(32)),
        GenderImageButton(
          gender: 'Girl',
          label: isAdult ? 'Woman' : null,
          assetPath: girlAsset,
          isSelected: gender == 'Girl',
          width: 140,
          height: 180,
          onTap: () => _handleGenderSelection('Girl'),
        ),
      ],
    );
  }

  // MT-267: Sprout (3-5) pre-readers can't type, and web mic STT often fails
  // silently — so an empty-name hard gate stranded them on page 1 behind a red
  // error they couldn't read. A friendly, gender-neutral "Surprise me!" name
  // gives a tap-only path that guarantees the child is never stuck.
  static const List<String> _surpriseHeroNames = [
    'Pip',
    'Juno',
    'Milo',
    'Luna',
    'Finn',
    'Nova',
    'Remy',
    'Sunny',
    'Bo',
    'Kit',
    'Ivy',
    'Max',
    'Zara',
    'Leo',
    'Mika',
    'Pax',
  ];

  void _pickSurpriseName() {
    final current = widget.wizardData.characterName.trim();
    // Don't hand back the same name twice in a row.
    final pool = _surpriseHeroNames.where((n) => n != current).toList();
    final name = pool[Random().nextInt(pool.length)];
    setState(() {
      _nameController.text = name;
      widget.wizardData.characterName = name;
    });
    // Read it back so a pre-reader hears who their hero is.
    _nameEchoTimer?.cancel();
    AppTtsService.instance.speak(name, rateScale: 0.8);
  }

  void _handleGenderSelection(String gender) {
    setState(() => widget.wizardData.characterGender = gender);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      // Only auto-advance from Page 1 (name + gender). Without a name the
      // wizard's final-step Make-Magic button stays disabled (isComplete
      // requires a non-empty name) and the bug looks like "the GO button
      // doesn't work." Gate the advance instead and prompt for a name.
      if (_heroPage == 1 && widget.wizardData.characterName.trim().isEmpty) {
        final band = Theme.of(context).extension<AgeBandThemeData>();
        // MT-267: a Sprout can't read the red error or use the text field, so
        // never block them — give a friendly surprise name and continue. They
        // can still mic/type/Surprise-me a different one. Older bands (who can
        // read + type) keep the gentle prompt-to-name.
        if (band?.band == AgeBand.sprout) {
          _pickSurpriseName();
          _heroNextPage();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('What\'s your hero\'s name?'),
          backgroundColor: const Color(0xFFFF6B6B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
        _nameFocusNode.requestFocus();
        return;
      }
      _heroNextPage();
    });
  }

  Widget _buildNameScrollInput() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final nameFontSize = band.headingScale * 20;
    // All Sprout-band children (ages 3-5) get the big mic button — not just ≤4.
    // A 5-year-old can't type a name any better than a 4-year-old can.
    final isSproutFour = band.band == AgeBand.sprout;

    if (band.band.isMature) {
      return Semantics(
        label: 'Character name',
        textField: true,
        child: TextField(
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
        ),
      );
    }

    if (isSproutFour) {
      final isListening = _listeningFor == 'name';
      return Column(
        children: [
          // Big mic button — primary input for sprouts
          Semantics(
            button: true,
            label: isListening ? 'Stop listening' : 'Tap to say your name',
            child: GestureDetector(
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
          ),
          const SizedBox(height: 6),
          Text(
            isListening ? 'Listening…' : 'Tap to say your name!',
            style: GoogleFonts.fredoka(
              color: isListening ? const Color(0xFFFFD700) : Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          // MT-267: tap-only "Surprise me!" so a pre-reader who can't type and
          // can't get the mic to work is never stuck on page 1 without a name.
          Semantics(
            button: true,
            label: 'Surprise me with a name',
            child: GestureDetector(
              onTap: _pickSurpriseName,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD54F).withAlpha(40),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFFFD54F),
                    width: 2,
                  ),
                ),
                child: Text(
                  '🎲  Surprise me!',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
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
              child: Semantics(
                label: 'Character name',
                textField: true,
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
          onMicTap: () => _toggleListening('name'),
          isListening: _listeningFor == 'name',
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
            label: 'Role: ${a.nameForAge(widget.wizardData.characterAge)}',
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
                    _buildArchetypeSceneImage(a, ageBand),
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: const BoxDecoration(
                              color: Color(0xFFFFD700), shape: BoxShape.circle),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(Icons.check,
                              size: 16, color: Colors.black),
                        ),
                      ),
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
            card =
                GestureDetector(onTap: () => _selectArchetype(a), child: card);
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
          label: 'Role: ${a.nameForAge(widget.wizardData.characterAge)}',
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
                    _buildArchetypeSceneImage(a, ageBand),
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
                                a.descriptionForAge(
                                    widget.wizardData.characterAge),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11),
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
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
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
              CreativeBriefWidget(
                wizardData: widget.wizardData,
                availableCharacters: widget.availableCharacters,
                briefScrollController: _briefScrollController,
                briefCharacterKey: _briefCharacterKey,
                briefCompanionsKey: _briefCompanionsKey,
                briefWorldKey: _briefWorldKey,
                briefConfigKey: _briefConfigKey,
                briefCharacterController: _briefCharacterController,
                briefCompanionsController: _briefCompanionsController,
                briefWorldController: _briefWorldController,
                briefConfigController: _briefConfigController,
                nameController: _nameController,
                characterDesireController: _characterDesireController,
                imagineItController: _imagineItController,
                wishController: _wishController,
                selectedArchetypeId: _selectedArchetypeId,
                onChanged: () => setState(() {}),
                onContinue: _handleContinue,
                onLoadCharacter: (char) {
                  setState(() {
                    _loadExistingCharacter(char);
                    _nameController.text = char.name;
                  });
                },
                onSelectArchetype: _selectArchetype,
                companionShowcase: _buildCompanionShowcase(),
                companionGrid: _buildCompanionGrid(),
                onLaunchSuperhero: _launchSuperheroFromStoryType,
              )
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
                  HeroScenePage(
                    wizardData: widget.wizardData,
                    imagineItController: _imagineItController,
                    wishController: _wishController,
                    onChanged: () => setState(() {}),
                    onContinue: _heroNextPage,
                    onSceneTap: _onSceneTap,
                    onSpeakForSprout: _speakForSprout,
                  ),
                  HeroStoryTypePage(
                    wizardData: widget.wizardData,
                    wishController: _wishController,
                    listeningFor: _listeningFor,
                    speechAvailable: _speechAvailable,
                    onChanged: () => setState(() {}),
                    onContinue: _advanceFromStoryType,
                    onToggleListening: _toggleListening,
                    onSpeakForSprout: _speakForSprout,
                    onLaunchSuperhero: _launchSuperheroFromStoryType,
                    illustrationsEnabled: _isPremium,
                  ),
                ],
              ),
            if (!isTeen && _heroPage > 0)
              Positioned(
                top: 10,
                left: 10,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                  tooltip: 'Back',
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
    unawaited(AppTtsService.instance.speak(text, rateScale: 0.65));
  }

  Future<void> _speakPagePrompt(int page) async {
    final age = widget.wizardData.characterAge;
    final knownName = widget.wizardData.characterName.trim();
    final hasKnownName = knownName.isNotEmpty;
    if (age <= 5) {
      // Sprout — full guided TTS on every page.
      // Page 1 opens with a warm, personalised greeting when the name is
      // already known (from the welcome screen) so we don't ask for it twice
      // in a row, which a 4yo finds confusing.
      final page1Prompt = hasKnownName
          ? "Hi $knownName! Let's go on a magical adventure together. "
              "Tap a picture to start making your hero!"
          : "Hi there! Let's go on a magical adventure together. "
              "What is your hero's name? Tap the microphone to say it!";
      final prompt = switch (page) {
        1 => page1Prompt,
        2 => "Pick your hero's look! Tap Choose Look to pick one.",
        3 => "Who is your hero? Tap the one you like!",
        4 => "Tap your buddy to bring them along!",
        5 => "Where should we go? Tap the picture you want.",
        6 =>
          "What kind of story do you want? Story Quest, Rhyme Time, or Learning to Read! Then tap Make Magic!",
        _ => null,
      };
      if (prompt != null) await _speakForSprout(prompt);
    } else {
      // Older bands — warm narrator voice. Page 1 opens with a personalised
      // greeting framed for the band; archetype + companion pages keep their
      // existing guidance.
      final isAdventurer = age >= 9;
      final page1Prompt = isAdventurer
          ? (hasKnownName
              ? "Hey $knownName! Your next adventure is about to begin. "
                  "Let's build your hero."
              : "Hey there! Your next adventure is about to begin. "
                  "Let's build your hero.")
          : (hasKnownName
              ? "Hi $knownName! Get ready for a brand-new adventure. "
                  "Let's create your hero!"
              : "Hi there! Get ready for a brand-new adventure. "
                  "Let's create your hero!");
      final prompt = switch (page) {
        1 => page1Prompt,
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
        'big_feelings_quest' => 'Big Feelings!',
        _ => null,
      };
}

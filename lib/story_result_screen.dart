// lib/story_result_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_flip_builder/page_flip_builder.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/elevenlabs_voice.dart';
import 'services/api_service_manager.dart';
import 'services/tts_api_service.dart';
import 'story_reader_screen.dart';
import 'services/isar_service.dart';
import 'services/offline_story_service.dart';
import 'models/local/story_local.dart';
import 'story_illustration_service.dart';
import 'coloring_book_service.dart';
import 'character_appearance.dart';
import 'coloring_book_library_screen.dart';
import 'models.dart';
import 'therapeutic_focus_options.dart';
import 'services/progression_service.dart';
import 'services/achievement_service.dart';
import 'config/environment.dart';
import 'services/story_feedback_service.dart';
import 'services/story_analytics.dart';
import 'services/therapeutic_analytics.dart';
import 'subscription_models.dart';
import 'theme/age_band_theme.dart';
import 'theme/app_theme.dart';
import 'widgets/crisis_resources_panel.dart';
import 'widgets/error_boundary.dart';
import 'widgets/user_friendly_error_dialog.dart';
import 'widgets/golden_ticket_animation.dart';
import 'services/audio_ambience_service.dart';
import 'widgets/magical_typewriter_text.dart';
import 'widgets/breathing_avatar.dart';
import 'services/feature_tour_service.dart';
import 'widgets/storybook_progress_indicator.dart';
import 'widgets/storybook_page.dart';
import 'widgets/open_book_frame.dart';
import 'utils/motion_utils.dart';
import 'utils/paywall_gate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/byok_setup_wizard.dart';
import 'screens/story_notes_screen.dart';
import 'screens/wizard_story_screen.dart';
import 'screens/chronicles_list_screen.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';
import 'services/per_page_illustration_prefetcher.dart';
import 'widgets/per_page_illustration.dart';
import 'widgets/ai_generated_badge.dart';
import 'package:url_launcher/url_launcher.dart';

class StoryResultScreen extends ConsumerStatefulWidget {
  final String title;
  final String storyText;
  final String? wisdomGem;
  final String? characterName;
  final String? storyId;
  final String? theme;
  final String? characterId;
  final int? characterAge;
  final bool? isInteractive;
  final bool? isRhyming;
  final AchievementService? achievementsService;
  final DateTime? storyCreatedAt;
  final bool trackStoryCreation;
  final bool trackAnalytics;
  final List<Map<String, dynamic>>? backendIllustrations;
  final UserSubscription? subscription;
  final bool isLearningToReadMode;
  final bool usedUserApiKey;
  final bool asyncIllustrations;
  final List<String>? choicesMade;
  // NEW: Page-based story structure
  final List<String>? pages;
  final List<String>? adventureSteps;
  final OfflineStoryService? offlineService;
  final String? storyLengthHint;
  final Map<String, GeneratedAvatar>? companionAvatars;
  final List<String>? companionNames;
  final List<Map<String, dynamic>>? companionPets;
  final List<dynamic>? companionCharacters;
  final String? customElements;
  final WizardData? wizardData;

  /// Base64-encoded cover illustration restored from a saved story. When set,
  /// the cover renders directly without contacting the backend.
  final String? persistedCoverImageBase64;

  /// JSON array of base64-encoded per-page illustrations (indexed by page)
  /// restored from a saved story. When set, pages render their saved art
  /// directly instead of triggering regeneration.
  final String? persistedPageIllustrationsJson;

  /// MT-235 Phase 2 (the returnable saga): the cliffhanger thread this Creator
  /// superhero Issue left dangling (the persisted HeroSaga.nextHook). When set,
  /// a tasteful "Next time…" card + a light one-tap reflection are surfaced at
  /// the end of the story. Null for non-Creator / non-superhero stories.
  final String? sagaNextHook;

  /// Story Notes (MT-254): the parent-selected focus this story actually
  /// practiced — the backend `practiced` field, one of the Big Feelings
  /// trigger values. When set, a quiet "Why this story? 💛" button is offered
  /// at the end so the child (or a co-reading adult) can pull up an
  /// age-appropriate explanation of what the story was guided toward. Null for
  /// stories that carried no hidden parent context → no button, no change.
  final String? practicedFocus;

  /// Story Notes (MT-254): the age the disclosure's directness should match —
  /// the age of the child this story was written for. Used ONLY to pick the
  /// disclosure band, so a re-opened story discloses at the right level even
  /// when the app is currently themed to a different profile. Null on the live
  /// path (where [characterAge] already carries the right age).
  final int? practicedAge;

  const StoryResultScreen({
    super.key,
    required this.title,
    required this.storyText,
    this.wisdomGem,
    this.characterName,
    this.storyId,
    this.theme,
    this.characterId,
    this.characterAge,
    this.isInteractive,
    this.isRhyming,
    this.achievementsService,
    this.storyCreatedAt,
    this.trackStoryCreation = false,
    this.trackAnalytics = true,
    this.backendIllustrations,
    this.subscription,
    this.isLearningToReadMode = false,
    this.usedUserApiKey = false,
    this.asyncIllustrations = false,
    this.choicesMade,
    this.pages,
    this.adventureSteps,
    this.offlineService,
    this.storyLengthHint,
    this.companionAvatars,
    this.companionNames,
    this.companionPets,
    this.companionCharacters,
    this.customElements,
    this.wizardData,
    this.persistedCoverImageBase64,
    this.persistedPageIllustrationsJson,
    this.sagaNextHook,
    this.practicedFocus,
    this.practicedAge,
  })  : assert(!trackStoryCreation || achievementsService != null),
        assert(!trackStoryCreation || storyCreatedAt != null);

  @override
  ConsumerState<StoryResultScreen> createState() => _StoryResultScreenState();
}

class _StoryResultScreenState extends ConsumerState<StoryResultScreen> {
  late final OfflineStoryService _offlineService;
  final _illustrationService =
      GeminiIllustrationService(); // Using Gemini Imagen 3.0 via backend
  final _coloringService =
      GeminiColoringBookService(); // Using Gemini for therapeutic coloring pages
  final _progressionService =
      ProgressionService(); // Track user progress and unlocks
  final _feedbackService = StoryFeedbackService();
  final TextEditingController _feedbackController = TextEditingController();
  bool _isFavorite = false;
  bool _isLoading = true;
  bool _isSaved = false; // tracks whether story has been saved to library
  // Local storyId assigned by OfflineStoryService.saveStory when the wizard
  // flow has no pre-existing widget.storyId. Used so post-save actions like
  // toggling the heart icon can target the saved record.
  String? _savedLocalStoryId;
  List<StoryIllustration>? _cachedIllustrations;
  List<ColoringPage>? _cachedColoringPages;
  int? _characterAge;
  Character? _character; // Stored character for saving
  String? _activeTherapeuticFocus;
  late final PageController _pageController;
  late final GlobalKey<PageFlipBuilderState> _pageFlipKey;
  final GlobalKey _storyBoundaryKey = GlobalKey();
  late List<String> _storyPages;
  late List<String> _adventureSteps; // NEW: Adventure step labels
  int _currentPageIndex = 0;
  double _textScale = 1.0;
  bool _highContrastMode = false;

  // Magic Typewriter state
  final Set<int> _revealedPages = {};

  // MT-235 Phase 2: which one-tap saga reflection the Creator hero acknowledged
  // at the cliffhanger (null until tapped). Cosmetic — confirms the beat landed.
  int? _sagaReflectionChoice;

  bool _isSubmittingFeedback = false;
  double _storyRating = 4.0;
  bool _hasExplicitlyRated = false; // true once user taps a rating

  FlutterTts? _tts;
  AudioPlayer? _audioPlayer;
  bool _ttsAutoEnabled = false;

  List<_InlineIllustration> _inlineIllustrations = [];

  /// Per-page illustrations restored from a saved story, indexed by story
  /// page. Decoded once from [widget.persistedPageIllustrationsJson]. When a
  /// page has saved art here, it renders directly and no regeneration runs.
  List<Uint8List?> _persistedPageIllustrations = const [];

  bool get _hasPersistedPageIllustrations =>
      _persistedPageIllustrations.any((b) => b != null);

  /// Per-page background prefetcher (BYOK only). Lazily created in initState.
  PerPageIllustrationPrefetcher? _perPagePrefetcher;

  /// True once the character-details fetch has finished (success OR failure).
  /// The per-page prefetcher waits for this so illustrations carry the
  /// character's appearance instead of being generated generically.
  bool _characterLoadDone = false;

  /// Once the reader dismisses the "out of free illustrations" banner for
  /// this story, don't show it again. Per-page upsell cards (older bands)
  /// are not affected.
  bool _quotaBannerDismissed = false;

  /// True when the first page is a full-bleed illustration cover.
  bool get _hasCoverIllustration => _inlineIllustrations.isNotEmpty;

  /// The total "virtual" page count (cover + text pages + end page).
  int get _totalPages =>
      _storyPages.length +
      (_hasCoverIllustration ? 1 : 0) +
      1; // +1 for end page

  // Quality scoring
  Map<String, dynamic>? _qualityData;
  bool _isLoadingQuality = false;

  bool get _isYoungUser {
    final band = Theme.of(context).extension<AgeBandThemeData>();
    return band != null &&
        (band.band == AgeBand.sprout || band.band == AgeBand.explorer);
  }

  /// Bands that get the per-page illustration-quota upsell card. Younger
  /// readers (explorer / adventurer) get a single dismissible banner above
  /// the pages instead, to stay less ad-heavy. Sprout never trips quota.
  bool get _useInlineQuotaUpsell {
    final band = Theme.of(context).extension<AgeBandThemeData>()?.band;
    if (band == null) return false;
    return band == AgeBand.creator ||
        band == AgeBand.adolescent ||
        band == AgeBand.adult;
  }

  bool get _isReaderLayout => _effectiveAge >= 11;

  String get _analyticsStoryId =>
      widget.storyId ?? widget.title.hashCode.toString();

  void _trackResultAction(
    String action, {
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    unawaited(
      StoryAnalytics.trackStoryResultAction(
        storyId: _analyticsStoryId,
        action: action,
        theme: widget.theme,
        extra: extra,
      ),
    );
  }

  void _retryLoadData() {
    setState(() {
      _isLoading = true;
    });
    _loadFavoriteStatus();
    _loadCharacterDetails();
    _loadCachedIllustrations();
    _loadCachedColoringPages();
    _decodeInlineIllustrations();
    _loadQualityData();
  }

  int get _effectiveAge {
    final age = _characterAge;
    if (age == null || age < 3 || age > 100) {
      return 7;
    }
    return age;
  }

  /// True when an illustration is actually rendered on the page (vs merely
  /// possible based on subscription tier). The "Picture Book" badge should
  /// only claim that label when art is truly present — otherwise, the badge
  /// promises something the BYOK upsell is simultaneously gating.
  bool get _hasRenderedIllustrations =>
      _inlineIllustrations.isNotEmpty ||
      _hasPersistedPageIllustrations ||
      (_cachedIllustrations?.isNotEmpty ?? false);

  String _readingLevelLabel(AgeBandThemeData band) {
    if (widget.isLearningToReadMode) return 'Reading Level: Read Along';
    switch (band.band) {
      case AgeBand.sprout:
        // Honest copy: only show "Picture Book" when art is actually
        // rendered. When illustrations are gated behind BYOK, the page is
        // really a "Read Along" experience.
        return _hasRenderedIllustrations
            ? 'Reading Level: Picture Book'
            : 'Reading Level: Read Along';
      case AgeBand.explorer:
        return 'Reading Level: Early Reader';
      case AgeBand.adventurer:
        return 'Reading Level: Middle Grade';
      case AgeBand.creator:
        return 'Teen';
      case AgeBand.adolescent:
        return 'Young Adult';
      case AgeBand.adult:
        return 'Adult';
    }
  }

  CharacterAppearance? _buildCharacterAppearance() {
    final character = _character;
    if (character == null) return null;

    final avatarAttributes = character.generatedAvatar?.attributes ?? const {};

    final hairColorSource = avatarAttributes['hair_color'] ?? character.hair;
    final hairStyleSource =
        avatarAttributes['hair_style'] ?? character.hairstyle;
    final eyeColorSource = avatarAttributes['eye_color'] ?? character.eyes;
    final skinToneSource = avatarAttributes['skin_tone'] ?? character.skinTone;
    final outfitSource = avatarAttributes['outfit'] ??
        character.outfit ??
        character.characterStyle;

    return CharacterAppearance(
      characterName: character.name,
      hairColor: _mapHairColor(hairColorSource),
      hairLength: _mapHairLength(hairStyleSource),
      hairStyle: _mapHairStyle(hairStyleSource),
      eyeColor: _mapEyeColor(eyeColorSource),
      skinTone: _mapSkinTone(skinToneSource),
      clothingStyle: _mapClothingStyle(outfitSource),
      clothingColors: _mapClothingColors(outfitSource),
      bodyBuild: BodyBuild.average,
    );
  }

  HairColor _mapHairColor(String? value) {
    final input = (value ?? '').toLowerCase();
    if (input.contains('strawberry')) return HairColor.strawberryBlonde;
    if (input.contains('light') && input.contains('brown')) {
      return HairColor.lightBrown;
    }
    if (input.contains('dark') && input.contains('brown')) {
      return HairColor.darkBrown;
    }
    if (input.contains('auburn')) return HairColor.auburn;
    if (input.contains('blond')) return HairColor.blonde;
    if (input.contains('red') || input.contains('ginger')) return HairColor.red;
    if (input.contains('gray') || input.contains('grey')) return HairColor.gray;
    if (input.contains('white') || input.contains('silver')) {
      return HairColor.white;
    }
    if (input.contains('black')) return HairColor.black;
    return HairColor.brown;
  }

  HairLength _mapHairLength(String? value) {
    final input = (value ?? '').toLowerCase();
    if (input.contains('very long')) return HairLength.veryLong;
    if (input.contains('long')) return HairLength.long;
    if (input.contains('medium') || input.contains('shoulder')) {
      return HairLength.medium;
    }
    return HairLength.short;
  }

  HairStyle _mapHairStyle(String? value) {
    final input = (value ?? '').toLowerCase();
    if (input.contains('braid')) return HairStyle.braided;
    if (input.contains('ponytail')) return HairStyle.ponytail;
    if (input.contains('pigtail')) return HairStyle.pigtails;
    if (input.contains('bun')) return HairStyle.bun;
    if (input.contains('curly')) return HairStyle.curly;
    if (input.contains('wavy')) return HairStyle.wavy;
    if (input.contains('messy')) return HairStyle.messy;
    return HairStyle.straight;
  }

  EyeColor _mapEyeColor(String? value) {
    final input = (value ?? '').toLowerCase();
    if (input.contains('dark') && input.contains('brown')) {
      return EyeColor.darkBrown;
    }
    if (input.contains('light') && input.contains('blue')) {
      return EyeColor.lightBlue;
    }
    if (input.contains('hazel')) return EyeColor.hazel;
    if (input.contains('amber')) return EyeColor.amber;
    if (input.contains('green')) return EyeColor.green;
    if (input.contains('gray') || input.contains('grey')) return EyeColor.gray;
    if (input.contains('blue')) return EyeColor.blue;
    return EyeColor.brown;
  }

  SkinTone _mapSkinTone(String? value) {
    final input = (value ?? '').toLowerCase();
    if (input.contains('very fair')) return SkinTone.veryFair;
    if (input.contains('fair')) return SkinTone.fair;
    if (input.contains('light-medium') || input.contains('light medium')) {
      return SkinTone.lightMedium;
    }
    if (input.contains('medium-tan') || input.contains('medium tan')) {
      return SkinTone.mediumTan;
    }
    if (input.contains('tan')) return SkinTone.tan;
    if (input.contains('dark') && input.contains('brown')) {
      return SkinTone.darkBrown;
    }
    if (input.contains('very dark')) return SkinTone.veryDark;
    if (input.contains('brown')) return SkinTone.brown;
    if (input.contains('medium')) return SkinTone.medium;
    return SkinTone.light;
  }

  ClothingStyle _mapClothingStyle(String? value) {
    final input = (value ?? '').toLowerCase();
    if (input.contains('superhero') || input.contains('hero')) {
      return ClothingStyle.superhero;
    }
    if (input.contains('princess') || input.contains('royal')) {
      return ClothingStyle.princess;
    }
    if (input.contains('fantasy') || input.contains('magic')) {
      return ClothingStyle.fantasy;
    }
    if (input.contains('adventur')) return ClothingStyle.adventurer;
    if (input.contains('sport')) return ClothingStyle.sporty;
    if (input.contains('dress') || input.contains('formal')) {
      return ClothingStyle.dressy;
    }
    if (input.contains('scientist') || input.contains('lab')) {
      return ClothingStyle.scientist;
    }
    return ClothingStyle.casual;
  }

  ClothingColors _mapClothingColors(String? value) {
    final input = (value ?? '').toLowerCase();
    if (input.contains('rainbow') || input.contains('multicolor')) {
      return ClothingColors.rainbow;
    }
    if (input.contains('pastel')) return ClothingColors.pastel;
    if (input.contains('earth')) return ClothingColors.earth;
    if (input.contains('dark') || input.contains('black')) {
      return ClothingColors.dark;
    }
    if (input.contains('blue')) return ClothingColors.blue;
    if (input.contains('gold')) return ClothingColors.gold;
    if (input.contains('mono') || input.contains('white')) {
      return ClothingColors.monochrome;
    }
    return ClothingColors.bright;
  }

  // The `imageBase64` field on a GeneratedAvatar is overloaded — depending on
  // the avatar pipeline that produced it, the value can be a real base64 blob
  // (optionally `data:image/...;base64,` prefixed), an asset path
  // (`assets/avatars/midjourney/avatar_NNN.webp`), or an http(s) URL. Blindly
  // base64-decoding an asset path crashes the result screen mid-build.
  Widget _avatarImage({
    required String raw,
    required double size,
    required Widget Function() fallback,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return fallback();
    if (trimmed.startsWith('assets/')) {
      return Image.asset(
        trimmed,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }
    try {
      return Image.memory(
        base64Decode(trimmed.split(',').last),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      );
    } on FormatException {
      return fallback();
    }
  }

  Widget _buildBreathingHeroAvatar({required double size}) {
    final character = _character;
    if (character == null) return const SizedBox.shrink();

    final Widget content;
    final generated = character.generatedAvatar;
    if (generated != null && generated.imageBase64.trim().isNotEmpty) {
      content = _avatarImage(
        raw: generated.imageBase64,
        size: size,
        fallback: () => character.buildAvatar(size: size),
      );
    } else {
      content = character.buildAvatar(size: size);
    }

    return BreathingAvatar(
      glowColor: AppColors.gold,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.7),
            width: 2,
          ),
        ),
        child: ClipOval(child: content),
      ),
    );
  }

  Widget _buildBreathingCompanionAvatars({required double size}) {
    if (widget.companionAvatars == null || widget.companionAvatars!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: widget.companionAvatars!.entries.map((entry) {
        final avatar = entry.value;
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: BreathingAvatar(
            glowColor: AppColors.primaryLight,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.7),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: _avatarImage(
                  raw: avatar.imageBase64,
                  size: size,
                  fallback: () => Container(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    child:
                        const Icon(Icons.pets, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  bool _ambienceMuted = false;

  @override
  void initState() {
    super.initState();
    _offlineService =
        widget.offlineService ?? OfflineStoryService(IsarService.instance);

    // Load mute preference (no background ambience — this is a reading app)
    AudioAmbienceService().loadMutePreference().then((_) {
      _ambienceMuted = AudioAmbienceService().isMuted;
      if (mounted) setState(() {});
    });

    final normalizedStoryText = _normalizeStoryText(widget.storyText);
    final normalizedIncomingPages = (widget.pages ?? const <String>[])
        .map(_normalizeStoryText)
        .where((p) => p.trim().isNotEmpty)
        .toList();

    // For epic stories, repaginate from the full story text to avoid sparse pages.
    if (widget.storyLengthHint == 'epic') {
      final epicSource = normalizedStoryText.trim().isNotEmpty
          ? normalizedStoryText
          : normalizedIncomingPages.join('\n\n');
      _storyPages = _paginateStory(epicSource, wordsPerPage: 170);
      _adventureSteps = List.generate(
        _storyPages.length,
        (i) => 'Page ${i + 1}',
      );
    } else if (normalizedIncomingPages.isNotEmpty) {
      // Trust the backend's page splits. Mode + age band already pick the
      // right per-page word target (Sprout/LTR/Rhyme = 10-25 words/page;
      // Explorer = ~80-130; older = denser). Repaginating client-side
      // collapses Sprout/LTR picture-book pacing onto page 1 — see the bug
      // where the wizard-default characterAge=8 made an age-gate unreliable.
      _storyPages = normalizedIncomingPages;
      _adventureSteps = widget.adventureSteps ??
          List.generate(
            _storyPages.length,
            (i) => 'Step ${i + 1}',
          );
    } else {
      _storyPages = _paginateStory(normalizedStoryText);
      _adventureSteps = List.generate(
        _storyPages.length,
        (i) => 'Page ${i + 1}',
      );
    }

    _pageController = PageController();
    _pageFlipKey = GlobalKey<PageFlipBuilderState>();

    _loadCharacterDetails();
    _loadFavoriteStatus();
    // Cache is now automatic via main_story.dart
    _loadCachedIllustrations();
    _loadCachedColoringPages();
    _decodeInlineIllustrations();
    _restoreReadingProgress();
    _loadQualityData();
    if (widget.trackStoryCreation) {
      _trackStoryCreation(); // Track that user created a story, check for unlocks
    }
    if (widget.trackAnalytics) {
      _trackStoryView();
    }
    if (ageBandFromAge(_effectiveAge).index <= AgeBand.explorer.index) {
      _initAutoTts();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStartPerPagePrefetcher();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Auto-save Sprout-band stories. We use the age-band helper rather than
      // a raw age comparison because widget.characterAge can be the wizard
      // default (8) when the user is actually a Sprout — fall back to the
      // user_age pref so the gate still fires.
      if (!mounted || _isSaved || widget.storyId != null) return;
      var age = widget.characterAge;
      if (age == null || age >= 6) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final prefAge = prefs.getInt('user_age');
          if (prefAge != null) age = prefAge;
        } catch (_) {}
      }
      final resolvedAge = age ?? 99;
      if (ageBandFromAge(resolvedAge) == AgeBand.sprout &&
          !_isSaved &&
          widget.storyId == null &&
          mounted) {
        await _saveStory();
      }
    });
  }

  Future<void> _initAutoTts() async {
    _tts = FlutterTts();
    await _tts!.setLanguage("en-US");
    await _tts!.setSpeechRate(0.45); // Slower for young listeners
    await _tts!.setPitch(1.1);
    _audioPlayer = AudioPlayer();
    if (mounted) setState(() => _ttsAutoEnabled = true);
  }

  /// Narrate a story page — tries ElevenLabs first, falls back to on-device TTS.
  Future<void> _speakPage(String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVoiceId = prefs.getString(ElevenLabsVoice.prefsKey);
      // Fall back to band-appropriate default rather than always using Matilda.
      final voiceId = savedVoiceId ??
          ElevenLabsVoice.defaultVoiceIdForBand(ageBandFromAge(_effectiveAge));
      final ttsResult = await TtsApiService.synthesize(text, voiceId: voiceId);
      final mp3 = ttsResult?.audioBytes;
      if (mp3 != null && mp3.isNotEmpty) {
        await _audioPlayer?.stop();
        await _audioPlayer?.play(BytesSource(mp3));
        return;
      }
    } catch (_) {}
    await _tts?.speak(text);
  }

  void _decodeInlineIllustrations() {
    _decodePersistedPageIllustrations();

    final raw = widget.backendIllustrations;
    if (raw == null || raw.isEmpty) {
      // No fresh backend illustrations — fall back to a persisted cover so a
      // re-opened saved story still shows its picture-book cover.
      _decodePersistedCover();
      return;
    }

    final decoded = <_InlineIllustration>[];
    for (final item in raw) {
      final data = item['image_data'] ?? item['imageUrl'];
      if (data is String && data.isNotEmpty) {
        try {
          // Handle potential data URL prefix
          final String base64Str =
              data.contains(',') ? data.split(',').last : data;
          decoded.add(
            _InlineIllustration(
              bytes: base64Decode(base64Str),
              prompt: item['prompt'] as String?,
            ),
          );
        } catch (_) {
          // Ignore invalid base64 blobs
        }
      }
    }

    _inlineIllustrations = decoded;
    if (_inlineIllustrations.isEmpty) _decodePersistedCover();
  }

  void _decodePersistedCover() {
    final raw = widget.persistedCoverImageBase64;
    if (raw == null || raw.isEmpty) return;
    try {
      final base64Str = raw.contains(',') ? raw.split(',').last : raw;
      _inlineIllustrations = [
        _InlineIllustration(bytes: base64Decode(base64Str)),
      ];
    } catch (_) {
      // Ignore corrupt persisted cover.
    }
  }

  void _decodePersistedPageIllustrations() {
    final raw = widget.persistedPageIllustrationsJson;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _persistedPageIllustrations = decoded.map<Uint8List?>((entry) {
        if (entry is! String || entry.isEmpty) return null;
        try {
          final base64Str = entry.contains(',') ? entry.split(',').last : entry;
          return base64Decode(base64Str);
        } catch (_) {
          return null;
        }
      }).toList();
    } catch (_) {
      // Ignore malformed persisted illustrations payload.
    }
  }

  @override
  void dispose() {
    AudioAmbienceService().stopAmbience();
    _tts?.stop();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _pageController.dispose();
    _feedbackController.dispose();
    _perPagePrefetcher?.dispose();
    super.dispose();
  }

  /// Start a per-page background prefetcher. Eligibility:
  ///   - BYOK on:    uses the user's own Gemini key (no server cost)
  ///   - Sprout band: uses server Gemini-via-OpenRouter (per-page art is
  ///                  essential to the 3-5 picture-book experience)
  ///   - Ages 6+ non-BYOK: NEW — uses Flux Schnell at $0.003/image, server
  ///                       enforces a monthly quota (Free 10, Premium 100,
  ///                       Family 200) and returns ILLUSTRATION_QUOTA_EXCEEDED
  ///                       past the cap. The prefetcher will start; individual
  ///                       page fetches will return empty once capped.
  /// Safe to call multiple times — only the first call wires up.
  void _maybeStartPerPagePrefetcher() {
    if (!mounted || _perPagePrefetcher != null || _perPagePrefetcherStarting) {
      return;
    }
    if (_storyPages.isEmpty) return;
    // Defer until character details have loaded — otherwise the prefetcher
    // fires every page request with characterAppearance=null and the
    // illustrations don't match the character the user created.
    // _loadCharacterDetails() re-invokes this once the fetch settles.
    if (widget.characterId != null &&
        _character == null &&
        !_characterLoadDone) {
      return;
    }
    final settings = ref.read(settingsProvider);
    final isSproutBand = ageBandFromAge(_effectiveAge) == AgeBand.sprout;
    final hasByok = settings.useOwnApiKey || widget.usedUserApiKey;
    // All age bands are eligible now; backend's illustration quota gates the
    // ages-6+ non-BYOK path.
    final allowServerKey = isSproutBand || (!hasByok && _effectiveAge >= 6);
    if (!hasByok && !allowServerKey) return;

    // Pages restored from a saved story already have art — never regenerate
    // them. If every page is persisted, skip the prefetcher entirely so a
    // re-opened saved story costs zero quota.
    final skipPages = <int>{
      for (int i = 0; i < _persistedPageIllustrations.length; i++)
        if (i < _storyPages.length && _persistedPageIllustrations[i] != null) i,
    };
    if (skipPages.length >= _storyPages.length) return;

    // Resolving the avatar reference image is async (an asset/URL avatar must
    // be loaded to base64). Claim the start slot now so a concurrent caller
    // doesn't wire up a second prefetcher across that await.
    _perPagePrefetcherStarting = true;
    unawaited(_wirePerPagePrefetcher(allowServerKey, skipPages));
  }

  bool _perPagePrefetcherStarting = false;

  Future<void> _wirePerPagePrefetcher(
    bool allowServerKey,
    Set<int> skipPages,
  ) async {
    final characterAppearance = await _characterAppearanceForBackend();
    if (!mounted || _perPagePrefetcher != null) {
      _perPagePrefetcherStarting = false;
      return;
    }

    final prefetcher = PerPageIllustrationPrefetcher(
      storyId: _analyticsStoryId,
      pageTexts: List<String>.from(_storyPages),
      characterName: widget.characterName ?? 'the hero',
      age: _effectiveAge,
      theme: widget.theme,
      characterAppearance: characterAppearance,
      companions: _illustrationCompanions(),
      sceneRequirements: (widget.customElements?.trim().isEmpty ?? true)
          ? null
          : widget.customElements,
      heroPower: widget.wizardData?.heroPower,
      // Server key is used for Sprout AND ages-6+ non-BYOK (Flux Schnell route).
      allowServerKey: allowServerKey,
      skipPages: skipPages,
    );
    _perPagePrefetcher = prefetcher;
    unawaited(prefetcher.initialize().then((_) {
      if (!mounted) return;
      // Bias work toward whatever the user is currently looking at.
      final textIndex =
          _hasCoverIllustration ? _currentPageIndex - 1 : _currentPageIndex;
      if (textIndex >= 0) prefetcher.prioritize(textIndex);
    }));
  }

  /// Build the `character_appearance` payload for `/generate-illustrations`.
  ///
  /// MT-129: this used to run every field through `_buildCharacterAppearance()`
  /// and serialize the result — but those mappers return a **non-null default**
  /// (`brown` hair, `light` skin, …) when the source is empty, so the backend
  /// was always handed a confident, fabricated description. The illustration
  /// model rendered that description faithfully → a child who didn't match the
  /// one the user created. This now emits only fields backed by real source
  /// data; an unknown field is omitted so the model stays neutral instead of
  /// being told something false.
  Future<Map<String, dynamic>?> _characterAppearanceForBackend() async {
    final character = _character;
    // Prefer the backend-fetched character, but fall back to the live wizard
    // data — a freshly created (often unsaved/anonymous) character has no
    // `characterId`, so `_character` is null even though the user just built
    // an avatar this session.
    final generatedAvatar =
        character?.generatedAvatar ?? widget.wizardData?.generatedAvatar;
    final attrs = generatedAvatar?.attributes ?? const <String, String>{};

    // Returns the trimmed value, or null when there is nothing real to send.
    String? real(Object? value) {
      final text = value?.toString().trim();
      return (text == null || text.isEmpty) ? null : text;
    }

    final name = real(character?.name) ?? real(widget.characterName);

    // Hair: the custom-photo pipeline returns `hair_style` as one combined
    // phrase ("wavy brown shoulder-length"); a legacy avatar-builder character
    // may instead carry separate `hair`/`hairstyle` fields. All passed
    // verbatim — the backend prompt builder reads free text.
    final hairStyle = real(attrs['hair_style']) ??
        real(attrs['hairstyle']) ??
        real(character?.hairstyle);
    final hairColor = real(attrs['hair_color']) ?? real(character?.hair);
    final eyeColor = real(attrs['eye_color']) ?? real(character?.eyes);
    final skinTone = real(attrs['skin_tone']) ?? real(character?.skinTone);
    final outfit = real(attrs['outfit']) ??
        real(character?.outfit) ??
        real(character?.characterStyle);
    final distinguishing = real(attrs['distinguishing']);
    final gender = real(attrs['gender']);

    // Superhero Mode: when the hero portrait is the likeness reference (see
    // `_resolveAvatarReferenceBase64`), the reference already depicts the child
    // in their hero costume. Suppress the plain-clothes `outfit` text field so
    // the prompt doesn't tell the model "wearing <everyday outfit>" and fight
    // the costume in the reference image. Everything else (hair/eyes/skin/etc.)
    // still describes the same child and is kept.
    final usingHeroPortrait =
        widget.wizardData?.selectedScenario == 'superhero' &&
            (widget.wizardData?.heroPortraitUrl?.trim().isNotEmpty ?? false);
    final outfitForPayload = usingHeroPortrait ? null : outfit;

    final payload = <String, dynamic>{
      if (name != null) 'character_name': name,
      if (hairStyle != null) 'hair_style': hairStyle,
      if (hairColor != null) 'hair_color': hairColor,
      if (eyeColor != null) 'eye_color': eyeColor,
      if (skinTone != null) 'skin_tone': skinTone,
      if (outfitForPayload != null) 'outfit': outfitForPayload,
      if (distinguishing != null) 'distinguishing': distinguishing,
      if (gender != null) 'gender': gender,
    };

    // The avatar image itself — used as a true likeness reference by
    // image-capable backends (the BYOK Gemini path). The non-BYOK Flux path is
    // text-to-image only and ignores it; see MT-129.
    final avatarReference = await _resolveAvatarReferenceBase64();
    if (avatarReference != null && avatarReference.isNotEmpty) {
      payload['custom_avatar_base64'] = avatarReference;
    }

    // No appearance fields and no reference image → nothing useful to send.
    final hasAppearance = payload.keys.any((k) => k != 'character_name');
    return hasAppearance ? payload : null;
  }

  /// Resolve the saved avatar image to a base64 (data-URI) string the backend
  /// can decode for `custom_avatar_base64`.
  ///
  /// `GeneratedAvatar.imageBase64` is overloaded — depending on the pipeline
  /// that produced it the value can already be a base64 blob, an asset path
  /// (`assets/avatars/.../avatar_NNN.webp`), or an http(s) URL. The backend's
  /// `gemini_image_generator` only base64-decodes the value, so an asset path
  /// or URL would throw and the photo reference would be silently dropped —
  /// leaving the illustration model to render a generic child. Fetch/load
  /// non-base64 forms here so the reference always arrives as base64.
  Future<String?> _resolveAvatarReferenceBase64() async {
    // Superhero Mode: when the reveal screen has already generated a portrait of
    // the child AS their superhero, use THAT as the illustration likeness
    // reference instead of the plain avatar — so the story pictures depict the
    // child in their hero costume. Opt-in by data: only when the scenario is
    // 'superhero' and a portrait actually exists. `heroPortraitUrl` is a
    // `data:image/...;base64,` URI, which the backend's `custom_avatar_base64`
    // path decodes directly (the existing base64 branch below handles it).
    final wizard = widget.wizardData;
    if (wizard?.selectedScenario == 'superhero') {
      final portrait = wizard?.heroPortraitUrl?.trim();
      if (portrait != null && portrait.isNotEmpty) {
        return portrait;
      }
    }

    // MT-129: same fallback as `_characterAppearanceForBackend` — the avatar
    // may live only on the live wizard data when the character is unsaved.
    final generatedAvatar =
        _character?.generatedAvatar ?? widget.wizardData?.generatedAvatar;
    final raw = generatedAvatar?.imageBase64.trim();
    if (raw == null || raw.isEmpty) return null;

    // Already base64 (optionally `data:image/...;base64,` prefixed).
    if (!raw.startsWith('assets/') &&
        !raw.startsWith('http://') &&
        !raw.startsWith('https://')) {
      return raw;
    }

    try {
      Uint8List bytes;
      if (raw.startsWith('assets/')) {
        final data = await rootBundle.load(raw);
        bytes = data.buffer.asUint8List();
      } else {
        final response =
            await http.get(Uri.parse(raw)).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          debugPrint(
            'Avatar reference fetch failed (${response.statusCode}) for $raw',
          );
          return null;
        }
        bytes = response.bodyBytes;
      }
      return base64Encode(bytes);
    } catch (e) {
      // Best-effort: if the reference can't be resolved, fall back to the
      // text appearance fields rather than failing illustration generation.
      debugPrint('Could not resolve avatar reference image: $e');
      return null;
    }
  }

  List<Map<String, String>> _illustrationCompanions() {
    final companions = <Map<String, String>>[];
    for (final pet in widget.companionPets ?? const <Map<String, dynamic>>[]) {
      final name = pet['name']?.toString().trim();
      if (name == null || name.isEmpty) continue;
      final species = pet['species']?.toString().trim();
      companions.add({
        'name': name,
        if (species != null && species.isNotEmpty) 'type': species,
      });
    }
    for (final character in widget.companionCharacters ?? const <dynamic>[]) {
      if (character is Map) {
        final name = character['name']?.toString().trim();
        if (name == null || name.isEmpty) continue;
        companions.add({'name': name});
      } else {
        final name = character.toString().trim();
        if (name.isEmpty) continue;
        companions.add({'name': name});
      }
    }
    return companions;
  }

  /// Track that a story was created and show celebration if features unlocked
  Future<void> _trackStoryCreation() async {
    // Track story creation analytics
    try {
      await StoryAnalytics.trackStoryCreation(
        theme: widget.theme ?? 'Adventure',
        characterName: widget.characterName ?? 'Unknown',
        characterAge: widget.characterAge ?? 7,
        interactiveMode: widget.isInteractive ?? false,
        rhymeMode: widget.isRhyming ?? false,
        qualityScore: _qualityData?['overall_score'],
        qualityBadge: _qualityData?['quality_badge'],
        wordCount: _qualityData?['word_count'],
        readabilityScore: _qualityData?['readability_score'],
      );
    } catch (e) {
      debugPrint('Failed to track story creation analytics: $e');
    }

    final achievementService = widget.achievementsService;
    if (achievementService != null) {
      final achievementUnlocks = await achievementService.recordStoryCreated(
        theme: widget.theme ?? 'Adventure',
        timestamp: widget.storyCreatedAt,
      );
      if (mounted && achievementUnlocks.isNotEmpty) {
        // Disabled per user feedback: "annoying popups"
        // await AchievementCelebrationDialog.show(context, achievementUnlocks);
        debugPrint(
            'Achievement unlocked (dialog suppressed): $achievementUnlocks');
      }
    }

    final newFeatureUnlocks = await _progressionService
        .incrementStoriesCreated(widget.characterAge ?? 8);
    if (mounted && newFeatureUnlocks.isNotEmpty) {
      // Disabled per user feedback
      // await UnlockCelebrationDialog.show(context, newFeatureUnlocks);
      debugPrint('Feature unlocked (dialog suppressed): $newFeatureUnlocks');
    }

    await FeatureTourService.incrementStoryCount();
  }

  Future<void> _trackStoryView() async {
    final wordCount = widget.storyText
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    final estimatedSeconds = max(30, (wordCount / 3).round());
    await StoryAnalytics.trackStoryCompletion(
      storyId: widget.storyId ?? widget.title.hashCode.toString(),
      wordCount: wordCount,
      readingTime: Duration(seconds: estimatedSeconds),
    );
  }

  // Cache logic moved to main_story.dart (auto-save)

  /// Load character info so we can adapt prompts for age and focus
  Future<void> _loadCharacterDetails() async {
    if (widget.characterId == null) return;

    try {
      final headers = await ApiServiceManager.authHeaders();
      final response = await http
          .get(
            Uri.parse(
                '${Environment.backendUrl}/characters/${widget.characterId}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final character = Character.fromJson(data);
        if (!mounted) return;
        setState(() {
          _character = character;
          _characterAge = character.age > 0 ? character.age : null;
        });
      } else {
        debugPrint(
          'Failed to load character ${widget.characterId}: ${response.statusCode}',
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Loading character details timed out. Using a default age for now.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading character ${widget.characterId}: $e');
    } finally {
      // Release the per-page prefetcher even if the fetch failed — better to
      // illustrate without appearance than to never illustrate at all.
      _characterLoadDone = true;
      if (mounted) _maybeStartPerPagePrefetcher();
    }
  }

  /// Load cached illustrations if they exist
  Future<void> _loadCachedIllustrations() async {
    if (widget.storyId != null) {
      final illustrations =
          await _illustrationService.getCachedIllustrations(widget.storyId!);
      if (mounted) {
        setState(() {
          _cachedIllustrations = illustrations;
        });
      }
    }
  }

  /// Load cached coloring pages if they exist
  Future<void> _loadCachedColoringPages() async {
    if (widget.storyId != null) {
      final pages =
          await _coloringService.getColoringPagesForStory(widget.storyId!);
      if (mounted) {
        setState(() {
          _cachedColoringPages = pages.isEmpty ? null : pages;
        });
      }
    }
  }

  Future<void> _loadQualityData() async {
    if (_isLoadingQuality) return;

    setState(() => _isLoadingQuality = true);

    try {
      final qualityHeaders = await ApiServiceManager.authHeaders();
      final response = await http.post(
        Uri.parse('${Environment.backendUrl}/quality/score-story'),
        headers: qualityHeaders,
        body: jsonEncode({
          'story_text': widget.storyText,
          'age': widget.characterAge ?? 7,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _qualityData = data;
          _isLoadingQuality = false;
        });
      } else {
        setState(() => _isLoadingQuality = false);
      }
    } catch (e) {
      setState(() => _isLoadingQuality = false);
    }
  }

  List<String> _buildScenes(int numberOfScenes) {
    final customElements = widget.customElements?.trim() ?? '';

    String applyStoryElements(String scene) {
      if (customElements.isEmpty) return scene;
      return '$scene\n\nStory elements to include: $customElements';
    }

    final sentences = widget.storyText
        .split(RegExp(r'[.!?]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (sentences.isEmpty) {
      return [applyStoryElements(widget.storyText)];
    }

    final scenes = <String>[];
    final chunkSize = ((sentences.length / numberOfScenes).ceil())
        .clamp(1, sentences.length)
        .toInt();

    for (int i = 0; i < sentences.length; i += chunkSize) {
      final endIndex = (i + chunkSize) > sentences.length
          ? sentences.length
          : (i + chunkSize);
      final chunk = sentences.sublist(i, endIndex);
      if (chunk.isEmpty) continue;
      final text = chunk.join('. ');
      final sceneText = text.endsWith('.') ? text : '$text.';
      scenes.add(applyStoryElements(sceneText));
      if (scenes.length == numberOfScenes) {
        break;
      }
    }

    while (scenes.length < numberOfScenes) {
      scenes.add(scenes.isNotEmpty ? scenes.last : widget.storyText);
    }

    return scenes;
  }

  List<String> _paginateStory(String text, {int wordsPerPage = 120}) {
    final normalized = _normalizeStoryText(text);
    final words =
        normalized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) {
      return [normalized];
    }
    final pages = <String>[];
    final buffer = StringBuffer();
    var count = 0;
    for (final word in words) {
      buffer.write(word);
      buffer.write(' ');
      count++;
      if (count >= wordsPerPage) {
        pages.add(buffer.toString().trim());
        buffer.clear();
        count = 0;
      }
    }
    if (buffer.isNotEmpty) {
      pages.add(buffer.toString().trim());
    }
    return pages.isEmpty ? [normalized] : pages;
  }

  String _normalizeStoryText(String raw) {
    var text = raw;
    // Decode escaped line breaks/tabs that sometimes arrive double-escaped.
    text = text.replaceAll(r'\n', '\n').replaceAll(r'\t', '  ');
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Remove internal/meta labels if they leak into visible story text.
    text = text.replaceAllMapped(
      RegExp(
        r'^\s*(REQUEST SUMMARY|STORY START|STORY END|WISDOM GEM|ADVENTURE REPORT|CRITICAL:.*)\s*$',
        multiLine: true,
        caseSensitive: false,
      ),
      (_) => '',
    );

    // Keep paragraph breaks, but collapse noisy excess whitespace.
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return text.trim();
  }

  /// Break a page's text into one phrase per line for the Read Along reading
  /// level (3–5 yo). Sentences are the primary break; long sentences are
  /// further split on commas. Tiny fragments are merged forward so we don't
  /// orphan a single word on its own line.
  String _phrasifyForEarlyReader(String text) {
    final source = text.trim();
    if (source.isEmpty) return text;

    final sentencePattern = RegExp(r'[^.!?\n]+[.!?]+["’”\)]*');
    final sentences = <String>[];
    var lastEnd = 0;
    for (final m in sentencePattern.allMatches(source)) {
      sentences.add(m.group(0)!.trim());
      lastEnd = m.end;
    }
    if (lastEnd < source.length) {
      final tail = source.substring(lastEnd).trim();
      if (tail.isNotEmpty) sentences.add(tail);
    }
    if (sentences.isEmpty) return text;

    const longSentenceThreshold = 50;
    const minPhraseLen = 15;
    final commaPattern = RegExp(r'[^,;:\n]+(?:[,;:]|$)');
    final lines = <String>[];
    for (final sentence in sentences) {
      if (sentence.length <= longSentenceThreshold) {
        lines.add(sentence);
        continue;
      }
      final parts = <String>[];
      var subEnd = 0;
      for (final m in commaPattern.allMatches(sentence)) {
        final part = sentence.substring(subEnd, m.end).trim();
        if (part.isNotEmpty) parts.add(part);
        subEnd = m.end;
      }
      if (parts.isEmpty) {
        lines.add(sentence);
        continue;
      }
      final merged = <String>[];
      for (final part in parts) {
        if (part.length < minPhraseLen && merged.isNotEmpty) {
          merged[merged.length - 1] = '${merged.last} $part';
        } else {
          merged.add(part);
        }
      }
      lines.addAll(merged);
    }

    return lines.join('\n');
  }

  List<InlineSpan> _buildStorySpans(String pageText) {
    final heroName = widget.characterName;
    if (heroName == null || heroName.trim().isEmpty) {
      return [TextSpan(text: pageText)];
    }
    final pattern = RegExp(RegExp.escape(heroName), caseSensitive: false);
    final spans = <InlineSpan>[];
    int lastIndex = 0;
    for (final match in pattern.allMatches(pageText)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: pageText.substring(lastIndex, match.start)));
      }
      spans.add(
        TextSpan(
          text: pageText.substring(match.start, match.end),
          style: TextStyle(
            backgroundColor: Colors.yellow.withValues(alpha: 0.4),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      lastIndex = match.end;
    }
    if (lastIndex < pageText.length) {
      spans.add(TextSpan(text: pageText.substring(lastIndex)));
    }
    return spans;
  }

  /// Build placeholder widget for failed image loads
  Widget _buildImageErrorPlaceholder() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Image unavailable',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> _buildCompanionPrompts() {
    final companions = <Map<String, String>>[];

    final companionPets =
        widget.companionPets ?? const <Map<String, dynamic>>[];
    for (final pet in companionPets) {
      final name = pet['name']?.toString().trim();
      if (name == null || name.isEmpty) continue;
      final species = pet['species']?.toString().trim();
      companions.add({
        'name': name,
        if (species != null && species.isNotEmpty) 'type': species,
      });
    }

    final companionCharacters = widget.companionCharacters ?? const <dynamic>[];
    for (final character in companionCharacters) {
      if (character is Map) {
        final name = character['name']?.toString().trim();
        if (name == null || name.isEmpty) continue;
        companions.add({'name': name});
      } else {
        final name = character.toString().trim();
        if (name.isEmpty) continue;
        companions.add({'name': name});
      }
    }

    if (companions.isEmpty) {
      final fallbackNames = widget.companionNames ?? const <String>[];
      for (final name in fallbackNames) {
        final trimmed = name.trim();
        if (trimmed.isEmpty) continue;
        companions.add({'name': trimmed});
      }
    }

    return companions;
  }

  /// Generate coloring pages from the story
  Future<void> _generateColoringPages() async {
    final initialCount = _cachedColoringPages?.length ?? 3;
    final settings = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ColoringSettingsDialog(
        initialPageCount: initialCount.clamp(1, 5),
        initialTherapeuticFocus: _activeTherapeuticFocus,
      ),
    );

    if (settings == null) return;

    final numberOfPages = settings['numberOfPages'] as int;
    final therapeuticFocus = settings['therapeuticFocus'] as String?;

    if (mounted) {
      setState(() {
        _activeTherapeuticFocus = therapeuticFocus;
      });
    }

    var progressShown = false;

    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ColoringGenerationDialog(
          totalPages: numberOfPages,
          therapeuticFocus: therapeuticFocus,
        ),
      );
      progressShown = true;

      final scenes = _buildScenes(numberOfPages);

      // MT-163: route coloring pages through the SAME MT-129 no-fabrication
      // builder the illustration path uses. The legacy `_buildCharacterAppearance()`
      // runs every field through mappers that default to `brown` hair / `light`
      // skin even when the source is empty, so coloring pages were handed an
      // invented description and could mismatch the created character.
      // `_characterAppearanceForBackend()` emits only fields backed by real
      // source data (and is null when there is nothing real to send).
      final appearancePayload = await _characterAppearanceForBackend();
      if (!mounted) return;

      final pages = await _coloringService.generateColoringPagesFromStory(
        storyId:
            widget.storyId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        storyTitle: widget.title,
        scenes: scenes,
        characterAppearance: _buildCharacterAppearance(),
        appearancePayload: appearancePayload,
        companions: _buildCompanionPrompts(),
        age: _effectiveAge,
        therapeuticFocus: therapeuticFocus,
      );

      await _coloringService.cacheColoringPages(pages);

      if (!mounted) return;
      setState(() {
        _cachedColoringPages = pages;
      });

      _trackResultAction(
        'coloring_generated',
        extra: {
          'count': pages.length,
          if (therapeuticFocus != null && therapeuticFocus.isNotEmpty)
            'therapeutic_focus': therapeuticFocus,
        },
      );

      _showSnackBar(
        '✨ Created ${pages.length} coloring ${pages.length == 1 ? "page" : "pages"}!',
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: _openColoringBook,
        ),
      );
    } on TimeoutException {
      if (mounted) {
        _showSnackBar(
          'Coloring page request timed out. Please try again soon.',
          backgroundColor: Colors.orange,
        );
      }
    } catch (e) {
      await _showFriendlyErrorDialog(e);
    } finally {
      if (progressShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        setState(() {
          // Reset generating state is no longer needed as field is removed
        });
      }
    }
  }

  /// Open the coloring book library
  void _openColoringBook() {
    _trackResultAction(
      'coloring_opened',
      extra: {'count': _cachedColoringPages?.length ?? 0},
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ColoringBookLibraryScreen(),
      ),
    ).then((_) => _loadCachedColoringPages());
  }

  void _showSnackBar(
    String message, {
    Color backgroundColor = Colors.red,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        action: action,
      ),
    );
  }

  Future<void> _showFriendlyErrorDialog(
    dynamic error, {
    VoidCallback? onRetry,
  }) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => UserFriendlyErrorDialog(
        error: error,
        onRetry: onRetry != null
            ? () {
                Navigator.of(dialogContext).pop();
                onRetry();
              }
            : null,
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  String _formatShareText({bool includeMetadata = false}) {
    final buffer = StringBuffer()
      ..writeln(widget.title)
      ..writeln()
      ..writeln(widget.storyText);
    if (includeMetadata) {
      buffer
        ..writeln()
        ..writeln('--- Story Metadata ---')
        ..writeln('Hero: ${widget.characterName ?? 'Unknown'}')
        ..writeln('Theme: ${widget.theme ?? 'Adventure'}')
        ..writeln('Created: ${widget.storyCreatedAt ?? DateTime.now()}');

      if (widget.choicesMade != null && widget.choicesMade!.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln('--- Adventure Log ---');
        for (int i = 0; i < widget.choicesMade!.length; i++) {
          buffer.writeln('${i + 1}. ${widget.choicesMade![i]}');
        }
      }
    }
    return buffer.toString();
  }

  Future<void> _shareStory() async {
    await SharePlus.instance.share(
      ShareParams(
        text: _formatShareText(includeMetadata: true),
        subject: widget.title,
      ),
    );
    _trackResultAction('share', extra: {'method': 'system_share'});
  }

  Future<void> _shareAsImage() async {
    if (kIsWeb) {
      _shareStory();
      return;
    }
    try {
      final boundary = _storyBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        _shareStory();
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/story_share.png');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        subject: widget.title,
      ));
      _trackResultAction('share', extra: {'method': 'image_screenshot'});
    } catch (_) {
      _shareStory();
    }
  }

  /// Plain-language explainer for the "Created with AI" badge, plus the
  /// in-app content-report affordance required by store gen-AI policies.
  void _showAiInfo() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: band.gradientEnd,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Created with AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: band.uiFontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'This story and its pictures were generated by artificial '
              'intelligence using the details your child chose. AI is '
              'creative but not perfect — it can sometimes get things wrong. '
              'Stories are not written by a person and are not reviewed by a '
              'teacher, doctor, or clinician.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                height: 1.5,
                fontFamily: band.uiFontFamily,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined, color: Colors.white),
              title: Text(
                'Report this content',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFamily: band.uiFontFamily,
                ),
              ),
              subtitle: const Text(
                'Tell us if something here seems wrong or unsafe',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _reportContent();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the parent's email client pre-filled with a content report for the
  /// current AI-generated story. No backend endpoint — a mailto: to the
  /// support address keeps the report path lightweight and store-compliant.
  Future<void> _reportContent() async {
    final subject = Uri.encodeComponent('Content report: "${widget.title}"');
    final body = Uri.encodeComponent(
      'Please describe what seemed wrong or unsafe in this AI-generated '
      'story or its illustrations:\n\n\n'
      '---\n'
      'Story title: ${widget.title}\n'
      'Story ID: ${widget.storyId ?? 'unsaved'}\n',
    );
    final uri = Uri.parse(
        'mailto:darcy@onceuponyourchild.app?subject=$subject&body=$body');
    bool opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    if (!opened) {
      await Clipboard.setData(
          const ClipboardData(text: 'darcy@onceuponyourchild.app'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Email darcy@onceuponyourchild.app to report this content '
                  '(address copied to clipboard).'),
        ),
      );
    }
  }

  void _showShareOptions() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: band.gradientEnd,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share "${widget.title}"',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: band.uiFontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading:
                  const Icon(Icons.text_snippet_rounded, color: Colors.white),
              title: Text('Share as text',
                  style: TextStyle(
                      color: Colors.white, fontFamily: band.uiFontFamily)),
              subtitle: const Text('Copy or send the story words',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _shareStory();
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_rounded, color: Colors.white),
              title: Text('Share as picture',
                  style: TextStyle(
                      color: Colors.white, fontFamily: band.uiFontFamily)),
              subtitle: const Text('Screenshot of your story page',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _shareAsImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Base64-encode the currently-displayed cover illustration (if any) so it
  /// can be persisted with the saved story. Returns null when there is no
  /// cover art to keep.
  Future<String?> _captureCoverImageBase64() async {
    if (_inlineIllustrations.isEmpty) return null;
    try {
      final bytes =
          await _compressImageForWeb(_inlineIllustrations.first.bytes);
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _compressImageForWeb(Uint8List bytes) async {
    if (!kIsWeb) return bytes;
    return await compute(_compressJpgSync, bytes);
  }

  /// Capture per-page illustration bytes available right now — from art that
  /// was already persisted (re-save case) or from the live prefetcher's
  /// `ready` pages — as a JSON array of base64 strings indexed by story page.
  /// Returns null when no page has art (avoids storing an all-null payload).
  Future<String?> _capturePageIllustrationsJson() async {
    final prefetcher = _perPagePrefetcher;
    final entries = <String?>[];
    var hasAny = false;
    for (int i = 0; i < _storyPages.length; i++) {
      Uint8List? bytes;
      if (i < _persistedPageIllustrations.length) {
        bytes = _persistedPageIllustrations[i];
      }
      if (bytes == null && prefetcher != null) {
        final state = prefetcher.stateOf(i).value;
        if (state.status == PageIllustrationStatus.ready) {
          bytes = state.bytes;
        }
      }
      if (bytes != null) {
        try {
          final compressed = await _compressImageForWeb(bytes);
          entries.add(base64Encode(compressed));
          hasAny = true;
          continue;
        } catch (_) {
          // Fall through to null entry.
        }
      }
      entries.add(null);
    }
    if (!hasAny) return null;
    return jsonEncode(entries);
  }

  Future<void> _saveStory() async {
    // If storyId is present, it might already be saved or we can't save a new one easily without checking.
    // But usually in Wizard flow, storyId is null.
    if (widget.storyId == null) {
      try {
        final characters = _character != null
            ? [_character!]
            : (widget.characterName != null && widget.characterName!.isNotEmpty)
                ? [
                    Character(
                        id: widget.characterId ?? '',
                        name: widget.characterName!,
                        age: widget.characterAge ?? 0,
                        role: 'Hero')
                  ]
                : <Character>[];
        final newStory = SavedStory(
          title: widget.title,
          storyText: widget.storyText,
          theme: widget.theme ?? 'Adventure',
          characters: characters,
          createdAt: widget.storyCreatedAt ?? DateTime.now(),
          isInteractive: widget.isInteractive ?? false,
          isRhyming: widget.isRhyming ?? false,
          isLearningToRead: widget.isLearningToReadMode,
          pages: widget.pages,
          adventureSteps: widget.adventureSteps,
          // Calculate stats
          totalWords: widget.storyText.split(RegExp(r'\s+')).length,
          totalPages: widget.pages?.length ?? _storyPages.length,
          // Persist whatever illustrations are available now so re-opening
          // this story shows its pictures without regenerating them.
          coverImageBase64: await _captureCoverImageBase64(),
          pageIllustrationsJson: await _capturePageIllustrationsJson(),
        );

        final storyLocal = StoryLocal.fromSavedStory(newStory)
          // Story Notes (MT-254): persist the guided focus so re-opening this
          // story still offers the "Why this story? 💛" disclosure.
          ..practiced = widget.practicedFocus;
        await _offlineService.saveStory(storyLocal);
        // saveStory assigns a millisecond-timestamp storyId in-place when the
        // incoming record has none — capture it so _toggleFavorite (and any
        // other post-save action) can act on the new local row.
        if (mounted) {
          setState(() {
            _isSaved = true;
            _savedLocalStoryId = storyLocal.identifier;
          });
        } else {
          _savedLocalStoryId = storyLocal.identifier;
        }

        debugPrint(
            '✅ Story saved locally with Rhyme: ${widget.isRhyming}, Learn: ${widget.isLearningToReadMode}');
      } catch (e) {
        debugPrint('❌ Failed to save story locally: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save story: $e')),
          );
        }
        return;
      }
    }

    _showGoldenTicketAnimation();
  }

  void _showGoldenTicketAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GoldenTicketAnimation(
        title: widget.title,
        onComplete: () {
          Navigator.of(context).pop();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Story is safely tucked away in your Library!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _createAnotherStory() {
    _trackResultAction('regenerate_requested');
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------------
  // Remix feature
  // ---------------------------------------------------------------------------

  static const _remixScenarios = [
    {'id': 'vanishing_colors', 'emoji': '🌈', 'label': 'Rainbow World'},
    {'id': 'crystal_cavern', 'emoji': '💎', 'label': 'Crystal Cave'},
    {'id': 'big_feelings_quest', 'emoji': '🧭', 'label': 'Life Quest'},
    {'id': 'volcano_dragons', 'emoji': '🐉', 'label': 'Dragon Volcano'},
    {'id': 'doorway_seasons', 'emoji': '🚪', 'label': 'Magic Door'},
    {'id': 'starship_engineers', 'emoji': '🚀', 'label': 'Space Quest'},
  ];

  static const _remixTwists = [
    {'id': 'shorter', 'emoji': '⚡', 'label': 'Shorter'},
    {'id': 'longer', 'emoji': '📚', 'label': 'Longer'},
    {'id': 'funnier', 'emoji': '😂', 'label': 'Funnier'},
    {'id': 'spookier', 'emoji': '👻', 'label': 'Spookier'},
    {'id': 'rhyming', 'emoji': '🎵', 'label': 'Rhyming'},
    {'id': 'interactive', 'emoji': '🎮', 'label': 'Adventure'},
  ];

  /// One-shot banner for younger bands (explorer/adventurer) when the
  /// free-tier illustration quota is exhausted. Tap → unlock sheet.
  /// Dismissible; remembers dismissal within the screen's lifetime.
  Widget _buildQuotaBanner() {
    final prefetcher = _perPagePrefetcher;
    if (prefetcher == null) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: prefetcher.quotaExceededListenable,
      builder: (context, exceeded, _) {
        if (!exceeded || _quotaBannerDismissed) {
          return const SizedBox.shrink();
        }
        const lavender = Color(0xFF7E57C2);
        final limit = prefetcher.quotaLimit ?? 10;
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showIllustrationUnlockSheet(context),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EEFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: lavender.withValues(alpha: 0.4),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Text('🎨', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'You\'ve used your $limit free illustrations '
                            'this month.',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: lavender,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Story Weaver Premium unlocks 100/mo.',
                            style: TextStyle(
                              fontSize: 12,
                              color: lavender.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _showIllustrationUnlockSheet(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: lavender,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text(
                        'Upgrade',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      icon: Icon(Icons.close,
                          size: 18, color: lavender.withValues(alpha: 0.6)),
                      onPressed: () => setState(() {
                        _quotaBannerDismissed = true;
                      }),
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

  void _showIllustrationUnlockSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('🎨', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'See This Scene Come Alive',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock AI illustrations and premium narration for every scene.',
              style:
                  TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Premium unlocks:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (final f in [
                    '🖼️  AI illustrations for every story scene',
                    '🎙️  Premium ElevenLabs narration',
                    '🎭  Interactive choose-your-own-adventure',
                    '📖  20 stories per month',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(f, style: const TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // P0: this upsell is shown to younger bands — never open the
                  // Stripe-backed SubscriptionScreen without a parent gate.
                  Navigator.pop(ctx);
                  if (!context.mounted) return;
                  await showPaywallGated<void>(
                    context: context,
                    showActualPaywall: () async {
                      if (!context.mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen(),
                          fullscreenDialog: true,
                        ),
                      );
                    },
                  );
                },
                icon: const Icon(Icons.star_rounded, size: 20),
                label: const Text(
                  'Upgrade to Premium',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E57C2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Secondary: BYOK link for users who'd rather supply their own
            // Gemini key (free, but ~5 minutes of parent setup). Premium is
            // the recommended path because it also unlocks ElevenLabs voice
            // — which BYOK cannot replace.
            TextButton.icon(
              onPressed: () async {
                final container = ProviderScope.containerOf(ctx);
                Navigator.pop(ctx);
                final result = await Navigator.of(ctx).push<String>(
                  MaterialPageRoute(
                    builder: (_) => const ByokSetupWizardScreen(),
                    fullscreenDialog: true,
                  ),
                );
                if (result != null && result.isNotEmpty) {
                  await container.read(settingsProvider.notifier).reload();
                }
              },
              icon: const Icon(Icons.key, size: 16),
              label: const Text(
                'Or paste a free Gemini key',
                style: TextStyle(fontSize: 13),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7E57C2),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Maybe later',
                  style: TextStyle(color: Colors.grey[500])),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemixSheet() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [band.gradientStart, band.gradientEnd],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '✨ Change One Thing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: band.uiFontFamily,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Keep the same hero, change the adventure!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontFamily: band.uiFontFamily,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Try a different world:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: band.uiFontFamily,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.1,
                  children: _remixScenarios
                      .map((s) => _RemixTile(
                            emoji: s['emoji']!,
                            label: (s['id'] == 'big_feelings_quest' &&
                                    band.band == AgeBand.sprout)
                                ? 'Big Feelings'
                                : s['label']!,
                            band: band,
                            onTap: () {
                              Navigator.pop(context);
                              _launchRemix(scenarioId: s['id']);
                            },
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                Text(
                  'Add a twist:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: band.uiFontFamily,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.1,
                  children: _remixTwists
                      .map((t) => _RemixTile(
                            emoji: t['emoji']!,
                            label: t['label']!,
                            band: band,
                            onTap: () {
                              Navigator.pop(context);
                              _launchRemix(twist: t['id']);
                            },
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _launchRemix({String? scenarioId, String? twist}) {
    final data = WizardData()
      ..characterId = widget.characterId
      ..characterName = widget.characterName ?? 'Hero'
      ..characterAge = widget.characterAge ?? 8
      ..selectedScenario = scenarioId ?? widget.theme ?? 'vanishing_colors'
      ..storyLength = twist == 'shorter'
          ? 'quick'
          : twist == 'longer'
              ? 'epic'
              : 'standard'
      ..rhymeTimeMode = twist == 'rhyming'
      ..interactiveMode = twist == 'interactive'
      ..customElements = switch (twist) {
        'funnier' =>
          'Make this story funny and silly with lots of jokes and humor',
        'spookier' =>
          'Add gentle spooky mystery elements (nothing scary for children)',
        _ => '',
      };

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WizardStoryScreen(
          initialWizardData: data,
          initialStep: 1,
        ),
      ),
    );
  }

  Future<void> _submitFeedback() async {
    if (_isSubmittingFeedback) return;
    setState(() => _isSubmittingFeedback = true);
    try {
      final feedback = StoryFeedback(
        storyId: widget.storyId ?? widget.title.hashCode.toString(),
        title: widget.title,
        rating: _storyRating,
        feedback: _feedbackController.text.trim(),
        therapeuticFocus: _activeTherapeuticFocus,
        submittedAt: DateTime.now(),
      );
      await _feedbackService.submitFeedback(feedback);
      await TherapeuticAnalytics.trackTherapeuticFeedback(
        rating: _storyRating.round(),
        feedbackText: _feedbackController.text.trim(),
      );
      _trackResultAction(
        'feedback_submitted',
        extra: {
          'rating': _storyRating.round(),
          'has_text': _feedbackController.text.trim().isNotEmpty,
        },
      );
      if (mounted) {
        _feedbackController.clear();
        _showSnackBar(
          'Thanks for helping us improve stories!',
          backgroundColor: Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Could not save feedback right now. Please try again soon.',
          backgroundColor: Colors.orange,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingFeedback = false);
      }
    }
  }

  Future<void> _loadFavoriteStatus() async {
    if (widget.storyId != null) {
      final story = await _offlineService.getStory(widget.storyId!);
      if (mounted) {
        setState(() {
          _isFavorite = story?.isFavorite ?? false;
          _isLoading = false;
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    // Wizard-generated stories have no widget.storyId. Save first so the
    // record exists, then toggle the heart on the freshly assigned local id.
    var targetId = widget.storyId ?? _savedLocalStoryId;
    if (targetId == null) {
      if (!_isSaved) {
        await _saveStory();
        targetId = widget.storyId ?? _savedLocalStoryId;
      } else {
        // Edge case: previously marked saved but we never captured the id
        // (e.g. older session state). Fall back by looking up a record that
        // matches this story so the heart still works.
        try {
          final stories = await _offlineService.getAllStories();
          final match = stories.firstWhere(
            (s) => s.title == widget.title && s.storyText == widget.storyText,
            orElse: () => stories.isNotEmpty
                ? stories.first
                : throw StateError('no stories'),
          );
          targetId = match.identifier;
          _savedLocalStoryId = targetId;
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Could not update favorite — please try saving the story first.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      }
    }
    if (targetId == null) return;

    await _offlineService.toggleFavorite(targetId);
    if (mounted) setState(() => _isFavorite = !_isFavorite);
    _trackResultAction(
      _isFavorite ? 'favorite_added' : 'favorite_removed',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _isFavorite ? 'Added to favorites!' : 'Removed from favorites'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Stable id used to bookmark this story's reading position. Prefers the id
  /// the story was opened with; falls back to the id auto-save assigns to a
  /// freshly generated story.
  String? get _progressStoryId => widget.storyId ?? _savedLocalStoryId;

  String _progressPrefsKey(String id) => 'story_progress_$id';

  /// Bookmarks the current page so the child can pick the story back up if
  /// they leave. A finished story clears its bookmark — it should re-open at
  /// the cover, not the last page.
  Future<void> _saveReadingProgress() async {
    final id = _progressStoryId;
    if (id == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _progressPrefsKey(id);
      if (_currentPageIndex >= _totalPages - 1) {
        await prefs.remove(key);
      } else {
        await prefs.setInt(key, _currentPageIndex);
      }
    } catch (_) {
      // Reading position is a nicety — never let it break page turns.
    }
  }

  /// Resumes a re-opened saved story at the page the child left off on.
  Future<void> _restoreReadingProgress() async {
    final id = widget.storyId;
    if (id == null) return; // fresh stories always start at the cover
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_progressPrefsKey(id));
      if (saved == null || !mounted) return;
      final target = saved.clamp(0, _totalPages - 1);
      if (target != _currentPageIndex) {
        setState(() => _currentPageIndex = target);
      }
    } catch (_) {
      // Fall back to the cover page.
    }
  }

  void _handlePageFlip(bool isForward) {
    if (mounted) {
      setState(() {
        if (isForward) {
          _currentPageIndex = (_currentPageIndex + 1).clamp(0, _totalPages - 1);
        } else {
          _currentPageIndex = (_currentPageIndex - 1).clamp(0, _totalPages - 1);
        }
        _flipBurstTrigger++;
        _flipBurstFromRight = isForward;
      });
      HapticFeedback.mediumImpact();
      // Paper page-rustle SFX on page flip (respects mute). If the asset is
      // missing, playSfx silently no-ops — haptic still fires.
      if (!_ambienceMuted) {
        unawaited(AudioAmbienceService().playSfx('sounds/page_turn.mp3'));
      }

      _trackResultAction(
        'story_page_flipped',
        extra: {
          'page_number': _currentPageIndex + 1,
          'total_pages': _totalPages,
          'direction': isForward ? 'forward' : 'backward',
        },
      );

      // Bias the prefetcher toward the page the reader just landed on so
      // its illustration (and the next one) jump the queue.
      final prefetcher = _perPagePrefetcher;
      if (prefetcher != null) {
        final textIndex =
            _hasCoverIllustration ? _currentPageIndex - 1 : _currentPageIndex;
        if (textIndex >= 0) prefetcher.prioritize(textIndex);
      }

      unawaited(_saveReadingProgress());
    }
  }

  void _goToNextStoryPage() {
    if (_currentPageIndex >= _totalPages - 1) return;
    _handlePageFlip(true);
  }

  void _goToPreviousStoryPage() {
    if (_currentPageIndex <= 0) return;
    _handlePageFlip(false);
  }

  /// Leaves the reader without stranding the child. A freshly generated story
  /// sits on top of the wizard, which is left parked on its "Make Magic"
  /// review step — popping back to it lands the child on a live "GO!" button
  /// that silently burns another daily story. Instead, replace the whole
  /// stack with a fresh wizard at step 0: the welcome-back character grid,
  /// where each saved hero offers its own Continue / start-new choice. A
  /// re-opened saved story just pops back where it came from.
  Future<void> _exitReader() async {
    if (widget.storyId != null) {
      Navigator.of(context).pop();
      return;
    }
    // Capture the navigator before the async gap so we never touch a
    // possibly-stale context afterwards.
    final navigator = Navigator.of(context);
    // Preload saved characters so the wizard's HeroCreatorStep can pick its
    // "welcome back" grid synchronously in initState — without them it falls
    // back to the blank create-a-hero form and the child (or a sibling
    // taking their turn) can't reach an already-created hero. Fetch from the
    // backend (the source the wizard itself uses): a hero created moments ago
    // in this session may not have synced to local Isar yet.
    List<Character> characters = const [];
    try {
      final response = await ApiServiceManager().get('/get-characters');
      final list = response['data'] is List
          ? response['data'] as List
          : (response['characters'] as List? ?? const []);
      characters = list
          .whereType<Map<String, dynamic>>()
          .map(Character.fromJson)
          .toList();
    } catch (_) {
      // Backend unreachable — fall back to the last-known local snapshot.
      try {
        characters = await IsarService.getAllCharacters();
      } catch (_) {
        // Non-fatal — the wizard reloads characters itself, just less smoothly.
      }
    }
    if (!mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => WizardStoryScreen(
          initialStep: 0,
          availableCharacters: characters,
        ),
      ),
      (route) => false,
    );
  }

  /// Per-page illustration for [textIndex]. Prefers art persisted from a
  /// saved story (rendered directly, no backend call); otherwise falls back
  /// to the live prefetcher; otherwise renders nothing.
  Widget _buildPerPageIllustration(int textIndex) {
    if (textIndex >= 0 && textIndex < _persistedPageIllustrations.length) {
      final bytes = _persistedPageIllustrations[textIndex];
      if (bytes != null) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildImageErrorPlaceholder(),
                    ),
                  ),
                  // AI-transparency label on the generated illustration.
                  const Positioned(
                    right: 6,
                    bottom: 6,
                    child: AiGeneratedBadge.corner(),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    final prefetcher = _perPagePrefetcher;
    if (prefetcher == null) return const SizedBox.shrink();
    return PerPageIllustration(
      listenable: prefetcher.stateOf(textIndex),
      onTapUpgrade: _useInlineQuotaUpsell
          ? () => _showIllustrationUnlockSheet(context)
          : null,
    );
  }

  /// Builds the page that occupies index [index] of the flip stack.
  ///
  /// On wide viewports (web / tablet landscape) this returns a two-page
  /// spread — the page itself on the left and a peek of the next leaf on
  /// the right, joined by a centre binding shadow — so the reader feels
  /// like an open book. On narrow phones it stays a single full-bleed page.
  Widget _buildStoryPage(int index) {
    // Cover illustration page — always full-bleed, never part of a spread.
    if (_hasCoverIllustration && index == 0) {
      return _buildCoverPage();
    }

    final isWide = MediaQuery.of(context).size.width >= 720;
    if (!isWide) return _buildSinglePage(index, bindingSide: null);

    // Two-page spread: current leaf binds on the right, the next leaf binds
    // on the left, and the StoryBookPage spine shadows meet in a gutter.
    final hasNext = index < _totalPages - 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildSinglePage(index, bindingSide: BookBindingSide.right),
        ),
        Expanded(
          child: hasNext
              ? _buildSinglePage(index + 1,
                  bindingSide: BookBindingSide.left, isSpreadPeek: true)
              : _buildSinglePage(index,
                  bindingSide: BookBindingSide.left,
                  isSpreadPeek: true,
                  blankLeaf: true),
        ),
      ],
    );
  }

  /// A single storybook leaf. [bindingSide] is null for a stand-alone phone
  /// page (binds left like a closed book), otherwise it places the spine on
  /// the gutter side of a spread. [isSpreadPeek] marks the right-hand leaf
  /// of a spread, and [blankLeaf] renders an empty leaf when the spread runs
  /// past the end of the story.
  Widget _buildSinglePage(
    int index, {
    required BookBindingSide? bindingSide,
    bool isSpreadPeek = false,
    bool blankLeaf = false,
  }) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final isDarkPage = !_highContrastMode && band.preferDarkMode;
    final pageBg = _highContrastMode
        ? Colors.black
        : (band.preferDarkMode
            ? const Color(0xFF1A1A2E)
            : const Color(0xFFFFF8E7));
    final effectiveBinding = bindingSide ?? BookBindingSide.left;
    final pageLabel = _totalPages > 1 && !blankLeaf
        ? 'Page ${index + 1} of $_totalPages'
        : null;

    // End-of-story / blank trailing leaf.
    final textIndex = _hasCoverIllustration ? index - 1 : index;
    if (blankLeaf) {
      return StoryBookPage(
        backgroundColor: pageBg,
        showDecorations: !_highContrastMode && !band.preferDarkMode,
        bindingSide: effectiveBinding,
        darkPage: _highContrastMode || isDarkPage,
        showPageEdges: !isSpreadPeek,
        framed: !_highContrastMode,
        child: const SizedBox.expand(),
      );
    }
    if (textIndex < 0 || textIndex >= _storyPages.length) {
      return _buildEndOfStoryPage(
        bindingSide: effectiveBinding,
        showPageEdges: !isSpreadPeek,
      );
    }

    final bool isRevealed = _revealedPages.contains(index);
    final pageTextColor = _highContrastMode
        ? Colors.white
        : (band.preferDarkMode
            ? const Color(0xFFE0E0E0)
            : const Color(0xFF2C3E50));

    final pageText = widget.isLearningToReadMode
        ? _phrasifyForEarlyReader(_storyPages[textIndex])
        : _storyPages[textIndex];
    final lineHeight = widget.isLearningToReadMode ? 2.1 : 1.8;

    return StoryBookPage(
      backgroundColor: pageBg,
      showDecorations: !_highContrastMode && !band.preferDarkMode,
      bindingSide: effectiveBinding,
      darkPage: _highContrastMode || isDarkPage,
      // The right-hand leaf of a spread sits against the gutter, not a free
      // edge, so it doesn't carry the page-edge fan.
      showPageEdges: !isSpreadPeek,
      framed: !_highContrastMode,
      pageLabel: pageLabel,
      // MT-071(a): tap-to-turn. A tap anywhere on the page body reveals the
      // text on first tap, then turns to the next page — the reader no
      // longer has to find the right-edge chevron. InkWell only claims tap
      // gestures, so the per-page scroll view keeps its drag/scroll
      // gestures and drag-to-flip on the page edges still works. The TTS
      // button and SelectableText are descendants with their own gesture
      // recognizers, so they win their own taps in the arena. A peeked
      // right-hand spread leaf isn't the live page, so it doesn't turn.
      child: InkWell(
        onTap: () {
          // The right-hand peek leaf of a spread isn't independently
          // revealable — a tap there just turns the book forward.
          if (isSpreadPeek) {
            if (_currentPageIndex < _totalPages - 1) _goToNextStoryPage();
            return;
          }
          if (!isRevealed) {
            setState(() {
              _revealedPages.add(index);
            });
          } else if (index < _totalPages - 1) {
            _goToNextStoryPage();
          }
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: SingleChildScrollView(
          // Per-index key forces a fresh Scrollable on page change so scroll
          // offset from the previous page doesn't bleed onto the next.
          key: ValueKey('story-page-scroll-$index'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Per-page illustration. Renders art persisted from a saved
              // story directly, otherwise the BYOK background prefetch:
              // bytes when ready, a skeleton while loading, an upsell card
              // when the free-tier monthly cap is hit (older bands only),
              // and nothing otherwise.
              _buildPerPageIllustration(textIndex),
              // Story text - MAGIC TYPEWRITER EFFECT
              if (!isRevealed)
                MagicalTypewriterText(
                  text: pageText,
                  readerAge: _effectiveAge,
                  onComplete: () {
                    setState(() {
                      _revealedPages.add(index);
                    });
                  },
                  style: GoogleFonts.merriweather(
                    fontSize: band.body(20) * _textScale,
                    height: lineHeight,
                    color: pageTextColor,
                  ),
                )
              else
                SelectableText.rich(
                  TextSpan(
                    style: GoogleFonts.merriweather(
                      fontSize: band.body(20) * _textScale,
                      height: lineHeight,
                      color: pageTextColor,
                    ),
                    children: _buildStorySpans(pageText),
                  ),
                ),
              if (_ttsAutoEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: IconButton(
                      tooltip: 'Read page out loud',
                      icon: const Icon(Icons.volume_up_rounded,
                          color: AppColors.gold, size: 36),
                      onPressed: () => _speakPage(_storyPages[textIndex]),
                    ),
                  ),
                ),
              // Bottom breathing room so the page-number badge tucked into
              // the corner never collides with the last line of text.
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReaderView() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final bgColor = _highContrastMode
        ? Colors.black
        : (band.preferDarkMode
            ? const Color(0xFF1A1A2E)
            : const Color(0xFFFFF8E7));
    final textColor = _highContrastMode
        ? Colors.white
        : (band.preferDarkMode
            ? const Color(0xFFE0E0E0)
            : const Color(0xFF2C3E50));

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(band.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      margin: EdgeInsets.only(bottom: band.space(24)),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: band.space(24),
          vertical: band.space(32),
        ),
        itemCount: _totalPages,
        itemBuilder: (context, index) {
          if (_hasCoverIllustration && index == 0) {
            final illustration = _inlineIllustrations.first;
            return Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(band.radiusMd),
                  child: Stack(
                    children: [
                      Image.memory(
                        illustration.bytes,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildImageErrorPlaceholder(),
                      ),
                      const Positioned(
                        right: 6,
                        bottom: 6,
                        child: AiGeneratedBadge.corner(),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: band.space(32)),
              ],
            );
          }

          final textIndex = _hasCoverIllustration ? index - 1 : index;

          if (textIndex >= _storyPages.length) {
            return _buildEndOfStoryPage();
          }

          final pageText = widget.isLearningToReadMode
              ? _phrasifyForEarlyReader(_storyPages[textIndex])
              : _storyPages[textIndex];
          final lineHeight = widget.isLearningToReadMode ? 2.1 : 1.8;
          return Padding(
            padding: EdgeInsets.only(bottom: band.space(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPerPageIllustration(textIndex),
                SelectableText.rich(
                  TextSpan(
                    style: GoogleFonts.merriweather(
                      fontSize: band.body(20) * _textScale,
                      height: lineHeight,
                      color: textColor,
                    ),
                    children: _buildStorySpans(pageText),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Full-bleed cover illustration page (picture-book opening spread).
  Widget _buildCoverPage() {
    final illustration = _inlineIllustrations.first;
    return StoryBookPage(
      backgroundColor:
          _highContrastMode ? Colors.black : const Color(0xFFFFF8E7),
      showDecorations: !_highContrastMode,
      framed: !_highContrastMode,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxImageHeight = constraints.maxHeight * 0.68;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxImageHeight),
                  // Tapping the cover picture begins the story — pre-readers
                  // navigate by tapping what they see, not by reading hints.
                  child: GestureDetector(
                    onTap: _goToNextStoryPage,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Image.memory(
                            illustration.bytes,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImageErrorPlaceholder();
                            },
                          ),
                          const Positioned(
                            right: 8,
                            bottom: 8,
                            child: AiGeneratedBadge.corner(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.quicksand(
                  fontSize: 22 * _textScale,
                  fontWeight: FontWeight.bold,
                  color: _highContrastMode
                      ? Colors.white
                      : const Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 20),
              // A big, obviously-tappable button that actually advances the
              // page. Replaces an earlier text hint whose arrow was purely
              // decorative — confusing for pre-readers who can't read it and
              // tapped the dead icon expecting it to work.
              _StartReadingButton(
                textScale: _textScale,
                highContrast: _highContrastMode,
                onTap: _goToNextStoryPage,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Celebratory end-of-story page with rating.
  Widget _buildEndOfStoryPage({
    BookBindingSide bindingSide = BookBindingSide.left,
    bool showPageEdges = true,
  }) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final isSprout = band.band == AgeBand.sprout;
    return StoryBookPage(
      backgroundColor:
          _highContrastMode ? Colors.black : const Color(0xFFFFF8E7),
      showDecorations: !_highContrastMode,
      bindingSide: bindingSide,
      showPageEdges: showPageEdges,
      darkPage: _highContrastMode,
      framed: !_highContrastMode,
      child: Center(
        child: SingleChildScrollView(
          key: const ValueKey('story-end-of-story-scroll'),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSprout) ...[
                _buildSproutEndCelebration(band),
                const SizedBox(height: 16),
              ] else
                Text(
                  '✨',
                  style: TextStyle(fontSize: 48 * _textScale),
                ),
              if (!isSprout) const SizedBox(height: 16),
              Text(
                'The End',
                style: GoogleFonts.quicksand(
                  fontSize: (isSprout ? 40 : 32) * _textScale,
                  fontWeight: FontWeight.bold,
                  color: _highContrastMode ? Colors.white : band.primary,
                ),
              ),
              // MT-235 Phase 2 (the returnable saga): the Creator superhero
              // cliffhanger. Surfaces this Issue's dangling thread as a
              // "Next time…" teaser + a light one-tap reflection, per the
              // design doc. Null hook (non-Creator / non-superhero) → nothing.
              ..._buildSagaCliffhanger(band: band),
              // Story Notes (MT-254): the quiet "Why this story? 💛" pull
              // trigger. Only present when this story carried a parent-selected
              // focus; tapping it opens the age-gated disclosure of what the
              // story practiced. Empty (nothing rendered) otherwise.
              ..._buildStoryNotesEntry(band: band),
              // MT-296: crisis-resources panel at story end for the Adolescent
              // antihero distress path only — parity with Life Quests, which
              // surface the same panel at story close. Empty for every other
              // story, so ordinary endings are unaffected.
              ..._buildAntiheroDistressSupport(band: band),
              SizedBox(height: isSprout ? 16 : 28),
              Divider(
                indent: 40,
                endIndent: 40,
                color: _highContrastMode
                    ? Colors.white24
                    : Colors.grey.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              // Young bands (sprout/explorer) get a quick 3-emoji rating;
              // older bands get the full 5-star row.
              if (band.band.isYoung) ...[
                Text(
                  'How was the story?',
                  style: GoogleFonts.quicksand(
                    fontSize: (isSprout ? 13 : 15) * _textScale,
                    fontWeight: FontWeight.w600,
                    color:
                        _highContrastMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                SizedBox(height: isSprout ? 4 : 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final entry in [
                      (emoji: '😕', stars: 1.0, label: 'Not great'),
                      (emoji: '😊', stars: 3.0, label: 'Good'),
                      (emoji: '🤩', stars: 5.0, label: 'Amazing'),
                    ])
                      Semantics(
                        label: entry.label,
                        button: true,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _storyRating = entry.stars;
                              _hasExplicitlyRated = true;
                            });
                            _submitFeedback();
                          },
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSprout ? 8 : 12,
                              vertical: isSprout ? 4 : 8,
                            ),
                            child: AnimatedScale(
                              scale: _hasExplicitlyRated &&
                                      _storyRating == entry.stars
                                  ? 1.3
                                  : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                entry.emoji,
                                style: TextStyle(
                                  fontSize: (isSprout ? 28 : 36) * _textScale,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ] else ...[
                Text(
                  '⭐ Rate this story',
                  style: GoogleFonts.quicksand(
                    fontSize: 16 * _textScale,
                    fontWeight: FontWeight.w600,
                    color:
                        _highContrastMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return Semantics(
                      label: 'Rate ${i + 1} stars',
                      button: true,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _storyRating = i + 1.0;
                            _hasExplicitlyRated = true;
                          });
                          _submitFeedback();
                        },
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            i < _storyRating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: AppColors.gold,
                            size: 36,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
              // Re-engagement buttons surfaced immediately below the rating
              if (widget.wizardData != null || widget.characterId != null) ...[
                const SizedBox(height: 20),
                Divider(
                  indent: 40,
                  endIndent: 40,
                  color: _highContrastMode
                      ? Colors.white24
                      : Colors.grey.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
              ],
              ..._buildEndOfStoryCtas(band: band, isSprout: isSprout),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRepeatButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    return SizedBox(
      width: 260,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: band.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  /// Build the re-engagement CTA section for the end-of-story page.
  ///
  /// Sprout band: compact tile-style buttons in a horizontal Wrap, leaving
  /// vertical room for the celebration illustration.
  /// Other bands: keep the existing 260-wide vertical stack.
  /// MT-235 Phase 2 (the returnable saga): the Creator superhero cliffhanger.
  /// Renders a "Next time…" teaser from [StoryResultScreen.sagaNextHook] plus a
  /// light one-tap reflection (per the design doc — growth framed as a choice,
  /// never therapy-speak). Returns an empty list when there is no hook to show,
  /// so non-Creator / non-superhero stories are entirely unaffected.
  List<Widget> _buildSagaCliffhanger({required AgeBandThemeData band}) {
    final hook = widget.sagaNextHook?.trim();
    if (hook == null || hook.isEmpty) return const [];

    final accent = _highContrastMode ? Colors.white : band.accent;
    // The card sits on the band's light cream `surface`, so text uses the
    // on-light color (in high-contrast mode the card goes dark → white text).
    final onSurface = _highContrastMode ? Colors.white : band.textOnLight;

    return [
      const SizedBox(height: 28),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: band.surface.withValues(alpha: _highContrastMode ? 0.15 : 0.9),
          borderRadius: BorderRadius.circular(band.cardRadiusBase),
          border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NEXT TIME…',
              style: GoogleFonts.quicksand(
                fontSize: 12 * _textScale,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hook,
              style: GoogleFonts.quicksand(
                fontSize: 16 * _textScale,
                fontWeight: FontWeight.w600,
                height: 1.35,
                fontStyle: FontStyle.italic,
                color: _highContrastMode ? Colors.white : band.textOnLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Before the next Issue — what does this chapter say about who your hero is becoming?',
              style: GoogleFonts.quicksand(
                fontSize: 13 * _textScale,
                fontWeight: FontWeight.w500,
                color: onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, label) in const [
                  'Braver',
                  'Wiser',
                  'Still figuring it out',
                ].indexed)
                  ChoiceChip(
                    label: Text(label),
                    selected: _sagaReflectionChoice == i,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _sagaReflectionChoice = i);
                    },
                    labelStyle: GoogleFonts.quicksand(
                      fontSize: 13 * _textScale,
                      fontWeight: FontWeight.w600,
                      color:
                          _sagaReflectionChoice == i ? Colors.black : onSurface,
                    ),
                    selectedColor: accent,
                    backgroundColor: accent.withValues(alpha: 0.12),
                    side: BorderSide(color: accent.withValues(alpha: 0.4)),
                  ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  /// Story Notes entry (MT-254) — the quiet "Why this story? 💛" pull trigger.
  ///
  /// Returns an empty list when this story carried no parent-selected focus, so
  /// ordinary stories are entirely unaffected. When a [practicedFocus] is
  /// present, surfaces [StoryNotesButton]; tapping it opens the age-gated
  /// disclosure built from the band + focus. The caregiver name is left to its
  /// warm default for now (TODO(MT-254): thread the per-child caregiver label).
  List<Widget> _buildStoryNotesEntry({required AgeBandThemeData band}) {
    final focus = widget.practicedFocus?.trim();
    if (focus == null || focus.isEmpty) return const [];
    // Match the disclosure's directness to the child the story was written for
    // (persisted age on reopen, live age otherwise) rather than whatever band
    // the app is currently themed to. Falls back to the themed band only when
    // no age is known.
    final disclosureAge = widget.practicedAge ?? widget.characterAge;
    final disclosureBand = (disclosureAge != null &&
            disclosureAge >= 3 &&
            disclosureAge <= 100)
        ? ageBandFromAge(disclosureAge)
        : band.band;
    return [
      const SizedBox(height: 12),
      StoryNotesButton(
        focusValue: focus,
        band: disclosureBand,
        heroName: widget.characterName,
      ),
    ];
  }

  /// MT-296: real-world safety net at the story's close for the Adolescent
  /// antihero "double life" distress path — parity with how Life Quests surface
  /// the same [CrisisResourcesPanel] at story end (see life_quest_screen.dart).
  ///
  /// Returns an empty list for every other story, so ordinary endings are
  /// entirely unaffected. Gated narrowly: only when the themed band is
  /// Adolescent AND the teen chose the wellbeing-distress secret on the Identity
  /// page (`WizardData.isAntiheroDistressPath`). The warm palette keeps it "we
  /// care", not "alarm", matching the inline treatment on the Identity page.
  List<Widget> _buildAntiheroDistressSupport({required AgeBandThemeData band}) {
    if (band.band != AgeBand.adolescent) return const [];
    if (!(widget.wizardData?.isAntiheroDistressPath ?? false)) return const [];

    final onSurface = _highContrastMode ? Colors.white : band.textOnLight;
    return [
      const SizedBox(height: 28),
      Text(
        'A quiet note, just in case',
        key: const ValueKey('story-end-distress-support'),
        textAlign: TextAlign.center,
        style: GoogleFonts.quicksand(
          fontSize: 14 * _textScale,
          fontWeight: FontWeight.w600,
          color: onSurface.withValues(alpha: 0.8),
        ),
      ),
      const SizedBox(height: 14),
      const CrisisResourcesPanel(),
    ];
  }

  List<Widget> _buildEndOfStoryCtas({
    required AgeBandThemeData band,
    required bool isSprout,
  }) {
    final ctas = <_EndCta>[];
    if (widget.wizardData != null) {
      ctas.add(_EndCta(
        label: widget.characterName != null
            ? 'New Story with ${widget.characterName}'
            : 'Same Character, New Story',
        shortLabel: 'New Story',
        icon: Icons.auto_stories_rounded,
        onTap: () {
          final clone = widget.wizardData!.clone();
          clone.selectedScenario = null;
          clone.selectedEmotionChips = [];
          clone.selectedFeeling = null;
          clone.selectedTrigger = null;
          clone.selectedBodySignal = null;
          clone.selectedCopingTool = null;
          clone.selectedRepairGoal = null;
          clone.customElements = '';
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => WizardStoryScreen(
              initialStep: 0,
              initialWizardData: clone,
            ),
          ));
        },
      ));
      ctas.add(_EndCta(
        label: 'Start Fresh',
        shortLabel: 'Start Fresh',
        icon: Icons.replay_rounded,
        onTap: () {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => WizardStoryScreen(
              initialStep: 1,
              initialWizardData: widget.wizardData!.clone(),
            ),
          ));
        },
      ));
    }
    if (widget.characterId != null) {
      ctas.add(_EndCta(
        label: 'My Chronicles',
        shortLabel: 'Chronicles',
        icon: Icons.menu_book_rounded,
        onTap: () {
          final stub = Character(
            id: widget.characterId!,
            name: widget.characterName ?? '',
            age: widget.characterAge ?? 8,
            role: 'Adventurer',
          );
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChroniclesListScreen(
              character: stub,
              userId: '',
            ),
          ));
        },
      ));
    }

    if (ctas.isEmpty) return const <Widget>[];

    final widgets = <Widget>[
      const SizedBox(height: 20),
      Divider(
        indent: 40,
        endIndent: 40,
        color: _highContrastMode
            ? Colors.white24
            : Colors.grey.withValues(alpha: 0.3),
      ),
      const SizedBox(height: 12),
    ];

    if (isSprout) {
      widgets.add(
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final cta in ctas) _buildSproutCtaTile(band: band, cta: cta),
          ],
        ),
      );
    } else {
      for (var i = 0; i < ctas.length; i++) {
        final cta = ctas[i];
        widgets.add(_buildRepeatButton(
          label: cta.label,
          icon: cta.icon,
          onTap: cta.onTap,
        ));
        if (i < ctas.length - 1) {
          widgets.add(const SizedBox(height: 10));
        }
      }
    }
    return widgets;
  }

  /// Compact icon-over-label tile sized for Sprout's horizontal CTA row.
  Widget _buildSproutCtaTile({
    required AgeBandThemeData band,
    required _EndCta cta,
  }) {
    return SizedBox(
      width: 96,
      child: ElevatedButton(
        onPressed: cta.onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: band.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cta.icon, size: 24),
            const SizedBox(height: 4),
            Text(
              cta.shortLabel,
              textAlign: TextAlign.center,
              style: GoogleFonts.quicksand(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hero celebration banner for Sprout's "The End" page. Uses the cover
  /// illustration when available, else a sparkle constellation on a
  /// band-tinted background so the page feels illustrated rather than blank.
  Widget _buildSproutEndCelebration(AgeBandThemeData band) {
    const double height = 180;
    if (_hasCoverIllustration) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.memory(
            _inlineIllustrations.first.bytes,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildSproutEndSparkleBanner(band, height),
          ),
        ),
      );
    }
    return _buildSproutEndSparkleBanner(band, height);
  }

  Widget _buildSproutEndSparkleBanner(AgeBandThemeData band, double height) {
    final accent = band.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.85),
              band.primary.withValues(alpha: 0.85),
            ],
          ),
        ),
        child: Stack(
          children: const [
            Positioned(
              top: 18,
              left: 24,
              child: Icon(Icons.auto_awesome, color: Colors.white70, size: 28),
            ),
            Positioned(
              top: 36,
              right: 30,
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 44),
            ),
            Positioned(
              bottom: 28,
              left: 60,
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 36),
            ),
            Positioned(
              bottom: 14,
              right: 56,
              child: Icon(Icons.auto_awesome, color: Colors.white70, size: 22),
            ),
            Center(
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 64),
            ),
          ],
        ),
      ),
    );
  }

  void _showReadingOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reading Magic',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Quicksand',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.text_fields, color: Colors.black54),
                const SizedBox(width: 16),
                const Text('Text Size',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: () =>
                      setState(() => _textScale = max(0.8, _textScale - 0.1)),
                  tooltip: 'Decrease Text Size',
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppColors.primary,
                ),
                Text(
                  '${(_textScale * 100).round()}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _textScale = min(2.0, _textScale + 0.1)),
                  tooltip: 'Increase Text Size',
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('High Contrast Mode',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              secondary: const Icon(Icons.contrast, color: Colors.black54),
              value: _highContrastMode,
              activeThumbColor: AppColors.primary,
              onChanged: (value) => setState(() {
                _highContrastMode = value;
              }),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showAdventureLog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_edu,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Adventure Log',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Quicksand',
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.choicesMade == null || widget.choicesMade!.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No choices recorded for this adventure.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.choicesMade!.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.gold),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choice ${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.choicesMade![index],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close Log'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Wisdom gem feature removed — stories now end cleanly without a lesson overlay.

  double _flipShadowIntensity = 0.0;
  double _flipShadowAlignment = 0.0;

  // Sparkle burst trigger — incremented each completed flip so the overlay
  // re-runs its animation. Direction tracks where the page came from so the
  // burst emanates from the trailing edge.
  int _flipBurstTrigger = 0;
  bool _flipBurstFromRight = true;

  void _onFlipStarted(PointerEvent event) {
    if (mounted) {
      setState(() {
        _flipShadowIntensity = 0.2;
        _flipShadowAlignment =
            (event.localPosition.dx / MediaQuery.of(context).size.width) * 2 -
                1;
      });
      HapticFeedback.lightImpact();
    }
  }

  void _onFlipUpdated(PointerEvent event) {
    if (mounted) {
      setState(() {
        _flipShadowAlignment =
            (event.localPosition.dx / MediaQuery.of(context).size.width) * 2 -
                1;
        // Increase intensity as we move towards the center
        _flipShadowIntensity = (0.3 -
                (event.localPosition.dx / MediaQuery.of(context).size.width -
                            0.5)
                        .abs() *
                    0.4)
            .clamp(0.0, 0.4);
      });
    }
  }

  void _onFlipEnded(PointerEvent event) {
    if (mounted) {
      setState(() {
        _flipShadowIntensity = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    // MT-099: the 3D page-flip and its sparkle burst are motion. Honour the
    // OS "reduce motion" flag so vestibular-sensitive readers get instant,
    // animation-free page turns (the arrows/taps still change the page).
    final bool reduceMotion = MotionPrefs.reduceMotion(context);
    return ErrorBoundary(
      onRetry: _retryLoadData,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [band.gradientStart, band.gradientMid, band.gradientEnd],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Magical App Bar
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: band.space(8),
                    vertical: band.space(8),
                  ),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final bool isNarrow = constraints.maxWidth < 400;
                    final compactIconSize =
                        band.touchTarget(40).clamp(40.0, 64.0).toDouble();
                    final iconPadding = isNarrow
                        ? EdgeInsets.zero
                        : EdgeInsets.all(band.space(8));

                    return Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            tooltip: 'Exit Reader',
                            onPressed: _exitReader,
                          ),
                        ),
                        SizedBox(width: band.space(8)),
                        if (_character != null) ...[
                          _buildBreathingHeroAvatar(size: isNarrow ? 36 : 42),
                          _buildBreathingCompanionAvatars(
                              size: isNarrow ? 28 : 32),
                          SizedBox(width: band.space(8)),
                        ],
                        SizedBox(width: band.space(8)),
                        // Adventure Log Button (only if choices exist)
                        if (widget.choicesMade != null &&
                            widget.choicesMade!.isNotEmpty) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.history_edu,
                                  color: Colors.white),
                              tooltip: 'Adventure Log',
                              constraints: isNarrow
                                  ? BoxConstraints(
                                      maxWidth: compactIconSize,
                                      maxHeight: compactIconSize)
                                  : null,
                              padding: iconPadding,
                              onPressed: _showAdventureLog,
                            ),
                          ),
                          SizedBox(width: band.space(4)),
                        ],
                        // Favorite Button
                        Container(
                          decoration: BoxDecoration(
                            color: _isFavorite
                                ? AppColors.gold.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color:
                                  _isFavorite ? AppColors.gold : Colors.white,
                            ),
                            tooltip: _isFavorite
                                ? 'Remove from favorites'
                                : 'Add to favorites',
                            constraints: isNarrow
                                ? BoxConstraints(
                                    maxWidth: compactIconSize,
                                    maxHeight: compactIconSize)
                                : null,
                            padding: iconPadding,
                            onPressed: _toggleFavorite,
                          ),
                        ),
                        SizedBox(width: band.space(4)),
                        // Sound Mute Button
                        Container(
                          decoration: BoxDecoration(
                            color: _ambienceMuted
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              _ambienceMuted
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                              color: _ambienceMuted
                                  ? Colors.white54
                                  : Colors.white,
                            ),
                            tooltip: _ambienceMuted
                                ? 'Turn sound on'
                                : 'Turn sound off',
                            constraints: isNarrow
                                ? BoxConstraints(
                                    maxWidth: compactIconSize,
                                    maxHeight: compactIconSize)
                                : null,
                            padding: iconPadding,
                            onPressed: () async {
                              await AudioAmbienceService().toggleMute();
                              if (mounted) {
                                setState(() {
                                  _ambienceMuted =
                                      AudioAmbienceService().isMuted;
                                });
                              }
                            },
                          ),
                        ),
                        SizedBox(width: band.space(4)),
                        // Settings Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon:
                                const Icon(Icons.settings, color: Colors.white),
                            tooltip: 'Reading Settings',
                            constraints: isNarrow
                                ? BoxConstraints(
                                    maxWidth: compactIconSize,
                                    maxHeight: compactIconSize)
                                : null,
                            padding: iconPadding,
                            onPressed: _showReadingOptions,
                          ),
                        ),
                      ],
                    );
                  }),
                ),

                // Story Book Area
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: LayoutBuilder(
                        builder: (context, areaConstraints) {
                          // On narrow phones, reclaim every pixel for the page itself.
                          final isNarrowArea = areaConstraints.maxWidth < 400;
                          final isShortArea = areaConstraints.maxHeight < 560;
                          final outerHorizontal =
                              isNarrowArea ? band.space(8) : band.space(24);
                          final titleSize = isNarrowArea
                              ? band.heading(20)
                              : band.heading(28);
                          final titleSpacing =
                              isShortArea ? band.space(8) : band.space(20);
                          // Sprout doesn't read; the reading-level pill is for parents
                          // and only adds clutter on the kid's reading screen. Hide it
                          // for sprout, and on any short viewport where space is precious.
                          final showReadingLevel =
                              band.band != AgeBand.sprout && !isShortArea;
                          return Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: outerHorizontal),
                            child: Column(
                              children: [
                                SizedBox(height: titleSpacing),
                                Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.merriweather(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.3),
                                        offset: const Offset(0, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                // Thin gold rule under the title — evokes a
                                // chapter heading and ties the title to the
                                // book below it.
                                SizedBox(height: band.space(8)),
                                Container(
                                  width: isNarrowArea ? 90 : 140,
                                  height: 2,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(1),
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.gold.withValues(alpha: 0.0),
                                        AppColors.gold,
                                        AppColors.gold.withValues(alpha: 0.0),
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                    ),
                                  ),
                                ),
                                if (showReadingLevel) ...[
                                  SizedBox(height: band.space(8)),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: band.space(12),
                                      vertical: band.space(6),
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(band.radiusMd),
                                      border: Border.all(
                                        color:
                                            band.accent.withValues(alpha: 0.55),
                                      ),
                                    ),
                                    child: Text(
                                      _readingLevelLabel(band),
                                      style: GoogleFonts.quicksand(
                                        color: band.accentLight,
                                        fontSize: band.body(12),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                                // Persistent AI-transparency label. Required by
                                // Google Play's Generative-AI policy, Apple, and
                                // EU AI Act Art. 50: this story and its artwork
                                // are machine-generated. Tap for details.
                                SizedBox(height: band.space(8)),
                                GestureDetector(
                                  onTap: _showAiInfo,
                                  child: const AiGeneratedBadge(
                                    label: 'Created with AI',
                                  ),
                                ),
                                SizedBox(
                                    height: isShortArea
                                        ? band.space(12)
                                        : band.space(24)),
                                Expanded(
                                  child: _isLoading
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                              color: Colors.white))
                                      : Column(
                                          children: [
                                            // Free-tier illustration cap banner.
                                            // Shown once per story for younger
                                            // bands (per-page cards cover older
                                            // bands). BYOK + Sprout never trip.
                                            if (_perPagePrefetcher != null &&
                                                !_useInlineQuotaUpsell)
                                              _buildQuotaBanner(),
                                            // Story Content - ENHANCED PAGE FLIP OR READER VIEW
                                            Expanded(
                                              child: RepaintBoundary(
                                                key: _storyBoundaryKey,
                                                child: _isReaderLayout
                                                    ? _buildReaderView()
                                                    : Listener(
                                                        onPointerDown:
                                                            _onFlipStarted,
                                                        onPointerMove:
                                                            _onFlipUpdated,
                                                        onPointerUp:
                                                            _onFlipEnded,
                                                        onPointerCancel:
                                                            _onFlipEnded,
                                                        // MT-099: ground the leaf inside a
                                                        // visible open hardback (leather
                                                        // rim + warm body + stacked-leaves
                                                        // footer) instead of floating it on
                                                        // the purple background. Decorative
                                                        // only; disabled in high contrast.
                                                        child: OpenBookFrame(
                                                          palette:
                                                              BookLeatherPalette
                                                                  .forBand(
                                                                      band),
                                                          enabled:
                                                              !_highContrastMode,
                                                          showFooter:
                                                              !isShortArea,
                                                          child: Stack(
                                                            children: [
                                                              PageFlipBuilder(
                                                                key:
                                                                    _pageFlipKey,
                                                                frontBuilder:
                                                                    (context) =>
                                                                        _buildStoryPage(
                                                                            _currentPageIndex),
                                                                backBuilder: (context) => _currentPageIndex <
                                                                        _totalPages -
                                                                            1
                                                                    ? _buildStoryPage(
                                                                        _currentPageIndex +
                                                                            1)
                                                                    : _buildStoryPage(
                                                                        _currentPageIndex),
                                                                flipAxis: Axis
                                                                    .horizontal,
                                                                maxTilt:
                                                                    0.005, // Increased tilt for more 3D feel
                                                                maxScale: 0.1,
                                                                onFlipComplete:
                                                                    _handlePageFlip,
                                                                // Reduce-motion: kill the
                                                                // drag-flip 3D animation;
                                                                // page turns stay instant.
                                                                interactiveFlipEnabled:
                                                                    !reduceMotion,
                                                              ),
                                                              // Dynamic Shadow Overlay
                                                              if (_flipShadowIntensity >
                                                                  0)
                                                                IgnorePointer(
                                                                  child:
                                                                      AnimatedContainer(
                                                                    duration: const Duration(
                                                                        milliseconds:
                                                                            100),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      gradient:
                                                                          LinearGradient(
                                                                        begin: Alignment(
                                                                            _flipShadowAlignment -
                                                                                0.2,
                                                                            0),
                                                                        end: Alignment(
                                                                            _flipShadowAlignment +
                                                                                0.2,
                                                                            0),
                                                                        colors: [
                                                                          Colors
                                                                              .transparent,
                                                                          Colors
                                                                              .black
                                                                              .withValues(alpha: _flipShadowIntensity),
                                                                          Colors
                                                                              .transparent,
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              // Magical sparkle burst on flip
                                                              // — suppressed under reduce
                                                              // motion (it's pure motion).
                                                              if (!reduceMotion)
                                                                Positioned.fill(
                                                                  child:
                                                                      _FlipSparkles(
                                                                    trigger:
                                                                        _flipBurstTrigger,
                                                                    fromRight:
                                                                        _flipBurstFromRight,
                                                                    largeBurst:
                                                                        _isYoungUser,
                                                                  ),
                                                                ),
                                                              // Left arrow (previous page)
                                                              if (_currentPageIndex >
                                                                  0)
                                                                Positioned(
                                                                  left: 0,
                                                                  top: 0,
                                                                  bottom: 0,
                                                                  width: isNarrowArea
                                                                      ? 48
                                                                      : (_isYoungUser
                                                                          ? 80
                                                                          : 56),
                                                                  child:
                                                                      _PageArrowOverlay(
                                                                    direction:
                                                                        _PageArrowDirection
                                                                            .left,
                                                                    onTap:
                                                                        _goToPreviousStoryPage,
                                                                    alwaysVisible:
                                                                        _isYoungUser,
                                                                    buttonSize: isNarrowArea
                                                                        ? 44
                                                                        : (_isYoungUser
                                                                            ? 64
                                                                            : 48),
                                                                    iconSize: isNarrowArea
                                                                        ? 28
                                                                        : (_isYoungUser
                                                                            ? 44
                                                                            : 32),
                                                                  ),
                                                                ),
                                                              // Right arrow (next page)
                                                              if (_currentPageIndex <
                                                                  _totalPages -
                                                                      1)
                                                                Positioned(
                                                                  right: 0,
                                                                  top: 0,
                                                                  bottom: 0,
                                                                  width: isNarrowArea
                                                                      ? 48
                                                                      : (_isYoungUser
                                                                          ? 80
                                                                          : 56),
                                                                  child:
                                                                      _PageArrowOverlay(
                                                                    direction:
                                                                        _PageArrowDirection
                                                                            .right,
                                                                    onTap:
                                                                        _goToNextStoryPage,
                                                                    alwaysVisible:
                                                                        _isYoungUser,
                                                                    buttonSize: isNarrowArea
                                                                        ? 44
                                                                        : (_isYoungUser
                                                                            ? 64
                                                                            : 48),
                                                                    iconSize: isNarrowArea
                                                                        ? 28
                                                                        : (_isYoungUser
                                                                            ? 44
                                                                            : 32),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                            ),
                                            // Footer controls
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                              decoration: BoxDecoration(
                                                color: _highContrastMode
                                                    ? Colors.grey[900]
                                                    : Colors.grey[50],
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                        bottom: Radius.circular(
                                                            24)),
                                                border: Border(
                                                  top: BorderSide(
                                                    color: _highContrastMode
                                                        ? Colors.grey[800]!
                                                        : Colors.grey[200]!,
                                                  ),
                                                ),
                                              ),
                                              child: Wrap(
                                                alignment:
                                                    WrapAlignment.spaceBetween,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  if (_totalPages > 1)
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        IconButton(
                                                          tooltip:
                                                              'Previous page',
                                                          onPressed:
                                                              _currentPageIndex >
                                                                      0
                                                                  ? _goToPreviousStoryPage
                                                                  : null,
                                                          icon: const Icon(Icons
                                                              .arrow_back_rounded),
                                                          color:
                                                              AppColors.primary,
                                                        ),
                                                        // The "Page N of M" text
                                                        // now lives in the bottom
                                                        // corner of the page
                                                        // itself (MT-099 d) — the
                                                        // footer keeps only the
                                                        // prev/next controls.
                                                        IconButton(
                                                          tooltip: 'Next page',
                                                          onPressed: _currentPageIndex <
                                                                  _totalPages -
                                                                      1
                                                              ? _goToNextStoryPage
                                                              : null,
                                                          icon: const Icon(Icons
                                                              .arrow_forward_rounded),
                                                          color:
                                                              AppColors.primary,
                                                        ),
                                                      ],
                                                    ),
                                                  // NEW: Storybook progress indicator instead of "Chapter X of Y"
                                                  StorybookProgressIndicator(
                                                    currentPage:
                                                        _currentPageIndex + 1,
                                                    totalPages: _totalPages,
                                                    isCompleted:
                                                        _currentPageIndex >=
                                                            _totalPages - 1,
                                                    stageLabel: _currentPageIndex >=
                                                            _totalPages - 1
                                                        ? null
                                                        : (_adventureSteps
                                                                    .length >
                                                                _currentPageIndex
                                                            ? _adventureSteps[
                                                                    _currentPageIndex]
                                                                .replaceAll(
                                                                    RegExp(
                                                                        r'^(Step \d+:|🌟|🚪|🎨|😮|🤔|💪|✨|🏠|🎭|🤪|🎉|💭)\s*'),
                                                                    '')
                                                            : null),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Use a bottom action bar instead of a floating button cluster so it doesn't
        // cover the story footer controls on smaller viewports.
        bottomNavigationBar: _isLoading
            ? null
            : _PostStoryActionBar(
                isSaved: _isSaved,
                isFreeTier: (widget.subscription?.isFree ?? true) &&
                    !widget.usedUserApiKey &&
                    !ref.watch(settingsProvider).useOwnApiKey,
                hasIllustrations: _inlineIllustrations.isNotEmpty ||
                    (_cachedIllustrations?.isNotEmpty ?? false),
                isYoungUser: _isYoungUser,
                isOnEndPage: _currentPageIndex >= _totalPages - 1,
                characterName: widget.characterName,
                hasWizardData: widget.wizardData != null,
                hasExplicitlyRated: _hasExplicitlyRated,
                onUnlockIllustrations: () =>
                    _showIllustrationUnlockSheet(context),
                onTellMeAnother: _createAnotherStory,
                onReread: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryReaderScreen(
                      storyText: widget.storyText,
                      title: widget.title,
                      theme: widget.theme,
                    ),
                  ),
                ),
                onSave: _isSaved ? null : _saveStory,
                onShare: _showShareOptions,
                onColor: _generateColoringPages,
                onRemix: _showRemixSheet,
                onQuickRate: (stars) {
                  setState(() {
                    _storyRating = stars;
                    _hasExplicitlyRated = true;
                  });
                  _submitFeedback();
                },
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Post-story action bar
// ---------------------------------------------------------------------------

/// Sticky bottom bar shown after story generation completes.
/// Primary CTA: "New Story with [name]" / "Tell Me Another" (full width).
/// Quick rating row (if not yet rated) + secondary actions row.
class _PostStoryActionBar extends StatelessWidget {
  final bool isSaved;
  final bool isFreeTier;
  final bool hasIllustrations;
  final bool isYoungUser;
  final bool isOnEndPage;
  final String? characterName;
  final bool hasWizardData;
  final bool hasExplicitlyRated;
  final VoidCallback onUnlockIllustrations;
  final VoidCallback onTellMeAnother;
  final VoidCallback onReread;
  final VoidCallback? onSave; // null when already saved
  final VoidCallback onShare;
  final VoidCallback onColor;
  final VoidCallback onRemix;
  final void Function(double stars) onQuickRate;

  const _PostStoryActionBar({
    required this.isSaved,
    required this.isFreeTier,
    required this.hasIllustrations,
    this.isYoungUser = false,
    this.isOnEndPage = false,
    this.characterName,
    required this.hasWizardData,
    required this.hasExplicitlyRated,
    required this.onUnlockIllustrations,
    required this.onTellMeAnother,
    required this.onReread,
    required this.onSave,
    required this.onShare,
    required this.onColor,
    required this.onRemix,
    required this.onQuickRate,
  });

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    // Sprout (2-5) gets bigger CTA padding and label so the button feels
    // friendly to small fingers and easy to spot.
    final isSprout = band.band == AgeBand.sprout;
    final primaryCtaVerticalPadding =
        isSprout ? 22.0 : (isYoungUser ? 18.0 : 14.0);
    final primaryCtaFontSize = isSprout ? 22.0 : (isYoungUser ? 19.0 : 17.0);
    // The mid-story upsell + quick rating clutter the screen on every page
    // turn. Defer them to the end-of-story page where the kid is done reading
    // and the parent might actually act on them. Sprout never sees the upsell.
    final showUpsell =
        isFreeTier && !hasIllustrations && isOnEndPage && !isSprout;
    final showQuickRating = !hasExplicitlyRated && isOnEndPage && !isSprout;
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          isSprout ? 12 : 10,
          16,
          isSprout ? 16 : 12,
        ),
        decoration: BoxDecoration(
          color: band.gradientEnd.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration teaser for free users who have no illustrations
            if (showUpsell)
              GestureDetector(
                onTap: onUnlockIllustrations,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.deepPurple.shade800.withValues(alpha: 0.9),
                        Colors.purple.shade700.withValues(alpha: 0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.5), width: 1),
                  ),
                  child: Row(
                    children: [
                      // Shimmer "locked illustration" preview
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF9C27B0),
                                    Color(0xFF3F51B5),
                                    Color(0xFF009688),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(Icons.auto_awesome,
                                  color: Colors.white30, size: 28),
                            ),
                            Positioned.fill(
                              child: BackdropFilter(
                                filter:
                                    ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  child: const Icon(Icons.lock_rounded,
                                      color: Colors.white, size: 22),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '🎨 See this scene illustrated!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Unlock AI artwork for every story — free with your own key',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: Colors.amber, size: 20),
                    ],
                  ),
                ),
              ),
            // Quick rating — only shown on end-of-story page (and never for Sprout)
            if (showQuickRating) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Quick rating:',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontFamily: band.uiFontFamily,
                    ),
                  ),
                  const SizedBox(width: 8),
                  for (final entry in [
                    (emoji: '😕', stars: 1.0),
                    (emoji: '😊', stars: 3.0),
                    (emoji: '🤩', stars: 5.0),
                  ])
                    GestureDetector(
                      onTap: () => onQuickRate(entry.stars),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(entry.emoji,
                            style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            // Primary CTA — shows character name when available
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onTellMeAnother,
                icon: Text(
                  band.band.isMature ? '✍️' : '🪄',
                  style: TextStyle(fontSize: primaryCtaFontSize + 2),
                ),
                label: Text(
                  characterName != null && hasWizardData
                      ? 'New Story with $characterName'
                      : (band.band.isMature ? 'New Story' : 'Tell Me Another!'),
                  style: TextStyle(
                    fontSize: primaryCtaFontSize,
                    fontWeight: FontWeight.bold,
                    fontFamily: band.uiFontFamily,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: band.primary,
                  foregroundColor: Colors.white,
                  padding:
                      EdgeInsets.symmetric(vertical: primaryCtaVerticalPadding),
                  shape: const StadiumBorder(),
                  elevation: 4,
                ),
              ),
            ),
            // "Start Fresh" secondary link — only when character context is available.
            // Hidden for young users (Sprout/Explorer): duplicates the primary CTA's
            // pop behavior and adds an extra string of small text the kid won't read.
            if (characterName != null && hasWizardData && !isYoungUser)
              TextButton(
                onPressed: onTellMeAnother,
                child: Text(
                  'Start Fresh',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontFamily: band.uiFontFamily,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // Secondary action row — simplified for young users (5-7)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!isYoungUser) ...[
                  _ActionChip(
                    icon: Icons.headphones_rounded,
                    label: 'Re-read',
                    onTap: onReread,
                    color: Colors.white,
                  ),
                  _ActionChip(
                    icon: Icons.shuffle_rounded,
                    label: 'Remix',
                    onTap: onRemix,
                    color: Colors.white,
                  ),
                  _ActionChip(
                    icon:
                        isSaved ? Icons.bookmark : Icons.bookmark_add_outlined,
                    label: isSaved ? 'Saved ✓' : 'Save',
                    onTap: onSave,
                    color: isSaved ? AppColors.gold : Colors.white,
                  ),
                  _ActionChip(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    onTap: onShare,
                    color: Colors.white,
                  ),
                  // Coloring pages are a deliberate end-of-story activity —
                  // surfaced only on the final page, where the kid is done
                  // reading, rather than cluttering every page-turn.
                  if (isOnEndPage)
                    _ActionChip(
                      icon: Icons.palette_rounded,
                      label: 'Color',
                      onTap: onColor,
                      color: Colors.white,
                    ),
                ],
                if (isYoungUser) ...[
                  _ActionChip(
                    icon: Icons.headphones_rounded,
                    label: 'Read to me',
                    onTap: onReread,
                    color: Colors.white,
                    largeMode: true,
                  ),
                  // Heart for young users — feelings-coded, not a filing-cabinet
                  // bookmark icon. Once saved, the heart fills gold and the label
                  // confirms with a child-friendly verb.
                  _ActionChip(
                    icon: isSaved
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: isSaved ? 'Loved ✓' : 'Love it',
                    onTap: onSave,
                    color: isSaved ? AppColors.gold : Colors.white,
                    largeMode: true,
                  ),
                  // Coloring is a calm end-of-story activity — a natural fit
                  // for young kids, shown only once the story is finished.
                  if (isOnEndPage)
                    _ActionChip(
                      icon: Icons.palette_rounded,
                      label: 'Color',
                      onTap: onColor,
                      color: Colors.white,
                      largeMode: true,
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final bool largeMode;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.largeMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final band = Theme.of(context).extension<AgeBandThemeData>();
    final isSprout = band?.band == AgeBand.sprout;
    final isDisabled = onTap == null;
    final effectiveColor = isDisabled ? color.withValues(alpha: 0.45) : color;
    final iconSize = isSprout ? 44.0 : (largeMode ? 32.0 : 24.0);
    final fontSize = isSprout ? 15.0 : (largeMode ? 13.0 : 11.0);
    final hitMin = isSprout ? 64.0 : (largeMode ? 56.0 : 48.0);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: hitMin, minHeight: hitMin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: effectiveColor, size: iconSize),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Remix tile widget
// ---------------------------------------------------------------------------

class _RemixTile extends StatelessWidget {
  final String emoji;
  final String label;
  final AgeBandThemeData band;
  final VoidCallback onTap;

  const _RemixTile({
    required this.emoji,
    required this.label,
    required this.band,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(band.buttonRadiusBase),
          border: Border.all(color: Colors.white30),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: band.uiFontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class ColoringSettingsDialog extends StatefulWidget {
  final int initialPageCount;
  final String? initialTherapeuticFocus;

  const ColoringSettingsDialog({
    super.key,
    required this.initialPageCount,
    this.initialTherapeuticFocus,
  });

  @override
  State<ColoringSettingsDialog> createState() => _ColoringSettingsDialogState();
}

class _ColoringSettingsDialogState extends State<ColoringSettingsDialog> {
  late int _pageCount;
  late String _selectedTherapeuticFocus;

  @override
  void initState() {
    super.initState();
    _pageCount = widget.initialPageCount.clamp(1, 5);
    final initial = widget.initialTherapeuticFocus;
    _selectedTherapeuticFocus = initial != null && initial.isNotEmpty
        ? initial
        : therapeuticFocusOptions.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.palette_outlined, color: Colors.pink),
          const SizedBox(width: 8),
          const Text('Coloring Page Settings'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How many pages?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Slider(
              value: _pageCount.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$_pageCount',
              onChanged: (value) {
                setState(() {
                  _pageCount = value.round();
                });
              },
            ),
            Center(
              child: Text(
                '$_pageCount ${_pageCount == 1 ? 'page' : 'pages'}',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Therapeutic focus (optional):',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedTherapeuticFocus,
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              items: therapeuticFocusOptions
                  .map(
                    (focus) => DropdownMenuItem<String>(
                      value: focus,
                      child: Text(focus),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedTherapeuticFocus = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              _selectedTherapeuticFocus == 'None'
                  ? 'Keep coloring prompts general and uplifting.'
                  : 'We\'ll weave in themes about $_selectedTherapeuticFocus.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context, {
              'numberOfPages': _pageCount,
              'therapeuticFocus': _selectedTherapeuticFocus == 'None'
                  ? null
                  : _selectedTherapeuticFocus,
            });
          },
          icon: const Icon(Icons.check),
          label: const Text('Generate'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pink,
          ),
        ),
      ],
    );
  }
}

class _InlineIllustration {
  const _InlineIllustration({
    required this.bytes,
    this.prompt,
  });

  final Uint8List bytes;
  final String? prompt;
}

class ColoringGenerationDialog extends StatelessWidget {
  final int totalPages;
  final String? therapeuticFocus;

  const ColoringGenerationDialog({
    super.key,
    required this.totalPages,
    this.therapeuticFocus,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Creating coloring pages...'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generating $totalPages ${totalPages == 1 ? "page" : "pages"} with age-appropriate detail.',
          ),
          const SizedBox(height: 12),
          const Text(
            'This usually takes 30-60 seconds. We\'ll let you know as soon as they\'re ready!',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          if (therapeuticFocus != null && therapeuticFocus!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.self_improvement, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Focus: $therapeuticFocus',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Plain CTA descriptor used by the end-of-story page to render either a
/// vertical stack of full-width buttons or a horizontal row of compact
/// tiles (Sprout band).
class _EndCta {
  const _EndCta({
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final String shortLabel;
  final IconData icon;
  final VoidCallback onTap;
}

/// Brief golden-star burst that fans out from one edge whenever its
/// [trigger] value changes — used to celebrate a completed page flip.
class _FlipSparkles extends StatefulWidget {
  const _FlipSparkles({
    required this.trigger,
    required this.fromRight,
    this.largeBurst = false,
  });

  final int trigger;
  final bool fromRight;

  /// When true, render a denser/bigger constellation with a longer animation
  /// — used for the Sprout band where the page-flip celebration needs to be
  /// more obvious to keep the toddler's attention.
  final bool largeBurst;

  @override
  State<_FlipSparkles> createState() => _FlipSparklesState();
}

class _FlipSparklesState extends State<_FlipSparkles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Hand-tuned constellation: angle (radians, 0 = horizontal outward),
  // travel distance, icon size, color.
  static const _sparks = <(double, double, double, Color)>[
    (-1.1, 70, 14, Color(0xFFFFFFFF)),
    (-0.55, 110, 22, Color(0xFFFFD700)),
    (-0.2, 140, 26, Color(0xFFFFB300)),
    (0.2, 145, 24, Color(0xFFFFD700)),
    (0.55, 105, 20, Color(0xFFFFC107)),
    (1.1, 75, 16, Color(0xFFFFFFFF)),
  ];

  // Sprout-band variant: 9 sparks, sizes 20-32, distances 100-180, 800ms.
  static const _sparksLarge = <(double, double, double, Color)>[
    (-1.2, 100, 20, Color(0xFFFFFFFF)),
    (-0.8, 130, 26, Color(0xFFFFD700)),
    (-0.4, 165, 30, Color(0xFFFFB300)),
    (-0.1, 180, 32, Color(0xFFFFD700)),
    (0.1, 175, 30, Color(0xFFFFC107)),
    (0.4, 160, 28, Color(0xFFFFD700)),
    (0.8, 125, 24, Color(0xFFFFB300)),
    (1.2, 100, 22, Color(0xFFFFFFFF)),
    (0.0, 140, 28, Color(0xFFFFFFFF)),
  ];

  List<(double, double, double, Color)> get _activeSparks =>
      widget.largeBurst ? _sparksLarge : _sparks;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.largeBurst ? 800 : 650),
    );
  }

  @override
  void didUpdateWidget(_FlipSparkles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.largeBurst != widget.largeBurst) {
      _controller.duration =
          Duration(milliseconds: widget.largeBurst ? 800 : 650);
    }
    if (oldWidget.trigger != widget.trigger && widget.trigger > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          if (t == 0 || _controller.isDismissed) {
            return const SizedBox.shrink();
          }
          final dir = widget.fromRight ? -1.0 : 1.0;
          final eased = Curves.easeOutCubic.transform(t);
          final fade = (1.0 - t).clamp(0.0, 1.0);
          return Stack(
            children: [
              for (final spark in _activeSparks)
                Align(
                  alignment: widget.fromRight
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Transform.translate(
                    offset: Offset(
                      cos(spark.$1) * spark.$2 * eased * dir,
                      sin(spark.$1) * spark.$2 * eased,
                    ),
                    child: Opacity(
                      opacity: fade,
                      child: Transform.rotate(
                        angle: t * pi * 1.5 * dir,
                        child: Icon(
                          Icons.auto_awesome,
                          size: spark.$3 * (0.6 + 0.4 * fade),
                          color: spark.$4,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

enum _PageArrowDirection { left, right }

class _PageArrowOverlay extends StatefulWidget {
  final _PageArrowDirection direction;
  final VoidCallback onTap;
  final bool alwaysVisible;
  final double buttonSize;
  final double iconSize;

  const _PageArrowOverlay({
    required this.direction,
    required this.onTap,
    this.alwaysVisible = false,
    this.buttonSize = 48,
    this.iconSize = 32,
  });

  @override
  State<_PageArrowOverlay> createState() => _PageArrowOverlayState();
}

class _PageArrowOverlayState extends State<_PageArrowOverlay>
    with SingleTickerProviderStateMixin {
  double _opacity = 1.0;
  bool _hasInteracted = false;
  Timer? _fadeTimer;
  Timer? _pulseTimer;
  int _pulseTrigger = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.alwaysVisible) {
      _fadeTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && !_hasInteracted) {
          setState(() => _opacity = 0.0);
        }
      });
    } else {
      // Sprout-band only: pulse the always-visible arrow every ~4.5s to
      // invite a tap. Drives a one-shot TweenAnimationBuilder (in build)
      // via a monotonically-increasing key.
      _pulseTimer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
        if (!mounted) return;
        setState(() => _pulseTrigger++);
      });
    }
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _pulseTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _hasInteracted = true;
      _opacity = 1.0;
    });
    widget.onTap();
    if (!widget.alwaysVisible) {
      _fadeTimer?.cancel();
      _fadeTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _opacity = 0.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLeft = widget.direction == _PageArrowDirection.left;
    final tappable = GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.translucent,
      child: AnimatedOpacity(
        opacity: widget.alwaysVisible ? 0.7 : _opacity * 0.6,
        duration: const Duration(milliseconds: 500),
        child: Center(
          child: Container(
            width: widget.alwaysVisible
                ? widget.buttonSize
                : widget.buttonSize * 0.83,
            height: widget.alwaysVisible
                ? widget.buttonSize
                : widget.buttonSize * 0.83,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(widget.alwaysVisible ? 80 : 40),
              shape: BoxShape.circle,
              border: widget.alwaysVisible
                  ? Border.all(color: Colors.white.withAlpha(120), width: 2)
                  : null,
            ),
            child: Icon(
              isLeft ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              color: Colors.white,
              size: widget.alwaysVisible
                  ? widget.iconSize
                  : widget.iconSize * 0.875,
            ),
          ),
        ),
      ),
    );
    if (!widget.alwaysVisible) return tappable;
    // Each time _pulseTrigger increments, run a one-shot scale tween that
    // peaks around 1.15 and rings back to 1.0 with an elastic feel. We
    // tween a normalized 0..1 progress and shape it ourselves so the
    // animation both starts AND ends at scale 1.0. The ValueKey forces
    // the builder to restart from 0 instead of holding at 1.
    return TweenAnimationBuilder<double>(
      key: ValueKey('pulse-$_pulseTrigger'),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, t, child) {
        // Triangle pulse 0→1→0 fed through elasticOut for the bouncy ring.
        final pulse = 1.0 - (2.0 * t - 1.0).abs();
        final eased = Curves.elasticOut.transform(pulse.clamp(0.0, 1.0));
        final scale = 1.0 + 0.15 * eased;
        return Transform.scale(scale: scale, child: child);
      },
      child: tappable,
    );
  }
}

/// Big, pulsing "Start Reading" button shown on the storybook cover page.
///
/// Sized and styled for pre-readers (ages 2-5): a large tap target, an
/// instantly-recognizable play icon, a gentle idle pulse to draw the eye,
/// and a press-down scale + haptic so the child feels the tap register.
class _StartReadingButton extends StatefulWidget {
  final double textScale;
  final bool highContrast;
  final VoidCallback onTap;

  const _StartReadingButton({
    required this.textScale,
    required this.highContrast,
    required this.onTap,
  });

  @override
  State<_StartReadingButton> createState() => _StartReadingButtonState();
}

class _StartReadingButtonState extends State<_StartReadingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.highContrast ? Colors.white : const Color(0xFF6C3FC7);
    final fg = widget.highContrast ? Colors.black : Colors.white;

    final button = AnimatedScale(
      scale: _pressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 90),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64, minWidth: 200),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded,
                color: fg, size: 32 * widget.textScale),
            const SizedBox(width: 8),
            Text(
              'Start Reading',
              style: GoogleFonts.fredoka(
                fontSize: 22 * widget.textScale,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      label: 'Start reading the story',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.06).animate(
            CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
          ),
          child: button,
        ),
      ),
    );
  }
}

Uint8List _compressJpgSync(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return bytes;
  var resized = image;
  if (image.width > 400 || image.height > 400) {
    resized = img.copyResize(
      image,
      width: image.width > image.height ? 400 : null,
      height: image.height >= image.width ? 400 : null,
      maintainAspect: true,
    );
  }
  return Uint8List.fromList(img.encodeJpg(resized, quality: 65));
}

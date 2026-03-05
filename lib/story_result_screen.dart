// lib/story_result_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_flip_builder/page_flip_builder.dart';
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
import 'widgets/app_button.dart';
import 'widgets/app_card.dart';
import 'widgets/error_boundary.dart';
import 'widgets/user_friendly_error_dialog.dart';
import 'widgets/golden_ticket_animation.dart';
import 'services/audio_ambience_service.dart';
import 'widgets/magical_typewriter_text.dart';
import 'widgets/breathing_avatar.dart';
import 'services/feature_tour_service.dart';
import 'widgets/storybook_progress_indicator.dart';
import 'widgets/storybook_page.dart';

class StoryResultScreen extends StatefulWidget {
  final String title;
  final String storyText;
  final String wisdomGem;
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

  const StoryResultScreen({
    super.key,
    required this.title,
    required this.storyText,
    required this.wisdomGem,
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
  })  : assert(!trackStoryCreation || achievementsService != null),
        assert(!trackStoryCreation || storyCreatedAt != null);

  @override
  State<StoryResultScreen> createState() => _StoryResultScreenState();
}

class _StoryResultScreenState extends State<StoryResultScreen> {
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

  bool _isSubmittingFeedback = false;
  double _storyRating = 4.0;

  List<_InlineIllustration> _inlineIllustrations = [];

  // Quality scoring
  Map<String, dynamic>? _qualityData;
  bool _isLoadingQuality = false;

  bool get _isYoungUser {
    final band = Theme.of(context).extension<AgeBandThemeData>();
    return band != null && (band.band == AgeBand.sprout || band.band == AgeBand.explorer);
  }

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

  Widget _buildBreathingHeroAvatar({required double size}) {
    final character = _character;
    if (character == null) return const SizedBox.shrink();

    Widget content;
    final generated = character.generatedAvatar;
    if (generated != null && generated.imageBase64.trim().isNotEmpty) {
      content = Image.memory(
        base64Decode(generated.imageBase64.split(',').last),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return character.buildAvatar(size: size);
        },
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
                child: Image.memory(
                  base64Decode(avatar.imageBase64.split(',').last),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    child: const Icon(Icons.pets, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  void initState() {
    super.initState();
    _offlineService =
        widget.offlineService ?? OfflineStoryService(IsarService.instance);

    // Start background ambience
    AudioAmbienceService().startAmbience(widget.theme ?? 'Adventure');

    // For epic stories, repaginate from the full story text to avoid sparse pages.
    if (widget.storyLengthHint == 'epic') {
      final epicSource = widget.storyText.trim().isNotEmpty
          ? widget.storyText
          : (widget.pages ?? const <String>[]).join('\n\n');
      _storyPages = _paginateStory(epicSource, wordsPerPage: 170);
      _adventureSteps = List.generate(
        _storyPages.length,
        (i) => 'Page ${i + 1}',
      );
    } else if (widget.pages != null && widget.pages!.isNotEmpty) {
      _storyPages = widget.pages!;
      _adventureSteps = widget.adventureSteps ??
          List.generate(
            _storyPages.length,
            (i) => 'Step ${i + 1}',
          );
    } else {
      _storyPages = _paginateStory(widget.storyText);
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
    _loadQualityData();
    if (widget.trackStoryCreation) {
      _trackStoryCreation(); // Track that user created a story, check for unlocks
    }
    if (widget.trackAnalytics) {
      _trackStoryView();
    }
  }

  void _decodeInlineIllustrations() {
    final raw = widget.backendIllustrations;
    if (raw == null || raw.isEmpty) return;

    final decoded = <_InlineIllustration>[];
    for (final item in raw) {
      final data = item['image_data'];
      if (data is String && data.isNotEmpty) {
        try {
          decoded.add(
            _InlineIllustration(
              bytes: base64Decode(data),
              prompt: item['prompt'] as String?,
            ),
          );
        } catch (_) {
          // Ignore invalid base64 blobs
        }
      }
    }

    _inlineIllustrations = decoded;
  }

  @override
  void dispose() {
    AudioAmbienceService().stopAmbience();
    _pageController.dispose();
    _feedbackController.dispose();
    super.dispose();
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

    final newFeatureUnlocks =
        await _progressionService.incrementStoriesCreated();
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
      final response = await http
          .get(
            Uri.parse(
                '${Environment.backendUrl}/characters/${widget.characterId}'),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Loading character details timed out. Using a default age for now.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint('Error loading character ${widget.characterId}: $e');
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
      final response = await http.post(
        Uri.parse('${Environment.backendUrl}/quality/score-story'),
        headers: {'Content-Type': 'application/json'},
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
    final sentences = widget.storyText
        .split(RegExp(r'[.!?]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (sentences.isEmpty) {
      return [widget.storyText];
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
      scenes.add(text.endsWith('.') ? text : '$text.');
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
    final words =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) {
      return [text];
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
    return pages.isEmpty ? [text] : pages;
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

      final pages = await _coloringService.generateColoringPagesFromStory(
        storyId:
            widget.storyId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        storyTitle: widget.title,
        scenes: scenes,
        characterAppearance: _buildCharacterAppearance(),
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

  Map<String, dynamic> _buildSharePayload() => {
        'title': widget.title,
        'story': widget.storyText,
        'wisdomGem': widget.wisdomGem,
        'characterName': widget.characterName,
        'theme': widget.theme,
        'generatedAt': widget.storyCreatedAt?.toIso8601String(),
      };

  String _formatShareText({bool includeMetadata = false}) {
    final buffer = StringBuffer()
      ..writeln(widget.title)
      ..writeln()
      ..writeln(widget.storyText);
    if (widget.wisdomGem.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Wisdom Gem: ${widget.wisdomGem}');
    }

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

  Future<void> _saveStory() async {
    // If storyId is present, it might already be saved or we can't save a new one easily without checking.
    // But usually in Wizard flow, storyId is null.
    if (widget.storyId == null) {
      try {
        final newStory = SavedStory(
          title: widget.title,
          storyText: widget.storyText,
          theme: widget.theme ?? 'Adventure',
          characters: _character != null ? [_character!] : [],
          createdAt: widget.storyCreatedAt ?? DateTime.now(),
          isInteractive: widget.isInteractive ?? false,
          isRhyming: widget.isRhyming ?? false,
          isLearningToRead: widget.isLearningToReadMode,
          wisdomGem: widget.wisdomGem,
          pages: widget.pages,
          adventureSteps: widget.adventureSteps,
          // Calculate stats
          totalWords: widget.storyText.split(RegExp(r'\s+')).length,
          totalPages: widget.pages?.length ?? _storyPages.length,
        );

        final storyLocal = StoryLocal.fromSavedStory(newStory);
        await _offlineService.saveStory(storyLocal);
        if (mounted) setState(() => _isSaved = true);

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

  Future<void> _exportStory() async {
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(
        text: _formatShareText(includeMetadata: true),
      ));
      if (mounted) {
        _showSnackBar('Story text copied to clipboard! 📄', backgroundColor: Colors.green);
      }
      _trackResultAction('share', extra: {'method': 'copy_txt_web'});
      return;
    }
    final directory = await getTemporaryDirectory();
    final fileName =
        widget.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final file = File('${directory.path}/$fileName.txt');
    await file.writeAsString(_formatShareText(includeMetadata: true));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Story export ready to download or print.',
        subject: widget.title,
      ),
    );
    _trackResultAction('share', extra: {'method': 'export_txt'});
  }

  Future<void> _copyShareData() async {
    await Clipboard.setData(ClipboardData(
      text: jsonEncode(_buildSharePayload()),
    ));
    if (mounted) {
      _showSnackBar('Story data copied for Gemini coordination.',
          backgroundColor: Colors.green);
    }
    _trackResultAction('share', extra: {'method': 'copy_json'});
  }

  Widget _buildShareActions() {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share this story',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Send the adventure to family, export a text copy, or grab the JSON payload for coordination.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              SizedBox(
                width: 200,
                child: AppButton.primary(
                  label: 'Share',
                  icon: Icons.share,
                  onPressed: _shareStory,
                ),
              ),
              SizedBox(
                width: 200,
                child: AppButton.secondary(
                  label: 'Export .txt',
                  icon: Icons.file_download,
                  onPressed: _exportStory,
                ),
              ),
              SizedBox(
                width: 200,
                child: AppButton.secondary(
                  label: 'Copy JSON',
                  icon: Icons.code,
                  onPressed: _copyShareData,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Actions',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              SizedBox(
                width: 200,
                child: AppButton.secondary(
                  label: 'Save to Library',
                  icon: Icons.bookmark_add_outlined,
                  onPressed: () {
                    Navigator.pop(context);
                    _saveStory();
                  },
                ),
              ),
              SizedBox(
                width: 200,
                child: AppButton.primary(
                  label: 'Create New Story',
                  icon: Icons.auto_awesome,
                  onPressed: _createAnotherStory,
                ),
              ),
            ],
          ),
        ],
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
    if (widget.storyId == null) return;

    await _offlineService.toggleFavorite(widget.storyId!);
    setState(() => _isFavorite = !_isFavorite);
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

  void _handlePageFlip(bool isForward) {
    if (mounted) {
      setState(() {
        if (isForward) {
          _currentPageIndex =
              (_currentPageIndex + 1).clamp(0, _storyPages.length - 1);
        } else {
          _currentPageIndex =
              (_currentPageIndex - 1).clamp(0, _storyPages.length - 1);
        }
      });
      unawaited(AudioAmbienceService().onUserGesture());
      // Play page turn SFX (skip on web due codec/asset format issues in browser runtime).
      if (!kIsWeb) {
        unawaited(AudioAmbienceService().playSfx('sounds/page_turn.mp3'));
      }

      _trackResultAction(
        'story_page_flipped',
        extra: {
          'page_number': _currentPageIndex + 1,
          'total_pages': _storyPages.length,
          'direction': isForward ? 'forward' : 'backward',
        },
      );
    }
  }

  void _goToNextStoryPage() {
    if (_currentPageIndex >= _storyPages.length - 1) return;
    _handlePageFlip(true);
  }

  void _goToPreviousStoryPage() {
    if (_currentPageIndex <= 0) return;
    _handlePageFlip(false);
  }

  Widget _buildStoryPage(int index) {
    if (index < 0 || index >= _storyPages.length) {
      return StoryBookPage(
        backgroundColor:
            _highContrastMode ? Colors.black : const Color(0xFFFFF8E7),
        showDecorations: !_highContrastMode,
        child: const Center(child: Text('End of Adventure')),
      );
    }

    // Get illustration for this page if available
    final inlineIllustration = index < _inlineIllustrations.length
        ? _inlineIllustrations[index]
        : null;
    final cachedIllustration =
        _cachedIllustrations != null && index < _cachedIllustrations!.length
            ? _cachedIllustrations![index]
            : null;
    final hasIllustration =
        inlineIllustration != null || cachedIllustration != null;

    final bool isRevealed = _revealedPages.contains(index);

    return StoryBookPage(
      backgroundColor:
          _highContrastMode ? Colors.black : const Color(0xFFFFF8E7),
      showDecorations: !_highContrastMode,
      child: InkWell(
        onTap: () {
          unawaited(AudioAmbienceService().onUserGesture());
          if (!isRevealed) {
            setState(() {
              _revealedPages.add(index);
            });
          }
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Show illustration at top of page if available
              if (hasIllustration) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: inlineIllustration != null
                      ? Image.memory(
                          inlineIllustration.bytes,
                          fit: BoxFit.cover,
                          height: 250,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildImageErrorPlaceholder();
                          },
                        )
                      : Image.network(
                          cachedIllustration!.imageUrl,
                          fit: BoxFit.cover,
                          height: 250,
                          width: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 250,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildImageErrorPlaceholder();
                          },
                        ),
                ),
                const SizedBox(height: 24),
              ],
              // Story text - MAGIC TYPEWRITER EFFECT
              if (!isRevealed)
                MagicalTypewriterText(
                  text: _storyPages[index],
                  readerAge: _effectiveAge,
                  onComplete: () {
                    setState(() {
                      _revealedPages.add(index);
                    });
                  },
                  style: GoogleFonts.merriweather(
                    fontSize: 20 * _textScale,
                    height: 1.8,
                    color: _highContrastMode
                        ? Colors.white
                        : const Color(0xFF2C3E50),
                  ),
                )
              else
                SelectableText.rich(
                  TextSpan(
                    style: GoogleFonts.merriweather(
                      fontSize: 20 * _textScale,
                      height: 1.8,
                      color: _highContrastMode
                          ? Colors.white
                          : const Color(0xFF2C3E50),
                    ),
                    children: _buildStorySpans(_storyPages[index]),
                  ),
                ),
            ],
          ),
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

  double _flipShadowIntensity = 0.0;
  double _flipShadowAlignment = 0.0;

  void _onFlipStarted(PointerEvent event) {
    if (mounted) {
      setState(() {
        _flipShadowIntensity = 0.2;
        _flipShadowAlignment =
            (event.localPosition.dx / MediaQuery.of(context).size.width) * 2 -
                1;
      });
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
    final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final bool isNarrow = constraints.maxWidth < 400;

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
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_character != null) ...[
                          _buildBreathingHeroAvatar(size: isNarrow ? 36 : 42),
                          _buildBreathingCompanionAvatars(
                              size: isNarrow ? 28 : 32),
                          const SizedBox(width: 8),
                        ],
                        if (widget.wisdomGem.isNotEmpty)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                    color:
                                        AppColors.gold.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome,
                                      color: AppColors.gold, size: 20),
                                  if (!isNarrow) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        widget.wisdomGem,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.quicksand(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
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
                                  ? const BoxConstraints(
                                      maxWidth: 40, maxHeight: 40)
                                  : null,
                              padding: isNarrow
                                  ? EdgeInsets.zero
                                  : const EdgeInsets.all(8),
                              onPressed: _showAdventureLog,
                            ),
                          ),
                          const SizedBox(width: 4),
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
                                ? const BoxConstraints(
                                    maxWidth: 40, maxHeight: 40)
                                : null,
                            padding: isNarrow
                                ? EdgeInsets.zero
                                : const EdgeInsets.all(8),
                            onPressed: _toggleFavorite,
                          ),
                        ),
                        const SizedBox(width: 4),
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
                                ? const BoxConstraints(
                                    maxWidth: 40, maxHeight: 40)
                                : null,
                            padding: isNarrow
                                ? EdgeInsets.zero
                                : const EdgeInsets.all(8),
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.merriweather(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Expanded(
                              child: _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                          color: Colors.white))
                                  : Column(
                                      children: [
                                        // Story Content - ENHANCED PAGE FLIP
                                        Expanded(
                                          child: RepaintBoundary(
                                            key: _storyBoundaryKey,
                                            child: Listener(
                                              onPointerDown: _onFlipStarted,
                                              onPointerMove: _onFlipUpdated,
                                              onPointerUp: _onFlipEnded,
                                              onPointerCancel: _onFlipEnded,
                                              child: Stack(
                                              children: [
                                                PageFlipBuilder(
                                                  key: _pageFlipKey,
                                                  frontBuilder: (context) =>
                                                      _buildStoryPage(
                                                          _currentPageIndex),
                                                  backBuilder: (context) =>
                                                      _currentPageIndex <
                                                              _storyPages
                                                                      .length -
                                                                  1
                                                          ? _buildStoryPage(
                                                              _currentPageIndex +
                                                                  1)
                                                          : _buildStoryPage(
                                                              _currentPageIndex),
                                                  flipAxis: Axis.horizontal,
                                                  maxTilt:
                                                      0.005, // Increased tilt for more 3D feel
                                                  maxScale: 0.1,
                                                  onFlipComplete:
                                                      _handlePageFlip,
                                                  interactiveFlipEnabled: true,
                                                ),
                                                // Dynamic Shadow Overlay
                                                if (_flipShadowIntensity > 0)
                                                  IgnorePointer(
                                                    child: AnimatedContainer(
                                                      duration: const Duration(
                                                          milliseconds: 100),
                                                      decoration: BoxDecoration(
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
                                                            Colors.transparent,
                                                            Colors.black.withValues(
                                                                alpha:
                                                                    _flipShadowIntensity),
                                                            Colors.transparent,
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                // Left arrow (previous page)
                                                if (_currentPageIndex > 0)
                                                  Positioned(
                                                    left: 0,
                                                    top: 0,
                                                    bottom: 0,
                                                    width: 56,
                                                    child: _PageArrowOverlay(
                                                      direction: _PageArrowDirection.left,
                                                      onTap: _goToPreviousStoryPage,
                                                      alwaysVisible: _isYoungUser,
                                                    ),
                                                  ),
                                                // Right arrow (next page)
                                                if (_currentPageIndex < _storyPages.length - 1)
                                                  Positioned(
                                                    right: 0,
                                                    top: 0,
                                                    bottom: 0,
                                                    width: 56,
                                                    child: _PageArrowOverlay(
                                                      direction: _PageArrowDirection.right,
                                                      onTap: _goToNextStoryPage,
                                                      alwaysVisible: _isYoungUser,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        ),
                                        // Footer controls
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _highContrastMode
                                                ? Colors.grey[900]
                                                : Colors.grey[50],
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    bottom:
                                                        Radius.circular(24)),
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
                                              if (_storyPages.length > 1)
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      tooltip: 'Previous page',
                                                      onPressed:
                                                          _currentPageIndex > 0
                                                              ? _goToPreviousStoryPage
                                                              : null,
                                                      icon: const Icon(Icons
                                                          .arrow_back_rounded),
                                                      color: AppColors.primary,
                                                    ),
                                                    Text(
                                                      'Page ${_currentPageIndex + 1} of ${_storyPages.length}',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: _highContrastMode
                                                            ? Colors.white
                                                            : AppColors.primary,
                                                      ),
                                                    ),
                                                    IconButton(
                                                      tooltip: 'Next page',
                                                      onPressed: _currentPageIndex <
                                                              _storyPages
                                                                      .length -
                                                                  1
                                                          ? _goToNextStoryPage
                                                          : null,
                                                      icon: const Icon(Icons
                                                          .arrow_forward_rounded),
                                                      color: AppColors.primary,
                                                    ),
                                                  ],
                                                ),
                                              // NEW: Storybook progress indicator instead of "Chapter X of Y"
                                              StorybookProgressIndicator(
                                                currentPage:
                                                    _currentPageIndex + 1,
                                                totalPages: _storyPages.length,
                                                stageLabel: _adventureSteps
                                                            .length >
                                                        _currentPageIndex
                                                    ? _adventureSteps[
                                                            _currentPageIndex]
                                                        .replaceAll(
                                                            RegExp(
                                                                r'^(Step \d+:|🌟|🚪|🎨|😮|🤔|💪|✨|🏠|🎭|🤪|🎉|💭)\s*'),
                                                            '')
                                                    : null,
                                              ),
                                              // Simple Feedback
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children:
                                                    List.generate(5, (index) {
                                                  return Semantics(
                                                    label:
                                                        'Rate ${index + 1} stars',
                                                    button: true,
                                                    child: InkWell(
                                                      onTap: () {
                                                        setState(() =>
                                                            _storyRating =
                                                                index + 1.0);
                                                        _submitFeedback();
                                                      },
                                                      customBorder:
                                                          const CircleBorder(),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child: Icon(
                                                          index < _storyRating
                                                              ? Icons
                                                                  .star_rounded
                                                              : Icons
                                                                  .star_outline_rounded,
                                                          color: AppColors.gold,
                                                          size: 24,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }),
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
                onTellMeAnother: _createAnotherStory,
                onReread: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryReaderScreen(
                      storyText: widget.storyText,
                      title: widget.title,
                    ),
                  ),
                ),
                onSave: _isSaved ? null : _saveStory,
                onShare: _showShareOptions,
                onColor: _generateColoringPages,
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Post-story action bar
// ---------------------------------------------------------------------------

/// Sticky bottom bar shown after story generation completes.
/// Primary CTA: "Tell Me Another" (magic wand, full width).
/// Secondary row: Re-read · Save · Share · Color.
class _PostStoryActionBar extends StatelessWidget {
  final bool isSaved;
  final VoidCallback onTellMeAnother;
  final VoidCallback onReread;
  final VoidCallback? onSave; // null when already saved
  final VoidCallback onShare;
  final VoidCallback onColor;

  const _PostStoryActionBar({
    required this.isSaved,
    required this.onTellMeAnother,
    required this.onReread,
    required this.onSave,
    required this.onShare,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: band.gradientEnd.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Primary CTA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onTellMeAnother,
                icon: const Text('🪄', style: TextStyle(fontSize: 18)),
                label: Text(
                  'Tell Me Another!',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    fontFamily: band.uiFontFamily,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: band.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                  elevation: 4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Secondary action row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionChip(
                  icon: Icons.record_voice_over_rounded,
                  label: 'Re-read',
                  onTap: onReread,
                  color: Colors.white,
                ),
                _ActionChip(
                  icon: isSaved ? Icons.bookmark : Icons.bookmark_add_outlined,
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
                _ActionChip(
                  icon: Icons.palette_rounded,
                  label: 'Color',
                  onTap: onColor,
                  color: Colors.white,
                ),
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

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    final effectiveColor = isDisabled ? color.withValues(alpha: 0.45) : color;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: effectiveColor, size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
  static const int _pageCount = 1;
  late String _selectedTherapeuticFocus;

  @override
  void initState() {
    super.initState();
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

enum _PageArrowDirection { left, right }

class _PageArrowOverlay extends StatefulWidget {
  final _PageArrowDirection direction;
  final VoidCallback onTap;
  final bool alwaysVisible;

  const _PageArrowOverlay({
    required this.direction,
    required this.onTap,
    this.alwaysVisible = false,
  });

  @override
  State<_PageArrowOverlay> createState() => _PageArrowOverlayState();
}

class _PageArrowOverlayState extends State<_PageArrowOverlay>
    with SingleTickerProviderStateMixin {
  double _opacity = 1.0;
  bool _hasInteracted = false;

  @override
  void initState() {
    super.initState();
    if (!widget.alwaysVisible) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && !_hasInteracted) {
          setState(() => _opacity = 0.0);
        }
      });
    }
  }

  void _handleTap() {
    setState(() {
      _hasInteracted = true;
      _opacity = 1.0;
    });
    widget.onTap();
    if (!widget.alwaysVisible) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _opacity = 0.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLeft = widget.direction == _PageArrowDirection.left;
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.translucent,
      child: AnimatedOpacity(
        opacity: widget.alwaysVisible ? 0.7 : _opacity * 0.6,
        duration: const Duration(milliseconds: 500),
        child: Center(
          child: Container(
            width: widget.alwaysVisible ? 48 : 40,
            height: widget.alwaysVisible ? 48 : 40,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLeft ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              color: Colors.white,
              size: widget.alwaysVisible ? 32 : 28,
            ),
          ),
        ),
      ),
    );
  }
}

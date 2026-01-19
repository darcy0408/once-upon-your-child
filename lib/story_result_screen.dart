// lib/story_result_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'story_reader_screen.dart';
import 'services/isar_service.dart';
import 'services/offline_story_service.dart';
import 'story_illustration_service.dart';
import 'illustration_settings_dialog.dart';
import 'illustrated_story_viewer.dart';
import 'coloring_book_service.dart';
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
import 'theme/app_theme.dart';
import 'widgets/app_button.dart';
import 'widgets/app_card.dart';
import 'widgets/error_boundary.dart';
import 'widgets/user_friendly_error_dialog.dart';
import 'widgets/storybook_progress_indicator.dart';
import 'services/feature_tour_service.dart';

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
  List<StoryIllustration>? _cachedIllustrations;
  List<ColoringPage>? _cachedColoringPages;
  int? _characterAge;
  Character? _character;  // Store full character data for illustrations
  String? _activeTherapeuticFocus;
  late final PageController _pageController;
  late List<String> _storyPages;
  late List<String> _adventureSteps;  // NEW: Adventure step labels
  int _currentPageIndex = 0;
  double _textScale = 1.0;
  bool _highContrastMode = false;

  bool _isSubmittingFeedback = false;
  double _storyRating = 4.0;

  List<_InlineIllustration> _inlineIllustrations = [];

  // Quality scoring
  Map<String, dynamic>? _qualityData;
  bool _isLoadingQuality = false;
  
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

  void _handlePageChanged(int index) {
    setState(() => _currentPageIndex = index);

    _trackResultAction(
      'story_page_viewed',
      extra: {
        'page_number': index + 1,
        'total_pages': _storyPages.length,
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _offlineService = widget.offlineService ?? OfflineStoryService(IsarService.instance);

    // NEW: Use backend-generated pages if available, otherwise paginate
    if (widget.pages != null && widget.pages!.isNotEmpty) {
      _storyPages = widget.pages!;
      _adventureSteps = widget.adventureSteps ?? List.generate(
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
        debugPrint('Achievement unlocked (dialog suppressed): $achievementUnlocks');
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
          _character = character;  // Store full character for illustrations
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
        characterAppearance: null, // TODO: Hydrate from character appearance
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

  Future<void> _saveStory() async {
    // Story is already saved via main_story.dart
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Story is already saved in your Library!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _createAnotherStory() {
    _trackResultAction('regenerate_requested');
    Navigator.of(context).pop();
  }

  Future<void> _exportStory() async {
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
                const Text('Text Size', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _textScale = max(0.8, _textScale - 0.1)),
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppColors.primary,
                ),
                Text(
                  '${(_textScale * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  onPressed: () => setState(() => _textScale = min(2.0, _textScale + 0.1)),
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('High Contrast Mode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                const Icon(Icons.history_edu, color: AppColors.primary, size: 28),
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

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      onRetry: _retryLoadData,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppGradients.magicalBackground,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Magical App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (widget.wisdomGem.isNotEmpty)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, color: AppColors.gold, size: 20),
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
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      // Adventure Log Button (only if choices exist)
                      if (widget.choicesMade != null && widget.choicesMade!.isNotEmpty) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.history_edu, color: Colors.white),
                            tooltip: 'Adventure Log',
                            onPressed: _showAdventureLog,
                          ),
                        ),
                        const SizedBox(width: 8),
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
                            _isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: _isFavorite ? AppColors.gold : Colors.white,
                          ),
                            tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
                          onPressed: _toggleFavorite,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Settings Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white),
                          tooltip: 'Reading Settings',
                          onPressed: _showReadingOptions,
                        ),
                      ),
                    ],
                  ),
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
                                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                                : Container(
                                    decoration: BoxDecoration(
                                      color: _highContrastMode ? Colors.black : const Color(0xFFFFF8E7), // Magical parchment
                                      borderRadius: const BorderRadius.all(Radius.circular(24)),
                                      border: _highContrastMode ? null : Border.all(
                                        color: AppColors.gold.withValues(alpha: 0.3),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                        if (!_highContrastMode)
                                          BoxShadow(
                                            color: AppColors.gold.withValues(alpha: 0.1),
                                            blurRadius: 0,
                                            spreadRadius: 4, 
                                            offset: const Offset(0, 0),
                                          ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      children: [
                                        // Story Content
                                        Expanded(
                                          child: PageView.builder(
                                            controller: _pageController,
                                            onPageChanged: _handlePageChanged,
                                            itemCount: _storyPages.length,
                                            itemBuilder: (context, index) {
                                              return SingleChildScrollView(
                                                padding: const EdgeInsets.all(32),
                                                child: SelectableText.rich(
                                                  TextSpan(
                                                    style: GoogleFonts.merriweather(
                                                      fontSize: 20 * _textScale,
                                                      height: 1.8,
                                                      color: _highContrastMode ? Colors.white : const Color(0xFF2C3E50),
                                                    ),
                                                    children: _buildStorySpans(_storyPages[index]),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        // Footer controls
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                          decoration: BoxDecoration(
                                            color: _highContrastMode ? Colors.grey[900] : Colors.grey[50],
                                            border: Border(
                                              top: BorderSide(
                                                color: _highContrastMode ? Colors.grey[800]! : Colors.grey[200]!,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              // NEW: Storybook progress indicator instead of "Chapter X of Y"
                                              StorybookProgressIndicator(
                                                currentPage: _currentPageIndex + 1,
                                                totalPages: _storyPages.length,
                                                stageLabel: _adventureSteps.length > _currentPageIndex
                                                    ? _adventureSteps[_currentPageIndex].replaceAll(RegExp(r'^(Step \d+:|🌟|🚪|🎨|😮|🤔|💪|✨|🏠|🎭|🤪|🎉|💭)\s*'), '')
                                                    : null,
                                              ),
                                              const Spacer(),
                                              // Simple Feedback
                                              Row(
                                                children: List.generate(5, (index) {
                                                  return Semantics(
                                                    label: 'Rate ${index + 1} stars',
                                                    button: true,
                                                    child: InkWell(
                                                      onTap: () {
                                                        setState(() => _storyRating = index + 1.0);
                                                        _submitFeedback();
                                                      },
                                                      customBorder: const CircleBorder(),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(12.0),
                                                        child: Icon(
                                                          index < _storyRating ? Icons.star_rounded : Icons.star_outline_rounded,
                                                          color: AppColors.gold,
                                                          size: 28,
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
        floatingActionButton: _isLoading ? null : Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
                FloatingActionButton.extended(
                heroTag: 'read_fab',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoryReaderScreen(
                        storyText: widget.storyText,
                        title: widget.title,
                      ),
                    ),
                  );
                },
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.record_voice_over_rounded),
                label: const Text('Read'),
              ),
              const SizedBox(width: 16),
              FloatingActionButton.extended(
                heroTag: 'color_fab',
                onPressed: _generateColoringPages,
                backgroundColor: AppColors.secondary,
                icon: const Icon(Icons.palette_rounded),
                label: const Text('Color'),
              ),
              const SizedBox(width: 16),
              FloatingActionButton(
                heroTag: 'share_fab',
                onPressed: () => showModalBottomSheet(
                  context: context, 
                  backgroundColor: Colors.transparent,
                  builder: (context) => _buildShareActions(),
                ),
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                child: const Icon(Icons.more_vert_rounded),
                // label: const Text('More'),
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

}

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
              'Number of pages:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _pageCount.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _pageCount.toString(),
                    activeColor: Colors.pink,
                    onChanged: (value) {
                      setState(() {
                        _pageCount = value.toInt();
                      });
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _pageCount.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'More pages take a bit longer to generate.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
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

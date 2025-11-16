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
import 'story_reader_screen.dart';
import 'storage_service.dart';
import 'offline_story_cache.dart';
import 'story_illustration_service.dart';
import 'illustration_settings_dialog.dart';
import 'illustrated_story_viewer.dart';
import 'coloring_book_service.dart';
import 'coloring_book_library_screen.dart';
import 'models.dart';
import 'therapeutic_focus_options.dart';
import 'services/progression_service.dart';
import 'unlock_celebration_dialog.dart';
import 'services/achievement_service.dart';
import 'achievement_celebration_dialog.dart';
import 'config/environment.dart';
import 'services/story_feedback_service.dart';
import 'services/story_analytics.dart';
import 'services/therapeutic_analytics.dart';
import 'theme/app_theme.dart';
import 'widgets/app_button.dart';
import 'widgets/app_card.dart';

class StoryResultScreen extends StatefulWidget {
  final String title;
  final String storyText;
  final String wisdomGem;
  final String? characterName;
  final String? storyId;
  final String? theme;
  final String? characterId;
  final AchievementService? achievementsService;
  final DateTime? storyCreatedAt;
  final bool trackStoryCreation;
  final bool trackAnalytics;

  const StoryResultScreen({
    super.key,
    required this.title,
    required this.storyText,
    required this.wisdomGem,
    this.characterName,
    this.storyId,
    this.theme,
    this.characterId,
    this.achievementsService,
    this.storyCreatedAt,
    this.trackStoryCreation = false,
    this.trackAnalytics = true,
  }) : assert(!trackStoryCreation || achievementsService != null),
        assert(!trackStoryCreation || storyCreatedAt != null);

  @override
  State<StoryResultScreen> createState() => _StoryResultScreenState();
}

class _StoryResultScreenState extends State<StoryResultScreen> {
  final _storage = StorageService();
  final _cache = OfflineStoryCache();
  final _illustrationService =
      GeminiIllustrationService(); // Using Gemini Imagen 3.0 via backend
  final _coloringService =
      GeminiColoringBookService(); // Using Gemini for therapeutic coloring pages
  final _progressionService = ProgressionService(); // Track user progress and unlocks
  final _feedbackService = StoryFeedbackService();
  final TextEditingController _feedbackController = TextEditingController();
  bool _isFavorite = false;
  bool _isLoading = true;
  List<StoryIllustration>? _cachedIllustrations;
  List<ColoringPage>? _cachedColoringPages;
  int? _characterAge;
  String? _activeTherapeuticFocus;
  bool _isGeneratingIllustrations = false;
  bool _isGeneratingColoringPages = false;
  late final PageController _pageController;
  late List<String> _storyPages;
  int _currentPageIndex = 0;
  double _textScale = 1.0;
  bool _highContrastMode = false;
  bool _showWisdomDetails = false;
  bool _screenReaderHints = true;
  bool _isSubmittingFeedback = false;
  double _storyRating = 4.0;
  bool _isStoryHovered = false;

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

  int get _effectiveAge {
    final age = _characterAge;
    if (age == null || age < 3 || age > 100) {
      return 7;
    }
    return age;
  }

  @override
  void initState() {
    super.initState();
    _storyPages = _paginateStory(widget.storyText);
    _pageController = PageController();
    _loadCharacterDetails();
    _loadFavoriteStatus();
    _cacheStoryForOffline();
    _loadCachedIllustrations();
    _loadCachedColoringPages();
    if (widget.trackStoryCreation) {
      _trackStoryCreation(); // Track that user created a story, check for unlocks
    }
    if (widget.trackAnalytics) {
      _trackStoryView();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  /// Track that a story was created and show celebration if features unlocked
  Future<void> _trackStoryCreation() async {
    final achievementService = widget.achievementsService;
    if (achievementService != null) {
      final achievementUnlocks = await achievementService.recordStoryCreated(
        theme: widget.theme ?? 'Adventure',
        timestamp: widget.storyCreatedAt,
      );
      if (mounted && achievementUnlocks.isNotEmpty) {
        await AchievementCelebrationDialog.show(context, achievementUnlocks);
      }
    }

    final newFeatureUnlocks = await _progressionService.incrementStoriesCreated();
    if (mounted && newFeatureUnlocks.isNotEmpty) {
      await UnlockCelebrationDialog.show(context, newFeatureUnlocks);
    }
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

  /// Automatically cache the story for offline access
  Future<void> _cacheStoryForOffline() async {
    final cachedStory = CachedStory(
      id: widget.storyId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: widget.title,
      storyText: widget.storyText,
      characterName: widget.characterName ?? 'Unknown',
      theme: widget.theme ?? 'Adventure',
      companion: null, // You can add companion if available
      cachedAt: DateTime.now(),
      isFavorite: false,
    );

    await _cache.cacheStory(cachedStory);
  }

  /// Load character info so we can adapt prompts for age and focus
  Future<void> _loadCharacterDetails() async {
    if (widget.characterId == null) return;

    try {
      final response = await http
          .get(
        Uri.parse('${Environment.backendUrl}/characters/${widget.characterId}'),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final character = Character.fromJson(data);
        if (!mounted) return;
        setState(() {
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

  /// Generate illustrations for this story
  Future<void> _generateIllustrations() async {
    // Show settings dialog
    final settings = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => IllustrationSettingsDialog(
        initialTherapeuticFocus: _activeTherapeuticFocus,
      ),
    );

    if (settings == null) return;

    final style = settings['style'] as IllustrationStyle;
    final numberOfImages = settings['numberOfImages'] as int;
    final therapeuticFocus = settings['therapeuticFocus'] as String?;

    if (mounted) {
      setState(() {
        _activeTherapeuticFocus = therapeuticFocus;
        _isGeneratingIllustrations = true;
      });
    }

    var progressShown = false;

    try {
      if (!mounted) return;
      IllustrationGenerationDialog.show(context, numberOfImages, 1);
      progressShown = true;

      final illustrations = await _illustrationService.generateIllustrations(
        storyText: widget.storyText,
        storyTitle: widget.title,
        characterName: widget.characterName ?? 'the character',
        theme: widget.theme,
        style: style,
        numberOfImages: numberOfImages,
        age: _effectiveAge,
        therapeuticFocus: therapeuticFocus,
      );

      // Cache illustrations
      if (widget.storyId != null) {
        await _illustrationService.cacheIllustrations(
          storyId: widget.storyId!,
          illustrations: illustrations,
        );
      }

      if (!mounted) return;
      setState(() {
        _cachedIllustrations = illustrations;
      });

      _trackResultAction(
        'illustrations_generated',
        extra: {
          'count': illustrations.length,
          if (therapeuticFocus != null && therapeuticFocus.isNotEmpty)
            'therapeutic_focus': therapeuticFocus,
        },
      );

      // Show illustrated story
      _viewIllustratedStory(illustrations);
    } on TimeoutException {
      if (mounted) {
        _showSnackBar(
          'Illustration request timed out. Please try again or choose fewer scenes.',
          backgroundColor: Colors.orange,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Failed to generate illustrations: $e',
        );
      }
    } finally {
      if (progressShown && mounted) {
        IllustrationGenerationDialog.hide(context);
      }
      if (mounted) {
        setState(() {
          _isGeneratingIllustrations = false;
        });
      }
    }
  }

  /// View story with illustrations
  void _viewIllustratedStory(List<StoryIllustration> illustrations) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IllustratedStoryViewer(
          title: widget.title,
          storyText: widget.storyText,
          illustrations: illustrations,
          characterName: widget.characterName,
        ),
      ),
    );
    _trackResultAction(
      'illustrations_viewed',
      extra: {'count': illustrations.length},
    );
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
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
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

  int get _totalWords =>
      widget.storyText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  int get _estimatedMinutes => max(1, (_totalWords / 150).ceil());

  double get _pageProgress =>
      _storyPages.isEmpty ? 0 : (_currentPageIndex + 1) / _storyPages.length;

  Color get _storyTextColor =>
      _highContrastMode ? Colors.white : Colors.black87;

  Color get _storyBackgroundColor =>
      _highContrastMode ? Colors.black : Colors.white;

  Widget _buildReadingProgressHeader() {
    return Semantics(
      label:
          'Reading progress ${(100 * _pageProgress).toStringAsFixed(0)} percent, about $_estimatedMinutes minute read',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: _pageProgress,
                  backgroundColor: Colors.grey.shade200,
                  color: Colors.deepPurple,
                  minHeight: 10,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(_pageProgress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Page ${_currentPageIndex + 1} of ${_storyPages.length} · ≈ $_estimatedMinutes min read',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilityPanel() {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reading comfort',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Text('Text size'),
              Expanded(
                child: Slider(
                  value: _textScale,
                  min: 0.9,
                  max: 1.6,
                  divisions: 7,
                  label: _textScale.toStringAsFixed(1),
                  onChanged: (value) => setState(() => _textScale = value),
                ),
              ),
            ],
          ),
          SwitchListTile.adaptive(
            title: const Text('High contrast mode'),
            dense: true,
            value: _highContrastMode,
            onChanged: (value) => setState(() => _highContrastMode = value),
          ),
          SwitchListTile.adaptive(
            title: const Text('Screen reader hints'),
            dense: true,
            value: _screenReaderHints,
            onChanged: (value) => setState(() => _screenReaderHints = value),
          ),
        ],
      ),
    );
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

  Widget _buildStoryPager(double maxHeight) {
    final pageHeight = max(320.0, min(maxHeight * 0.55, 520.0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReadingProgressHeader(),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            color: _storyBackgroundColor,
            child: SizedBox(
              height: pageHeight,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _storyPages.length,
                onPageChanged: (index) {
                  setState(() => _currentPageIndex = index);
                },
                itemBuilder: (context, index) {
                  final page = _storyPages[index];
                  return Semantics(
                    label: _screenReaderHints
                        ? 'Story page ${index + 1}'
                        : null,
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _isStoryHovered = true),
                      onExit: (_) => setState(() => _isStoryHovered = false),
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _isStoryHovered
                              ? (_highContrastMode
                                  ? Colors.grey.shade900
                                  : Colors.deepPurple.shade50)
                              : Colors.transparent,
                          border: Border(
                            left: BorderSide(
                              color: Colors.deepPurple.shade100,
                              width: 4,
                            ),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText.rich(
                            TextSpan(
                              style: TextStyle(
                                fontSize: 18 * _textScale,
                                height: 1.5,
                                color: _storyTextColor,
                              ),
                              children: _buildStorySpans(page),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Swipe horizontally or use arrow keys to turn the page.',
          style: TextStyle(
            fontSize: 12,
            color: _highContrastMode ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  bool get _shouldShowMetaCard {
    final hasName =
        widget.characterName != null && widget.characterName!.trim().isNotEmpty;
    final hasFocus =
        _activeTherapeuticFocus != null && _activeTherapeuticFocus!.isNotEmpty;
    return hasName || widget.characterId != null || hasFocus;
  }

  Widget _buildStoryMetaCard() {
    final heroName = (widget.characterName != null &&
            widget.characterName!.trim().isNotEmpty)
        ? widget.characterName!.trim()
        : 'Your hero';
    final focusText = _activeTherapeuticFocus?.trim() ?? '';
    final hasFocus = focusText.isNotEmpty;
    final usingDefaultAge =
        _characterAge == null || _characterAge! < 3 || _characterAge! > 100;

    final chips = <Widget>[
      Chip(
        avatar:
            const Icon(Icons.cake_outlined, size: 18, color: Colors.deepPurple),
        label: Text(
          'Age ${_effectiveAge}${usingDefaultAge ? ' (default)' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.deepPurple.shade50,
      ),
    ];

    if (hasFocus) {
      chips.add(
        Chip(
          avatar:
              const Icon(Icons.self_improvement, size: 18, color: Colors.teal),
          label: Text(
            focusText,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.teal.shade50,
        ),
      );
    }

    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Story for $heroName',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: chips,
          ),
          if (hasFocus) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'We\'ll gently highlight themes about ${focusText.toLowerCase()}.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
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
        _isGeneratingColoringPages = true;
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
      if (mounted) {
        _showSnackBar('Failed to generate coloring pages: $e');
      }
    } finally {
      if (progressShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        setState(() {
          _isGeneratingColoringPages = false;
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
        _showSnackBar('Could not save feedback: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingFeedback = false);
      }
    }
  }

  Widget _buildFeedbackCard() {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How helpful was this story?',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _storyRating,
                  min: 1,
                  max: 5,
                  divisions: 8,
                  label: _storyRating.toStringAsFixed(1),
                  onChanged: (value) => setState(() => _storyRating = value),
                ),
              ),
              Text('${_storyRating.toStringAsFixed(1)}/5'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _feedbackController,
            maxLength: 240,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Share anything the story helped with',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 220,
              child: AppButton.primary(
                label: _isSubmittingFeedback ? 'Sending...' : 'Send feedback',
                icon: _isSubmittingFeedback
                    ? Icons.hourglass_bottom
                    : Icons.send,
                onPressed: _isSubmittingFeedback ? null : _submitFeedback,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWisdomGemCard() {
    final theme = Theme.of(context);
    final isExpanded = _showWisdomDetails;
    final cardColor = isExpanded ? AppColors.primary : Colors.white;
    final textColor = isExpanded ? Colors.white : AppColors.primary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _showWisdomDetails = !isExpanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: AppCard(
            color: cardColor,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Text(
                  'Wisdom Gem',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: textColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.wisdomGem,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: textColor,
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Tap to hide. Share this gem to reinforce the lesson.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadFavoriteStatus() async {
    if (widget.storyId != null) {
      final story = await _storage.findStoryById(widget.storyId!);
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

    await _storage.toggleFavorite(widget.storyId!);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Story Summary'),
        actions: [
          if (widget.storyId != null && !_isLoading)
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
              ),
              tooltip:
                  _isFavorite ? 'Remove from favorites' : 'Add to favorites',
              onPressed: _toggleFavorite,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_shouldShowMetaCard) _buildStoryMetaCard(),
              if (_shouldShowMetaCard) const SizedBox(height: AppSpacing.sm),
              if (!_shouldShowMetaCard) const SizedBox(height: AppSpacing.sm),

              LayoutBuilder(
              builder: (context, constraints) =>
                  _buildStoryPager(MediaQuery.of(context).size.height),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildAccessibilityPanel(),
            const SizedBox(height: AppSpacing.lg),

            // Make the Wisdom Gem stand out
            if (widget.wisdomGem.isNotEmpty)
              Center(child: _buildWisdomGemCard()),
            if (widget.wisdomGem.isNotEmpty)
              const SizedBox(height: AppSpacing.lg),

            _buildShareActions(),
            const SizedBox(height: AppSpacing.lg),

            _buildFeedbackCard(),
            const SizedBox(height: AppSpacing.lg),

            // Favorite button if story is saved
            if (widget.storyId != null && !_isLoading)
              Center(
                child: SizedBox(
                  width: 280,
                  child: AppButton.secondary(
                    label: _isFavorite
                        ? 'Remove from favorites'
                        : 'Add to favorites',
                    icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                    onPressed: _toggleFavorite,
                  ),
                ),
              ),
            if (widget.storyId != null && !_isLoading)
              const SizedBox(height: AppSpacing.md),

            // READ TO ME BUTTON
            Center(
              child: SizedBox(
                width: 360,
                child: AppButton.primary(
                  label: 'Read to Me',
                  icon: Icons.volume_up,
                  onPressed: () {
                    _trackResultAction('read_to_me');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StoryReaderScreen(
                          title: widget.title,
                          storyText: widget.storyText,
                          characterName: widget.characterName,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ILLUSTRATION BUTTON
            Center(
              child: ElevatedButton.icon(
                onPressed: _isGeneratingIllustrations
                    ? null
                    : (_cachedIllustrations != null
                        ? () => _viewIllustratedStory(_cachedIllustrations!)
                        : _generateIllustrations),
                icon: Icon(
                  _isGeneratingIllustrations
                      ? Icons.hourglass_top
                      : _cachedIllustrations != null
                          ? Icons.auto_stories
                          : Icons.image,
                  size: 28,
                ),
                label: Text(
                  _isGeneratingIllustrations
                      ? 'Generating illustrations...'
                      : _cachedIllustrations != null
                          ? 'View Illustrated Story'
                          : 'Add Illustrations',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // COLORING BOOK BUTTON
            Center(
              child: ElevatedButton.icon(
                onPressed: _isGeneratingColoringPages
                    ? null
                    : (_cachedColoringPages != null
                        ? _openColoringBook
                        : _generateColoringPages),
                icon: Icon(
                  _isGeneratingColoringPages
                      ? Icons.hourglass_top
                      : _cachedColoringPages != null
                          ? Icons.palette
                          : Icons.color_lens,
                  size: 28,
                ),
                label: Text(
                  _isGeneratingColoringPages
                      ? 'Creating coloring pages...'
                      : _cachedColoringPages != null
                          ? 'View Coloring Pages (${_cachedColoringPages!.length})'
                          : 'Create Coloring Pages',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
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

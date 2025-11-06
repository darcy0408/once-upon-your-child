// lib/story_result_screen.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  bool _isFavorite = false;
  bool _isLoading = true;
  List<StoryIllustration>? _cachedIllustrations;
  List<ColoringPage>? _cachedColoringPages;
  int? _characterAge;
  String? _activeTherapeuticFocus;
  bool _isGeneratingIllustrations = false;
  bool _isGeneratingColoringPages = false;

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
    _loadCharacterDetails();
    _loadFavoriteStatus();
    _cacheStoryForOffline();
    _loadCachedIllustrations();
    _loadCachedColoringPages();
    if (widget.trackStoryCreation) {
      _trackStoryCreation(); // Track that user created a story, check for unlocks
    }
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
            Uri.parse('http://127.0.0.1:5000/characters/${widget.characterId}'),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Story for $heroName',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips,
          ),
          if (hasFocus) ...[
            const SizedBox(height: 8),
            Text(
            'We\'ll gently emphasize themes about ${focusText.toLowerCase()}.',
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.black87,
              ),
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.deepPurple),
        actions: [
          if (widget.storyId != null && !_isLoading)
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : Colors.deepPurple,
              ),
              tooltip:
                  _isFavorite ? 'Remove from favorites' : 'Add to favorites',
              onPressed: _toggleFavorite,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display the title prominently
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 12),
            if (_shouldShowMetaCard) _buildStoryMetaCard(),
            if (_shouldShowMetaCard) const SizedBox(height: 12),
            if (!_shouldShowMetaCard) const SizedBox(height: 12),

            // Use a larger, more readable font for the story
            Text(
              widget.storyText,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 18,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 32),

            // Make the Wisdom Gem stand out
            if (widget.wisdomGem.isNotEmpty)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Wisdom Gem: ${widget.wisdomGem}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Colors.deepPurple,
                        ),
                  ),
                ),
              ),
            if (widget.wisdomGem.isNotEmpty) const SizedBox(height: 24),

            // Favorite button if story is saved
            if (widget.storyId != null && !_isLoading)
              Center(
                child: OutlinedButton.icon(
                  onPressed: _toggleFavorite,
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : Colors.deepPurple,
                  ),
                  label: Text(
                    _isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                    style: TextStyle(
                      fontSize: 16,
                      color: _isFavorite ? Colors.red : Colors.deepPurple,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _isFavorite ? Colors.red : Colors.deepPurple,
                      width: 2,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            if (widget.storyId != null && !_isLoading)
              const SizedBox(height: 16),

            // READ TO ME BUTTON
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
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
                icon: const Icon(Icons.volume_up, size: 28),
                label: const Text(
                  'Read to Me!',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

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
                  backgroundColor: _cachedIllustrations != null
                      ? Colors.purple
                      : Colors.orange,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

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
                  backgroundColor:
                      _cachedColoringPages != null ? Colors.teal : Colors.pink,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
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
              value: _selectedTherapeuticFocus,
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

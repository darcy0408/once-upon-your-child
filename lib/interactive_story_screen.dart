// lib/interactive_story_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models.dart';
import 'storage_service.dart';
import 'adventure_progress_service.dart';
import 'celebration_dialog.dart';
import 'therapeutic_models.dart';

class InteractiveStoryScreen extends StatefulWidget {
  final String title;
  final String characterName;
  final String theme;
  final String companion;
  final List<Character> additionalCharacters;
  final String? characterId;
  final TherapeuticStoryCustomization? therapeuticCustomization;

  const InteractiveStoryScreen({
    super.key,
    required this.title,
    required this.characterName,
    required this.theme,
    required this.companion,
    this.additionalCharacters = const [],
    this.characterId,
    this.therapeuticCustomization,
  });

  @override
  State<InteractiveStoryScreen> createState() => _InteractiveStoryScreenState();
}

class _InteractiveStoryScreenState extends State<InteractiveStoryScreen> {
  final List<String> _storyHistory = [];
  final List<String> _choiceHistory = [];
  final _storage = StorageService();
  final _progressService = AdventureProgressService();
  StorySegment? _currentSegment;
  bool _isLoading = true;
  bool _isLoadingChoice = false;
  String? _savedStoryId;
  bool _hasRecordedProgress = false;

  @override
  void initState() {
    super.initState();
    _loadInitialStory();
  }

  Future<void> _loadInitialStory() async {
    setState(() => _isLoading = true);

    final List<String> friendNames = widget.additionalCharacters.map((c) => c.name).toList();

    try {
      final Map<String, dynamic> requestBody = {
        'character': widget.characterName,
        'theme': widget.theme,
        'companion': widget.companion,
        'friends': friendNames,
      };

      if (widget.therapeuticCustomization != null) {
        requestBody['therapeutic_prompt'] = widget.therapeuticCustomization!.toPromptAddition();
      }

      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/generate-interactive-story'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _currentSegment = StorySegment.fromJson(data);
          _storyHistory.add(_currentSegment!.text);
          _isLoading = false;
        });
      } else {
        _showError('Failed to load story');
      }
    } catch (e) {
      _showError('Network error: Could not connect to server');
    }
  }

  Future<void> _makeChoice(StoryChoice choice) async {
    setState(() => _isLoadingChoice = true);
    _choiceHistory.add(choice.text);

    final List<String> friendNames = widget.additionalCharacters.map((c) => c.name).toList();

    try {
      final Map<String, dynamic> requestBody = {
        'character': widget.characterName,
        'theme': widget.theme,
        'companion': widget.companion,
        'friends': friendNames,
        'choice': choice.text,
        'story_so_far': _storyHistory.join('\n\n'),
        'choices_made': _choiceHistory,
      };

      if (widget.therapeuticCustomization != null) {
        requestBody['therapeutic_prompt'] = widget.therapeuticCustomization!.toPromptAddition();
      }

      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/continue-interactive-story'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _currentSegment = StorySegment.fromJson(data);
          _storyHistory.add(_currentSegment!.text);
          _isLoadingChoice = false;
        });

        // Save story when it ends
        if (_currentSegment!.isEnding) {
          await _saveCompletedStory();
        }
      } else {
        _showError('Failed to continue story');
        setState(() => _isLoadingChoice = false);
      }
    } catch (e) {
      _showError('Network error');
      setState(() => _isLoadingChoice = false);
    }
  }

  Future<void> _saveCompletedStory() async {
    final fullStoryText = _storyHistory.join('\n\n');
    final friendNames = widget.additionalCharacters.map((c) => c.name).join(', ');
    final storyTitle = friendNames.isEmpty
        ? '${widget.characterName}\'s ${widget.theme} Adventure'
        : '${widget.characterName} & $friendNames\'s ${widget.theme} Adventure';

    final story = SavedStory(
      title: storyTitle,
      storyText: fullStoryText,
      theme: widget.theme,
      characters: [
        // We don't have full character objects, but we can create minimal ones
        // or you could pass the full characters from the main screen
        ...widget.additionalCharacters,
      ],
      createdAt: DateTime.now(),
      isInteractive: true,
      wisdomGem: 'Every choice shapes your adventure!',
    );

    await _storage.saveStory(story);
    setState(() => _savedStoryId = story.id);

    // Record adventure progress
    await _recordAdventureProgress(story.id);
  }

  /// Record progress and show celebration if rewards earned
  Future<void> _recordAdventureProgress(String storyId) async {
    if (_hasRecordedProgress) return;
    _hasRecordedProgress = true;

    // Map theme to location ID
    final locationId = _getLocationIdFromTheme(widget.theme);
    if (locationId == null) return;

    try {
      final result = await _progressService.completeStoryAtLocation(
        locationId: locationId,
        storyId: storyId,
        characterId: widget.characterId,
      );

      // Show celebration if something was achieved
      if (result.shouldCelebrate && mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          await CelebrationDialog.show(context, result);
        }
      }
    } catch (e) {
      debugPrint('Failed to record adventure progress: $e');
    }
  }

  /// Map theme to location ID
  String? _getLocationIdFromTheme(String theme) {
    final themeMap = {
      'Magic': 'enchanted_forest',
      'Adventure': 'crystal_caves',
      'Castles': 'floating_castle',
      'Dragons': 'dragon_peak',
      'Ocean': 'underwater_kingdom',
      'Space': 'star_realm',
    };
    return themeMap[theme];
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() {
        _isLoading = false;
        _isLoadingChoice = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.deepPurple,
        actions: [
          if (widget.additionalCharacters.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.people),
              tooltip: 'Characters in this story',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Characters in Story'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Main Character: ${widget.characterName}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Friends/Siblings:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                        ...widget.additionalCharacters.map((c) =>
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                            child: Text('• ${c.name}'),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Story content
                  ..._buildStoryContent(),

                  const SizedBox(height: 24),

                  // Current segment
                  if (_currentSegment != null) ...[
                    Card(
                      elevation: 2,
                      color: Colors.purple.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _currentSegment!.text,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Choices or ending
                    if (_currentSegment!.isEnding)
                      _buildEnding()
                    else if (_currentSegment!.choices != null && _currentSegment!.choices!.isNotEmpty)
                      _buildChoices()
                    else if (_isLoadingChoice)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
    );
  }

  List<Widget> _buildStoryContent() {
    if (_storyHistory.length <= 1) return [];

    return [
      const Text(
        'Story so far:',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
      const SizedBox(height: 12),
      ..._storyHistory.sublist(0, _storyHistory.length - 1).map((segment) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            segment,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ),
      ),
      const Divider(height: 32, thickness: 2),
    ];
  }

  Widget _buildChoices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'What will you do?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ..._currentSegment!.choices!.map((choice) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: ElevatedButton(
            onPressed: _isLoadingChoice ? null : () => _makeChoice(choice),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple.shade100,
              foregroundColor: Colors.deepPurple.shade900,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.deepPurple.shade300, width: 2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  choice.text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (choice.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    choice.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildEnding() {
    return Column(
      children: [
        const Icon(
          Icons.stars,
          size: 64,
          color: Colors.amber,
        ),
        const SizedBox(height: 16),
        const Text(
          'The End',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 16),
        if (_savedStoryId != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Story saved to My Stories!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.home),
          label: const Text('Back to Home'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ],
    );
  }
}

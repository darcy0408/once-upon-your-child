import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'storage_service.dart';
import 'services/interactive_story_service.dart';
import 'subscription_service.dart';

class InteractiveStoryScreen extends StatefulWidget {
  const InteractiveStoryScreen({
    super.key,
    required this.character,
    required this.theme,
    this.companion,
  });

  final Character character;
  final String theme;
  final String? companion;

  @override
  State<InteractiveStoryScreen> createState() => _InteractiveStoryScreenState();
}

class _InteractiveStoryScreenState extends State<InteractiveStoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final InteractiveStoryService _storyService = const InteractiveStoryService();
  final StorageService _storageService = StorageService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  final List<StorySegment> _segments = [];
  final List<String> _choiceIds = [];
  final List<StoryChoice> _choiceHistory = [];

  bool _isLoading = true;
  bool _isContinuing = false;
  bool _isSaving = false;
  bool _storySaved = false;

  String? _errorMessage;
  Future<void> Function()? _retryAction;
  StoryChoice? _pendingChoice;

  @override
  void initState() {
    super.initState();
    _loadOpeningSegment();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _storyEnded =>
      _segments.isNotEmpty &&
      (_segments.last.isEnding ||
          _segments.last.choices == null ||
          _segments.last.choices!.isEmpty);

  String get _fullStoryText =>
      _segments.map((segment) => segment.text.trim()).join('\n\n');

  Future<void> _loadOpeningSegment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _retryAction = null;
    });

    try {
      final segment = await _storyService.fetchOpeningSegment(
        character: widget.character,
        theme: widget.theme,
        companion: widget.companion,
      );

      if (!mounted) return;
      setState(() {
        _segments
          ..clear()
          ..add(segment);
        _isLoading = false;
      });
      _scrollToBottom();
    } on InteractiveStoryException catch (e) {
      _handleError(e.message, _loadOpeningSegment);
    } on TimeoutException {
      _handleError(
        'This is taking longer than usual. Please try again.',
        _loadOpeningSegment,
      );
    } catch (_) {
      _handleError(
        'We could not reach the story server. Please check the backend.',
        _loadOpeningSegment,
      );
    }
  }

  void _handleError(String message, Future<void> Function() retry) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isContinuing = false;
      _errorMessage = message;
      _retryAction = retry;
    });
  }

  Future<void> _handleChoiceSelected(StoryChoice choice) async {
    if (_isContinuing || _storyEnded) return;

    HapticFeedback.selectionClick();
    setState(() {
      _isContinuing = true;
      _errorMessage = null;
      _retryAction = null;
      _pendingChoice = choice;
    });

    try {
      final nextSegment = await _storyService.continueStory(
        character: widget.character,
        theme: widget.theme,
        companion: widget.companion,
        choice: choice,
        previousSegments: List<StorySegment>.from(_segments),
        choiceIds: List<String>.from(_choiceIds),
      );

      if (!mounted) return;
      setState(() {
        _choiceIds.add(choice.id);
        _choiceHistory.add(choice);
        _segments.add(nextSegment);
        _isContinuing = false;
        _pendingChoice = null;
      });
      _scrollToBottom();
    } on InteractiveStoryException catch (e) {
      _handleError(e.message, () => _retryPendingChoice());
    } on TimeoutException {
      _handleError(
        'This is taking longer than usual. Want to try again?',
        () => _retryPendingChoice(),
      );
    } catch (_) {
      _handleError(
        'Something went wrong continuing the story.',
        () => _retryPendingChoice(),
      );
    }
  }

  Future<void> _retryPendingChoice() async {
    final choice = _pendingChoice;
    if (choice == null) {
      return _loadOpeningSegment();
    }
    await _handleChoiceSelected(choice);
  }

  Future<void> _saveStory() async {
    if (_isSaving || !_storyEnded) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final title =
          '${widget.character.name}\'s ${widget.theme} Interactive Adventure';
      final savedStory = SavedStory(
        title: title,
        storyText: _fullStoryText,
        theme: widget.theme,
        characters: [widget.character],
        createdAt: DateTime.now(),
        isInteractive: true,
      );

      await _storageService.saveStory(savedStory);
      await _subscriptionService.recordStoryCreation();

      if (!mounted) return;
      setState(() {
        _storySaved = true;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story saved to your library!')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the story. Please try again.'),
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  int get _currentChoiceNumber => _choiceIds.length + 1;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_storySaved);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.character.name}\'s Adventure'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_storySaved),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurple.shade50,
                Colors.deepPurple.shade100,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _buildHeaderCard(),
              if (_choiceHistory.isNotEmpty) _buildChoiceHistoryChips(),
              if (_errorMessage != null) _buildErrorBanner(),
              Expanded(child: _buildStoryList()),
              if (_isContinuing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ),
              if (_storyEnded) _buildEndingCard(),
              if (_storyEnded) _buildSaveButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.deepPurple.shade200,
              child: Text(
                widget.character.name.isNotEmpty
                    ? widget.character.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.character.name} • ${widget.theme}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _storyEnded
                        ? 'Adventure complete!'
                        : 'Choice $_currentChoiceNumber of 4',
                    style: TextStyle(
                      color: _storyEnded
                          ? Colors.teal.shade700
                          : Colors.deepPurple.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceHistoryChips() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(_choiceHistory.length, (index) {
          final choice = _choiceHistory[index];
          return Chip(
            backgroundColor: Colors.deepPurple.shade100,
            label: Text('${index + 1}. ${choice.text}'),
          );
        }),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Colors.red.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _retryAction,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoryList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _segments.length,
      itemBuilder: (context, index) {
        final segment = _segments[index];
        final bool isLatest = index == _segments.length - 1;
        final bool showChoices =
            isLatest && !_storyEnded && (segment.choices?.isNotEmpty ?? false);

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: 1,
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    segment.text,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  if (showChoices) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    ...segment.choices!.map(_buildChoiceButton),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChoiceButton(StoryChoice choice) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: _isContinuing ? null : () => _handleChoiceSelected(choice),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          backgroundColor: Colors.deepPurple.shade400,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
                  color: Colors.deepPurple.shade50,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEndingCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  12,
                  (index) => Icon(
                    Icons.celebration,
                    color: Colors
                        .primaries[index % Colors.primaries.length].shade300,
                    size: 20 + ((index % 3) * 4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'The End',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'What an adventure! Tap save so you can read it again anytime.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: ElevatedButton.icon(
        onPressed: _storySaved || _isSaving ? null : _saveStory,
        icon: _isSaving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.bookmark_added_outlined),
        label: Text(_storySaved ? 'Story Saved!' : 'Save Story'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

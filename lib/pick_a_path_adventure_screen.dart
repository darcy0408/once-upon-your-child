import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'storage_service.dart';
import 'services/interactive_story_analytics.dart';
import 'services/interactive_story_service.dart';
import 'subscription_service.dart';
import 'widgets/app_card.dart';
import 'widgets/error_message.dart';

/// Pick-A-Path Adventures: Interactive stories with inventory, state tracking, and age-calibrated content
class PickAPathAdventureScreen extends StatefulWidget {
  const PickAPathAdventureScreen({
    super.key,
    required this.userId,
    required this.character,
    required this.theme,
    this.tone = 'whimsical',
    this.length = 'medium',
    this.interests,
    this.mustInclude,
    this.avoid,
    this.existingStoryId, // For resuming stories
  });

  final String userId;
  final Character character;
  final String theme;
  final String tone;
  final String length;
  final List<String>? interests;
  final List<String>? mustInclude;
  final List<String>? avoid;
  final String? existingStoryId;

  @override
  State<PickAPathAdventureScreen> createState() =>
      _PickAPathAdventureScreenState();
}

class _PickAPathAdventureScreenState
    extends State<PickAPathAdventureScreen> {
  final ScrollController _scrollController = ScrollController();
  final InteractiveStoryService _storyService =
      const InteractiveStoryService();
  final StorageService _storageService = StorageService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  String? _storyId;
  String? _storyTitle;
  StorySegmentData? _currentSegment;
  List<InventoryItemData> _inventory = [];
  StoryStateData? _state;
  bool _isCompleted = false;

  bool _isLoading = true;
  bool _isContinuing = false;
  bool _isSaving = false;
  bool _storySaved = false;
  bool _inventoryExpanded = false;
  bool _stateExpanded = false;

  String? _errorMessage;
  Future<void> Function()? _retryAction;

  @override
  void initState() {
    super.initState();
    if (widget.existingStoryId != null) {
      _resumeStory();
    } else {
      _startNewStory();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int get _targetSegmentCount {
    switch (widget.length) {
      case 'short':
        return 3;
      case 'long':
        return 10;
      default:
        return 6;
    }
  }

  String get _progressText {
    if (_currentSegment == null) return '';
    final current = _currentSegment!.segmentNumber;
    if (_isCompleted) {
      return 'Adventure complete!';
    }
    return 'Segment $current of $_targetSegmentCount';
  }

  Future<void> _startNewStory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _retryAction = null;
    });

    try {
      final response = await _storyService.startInteractiveStory(
        userId: widget.userId,
        characterId: widget.character.id,
        theme: widget.theme,
        tone: widget.tone,
        length: widget.length,
        age: widget.character.age,
        interests: widget.interests,
        mustInclude: widget.mustInclude,
        avoid: widget.avoid,
      );

      if (!mounted) return;
      setState(() {
        _storyId = response.storyId;
        _storyTitle = response.title;
        _currentSegment = response.segment;
        _inventory = response.inventory;
        _state = response.state;
        _isCompleted = response.isCompleted;
        _isLoading = false;
      });

      unawaited(
        InteractiveStoryAnalytics.trackStoryStarted(
          characterId: widget.character.id,
          characterName: widget.character.name,
          characterAge: widget.character.age,
          theme: widget.theme,
          hasCompanion: _state?.companionStatus.isNotEmpty ?? false,
        ),
      );

      _scrollToBottom();
    } on InteractiveStoryException catch (e) {
      _handleError(e.message, _startNewStory);
    } on TimeoutException {
      _handleError(
        'This is taking longer than usual. Please try again.',
        _startNewStory,
      );
    } catch (e) {
      _handleError(
        'We could not reach the story server. Error: $e',
        _startNewStory,
      );
    }
  }

  Future<void> _resumeStory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _retryAction = null;
    });

    try {
      final response =
          await _storyService.resumeStory(widget.existingStoryId!);

      if (!mounted) return;
      setState(() {
        _storyId = response.storyId;
        _currentSegment = response.segment;
        _inventory = response.inventory;
        _state = response.state;
        _isCompleted = response.isCompleted;
        _isLoading = false;
      });

      _scrollToBottom();
    } on InteractiveStoryException catch (e) {
      _handleError(e.message, _resumeStory);
    } catch (e) {
      _handleError('Unable to resume story: $e', _resumeStory);
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

  Future<void> _handleChoiceSelected(StoryChoiceData choice) async {
    if (_isContinuing || _isCompleted || _storyId == null) return;

    HapticFeedback.selectionClick();
    setState(() {
      _isContinuing = true;
      _errorMessage = null;
      _retryAction = null;
    });

    try {
      final response = await _storyService.continueInteractiveStory(
        storyId: _storyId!,
        choiceId: choice.id,
      );

      if (!mounted) return;
      setState(() {
        _currentSegment = response.segment;
        _inventory = response.inventory;
        _state = response.state;
        _isCompleted = response.isCompleted;
        _isContinuing = false;
      });

      _scrollToBottom();

      if (_isCompleted) {
        unawaited(
          InteractiveStoryAnalytics.trackStoryCompleted(
            characterId: widget.character.id,
            theme: widget.theme,
            segmentCount: _currentSegment?.segmentNumber ?? 0,
          ),
        );
      }
    } on InteractiveStoryException catch (e) {
      _handleError(e.message, () => _handleChoiceSelected(choice));
    } catch (e) {
      _handleError('Unable to continue story: $e',
          () => _handleChoiceSelected(choice));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _saveStory() async {
    if (_storyId == null || _currentSegment == null) return;

    setState(() => _isSaving = true);

    try {
      // Get full story from API
      final fullStory = await _storyService.getStory(_storyId!);

      // Build complete story text from all segments
      final completeText =
          fullStory.segments?.map((s) => s.content).join('\n\n') ??
              _currentSegment!.content;

      final savedStory = SavedStory(
        id: _storyId!,
        title: _storyTitle ?? fullStory.title,
        storyText: completeText,
        theme: widget.theme,
        characters: [widget.character],
        createdAt: fullStory.createdAt,
        isInteractive: true,
        isFavorite: false,
      );

      await _storageService.saveStory(savedStory);
      await _subscriptionService.recordUsage(widget.userId, 'story');

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _storySaved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Story saved to your library!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save story: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_storyTitle ?? 'Pick-A-Path Adventure'),
        actions: [
          if (!_isLoading && _currentSegment != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  _progressText,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Weaving your adventure...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: ErrorMessage(
                    message: _errorMessage!,
                    onRetry: _retryAction,
                  ),
                )
              : _buildStoryContent(),
    );
  }

  Widget _buildStoryContent() {
    if (_currentSegment == null) {
      return const Center(child: Text('No story segment available'));
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Current segment
          _buildSegmentCard(),
          const SizedBox(height: 16),

          // Inventory section
          if (_inventory.isNotEmpty) ...[
            _buildInventorySection(),
            const SizedBox(height: 16),
          ],

          // Story state section
          if (_state != null) ...[
            _buildStoryStateSection(),
            const SizedBox(height: 16),
          ],

          // Choices or completion
          if (_isCompleted)
            _buildCompletionSection()
          else if (_currentSegment!.choices.isNotEmpty)
            _buildChoicesSection(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSegmentCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration
          if (_currentSegment!.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _currentSegment!.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.image_not_supported),
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Story content
          Text(
            _currentSegment!.content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventorySection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _inventoryExpanded = !_inventoryExpanded),
            child: Row(
              children: [
                const Icon(Icons.backpack, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Inventory (${_inventory.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Icon(
                  _inventoryExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                ),
              ],
            ),
          ),
          if (_inventoryExpanded) ...[
            const SizedBox(height: 12),
            ..._inventory.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildStoryStateSection() {
    if (_state == null) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _stateExpanded = !_stateExpanded),
            child: Row(
              children: [
                const Icon(Icons.map, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Adventure Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Icon(
                  _stateExpanded ? Icons.expand_less : Icons.expand_more,
                ),
              ],
            ),
          ),
          if (_stateExpanded) ...[
            const SizedBox(height: 12),
            if (_state!.currentLocation.isNotEmpty) ...[
              _buildStateItem('Location', _state!.currentLocation),
              const SizedBox(height: 8),
            ],
            if (_state!.currentGoal.isNotEmpty) ...[
              _buildStateItem('Goal', _state!.currentGoal),
              const SizedBox(height: 8),
            ],
            if (_state!.keyClues.isNotEmpty) ...[
              _buildStateItem('Clues', _state!.keyClues.join(', ')),
              const SizedBox(height: 8),
            ],
            if (_state!.companionStatus.isNotEmpty) ...[
              _buildStateItem('Companion', _state!.companionStatus),
              const SizedBox(height: 8),
            ],
            if (_state!.timePressure != null) ...[
              _buildStateItem('Urgency', _state!.timePressure!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStateItem(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildChoicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'What do you do next?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ..._currentSegment!.choices.asMap().entries.map((entry) {
          final choice = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: AppButton(
              onPressed: _isContinuing
                  ? null
                  : () => _handleChoiceSelected(choice),
              child: Text(
                choice.text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCompletionSection() {
    return Column(
      children: [
        const Icon(
          Icons.auto_awesome,
          size: 64,
          color: Colors.amber,
        ),
        const SizedBox(height: 16),
        const Text(
          'Adventure Complete!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (!_storySaved)
          AppButton(
            onPressed: _isSaving ? null : _saveStory,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save to Library'),
          ),
        if (_storySaved)
          const Text(
            '✓ Saved to your library!',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }
}

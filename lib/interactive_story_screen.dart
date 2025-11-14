import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'storage_service.dart';
import 'services/interactive_story_analytics.dart';
import 'services/interactive_story_service.dart';
import 'subscription_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_button.dart';
import 'widgets/app_card.dart';
import 'widgets/error_message.dart';
import 'widgets/loading_spinner.dart';

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

  int get _wordCount =>
      _fullStoryText.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;

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
      unawaited(
        InteractiveStoryAnalytics.trackStoryStarted(
          characterId: widget.character.id,
          characterName: widget.character.name,
          characterAge: widget.character.age,
          theme: widget.theme,
          hasCompanion: widget.companion?.isNotEmpty ?? false,
        ),
      );
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

    final nextChoiceNumber = _choiceIds.length + 1;
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
      unawaited(
        InteractiveStoryAnalytics.trackChoiceSelected(
          characterId: widget.character.id,
          theme: widget.theme,
          choiceId: choice.id,
          choiceNumber: nextChoiceNumber,
          choiceTextLength: choice.text.length,
        ),
      );
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
      unawaited(
        InteractiveStoryAnalytics.trackStorySaved(
          characterId: widget.character.id,
          theme: widget.theme,
          choiceCount: _choiceIds.length,
          segmentCount: _segments.length,
          wordCount: _wordCount,
        ),
      );

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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.surface, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(),
                      if (_choiceHistory.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _buildChoiceHistoryChips(),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _buildErrorBanner(),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: _buildStoryList(),
                  ),
                ),
                if (_isContinuing) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const Center(
                    child: LoadingSpinner(
                      message: 'Continuing the adventure...',
                      size: 36,
                    ),
                  ),
                ],
                if (_storyEnded) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: _buildEndingCard(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: _buildSaveButton(),
                  ),
                ] else
                  const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withOpacity(0.2),
            child: Text(
              widget.character.name.isNotEmpty
                  ? widget.character.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.character.name} • ${widget.theme}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _storyEnded
                      ? 'Adventure complete!'
                      : 'Choice $_currentChoiceNumber of 4',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _storyEnded ? AppColors.secondary : AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceHistoryChips() {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your choices so far',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: List.generate(_choiceHistory.length, (index) {
              final choice = _choiceHistory[index];
              return Chip(
                backgroundColor: AppColors.accent.withOpacity(0.2),
                labelStyle: theme.textTheme.labelLarge,
                label: Text('${index + 1}. ${choice.text}'),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return ErrorMessage(
      title: 'Connection hiccup',
      message: _errorMessage ?? 'Something unexpected happened.',
      onRetry: _retryAction,
    );
  }

  Widget _buildStoryList() {
    final theme = Theme.of(context);
    if (_isLoading) {
      return const Center(
        child: LoadingSpinner(
          message: 'Summoning your adventure...',
        ),
      );
    }

    if (_segments.isEmpty) {
      return Center(
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_stories, color: AppColors.primary, size: 32),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your story will appear here',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tap retry above to try loading the adventure again.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      physics: const BouncingScrollPhysics(),
      itemCount: _segments.length,
      itemBuilder: (context, index) {
        final segment = _segments[index];
        final bool isLatest = index == _segments.length - 1;
        final bool showChoices =
            isLatest && !_storyEnded && (segment.choices?.isNotEmpty ?? false);

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                segment.text,
                style: theme.textTheme.bodyLarge,
              ),
              if (showChoices) ...[
                const SizedBox(height: AppSpacing.md),
                ...segment.choices!.map(_buildChoiceButton),
              ],
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
    );
  }

  Widget _buildChoiceButton(StoryChoice choice) {
    final theme = Theme.of(context);
    final isPending = _pendingChoice?.id == choice.id && _isContinuing;
    final isDisabled = _isContinuing;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDisabled ? 0.6 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isDisabled ? null : () => _handleChoiceSelected(choice),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isPending ? AppColors.primary : Colors.grey.shade200,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isPending ? Icons.hourglass_bottom : Icons.alt_route,
                        color: isPending ? AppColors.primary : AppColors.secondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          choice.text,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  if (choice.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      choice.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndingCard() {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: List.generate(
              12,
              (index) => Icon(
                Icons.celebration,
                color:
                    Colors.primaries[index % Colors.primaries.length].shade300,
                size: 20 + ((index % 3) * 4),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'The End',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'What an adventure! Tap save so you can read it again anytime.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final icon = _storySaved
        ? Icons.check_circle
        : _isSaving
            ? Icons.hourglass_bottom
            : Icons.bookmark_added_outlined;

    return AppButton.primary(
      label: _storySaved
          ? 'Story Saved!'
          : _isSaving
              ? 'Saving...'
              : 'Save Story',
      icon: icon,
      onPressed: _storySaved || _isSaving ? null : _saveStory,
    );
  }
}

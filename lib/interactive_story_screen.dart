import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:story_weaver_app/widgets/error_boundary.dart';
import 'package:story_weaver_app/widgets/loading_overlay.dart';

import 'models.dart';
import 'storage_service.dart';
import 'services/interactive_story_analytics.dart';
import 'services/interactive_story_service.dart';
import 'services/subscription_service.dart';
import 'theme/age_band_theme.dart';
import 'theme/app_theme.dart';
import 'widgets/app_button.dart';
import 'widgets/app_card.dart';
import 'widgets/error_message.dart';

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
          _segments.last.canConclude ||
          _segments.last.choices == null ||
          _segments.last.choices!.isEmpty);

  String get _fullStoryText =>
      _segments.map((segment) => segment.text.trim()).join('\n\n');

  int get _wordCount => _fullStoryText
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .length;

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
          emotionalSkill: choice.emotionalSkill,
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_storySaved);
      },
      child: ErrorBoundary(
        onRetry: () {
          final retry = _retryAction ?? _loadOpeningSegment;
          retry();
        },
        child: LoadingOverlay(
          isLoading: _isLoading || _isContinuing,
          message: _isLoading
              ? 'Creating your adventure...'
              : _isContinuing
                  ? 'Continuing the adventure...'
                  : null,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF1A0533),
              elevation: 0,
              title: Text(
                '${widget.character.name}\'s Adventure',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(_storySaved),
              ),
            ),
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A0533), Color(0xFF2D1B69)],
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
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9E6CFF).withAlpha(80)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFAA88FF), Color(0xFF7B4FBF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9E6CFF).withAlpha(120),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.character.name.isNotEmpty
                    ? widget.character.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
                  '${widget.character.name} • ${widget.theme}',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: band.uiFontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _storyEnded
                      ? '✨ Adventure complete!'
                      : 'Choice $_currentChoiceNumber of 4',
                  style: TextStyle(
                    color: _storyEnded
                        ? const Color(0xFFFFD700)
                        : const Color(0xFFAA88FF),
                    fontSize: 12,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_choiceHistory.length, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Tooltip(
              message: _choiceHistory[i].text,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      i.isEven
                          ? const Color(0xFFFFB347)
                          : const Color(0xFF00D4DD),
                      i.isEven
                          ? const Color(0xFFFF8C00).withAlpha(180)
                          : const Color(0xFF007B8A).withAlpha(180),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (i.isEven
                              ? const Color(0xFFFFB347)
                              : const Color(0xFF00D4DD))
                          .withAlpha(100),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
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

    if (_segments.isEmpty) {
      return Center(
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_stories,
                  color: AppColors.primary, size: 32),
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

        final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF9E6CFF).withAlpha(60),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9E6CFF).withAlpha(30),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                segment.text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withAlpha(235),
                  fontFamily: band.uiFontFamily,
                  height: 1.6,
                  fontSize: band.band == AgeBand.sprout
                      ? 21.0
                      : band.band == AgeBand.explorer
                          ? 19.0
                          : band.band == AgeBand.creator
                              ? 16.0
                              : null,
                ),
              ),
              if (showChoices) ...[
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        'What do you do next?',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: band.uiFontFamily,
                          fontSize: band.band == AgeBand.sprout ? 18 : 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                ...segment.choices!.asMap().entries.map((e) => _buildChoiceButton(e.value, index: e.key)),
              ],
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
    );
  }

  Widget _buildChoiceButton(StoryChoice choice, {int index = 0}) {
    final theme = Theme.of(context);
    final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final isPending = _pendingChoice?.id == choice.id && _isContinuing;
    final isDisabled = _isContinuing;
    final skill = choice.emotionalSkill;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDisabled ? 0.6 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isDisabled ? null : () => _handleChoiceSelected(choice),
            borderRadius: BorderRadius.circular(band.buttonRadiusBase),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(band.band == AgeBand.sprout
                  ? 20.0
                  : band.band == AgeBand.explorer
                      ? 16.0
                      : AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(band.buttonRadiusBase),
                border: Border.all(
                  color: isPending
                      ? Colors.white.withAlpha(200)
                      : (index.isEven
                          ? const Color(0xFFFFB347).withAlpha(160)
                          : const Color(0xFF00D4DD).withAlpha(160)),
                  width: isPending ? 2.0 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (index.isEven
                            ? const Color(0xFFFFB347)
                            : const Color(0xFF00D4DD))
                        .withAlpha(isPending ? 80 : 40),
                    blurRadius: isPending ? 16 : 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: band.band == AgeBand.sprout
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  if (band.band == AgeBand.sprout) ...[
                    if (isPending)
                      const Icon(Icons.hourglass_bottom, color: AppColors.primary)
                    else
                      Text(_choiceEmoji(choice.text),
                          style: const TextStyle(fontSize: 44)),
                    const SizedBox(height: 6),
                    Text(
                      choice.text,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontFamily: band.uiFontFamily,
                        fontSize: 14,
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        if (isPending)
                          const Icon(Icons.hourglass_bottom,
                              color: AppColors.primary)
                        else
                          Text(_choiceEmoji(choice.text),
                              style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            choice.text,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontFamily: band.uiFontFamily,
                              fontSize: band.band == AgeBand.explorer ? 16.0 : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (skill != null && skill.isNotEmpty && band.band != AgeBand.sprout) ...[
                    const SizedBox(height: 6),
                    Chip(
                      backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
                      label: Text(
                        _formatSkill(skill),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                  if (choice.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      choice.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withAlpha(160),
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

  static String _choiceEmoji(String choiceText) {
    final text = choiceText.toLowerCase();
    if (text.contains('run') || text.contains('escape') || text.contains('flee')) return '🏃';
    if (text.contains('hide') || text.contains('sneak')) return '👀';
    if (text.contains('help') || text.contains('friend') || text.contains('together')) return '🤝';
    if (text.contains('magic') || text.contains('spell') || text.contains('wand')) return '🪄';
    if (text.contains('brave') || text.contains('courage') || text.contains('fight')) return '⚔️';
    if (text.contains('explore') || text.contains('discover') || text.contains('search')) return '🔍';
    if (text.contains('talk') || text.contains('ask') || text.contains('tell')) return '💬';
    if (text.contains('climb') || text.contains('jump') || text.contains('fly')) return '🦅';
    if (text.contains('water') || text.contains('swim') || text.contains('ocean')) return '🌊';
    if (text.contains('dark') || text.contains('night') || text.contains('shadow')) return '🌙';
    if (text.contains('forest') || text.contains('tree') || text.contains('nature')) return '🌳';
    if (text.contains('treasure') || text.contains('gold') || text.contains('gem')) return '💎';
    if (text.contains('dragon') || text.contains('beast') || text.contains('creature')) return '🐉';
    if (text.contains('trust') || text.contains('believe') || text.contains('hope')) return '⭐';
    if (text.contains('care') || text.contains('heal') || text.contains('kind')) return '💚';
    return '✨';
  }

  String _formatSkill(String skill) {
    switch (skill) {
      case 'seeking_support':
        return 'Seeking help';
      case 'self_reliance':
        return 'Independent';
      case 'teamwork':
        return 'Collaboration';
      case 'closure':
        return 'Closure';
      default:
        return skill.replaceAll('_', ' ');
    }
  }

  Widget _buildEndingCard() {
    final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D1B69), Color(0xFF1A0533)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withAlpha(120), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withAlpha(60),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text('✨🌟✨', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 12),
          Text(
            'The End',
            style: TextStyle(
              color: const Color(0xFFFFD700),
              fontFamily: band.uiFontFamily,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'What an adventure! Tap save so you can read it again anytime.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontFamily: band.uiFontFamily,
              fontSize: 14,
              height: 1.5,
            ),
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

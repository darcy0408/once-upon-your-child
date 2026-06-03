import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'services/app_tts_service.dart';
import 'services/api_service_manager.dart';
import 'storage_service.dart';
import 'services/interactive_story_analytics.dart';
import 'services/interactive_story_service.dart';
import 'services/chronicle_service.dart';
import 'services/subscription_service.dart';
import 'theme/age_band_theme.dart';
import 'package:story_weaver_app/widgets/app_button.dart';
import 'widgets/app_card.dart';
import 'widgets/error_message.dart';
import 'widgets/magical_loading_view.dart';
import 'widgets/storybook_progress_indicator.dart';
import 'widgets/voice_mic_button.dart';

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
    this.lifeChallenge,
    this.personalitySliders,
    this.chronicleId, // Living Story Chronicle ID (null = normal story)
    this.bigFeelingsContext,
    this.companions,
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
  final String? lifeChallenge;
  final Map<String, int>? personalitySliders;
  final String? chronicleId;
  final Map<String, dynamic>? bigFeelingsContext;
  /// Companion list built from WizardData — passed directly to backend so
  /// companions appear in the story even for wizard-created temp characters.
  final List<Map<String, dynamic>>? companions;

  @override
  State<PickAPathAdventureScreen> createState() =>
      _PickAPathAdventureScreenState();
}

class _PickAPathAdventureScreenState extends State<PickAPathAdventureScreen> {
  final ScrollController _scrollController = ScrollController();
  final InteractiveStoryService _storyService = const InteractiveStoryService();
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
  int _segmentsThisSession = 0;
  bool _sessionLimitReached = false;
  bool _ttsEnabled = false;
  bool _inventoryExpanded = false;
  bool _stateExpanded = false;

  String? _errorMessage;
  Future<void> Function()? _retryAction;

  // Accumulated text for the current chapter (used for Chronicle summarization)
  final StringBuffer _chapterTextBuffer = StringBuffer();

  bool get _isChronicleMode => widget.chronicleId != null;

  // "Something Else" free-text choice state
  bool _showCustomInput = false;
  bool _showingSessionBreak = false;
  final TextEditingController _customChoiceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // TTS enabled for all bands — young kids hear choices read aloud,
    // older kids/adults get automatic narration as they advance.
    _initTts();
    if (widget.existingStoryId != null) {
      _resumeStory();
    } else {
      _startNewStory();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _customChoiceController.dispose();
    AppTtsService.instance.stop();
    super.dispose();
  }

  void _initTts() {
    if (mounted) setState(() => _ttsEnabled = true);
  }


  /// Speaks the segment; for young bands also reads choices aloud.
  /// Sprouts on continuation-only segments auto-advance after TTS.
  void _speakSegmentWithChoices() {
    if (!_ttsEnabled) return;
    final segment = _currentSegment;
    if (segment == null) return;
    final clean = segment.content.replaceAll(RegExp(r'\*+'), '').trim();

    final age = widget.character.age;
    final isSprout = age <= 5;
    final isYoung = age <= 8; // sprout + explorer

    if (!isYoung || segment.choices.isEmpty) {
      // For sprouts on continuation segments: auto-advance after narration.
      if (isSprout && segment.isContinuation && !_isCompleted) {
        unawaited(_speakThenAutoAdvance(clean));
      } else {
        unawaited(AppTtsService.instance.speak(clean));
      }
      return;
    }

    // Young bands with choices: read segment then choices.
    final choiceParts = segment.choices
        .asMap()
        .entries
        .map((e) => 'Choice ${e.key + 1}: ${e.value.text}')
        .join('. ');
    unawaited(_speakThenChoices(clean, choiceParts));
  }

  Future<void> _speakThenChoices(String content, String choicesText) async {
    await AppTtsService.instance.speak(content, awaitCompletion: true);
    if (!mounted) return;
    await AppTtsService.instance.speak('What will you choose? $choicesText');
  }

  /// Sprout-only: speaks content then waits briefly before auto-advancing.
  Future<void> _speakThenAutoAdvance(String content) async {
    await AppTtsService.instance.speak(content, awaitCompletion: true);
    if (!mounted || _isContinuing || _isCompleted) return;
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _isContinuing || _isCompleted) return;
    unawaited(_handleContinue());
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

  /// Max segments to show per sitting, based on age. Chronicle mode only.
  /// Outside chronicle mode there is no limit.
  int get _maxSegmentsPerSession {
    if (!_isChronicleMode) return 9999;
    final age = widget.character.age;
    if (age <= 5) return 3; // ~5 minutes
    if (age <= 7) return 5; // ~8 minutes
    if (age <= 10) return 8; // ~15 minutes
    if (age <= 14) return 15; // Adventurer/Creator: ~25-30 minutes
    return 20; // Adolescent/Adult: ~40 minutes
  }

  // Removed _progressText - now using StorybookProgressIndicator widget

  Future<void> _startNewStory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _retryAction = null;
    });

    try {
      Map<String, dynamic>? chronicleContext;
      if (_isChronicleMode) {
        chronicleContext = await ChronicleService.buildChapterStartPayload(
            widget.chronicleId!);
      }

      final response = await _runWithAuthRetry(() {
        return _storyService.startInteractiveStory(
          userId: widget.userId,
          characterId: widget.character.id,
          theme: widget.theme,
          tone: widget.tone,
          length: widget.length,
          age: widget.character.age,
          characterName: widget.character.name,
          companions: widget.companions,
          interests: widget.interests,
          mustInclude: widget.mustInclude,
          avoid: widget.avoid,
          lifeChallenge: widget.lifeChallenge,
          personalitySliders: widget.personalitySliders,
          chronicleContext: chronicleContext,
          bigFeelingsContext: widget.bigFeelingsContext,
        );
      });

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
      if (_ttsEnabled && _currentSegment != null) {
        _speakSegmentWithChoices();
      }

      _chapterTextBuffer.write(_currentSegment?.content ?? '');

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
      final response = await _runWithAuthRetry(() {
        return _storyService.resumeStory(widget.existingStoryId!);
      });

      if (!mounted) return;
      setState(() {
        _storyId = response.storyId;
        _currentSegment = response.segment;
        _inventory = response.inventory;
        _state = response.state;
        _isCompleted = response.isCompleted;
        _isLoading = false;
      });
      if (_ttsEnabled && _currentSegment != null) {
        _speakSegmentWithChoices();
      }

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

  bool _isAuthError(InteractiveStoryException error) =>
      error.message.contains('code 401');

  Future<T> _runWithAuthRetry<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on InteractiveStoryException catch (error) {
      if (!_isAuthError(error)) {
        rethrow;
      }
      await ApiServiceManager.resetAndReauthenticate();
      return action();
    }
  }

  Future<void> _handleChoiceSelected(StoryChoiceData choice) async {
    if (_isContinuing || _isCompleted || _storyId == null) return;

    HapticFeedback.selectionClick();
    // Stop any in-progress narration the instant a choice/skip is tapped, so the
    // previous page's audio doesn't keep reading over the next page while the
    // next segment is generated (the fetch can take several seconds). The new
    // page's narration starts via _speakSegmentWithChoices() once it loads.
    unawaited(AppTtsService.instance.stop());
    setState(() {
      _isContinuing = true;
      _errorMessage = null;
      _retryAction = null;
      _showCustomInput = false;
    });

    try {
      final response = await _runWithAuthRetry(() {
        return _storyService.continueInteractiveStory(
          storyId: _storyId!,
          choiceId: choice.id,
        );
      });

      if (!mounted) return;
      setState(() {
        _currentSegment = response.segment;
        _inventory = response.inventory;
        _state = response.state;
        _isCompleted = response.isCompleted;
        _isContinuing = false;
      });
      if (_ttsEnabled && _currentSegment != null) {
        _speakSegmentWithChoices();
      }
      _segmentsThisSession++;
      if (_segmentsThisSession >= _maxSegmentsPerSession) {
        setState(() => _sessionLimitReached = true);
      }

      _chapterTextBuffer.write('\n\n[Choice: ${choice.text}]\n\n');
      _chapterTextBuffer.write(_currentSegment?.content ?? '');

      _scrollToBottom();

      if (_isCompleted) {
        unawaited(
          InteractiveStoryAnalytics.trackStorySaved(
            characterId: widget.character.id,
            theme: widget.theme,
            choiceCount: _currentSegment?.segmentNumber ?? 0,
            segmentCount: _currentSegment?.segmentNumber ?? 0,
            wordCount: _currentSegment?.content.split(' ').length ?? 0,
          ),
        );
        if (_isChronicleMode) {
          _triggerChapterSummarization(choice.text);
        }
      }
    } on InteractiveStoryException catch (e) {
      _handleError(e.message, () => _handleChoiceSelected(choice));
    } catch (e) {
      _handleError(
          'Unable to continue story: $e', () => _handleChoiceSelected(choice));
    }
  }

  Future<void> _handleCustomChoice() async {
    final text = _customChoiceController.text.trim();
    if (text.isEmpty || _isContinuing || _isCompleted || _storyId == null) {
      return;
    }

    HapticFeedback.selectionClick();
    // Stop any in-progress narration the instant a choice/skip is tapped, so the
    // previous page's audio doesn't keep reading over the next page while the
    // next segment is generated (the fetch can take several seconds). The new
    // page's narration starts via _speakSegmentWithChoices() once it loads.
    unawaited(AppTtsService.instance.stop());
    setState(() {
      _isContinuing = true;
      _errorMessage = null;
      _retryAction = null;
      _showCustomInput = false;
    });
    _customChoiceController.clear();

    try {
      final response = await _runWithAuthRetry(() {
        return _storyService.continueInteractiveStory(
          storyId: _storyId!,
          choiceId: 'custom',
          customText: text,
        );
      });

      if (!mounted) return;
      setState(() {
        _currentSegment = response.segment;
        _inventory = response.inventory;
        _state = response.state;
        _isCompleted = response.isCompleted;
        _isContinuing = false;
      });
      if (_ttsEnabled && _currentSegment != null) {
        _speakSegmentWithChoices();
      }
      _segmentsThisSession++;
      if (_segmentsThisSession >= _maxSegmentsPerSession) {
        setState(() => _sessionLimitReached = true);
      }

      _chapterTextBuffer.write('\n\n[Choice: $text]\n\n');
      _chapterTextBuffer.write(_currentSegment?.content ?? '');

      _scrollToBottom();

      if (_isCompleted) {
        unawaited(
          InteractiveStoryAnalytics.trackStorySaved(
            characterId: widget.character.id,
            theme: widget.theme,
            choiceCount: _currentSegment?.segmentNumber ?? 0,
            segmentCount: _currentSegment?.segmentNumber ?? 0,
            wordCount: _currentSegment?.content.split(' ').length ?? 0,
          ),
        );
        if (_isChronicleMode) {
          _triggerChapterSummarization(text);
        }
      }
    } on InteractiveStoryException catch (e) {
      _handleError(e.message, () => _handleCustomChoice());
    } catch (e) {
      _handleError('Unable to continue story: $e', () => _handleCustomChoice());
    }
  }

  Future<void> _handleContinue() async {
    if (_isContinuing || _isCompleted || _storyId == null) return;

    HapticFeedback.selectionClick();
    // Stop any in-progress narration the instant a choice/skip is tapped, so the
    // previous page's audio doesn't keep reading over the next page while the
    // next segment is generated (the fetch can take several seconds). The new
    // page's narration starts via _speakSegmentWithChoices() once it loads.
    unawaited(AppTtsService.instance.stop());
    setState(() {
      _isContinuing = true;
      _errorMessage = null;
      _retryAction = null;
    });

    try {
      // For CONTINUE segments, we create a pseudo-choice to advance the story
      // The backend will recognize this and generate the next segment
      final response = await _runWithAuthRetry(() {
        return _storyService.continueInteractiveStory(
          storyId: _storyId!,
          choiceId: 'continue', // Special ID for continuation
        );
      });

      if (!mounted) return;
      setState(() {
        _currentSegment = response.segment;
        _inventory = response.inventory;
        _state = response.state;
        _isCompleted = response.isCompleted;
        _isContinuing = false;
      });
      if (_ttsEnabled && _currentSegment != null) {
        _speakSegmentWithChoices();
      }
      _segmentsThisSession++;
      if (_segmentsThisSession >= _maxSegmentsPerSession) {
        setState(() => _sessionLimitReached = true);
      }

      _chapterTextBuffer.write('\n\n');
      _chapterTextBuffer.write(_currentSegment?.content ?? '');

      _scrollToBottom();

      if (_isCompleted) {
        unawaited(
          InteractiveStoryAnalytics.trackStorySaved(
            characterId: widget.character.id,
            theme: widget.theme,
            choiceCount: _currentSegment?.segmentNumber ?? 0,
            segmentCount: _currentSegment?.segmentNumber ?? 0,
            wordCount: _currentSegment?.content.split(' ').length ?? 0,
          ),
        );
        if (_isChronicleMode) {
          _triggerChapterSummarization('');
        }
      }
    } on InteractiveStoryException catch (e) {
      _handleError(e.message, _handleContinue);
    } catch (e) {
      _handleError('Unable to continue story: $e', _handleContinue);
    }
  }

  void _triggerChapterSummarization(String choiceMadeText) {
    if (!_isChronicleMode || widget.chronicleId == null) return;

    // Extract last 2 sentences from chapter text as the "ending"
    final fullText = _chapterTextBuffer.toString();
    final sentences = fullText
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final lastTwo = sentences.length >= 2
        ? sentences.sublist(sentences.length - 2).join(' ')
        : (sentences.isNotEmpty ? sentences.last : '');

    // Determine chapter number: chronicle.chapterCount + 1
    // We use chapterCount from the chronicle; the service will increment after
    unawaited(
      ChronicleService.getChronicle(widget.chronicleId!).then((chronicle) {
        final chapterNumber = (chronicle?.chapterCount ?? 0) + 1;
        unawaited(
          ChronicleService.handleChapterComplete(
            chronicleId: widget.chronicleId!,
            chapterNumber: chapterNumber,
            chapterText: fullText,
            characterName: widget.character.name,
            lastChapterEnding: lastTwo,
            choiceMadeToStart: choiceMadeText,
          ),
        );
      }),
    );
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

      // Use current segment content as story text
      final completeText = _currentSegment!.content;

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
      await _subscriptionService.recordStoryCreation();

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

  AgeBandThemeData get _bandTheme => themeForAge(widget.character.age);

  bool get _isSprout => widget.character.age <= 5;
  bool get _isYoung => widget.character.age <= 8;
  bool get _isMature => _bandTheme.band.isMature;

  String get _continueLabel {
    if (_isSprout) return 'Keep going! ➡️';
    if (_isYoung) return 'What happens next? →';
    if (_isMature) return 'Continue';
    return 'Next →';
  }

  @override
  Widget build(BuildContext context) {
    final band = _bandTheme;
    return Scaffold(
      backgroundColor: band.gradientStart,
      appBar: AppBar(
        backgroundColor: band.gradientStart,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _storyTitle ?? 'Pick-A-Path Adventure',
          style: TextStyle(
            fontFamily: band.uiFontFamily,
            fontSize: _isSprout ? 20 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (!_isLoading && _currentSegment != null && !_showingSessionBreak)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: StorybookProgressIndicator(
                  currentPage: _currentSegment!.segmentNumber,
                  totalPages: _targetSegmentCount,
                  stageLabel: _currentSegment!.stageLabel,
                  isCompleted: _isCompleted,
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [band.gradientStart, band.gradientMid, band.gradientEnd],
          ),
        ),
        child: _isLoading
            ? MagicalLoadingView(
                status: _isSprout
                    ? 'Getting your story ready...'
                    : _isYoung
                        ? 'Weaving your adventure...'
                        : _isMature
                            ? 'Crafting your story...'
                            : 'Building your adventure...',
                isSproutBand: _isSprout,
              )
            : _errorMessage != null
                ? Center(
                    child: ErrorMessage(
                      title: 'Error',
                      message: _errorMessage!,
                      onRetry: _retryAction,
                    ),
                  )
                : _buildStoryContent(),
      ),
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

          // Inventory section — hidden for Sprouts (too abstract)
          if (_inventory.isNotEmpty && !_isSprout) ...[
            _buildInventorySection(),
            const SizedBox(height: 16),
          ],

          // Story state section — only for Adventurer+ who enjoy tracking
          if (_state != null && !_isSprout && !_isYoung) ...[
            _buildStoryStateSection(),
            const SizedBox(height: 16),
          ],

          // Choices, Continue, or completion
          if (_sessionLimitReached && _isChronicleMode)
            Builder(builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_showingSessionBreak) {
                  setState(() => _showingSessionBreak = true);
                }
              });
              return _buildSessionBreakSection();
            })
          else if (_isCompleted)
            _buildCompletionSection()
          else if (_currentSegment!.requiresChoice)
            _buildChoicesSection()
          else if (_currentSegment!.isContinuation)
            _buildContinueSection(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSegmentCard() {
    final band = _bandTheme;
    final double fontSize = _isSprout
        ? 19
        : _isYoung
            ? 17
            : _isMature
                ? 15
                : 16;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_ttsEnabled)
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.volume_off_rounded,
                    color: band.primary),
                tooltip: 'Stop reading',
                onPressed: () => AppTtsService.instance.stop(),
              ),
            ),
          // Illustration
          if (_currentSegment!.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _currentSegment!.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        band.primary.withValues(alpha: 0.3),
                        band.gradientMid.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _isSprout ? '✨' : _isYoung ? '🌟' : '📖',
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Story content
          Text(
            _currentSegment!.content,
            style: TextStyle(
              fontFamily: band.uiFontFamily,
              fontSize: fontSize,
              height: 1.7,
              color: Colors.white.withValues(alpha: 0.92),
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
            onTap: () =>
                setState(() => _inventoryExpanded = !_inventoryExpanded),
            child: Row(
              children: [
                Icon(_isMature ? Icons.list_alt_rounded : Icons.backpack,
                    size: 20),
                const SizedBox(width: 8),
                Text(
                  _isMature
                      ? 'Story Items (${_inventory.length})'
                      : 'My Backpack (${_inventory.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Icon(
                  _inventoryExpanded ? Icons.expand_less : Icons.expand_more,
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
                Icon(_isMature ? Icons.timeline_rounded : Icons.map, size: 20),
                const SizedBox(width: 8),
                Text(
                  _isMature ? 'Story Thread' : 'Adventure Map',
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

  /// Tries to match [spoken] words against the current choices.
  /// Returns the best-matching choice or null if no confident match found.
  StoryChoiceData? _matchSpokenToChoice(String spoken) {
    if (_currentSegment == null) return null;
    final words = spoken.toLowerCase().split(RegExp(r'\s+'));
    int bestScore = 0;
    StoryChoiceData? best;
    for (final choice in _currentSegment!.choices) {
      final choiceWords = choice.text.toLowerCase().split(RegExp(r'\s+'));
      final hits =
          words.where((w) => w.length > 2 && choiceWords.contains(w)).length;
      if (hits > bestScore) {
        bestScore = hits;
        best = choice;
      }
    }
    // Require at least one meaningful keyword match
    return bestScore >= 1 ? best : null;
  }

  void _handleVoiceResult(String spoken) {
    final match = _matchSpokenToChoice(spoken);
    if (match != null) {
      _handleChoiceSelected(match);
    } else {
      // No match — put the text into the "do something else" field
      setState(() {
        _showCustomInput = true;
        _customChoiceController.text = spoken;
      });
    }
  }

  Widget _buildChoicesSection() {
    if (_currentSegment!.choices.isEmpty) {
      return const Center(child: Text('No choices available'));
    }
    return widget.character.age <= 7
        ? _buildYoungChoicesSection()
        : _buildStandardChoicesSection();
  }

  Widget _buildYoungChoicesSection() {
    final isSprout = widget.character.age <= 5;
    final isExplorer = widget.character.age <= 8 && !isSprout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              Text(
                isSprout
                    ? 'What should happen? 🎙️'
                    : isExplorer
                        ? 'What do you choose? 🎙️'
                        : 'Say your choice or tap one!',
                style: TextStyle(
                  fontSize: isSprout ? 20 : 17,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              VoiceMicButton(
                onResult: _handleVoiceResult,
                hint: 'Say what happens next...',
                disabled: _isContinuing,
                size: isSprout ? 72 : 56,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ..._currentSegment!.choices.asMap().entries.map((entry) {
          final idx = entry.key;
          final choice = entry.value;
          final gradients = [
            [const Color(0xFF7B2FBE), const Color(0xFF9B59B6)],
            [const Color(0xFF1A7A4A), const Color(0xFF27AE60)],
            [const Color(0xFFB7410E), const Color(0xFFE74C3C)],
          ];
          final grad = gradients[idx % gradients.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14.0),
            child: GestureDetector(
              onTap: _isContinuing ? null : () => _handleChoiceSelected(choice),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: grad),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: grad[0].withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  choice.text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSprout ? 18 : 16,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        _buildYoungSomethingElse(),
        if (isSprout) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _isContinuing ? null : _showParentCopilotSheet,
            icon: const Icon(Icons.family_restroom, color: Colors.orange),
            label: const Text(
              'Grown-up adds to the story...',
              style: TextStyle(color: Colors.orange, fontSize: 14),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildYoungSomethingElse() {
    final isSprout = widget.character.age <= 5;
    if (_showCustomInput) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(16),
          color: Colors.deepPurple.withValues(alpha: 0.05),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _customChoiceController.text,
              style: TextStyle(
                fontSize: isSprout ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.deepPurple.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _showCustomInput = false;
                      _customChoiceController.clear();
                    }),
                    child: const Text('Try again'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isContinuing ? null : _handleCustomChoice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isSprout ? 'Yes! Do that! 🌟' : 'Use this!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    // Sprouts can't type — only show the "my own idea" button if voice
    // captured something. For Explorer+, tapping opens the text field.
    if (isSprout) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap:
          _isContinuing ? null : () => setState(() => _showCustomInput = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
              color: Colors.deepPurple.withValues(alpha: 0.5), width: 2),
          borderRadius: BorderRadius.circular(20),
          color: Colors.deepPurple.withValues(alpha: 0.04),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic_rounded, color: Colors.deepPurple, size: 28),
            const SizedBox(width: 10),
            const Text(
              'Something else...',
              style: TextStyle(
                color: Colors.deepPurple,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showParentCopilotSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E0538),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '👨‍👧 Add to the story',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Type something that happens next — it will appear in the story!',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Add to the story',
              textField: true,
              child: TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. "Then a grown-up appeared with a magic map!"',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.purple),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.purple),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(ctx).pop();
                  _customChoiceController.text = text;
                  _handleCustomChoice();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Add this to the story!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renamed copy of the original _buildChoicesSection — body is unchanged.
  Widget _buildStandardChoicesSection() {
    // Safety check: ensure we have choices to display
    if (_currentSegment!.choices.isEmpty) {
      return const Center(
        child: Text('No choices available'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'What do you do next?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(width: 8),
            VoiceMicButton(
              onResult: _handleVoiceResult,
              hint: 'Or say your choice',
              disabled: _isContinuing,
              size: 36,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._currentSegment!.choices.asMap().entries.map((entry) {
          final choice = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: AppButton.primary(
              label: choice.text,
              // FIXED: Only disable during actual API call, not when displaying new segment
              onPressed:
                  _isContinuing ? null : () => _handleChoiceSelected(choice),
            ),
          );
        }),
        // "Something Else" free-text option
        const SizedBox(height: 4),
        if (!_showCustomInput)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: TextButton.icon(
              onPressed: _isContinuing
                  ? null
                  : () => setState(() => _showCustomInput = true),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('✨ Do something else...'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepPurple,
              ),
            ),
          )
        else
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              border:
                  Border.all(color: Colors.deepPurple.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(12),
              color: Colors.deepPurple.withValues(alpha: 0.05),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'What would YOU do?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'What would you do? Type your own idea',
                  textField: true,
                  child: TextField(
                    controller: _customChoiceController,
                    maxLength: 200,
                    maxLines: 2,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Type your own idea...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      counterStyle: const TextStyle(fontSize: 11),
                    ),
                    onSubmitted: (_) => _handleCustomChoice(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _showCustomInput = false;
                        _customChoiceController.clear();
                      }),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isContinuing ? null : _handleCustomChoice,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Let\'s go!'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildContinueSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton.primary(
          label: _continueLabel,
          onPressed: _isContinuing ? null : _handleContinue,
          icon: Icons.arrow_forward,
        ),
      ],
    );
  }

  Widget _buildCompletionSection() {
    final age = widget.character.age;
    final isChronicle = _isChronicleMode && widget.chronicleId != null;
    final isSprout = age <= 5;

    final String title = isChronicle
        ? (isSprout
            ? '🌟 Chapter done! Great job!'
            : age <= 7
                ? 'Chapter Complete! Amazing! 🎉'
                : age <= 10
                    ? 'Chapter Complete!'
                    : 'Chapter Complete')
        : (isSprout
            ? 'The End! 🌈'
            : age <= 7
                ? 'Adventure Complete! 🎉'
                : 'Adventure Complete!');

    final String saveLabel = isChronicle
        ? (isSprout
            ? 'Save my story! ⭐'
            : age <= 7
                ? 'Save it!'
                : 'Save & continue another day')
        : (isSprout ? 'Keep this story! 📖' : 'Save to Library');

    final String continueLabel = isSprout
        ? 'Keep going! ➡️'
        : age <= 7
            ? 'Next chapter!'
            : age <= 10
                ? 'Start next chapter'
                : 'Continue Chronicle';

    return Column(
      children: [
        Icon(
          isChronicle ? Icons.menu_book_rounded : Icons.auto_awesome,
          size: isSprout ? 80 : 64,
          color: Colors.amber,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
              fontSize: isSprout ? 28 : 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (!_storySaved) ...[
          AppButton.primary(
            label: saveLabel,
            onPressed: _isSaving ? null : _saveStory,
          ),
          const SizedBox(height: 12),
        ],
        if (_storySaved) ...[
          Text(
            isSprout
                ? '✓ Saved! Great adventuring!'
                : '✓ Saved to your library!',
            style: const TextStyle(
                color: Colors.green, fontWeight: FontWeight.bold),
          ),
          if (isChronicle) ...[
            const SizedBox(height: 12),
            AppButton.secondary(
              label: continueLabel,
              onPressed: () {
                Navigator.of(context).pop('chapter_complete');
              },
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildSessionBreakSection() {
    final age = widget.character.age;
    final isSprout = age <= 5;
    return Column(
      children: [
        const SizedBox(height: 16),
        Icon(
          isSprout ? Icons.bedtime_rounded : Icons.bookmark_rounded,
          size: isSprout ? 72 : 56,
          color: Colors.amber,
        ),
        const SizedBox(height: 12),
        Text(
          isSprout
              ? 'Great adventuring! Time for a rest! 🌙'
              : age <= 7
                  ? 'Amazing! Your story is saved! Come back for more!'
                  : 'Good stopping point. Your chronicle is saved.',
          style: TextStyle(
            fontSize: isSprout ? 22 : 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isSprout
              ? 'Your story will be waiting for you!'
              : 'Continue whenever you\'re ready.',
          style:
              TextStyle(fontSize: isSprout ? 18 : 14, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        AppButton.primary(
          label: isSprout ? 'All done! 🌟' : 'Save & finish for now',
          onPressed: () {
            setState(() => _showingSessionBreak = false);
            _triggerChapterSummarization('');
            Navigator.of(context).pop('chapter_complete');
          },
        ),
      ],
    );
  }
}

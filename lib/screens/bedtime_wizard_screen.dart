import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/app_tts_service.dart';
import '../services/api_service_manager.dart';
import '../models.dart';
import 'wizard_steps/wizard_data_mapper.dart';

/// Voice-driven bedtime story wizard.
/// Minimal screen — just a pulsing star and voice interaction.
class BedtimeWizardScreen extends StatefulWidget {
  final String childName;
  final int childAge;
  final bool isInteractive;
  final int timerMinutes;

  const BedtimeWizardScreen({
    super.key,
    required this.childName,
    required this.childAge,
    this.isInteractive = false,
    this.timerMinutes = 0,
  });

  @override
  State<BedtimeWizardScreen> createState() => _BedtimeWizardScreenState();
}

enum BedtimeStep {
  greeting, // "Hi [name]! Let's make a bedtime story!"
  heroName, // "What's your hero's name?" (may reuse child's name)
  companion, // "Who's coming with you?"
  setting, // "Where will your adventure happen?"
  feeling, // "What kind of story?"
  confirm, // "OK! [name] and [companion] in [setting]. Ready?"
  generating, // "Making your story now... close your eyes..."
  reading, // Reading the story aloud
  done, // "The end. Goodnight!"
}

class _BedtimeWizardScreenState extends State<BedtimeWizardScreen>
    with TickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;

  BedtimeStep _step = BedtimeStep.greeting;
  final WizardData _wizardData = WizardData();

  // Collected answers
  String? _heroName;
  String? _companionChoice;
  String? _settingChoice;
  String? _feelingChoice;

  // UI state
  String _statusText = '';
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _timerExpired = false;

  late AnimationController _orbController;
  Timer? _sleepTimer;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (widget.timerMinutes > 0) {
      _sleepTimer =
          Timer(Duration(minutes: widget.timerMinutes), _handleSleepTimer);
    }

    _initAndStart();
  }

  void _handleSleepTimer() async {
    _timerExpired = true;
    _sleepTimer?.cancel();
    await _speech.stop();
    await AppTtsService.instance.stop();
    if (!mounted) return;
    setState(() => _step = BedtimeStep.done);
    await _speak(
        "It's time for sleep now. Goodnight, ${widget.childName}. Sweet dreams.");
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _initAndStart() async {
    _speechAvailable = await _speech.initialize();
    await _runStep();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _orbController.dispose();
    _speech.stop();
    AppTtsService.instance.stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _runStep() async {
    switch (_step) {
      case BedtimeStep.greeting:
        await _speakAndAdvance(
          "Hi ${widget.childName}! Let's make a magical bedtime story together. Just talk to me!",
          BedtimeStep.heroName,
        );
        break;

      case BedtimeStep.heroName:
        final answer = await _askQuestion(
          "What's your hero's name? Or should I use ${widget.childName}?",
        );
        _heroName = answer.isNotEmpty ? answer : widget.childName;
        _advance(BedtimeStep.companion);
        break;

      case BedtimeStep.companion:
        final answer = await _askQuestion(
          "Who's coming with $_heroName? A tiny dragon, a wise owl, a shadow cat, a star dog, or someone else?",
        );
        _companionChoice = _fuzzyMatchCompanion(answer);
        _advance(BedtimeStep.setting);
        break;

      case BedtimeStep.setting:
        final answer = await _askQuestion(
          "Where should the story go? A rainbow world, a cave full of crystals, friendly dragons, or somewhere you make up?",
        );
        _settingChoice = _fuzzyMatchScenario(answer);
        _advance(BedtimeStep.feeling);
        break;

      case BedtimeStep.feeling:
        final answer = await _askQuestion(
          "What kind of story? A brave adventure, a funny story, a story about friendship, or a calming story?",
        );
        _feelingChoice = _matchStoryMood(answer);
        _advance(BedtimeStep.confirm);
        break;

      case BedtimeStep.confirm:
        final summary =
            "$_heroName and $_companionChoice in $_settingChoice. A $_feelingChoice story.";
        final answer = await _askQuestion(
          "Here's your story recipe: $summary. Shall I make it? Say yes, or tell me what to change.",
        );
        if (_isAffirmative(answer)) {
          _advance(BedtimeStep.generating);
        } else {
          _advance(BedtimeStep.companion);
        }
        break;

      case BedtimeStep.generating:
        await _speak("Making your story now. Close your eyes and imagine...");
        await _generateAndReadStory();
        break;

      case BedtimeStep.reading:
        break;

      case BedtimeStep.done:
        await _speak("The end. Goodnight, ${widget.childName}. Sweet dreams.");
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) Navigator.of(context).pop();
        break;
    }
  }

  void _advance(BedtimeStep next) {
    if (!mounted) return;
    setState(() => _step = next);
    _runStep();
  }

  Future<void> _speakAndAdvance(String text, BedtimeStep next) async {
    await _speak(text);
    _advance(next);
  }

  Future<void> _speak(String text) async {
    if (!mounted) return;
    setState(() {
      _isSpeaking = true;
      _statusText = text;
    });
    await AppTtsService.instance.speak(text, awaitCompletion: true);
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<String> _askQuestion(String question) async {
    await _speak(question);
    if (!_speechAvailable) {
      await _speak("I can't hear you right now, so I'll pick for you!");
      return '';
    }
    final answer = await _listen();
    if (answer.isEmpty) {
      await _speak("I didn't catch that, so I'll surprise you!");
    }
    return answer;
  }

  Future<String> _listen() async {
    if (!mounted) return '';
    final completer = Completer<String>();
    setState(() => _isListening = true);

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _statusText = '"${result.recognizedWords}"');
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );

    final answer = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => '',
    );

    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
    return answer;
  }

  String _fuzzyMatchCompanion(String input) {
    final lower = input.toLowerCase();
    final companions = {
      'dragon': 'a tiny dragon',
      'owl': 'a wise owl',
      'cat': 'a shadow cat',
      'dog': 'a star dog',
      'unicorn': 'a magic unicorn',
      'fox': 'a clever fox',
      'robin': 'a rockin\' robin',
    };
    for (final entry in companions.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    for (final entry in companions.entries) {
      if (entry.key.startsWith(lower.trim()) ||
          lower.contains(
              entry.key.substring(0, (entry.key.length * 0.6).ceil()))) {
        return entry.value;
      }
    }
    return input.isNotEmpty ? input : 'a tiny dragon';
  }

  String _fuzzyMatchScenario(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('rainbow')) {
      return 'Rainbow World';
    }
    if (lower.contains('crystal') || lower.contains('cave')) {
      return 'Cave Full of Crystals';
    }
    if (lower.contains('dragon')) {
      return 'Friendly Dragons';
    }
    if (lower.contains('brave') || lower.contains('hero')) {
      return 'Making a New Friend';
    }
    if (lower.contains('feel') || lower.contains('emotion')) {
      return 'Big Feelings';
    }
    if (lower.contains('forest') || lower.contains('magic')) {
      return 'Magical Forest';
    }
    return input.isNotEmpty ? input : 'Magical Forest';
  }

  String _matchStoryMood(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('brave') || lower.contains('adventure')) return 'brave';
    if (lower.contains('funny') || lower.contains('silly')) return 'funny';
    if (lower.contains('friend')) return 'friendship';
    if (lower.contains('calm') ||
        lower.contains('relax') ||
        lower.contains('sleep')) {
      return 'calming';
    }
    return 'calming';
  }

  bool _isAffirmative(String input) {
    final lower = input.toLowerCase();
    return lower.contains('yes') ||
        lower.contains('yeah') ||
        lower.contains('ok') ||
        lower.contains('sure') ||
        lower.contains('ready') ||
        lower.isEmpty;
  }

  Future<void> _generateAndReadStory() async {
    _wizardData.characterName = _heroName ?? widget.childName;
    _wizardData.characterAge = widget.childAge;
    _wizardData.companionNames = [_companionChoice ?? 'a tiny dragon'];
    _wizardData.customElements = '$_feelingChoice story about $_settingChoice';
    _wizardData.storyLength = 'standard';

    final requestData = WizardDataMapper.mapToStoryRequest(_wizardData);

    try {
      if (widget.isInteractive) {
        await _runInteractiveStoryLoop(requestData);
      } else {
        await _runRegularStory(requestData);
      }
    } catch (e) {
      await _speak(
          "Oh no, something went wrong making the story. Let's try again tomorrow. Goodnight!");
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _runRegularStory(Map<String, dynamic> requestData) async {
    final result = await ApiServiceManager.generateStory(
        characterName: requestData['character'] ?? 'Hero',
        age: requestData['age'] ?? 5,
        theme: _settingChoice ?? 'Magical Adventure',
        companion: requestData['companion'] ?? '',
        characterDetails: requestData['characterDetails'],
        currentFeeling: null,
        additionalCharacters: null,
        includeIllustrations: false,
        rhymeTimeMode: false,
        learningToReadMode: false,
        companionPets: requestData['companion_pets'],
        companionCharacters: requestData['companion_characters'],
        storyLength: requestData['storyLength'] ?? 'standard',
        customElements: requestData['customElements'] ?? '',
        subscriptionTier: 'free',
        onProgress: (status) {
          if (mounted) setState(() => _statusText = status);
        });

    setState(() => _step = BedtimeStep.reading);

    final paragraphs = result.storyText.split(RegExp(r'\n\n+'));
    for (final paragraph in paragraphs) {
      if (_timerExpired) return;
      if (paragraph.trim().isEmpty) continue;
      if (!mounted) return;
      setState(() => _statusText = '...');
      try {
        await AppTtsService.instance.speak(
          paragraph.trim(),
          awaitCompletion: true,
        );
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (!_timerExpired) _advance(BedtimeStep.done);
  }

  Future<void> _runInteractiveStoryLoop(
      Map<String, dynamic> requestData) async {
    setState(() => _step = BedtimeStep.reading);

    final characterName = requestData['character'] ?? 'Hero';
    final theme = _settingChoice ?? 'Magical Adventure';
    final companion = requestData['companion'] ?? '';

    Map<String, dynamic> currentSegment =
        await ApiServiceManager.generateInteractiveStory(
      characterName: characterName,
      age: requestData['age'] ?? 5,
      theme: theme,
      companion: companion,
    );

    int turnCount = 0;
    const maxTurns = 5;

    String storySoFar = "";
    List<String> choicesMade = [];

    while (turnCount < maxTurns && !_timerExpired) {
      final text = currentSegment['text'] as String?;
      final choicesRaw = currentSegment['choices'];
      final isEnding =
          currentSegment['is_ending'] == true || turnCount == maxTurns - 1;

      if (text != null && text.isNotEmpty) {
        storySoFar += '$text ';
        if (!mounted) return;
        setState(() => _statusText = '...');
        try {
          await AppTtsService.instance
              .speak(text.trim(), awaitCompletion: true);
        } catch (_) {}
      }

      if (isEnding || _timerExpired) break;

      // Ask for choice
      String question = "What do you want to do next?";
      if (choicesRaw is List && choicesRaw.isNotEmpty) {
        question =
            "Do you want to ${choicesRaw[0]}, or ${choicesRaw[1]}? Or something else?";
      }

      final answer = await _askQuestion(question);
      if (_timerExpired) break;

      final choice = answer.isNotEmpty
          ? answer
          : (choicesRaw is List && choicesRaw.isNotEmpty
              ? choicesRaw[0].toString()
              : 'Keep going!');
      choicesMade.add(choice);

      setState(() => _statusText = 'Generating next part...');
      currentSegment = await ApiServiceManager.continueInteractiveStory(
        characterName: characterName,
        theme: theme,
        choice: choice,
        storySoFar: storySoFar,
        choicesMade: choicesMade,
      );

      turnCount++;
    }

    if (!_timerExpired) _advance(BedtimeStep.done);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B2E), // Deep night sky
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            if (_step == BedtimeStep.done && mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _orbController,
                  builder: (context, child) {
                    final scale = 1.0 + (_orbController.value * 0.3);
                    final opacity = 0.4 + (_orbController.value * 0.6);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _isListening
                                  ? Colors.purple.withValues(alpha: opacity)
                                  : _isSpeaking
                                      ? Colors.amber.withValues(alpha: opacity)
                                      : Colors.indigo
                                          .withValues(alpha: opacity * 0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Icon(
                          _isListening
                              ? Icons.mic
                              : _isSpeaking
                                  ? Icons.auto_stories
                                  : Icons.star,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 60),
                TextButton(
                  onPressed: () {
                    if (mounted) Navigator.of(context).pop();
                  },
                  child: Text(
                    'Exit Bedtime Mode',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

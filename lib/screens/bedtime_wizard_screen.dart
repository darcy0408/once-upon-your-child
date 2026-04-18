import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/app_tts_service.dart';
import '../services/api_service_manager.dart';
import '../models.dart';
import '../theme/age_band_theme.dart';
import 'wizard_steps/wizard_data_mapper.dart';
import 'parent_controls_screen.dart';

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
  byokSetup,  // No API key — show parent setup card
  greeting,   // "Hi [name]! Let's make a bedtime story!"
  age,        // "How old are you?" (only asked if age unknown)
  heroName,   // "What's your hero's name?"
  companion,  // "Who's coming with you?"
  listeners,  // "Are any brothers, sisters, or friends listening too?"
  setting,    // "Where will your adventure happen?"
  feeling,    // "What kind of story?"
  duration,   // "How long should the story be?"
  confirm,    // "OK! Ready?"
  generating, // "Making your story now... close your eyes..."
  reading,    // Reading the story aloud
  done,       // "The end. Goodnight!"
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
  List<String> _listenerNames = [];
  String? _settingChoice;
  int _resolvedAge = 0; // 0 = not yet set
  String? _feelingChoice;
  int _storyDurationMinutes = 15;

  // UI state
  String _statusText = '';
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _timerExpired = false;

  late AnimationController _orbController;
  Timer? _sleepTimer;

  int get _effectiveAge =>
      _resolvedAge > 0 ? _resolvedAge : (widget.childAge > 0 ? widget.childAge : 8);
  AgeBand get _ageBand => ageBandFromAge(_effectiveAge);
  bool get _isMature =>
      _ageBand == AgeBand.creator ||
      _ageBand == AgeBand.adolescent ||
      _ageBand == AgeBand.adult;
  bool get _isYoung =>
      _ageBand == AgeBand.sprout || _ageBand == AgeBand.explorer;

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
    _resolvedAge = widget.childAge > 0 ? widget.childAge : 0;
    final hasKey = await ApiServiceManager.isUsingOwnApiKey();
    if (!hasKey && mounted) {
      setState(() => _step = BedtimeStep.byokSetup);
      await _speak(
        "Bedtime stories need a free Gemini API key. A parent can set one up in Settings — it only takes a minute!",
      );
      return; // Stay on the byokSetup screen; parent taps Settings or Exit
    }
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
      case BedtimeStep.byokSetup:
        break; // handled in build() — parent must tap Settings or Exit

      case BedtimeStep.greeting:
        final greeting = _isMature
            ? 'Hey ${widget.childName}. Let\'s build your story. Just talk to me.'
            : 'Hi ${widget.childName}! Let\'s make a magical bedtime story together. Just talk to me!';
        await _speakAndAdvance(
          greeting,
          BedtimeStep.age, // Always ask age so stories are always age-appropriate
        );
        break;

      case BedtimeStep.age:
        final ageAnswer = await _askQuestion(
          "How old are you? Say a number like five, seven, or ten.",
        );
        final parsed = _parseAge(ageAnswer);
        _resolvedAge = parsed > 0 ? parsed : (widget.childAge > 0 ? widget.childAge : 8);
        _advance(BedtimeStep.heroName);
        break;

      case BedtimeStep.heroName:
        final answer = await _askQuestion(
          "What's your hero's name? Or should I use ${widget.childName}?",
        );
        _heroName = answer.isNotEmpty ? answer : widget.childName;
        _advance(BedtimeStep.companion);
        break;

      case BedtimeStep.companion:
        final answer = await _askQuestion(_companionPrompt());
        _companionChoice = _fuzzyMatchCompanion(answer);
        _advance(BedtimeStep.listeners);
        break;

      case BedtimeStep.listeners:
        final listenersAnswer = await _askQuestion(
          "Are any brothers, sisters, or friends listening with you tonight? Say their names, or say 'just me'.",
        );
        _listenerNames = _parseListenerNames(listenersAnswer);
        _advance(BedtimeStep.setting);
        break;

      case BedtimeStep.setting:
        final answer = await _askQuestion(_settingPrompt());
        _settingChoice = _fuzzyMatchScenario(answer);
        _advance(BedtimeStep.feeling);
        break;

      case BedtimeStep.feeling:
        final feelingPrompt = _isMature
            ? "What's the vibe? Brave, funny, friendship, or atmospheric?"
            : "What kind of story? A brave adventure, a funny story, a story about friendship, or a calming story?";
        final answer = await _askQuestion(feelingPrompt);
        _feelingChoice = _matchStoryMood(answer);
        _advance(BedtimeStep.duration);
        break;

      case BedtimeStep.duration:
        final answer = await _askQuestion(
          _isMature
              ? "How long should the story be? Ten, fifteen, or twenty minutes?"
              : "How long should the bedtime story be? Ten, fifteen, or twenty minutes?",
        );
        _storyDurationMinutes = _matchDurationMinutes(answer);
        _advance(BedtimeStep.confirm);
        break;

      case BedtimeStep.confirm:
        final listenersText = _listenerNames.isEmpty
            ? ''
            : ', with ${_listenerNames.join(' and ')}';
        final summary =
            "$_heroName$listenersText and $_companionChoice in $_settingChoice. A $_feelingChoice story for $_storyDurationMinutes minutes.";
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
        final genPrompt = _isMature
            ? "Writing your story now. Give it a moment..."
            : "Making your story now. Close your eyes and imagine...";
        await _speak(genPrompt);
        await _generateAndReadStory();
        break;

      case BedtimeStep.reading:
        break;

      case BedtimeStep.done:
        final donePrompt = _isMature
            ? "That's the end. Rest well, ${widget.childName}."
            : "The end. Goodnight, ${widget.childName}. Sweet dreams.";
        await _speak(donePrompt);
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

  String _companionPrompt() {
    switch (_ageBand) {
      case AgeBand.sprout:
      case AgeBand.explorer:
        return "Who's coming with $_heroName? Fluffy Dragon, Magic Bunny, Moon Owl, Star Fox, or someone else?";
      case AgeBand.adventurer:
        return "Who's joining $_heroName? Thunder Wolf, Shadow Panther, Crystal Phoenix, Robin, or someone else?";
      case AgeBand.creator:
      case AgeBand.adolescent:
      case AgeBand.adult:
        return "Who's with $_heroName tonight? Thunder Wolf, Shadow Panther, Crystal Phoenix, Robin, or someone you invent?";
    }
  }

  String _fuzzyMatchCompanion(String input) {
    final lower = input.toLowerCase();
    final companions = switch (_ageBand) {
      AgeBand.sprout || AgeBand.explorer => {
          'dragon': 'Fluffy Dragon',
          'fluffy': 'Fluffy Dragon',
          'bunny': 'Magic Bunny',
          'rabbit': 'Magic Bunny',
          'owl': 'Moon Owl',
          'moon': 'Moon Owl',
          'fox': 'Star Fox',
          'star': 'Star Fox',
          'puppy': 'Shining Puppy',
          'dog': 'Shining Puppy',
          'fairy': 'Tiny Fairy',
          'robin': 'Robin',
        },
      AgeBand.adventurer ||
      AgeBand.creator ||
      AgeBand.adolescent ||
      AgeBand.adult => {
          'wolf': 'Thunder Wolf',
          'thunder': 'Thunder Wolf',
          'panther': 'Shadow Panther',
          'shadow': 'Shadow Panther',
          'phoenix': 'Crystal Phoenix',
          'crystal': 'Crystal Phoenix',
          'robin': 'Robin',
          'hawk': 'Thunder Wolf',
          'lynx': 'Shadow Panther',
          'golem': 'Crystal Phoenix',
          'sprite': 'Robin',
        },
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
    return input.isNotEmpty ? input : _defaultCompanion();
  }

  String _defaultCompanion() {
    switch (_ageBand) {
      case AgeBand.sprout:
      case AgeBand.explorer:
        return 'Fluffy Dragon';
      case AgeBand.adventurer:
      case AgeBand.creator:
      case AgeBand.adolescent:
      case AgeBand.adult:
        return 'Thunder Wolf';
    }
  }

  String _settingPrompt() {
    switch (_ageBand) {
      case AgeBand.sprout:
      case AgeBand.explorer:
        return 'Where should the story go? A rainbow world, a magical forest, a cave full of crystals, or somewhere you make up?';
      case AgeBand.adventurer:
        return 'Where should the story go? A ruined citadel, a tidal shrine, an orbital station, a deep archive, or somewhere you invent?';
      case AgeBand.creator:
      case AgeBand.adolescent:
      case AgeBand.adult:
        return 'Where should the story unfold? A deep archive, a tidal shrine, an orbital station, a quiet city roof, or somewhere entirely your own?';
    }
  }

  String _fuzzyMatchScenario(String input) {
    final lower = input.toLowerCase();
    if (_isYoung) {
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
        return 'Life Quest';
      }
      if (lower.contains('forest') || lower.contains('magic')) {
        return 'Magical Forest';
      }
      return input.isNotEmpty ? input : _defaultSetting();
    }
    if (lower.contains('archive') || lower.contains('library')) {
      return 'Deep Archive';
    }
    if (lower.contains('tidal') || lower.contains('shrine') || lower.contains('ocean')) {
      return 'Tidal Shrine';
    }
    if (lower.contains('orbit') || lower.contains('station') || lower.contains('space')) {
      return 'Orbital Station';
    }
    if (lower.contains('citadel') || lower.contains('ruin')) {
      return 'Ruined Citadel';
    }
    if (lower.contains('roof') || lower.contains('city')) {
      return 'Quiet City Roof';
    }
    return input.isNotEmpty ? input : _defaultSetting();
  }

  String _defaultSetting() {
    switch (_ageBand) {
      case AgeBand.sprout:
      case AgeBand.explorer:
        return 'Magical Forest';
      case AgeBand.adventurer:
        return 'Ruined Citadel';
      case AgeBand.creator:
      case AgeBand.adolescent:
      case AgeBand.adult:
        return 'Deep Archive';
    }
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

  List<String> _parseListenerNames(String input) {
    final lower = input.toLowerCase().trim();
    if (lower.isEmpty ||
        lower.contains('just me') ||
        lower.contains('nobody') ||
        lower.contains('no one') ||
        lower.contains('only me')) {
      return [];
    }
    final parts = input
        .replaceAll(' and ', ',')
        .replaceAll(' with ', ',')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length >= 2)
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .toList();
    return parts.take(5).toList();
  }

  int _parseAge(String input) {
    final wordToNum = {
      'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
      'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11,
      'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
      'sixteen': 16, 'seventeen': 17, 'eighteen': 18,
    };
    final lower = input.toLowerCase();
    for (final entry in wordToNum.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    final digits = RegExp(r'\d+').firstMatch(input);
    if (digits != null) {
      final n = int.tryParse(digits.group(0)!);
      if (n != null && n >= 2 && n <= 18) return n;
    }
    return 0;
  }

  int _matchDurationMinutes(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('20') || lower.contains('twenty')) return 20;
    if (lower.contains('10') || lower.contains('ten')) return 10;
    if (lower.contains('15') || lower.contains('fifteen')) return 15;
    return 15;
  }

  void _selectDuration(int minutes) {
    if (!mounted) return;
    setState(() => _storyDurationMinutes = minutes);
  }

  Future<void> _generateAndReadStory() async {
    _wizardData.characterName = _heroName ?? widget.childName;
    _wizardData.characterAge = _effectiveAge;
    _wizardData.companionNames = [_companionChoice ?? _defaultCompanion()];
    _wizardData.customElements = '$_feelingChoice story about $_settingChoice';
    _wizardData.storyLength = 'standard';

    final requestData = WizardDataMapper.mapToStoryRequest(_wizardData);
    final additionalChars = _listenerNames
        .map((n) => <String, dynamic>{'name': n})
        .toList();

    try {
      if (widget.isInteractive) {
        await _runInteractiveStoryLoop(requestData);
      } else {
        await _runRegularStory(requestData, additionalChars);
      }
    } catch (e) {
      await _speak(
          "Oh no, something went wrong making the story. Let's try again tomorrow. Goodnight!");
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _runRegularStory(
    Map<String, dynamic> requestData,
    List<Map<String, dynamic>> additionalChars,
  ) async {
    final result = await ApiServiceManager.generateStory(
        characterName: requestData['character'] ?? 'Hero',
        age: requestData['age'] ?? 5,
        theme: _settingChoice ?? 'Magical Adventure',
        companion: requestData['companion'] ?? '',
        characterDetails: requestData['characterDetails'],
        currentFeeling: null,
        additionalCharacters: additionalChars.isEmpty
            ? null
            : additionalChars.map((m) => m['name'] as String).toList(),
        includeIllustrations: false,
        rhymeTimeMode: false,
        learningToReadMode: false,
        companionPets: requestData['companion_pets'],
        companionCharacters: requestData['companion_characters'],
        storyLength: requestData['storyLength'] ?? 'standard',
        customElements: requestData['customElements'] ?? '',
        bedtimeMode: true,
        bedtimeMood: _feelingChoice ?? 'calming',
        bedtimeDurationMinutes: _storyDurationMinutes,
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

  Widget _buildByokSetupCard(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.nights_stay_rounded, color: Colors.amber, size: 56),
              const SizedBox(height: 20),
              const Text(
                'Set Up Bedtime Stories',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bedtime stories play without a screen — your child just listens. '
                      'This uses a free Gemini AI key that you add once and never need to touch again.',
                      style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                    ),
                    SizedBox(height: 14),
                    Text('How to get your free key:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    _SetupStep(number: '1', text: 'Visit aistudio.google.com (free Google account)'),
                    _SetupStep(number: '2', text: 'Click "Get API key" → "Create API key"'),
                    _SetupStep(number: '3', text: 'Copy the key'),
                    _SetupStep(number: '4', text: 'Open Settings in this app and paste it under "Gemini API Key"'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  final nav = Navigator.of(context, rootNavigator: true);
                  Navigator.of(context).pop();
                  nav.push(MaterialPageRoute(
                    builder: (_) => const ParentControlsScreen(),
                  ));
                },
                icon: const Icon(Icons.settings),
                label: const Text('Go to Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: const Color(0xFF0D0B2E),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Not now', style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_step == BedtimeStep.byokSetup) return _buildByokSetupCard(context);

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
                if (_step == BedtimeStep.duration) ...[
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    alignment: WrapAlignment.center,
                    children: [10, 15, 20]
                        .map(
                          (minutes) => ChoiceChip(
                            label: Text('$minutes min'),
                            selected: _storyDurationMinutes == minutes,
                            onSelected: (_) => _selectDuration(minutes),
                            selectedColor:
                                Colors.amber.withValues(alpha: 0.3),
                            labelStyle: TextStyle(
                              color: _storyDurationMinutes == minutes
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.8),
                            ),
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
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

class _SetupStep extends StatelessWidget {
  final String number;
  final String text;
  const _SetupStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: const BoxDecoration(
              color: Color(0xFFFFD700),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Color(0xFF0D0B2E),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

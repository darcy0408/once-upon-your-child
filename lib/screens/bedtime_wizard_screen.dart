import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/app_tts_service.dart';
import '../services/api_service_manager.dart';
import '../models/story_generation_result.dart' show StoryGenerationCancelled;
import '../models.dart';
import '../models/hero_saga.dart';
import '../models/local/hero_profile_local.dart';
import '../providers/hero_profile_provider.dart';
import '../providers/hero_saga_provider.dart';
import '../theme/age_band_theme.dart';
import 'wizard_steps/superhero_entry_screen.dart' show SuperheroEntryScreen;
import 'wizard_steps/wizard_data_mapper.dart';

/// Voice-driven bedtime story wizard.
/// Minimal screen — just a pulsing star and voice interaction.
class BedtimeWizardScreen extends ConsumerStatefulWidget {
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
  ConsumerState<BedtimeWizardScreen> createState() =>
      _BedtimeWizardScreenState();
}

enum BedtimeStep {
  greeting,   // "Hi [name]! Let's make a bedtime story!"
  age,        // "How old are you?" (only asked if age unknown)
  sagaOffer,  // Returning hero with continuity — "continue your saga?"
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

class _BedtimeWizardScreenState extends ConsumerState<BedtimeWizardScreen>
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

  // Saga continuity (MT-235): a returning hero's saved profile + saga, keyed
  // by the same stable name-derived id the superhero flow uses. Loaded on
  // init; when continuity exists the wizard offers "continue your saga" and
  // the story runs as the next Issue (superhero theme + prior_saga) with a
  // calming bedtime overlay applied server-side.
  String _characterId = '';
  HeroSaga? _saga;
  HeroProfileLocal? _heroProfile;
  bool _continueSaga = false;

  // UI state
  String _statusText = '';

  // Tap-to-choose fallback: choice chips shown alongside each question so the
  // flow still works when the mic is unavailable (web/desktop/denied
  // permission) or a child prefers tapping. A tap resolves the same await
  // that speech does.
  List<String> _choiceOptions = [];
  Completer<String>? _tapCompleter;

  // PERF-04: backend task id of the in-flight generation. dispose() cancels the
  // worker if the user leaves before the story is ready. Nulled once the story
  // arrives so a later dispose doesn't fire a pointless cancel.
  String? _activeTaskId;
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
  bool get _isSprout => _ageBand == AgeBand.sprout;

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
    await _speak(_isMature
        ? "Time's up. Rest well, ${widget.childName}."
        : "It's time for sleep now. Goodnight, ${widget.childName}. Sweet dreams.");
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _initAndStart() async {
    _speechAvailable = await _speech.initialize();
    _resolvedAge = widget.childAge > 0 ? widget.childAge : 0;
    // Load any saved hero + saga for this child so bedtime can continue the
    // story where the superhero flow left off. Continuity is a bonus — a
    // failed load must never block bedtime.
    _wizardData.characterName = widget.childName;
    _characterId = SuperheroEntryScreen.resolveCharacterId(_wizardData);
    try {
      _saga = await ref.read(heroSagaProvider(_characterId).future);
      _heroProfile = await ref.read(heroProfileProvider(_characterId).future);
    } catch (_) {
      _saga = null;
      _heroProfile = null;
    }
    await _runStep();
  }

  /// Whether this child can be offered a saga continuation tonight: they have
  /// recorded at least one Issue and are in a band that runs the Hero Saga.
  bool get _canOfferSaga =>
      (_saga?.hasContinuity ?? false) && _ageBand.usesHeroSaga;

  /// The step after age is known: returning heroes get the saga offer.
  BedtimeStep get _stepAfterAge =>
      _canOfferSaga ? BedtimeStep.sagaOffer : BedtimeStep.heroName;

  @override
  void dispose() {
    // PERF-04: if the user leaves before the story is ready, abandon the
    // in-flight backend task (best-effort). No-op once it has finished.
    final taskId = _activeTaskId;
    if (taskId != null && taskId.isNotEmpty) {
      unawaited(ApiServiceManager.cancelTask(taskId));
    }
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
        final greeting = _isMature
            ? 'Hey ${widget.childName}. Let\'s build your story. Just talk to me.'
            : 'Hi ${widget.childName}! Let\'s make a magical bedtime story together. Just talk to me!';
        // Only ask age when we don't already know it — re-asking a known
        // child their age every night is pointless friction.
        await _speakAndAdvance(
          greeting,
          _resolvedAge > 0 ? _stepAfterAge : BedtimeStep.age,
        );
        break;

      case BedtimeStep.age:
        final ageAnswer = await _askQuestion(
          "How old are you? Say a number like five, seven, or ten.",
        );
        final parsed = _parseAge(ageAnswer);
        _resolvedAge = parsed > 0 ? parsed : (widget.childAge > 0 ? widget.childAge : 8);
        _advance(_stepAfterAge);
        break;

      case BedtimeStep.sagaOffer:
        final saga = _saga!;
        final savedHeroName = _heroProfile?.heroName?.trim();
        final heroLabel = (savedHeroName != null && savedHeroName.isNotEmpty)
            ? savedHeroName
            : widget.childName;
        // Spoken "Previously in your saga…" — same continuity fields the
        // welcome-back screen renders, condensed for the ear.
        final recap = StringBuffer();
        if (saga.whatChanged != null && saga.whatChanged!.isNotEmpty) {
          recap.write('Last time, ${saga.whatChanged}. ');
        }
        if (saga.nextHook != null && saga.nextHook!.isNotEmpty) {
          recap.write('And remember: ${saga.nextHook} ');
        }
        await _speak('$heroLabel is back! $recap');
        final answer = await _askQuestion(
          'Shall we find out what happens next in issue ${saga.issueNumber + 1} '
          'of your saga? Or say "new story" for something brand new.',
          options: const ['Continue the saga', 'New story'],
        );
        final lower = answer.toLowerCase();
        final wantsNew = lower.contains('new') ||
            lower.contains('different') ||
            lower.contains('fresh') ||
            lower.contains('no');
        final wantsContinue = lower.contains('continue') ||
            lower.contains('saga') ||
            lower.contains('next') ||
            _isAffirmative(answer);
        if (!wantsNew && wantsContinue) {
          // Silence counts as yes — continuing the saga is the cozy default
          // for a returning hero at bedtime.
          _continueSaga = true;
          _heroName = heroLabel;
          _feelingChoice = 'calming';
          _advance(BedtimeStep.duration);
        } else {
          _advance(BedtimeStep.heroName);
        }
        break;

      case BedtimeStep.heroName:
        final answer = await _askQuestion(
          "What's your hero's name? Or should I use ${widget.childName}?",
          options: widget.childName.trim().isNotEmpty
              ? [widget.childName.trim()]
              : const [],
        );
        _heroName = answer.isNotEmpty ? answer : widget.childName;
        _advance(BedtimeStep.companion);
        break;

      case BedtimeStep.companion:
        final answer =
            await _askQuestion(_companionPrompt(), options: _companionOptions());
        _companionChoice = _fuzzyMatchCompanion(answer);
        // Sprout (3-5) gets the shortest possible flow: no listeners, feeling,
        // duration, or read-back — companion, place, story. Duration stays 0
        // (= unsent) so the backend's band word caps rule: an explicit
        // duration OVERRIDES them, and 10 minutes of prose is far too long
        // for this band.
        if (_isSprout) {
          _feelingChoice = 'calming';
          _storyDurationMinutes = 0;
          _advance(BedtimeStep.setting);
        } else {
          _advance(BedtimeStep.listeners);
        }
        break;

      case BedtimeStep.listeners:
        final listenersAnswer = await _askQuestion(
          "Are any brothers, sisters, or friends listening with you tonight? Say their names, or say 'just me'.",
          options: const ['Just me'],
        );
        _listenerNames = _parseListenerNames(listenersAnswer);
        _advance(BedtimeStep.setting);
        break;

      case BedtimeStep.setting:
        final answer =
            await _askQuestion(_settingPrompt(), options: _settingOptions());
        _settingChoice = _fuzzyMatchScenario(answer);
        _advance(
            _isSprout ? BedtimeStep.generating : BedtimeStep.feeling);
        break;

      case BedtimeStep.feeling:
        final feelingPrompt = _isMature
            ? "What's the vibe? Brave, funny, friendship, or atmospheric?"
            : "What kind of story? A brave adventure, a funny story, a story about friendship, or a calming story?";
        final answer = await _askQuestion(
          feelingPrompt,
          options: const ['Brave', 'Funny', 'Friendship', 'Calming'],
        );
        _feelingChoice = _matchStoryMood(answer);
        _advance(BedtimeStep.duration);
        break;

      case BedtimeStep.duration:
        final answer = await _askQuestion(
          _isMature
              ? "How long should the story be? Ten, fifteen, or twenty minutes?"
              : "How long should the bedtime story be? Ten, fifteen, or twenty minutes?",
          options: const ['10 minutes', '15 minutes', '20 minutes'],
        );
        _storyDurationMinutes = _matchDurationMinutes(answer);
        // A saga continuation was already confirmed at the offer step — no
        // recipe to read back, go straight to generating.
        _advance(
            _continueSaga ? BedtimeStep.generating : BedtimeStep.confirm);
        break;

      case BedtimeStep.confirm:
        final listenersText = _listenerNames.isEmpty
            ? ''
            : ', with ${_listenerNames.join(' and ')}';
        final summary =
            "$_heroName$listenersText and $_companionChoice in $_settingChoice. A $_feelingChoice story for $_storyDurationMinutes minutes.";
        final answer = await _askQuestion(
          "Here's your story recipe: $summary. Shall I make it? Say yes, or tell me what to change.",
          options: const ['Yes!', 'Change it'],
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

  /// One guided wind-down breath, spoken as the story begins — the
  /// transition beat between wizard-question energy and listening
  /// stillness. Voice-led with wall-clock breath timing (real pauses, not
  /// TTS ellipses) while the ambient orb slows to breath tempo. Any TTS
  /// failure falls through to the story; a fired sleep timer skips it.
  Future<void> _windDownBreath() async {
    if (_timerExpired || !mounted) return;
    _orbController.duration = const Duration(seconds: 5);
    _orbController.repeat(reverse: true);
    try {
      await _speak(_isMature
          ? 'Almost ready. One slow breath first. In through your nose…'
          : 'Your story is almost here. First, one big sleepy breath. '
              'Breathe in… slow…');
      await Future.delayed(const Duration(seconds: 4));
      if (_timerExpired || !mounted) return;
      await _speak(_isMature
          ? '…and slowly out.'
          : '…and let it out… slow and soft…');
      await Future.delayed(const Duration(seconds: 6));
    } catch (_) {
      // Never let the breath block the story.
    } finally {
      if (mounted) {
        _orbController.duration = const Duration(seconds: 3);
        _orbController.repeat(reverse: true);
      }
    }
  }

  Future<String> _askQuestion(String question,
      {List<String> options = const []}) async {
    if (mounted && options.isNotEmpty) {
      setState(() => _choiceOptions = options);
    }
    await _speak(question);

    String answer = '';
    if (_speechAvailable) {
      answer = await _listenOrTap();
      if (answer.isEmpty) {
        // One gentle retry before improvising — kids often need a beat.
        await _speak("I didn't catch that. One more time?");
        answer = await _listenOrTap();
      }
    } else if (options.isNotEmpty) {
      // No mic — the chips are the whole interface for this question.
      answer = await _waitForTap(const Duration(seconds: 45));
    }

    if (answer.isEmpty) {
      await _speak(
          _isYoung ? "I'll surprise you!" : "I'll pick something good.");
    }
    if (mounted) setState(() => _choiceOptions = []);
    return answer;
  }

  /// Races speech recognition against a chip tap; first answer wins.
  Future<String> _listenOrTap() async {
    _tapCompleter = Completer<String>();
    final answer =
        await Future.any([_listen(), _tapCompleter!.future]);
    _tapCompleter = null;
    // If the tap won, _listen is still running — stop it so its onResult
    // can't overwrite the chosen answer's status text.
    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
    return answer;
  }

  Future<String> _waitForTap(Duration timeout) async {
    _tapCompleter = Completer<String>();
    final answer =
        await _tapCompleter!.future.timeout(timeout, onTimeout: () => '');
    _tapCompleter = null;
    return answer;
  }

  void _onChipTap(String option) {
    final c = _tapCompleter;
    if (c != null && !c.isCompleted) c.complete(option);
    if (mounted) setState(() => _statusText = '"$option"');
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
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
      ),
    );

    final answer = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => '',
    );

    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
    return answer;
  }

  List<String> _companionOptions() {
    switch (_ageBand) {
      case AgeBand.sprout:
      case AgeBand.explorer:
        return const ['Fluffy Dragon', 'Magic Bunny', 'Moon Owl', 'Star Fox'];
      case AgeBand.adventurer:
      case AgeBand.creator:
      case AgeBand.adolescent:
      case AgeBand.adult:
        return const [
          'Thunder Wolf',
          'Shadow Panther',
          'Crystal Phoenix',
          'Robin'
        ];
    }
  }

  List<String> _settingOptions() {
    switch (_ageBand) {
      case AgeBand.sprout:
      case AgeBand.explorer:
        return const [
          'Rainbow World',
          'Magical Forest',
          'Cave Full of Crystals'
        ];
      case AgeBand.adventurer:
        return const [
          'Ruined Citadel',
          'Tidal Shrine',
          'Orbital Station',
          'Deep Archive'
        ];
      case AgeBand.creator:
      case AgeBand.adolescent:
      case AgeBand.adult:
        return const [
          'Deep Archive',
          'Tidal Shrine',
          'Orbital Station',
          'Quiet City Roof'
        ];
    }
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
        return _ageBand == AgeBand.sprout ? 'Big Feelings' : 'Life Quest';
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
      // Saga continuations always run as a single narrated Issue — the
      // interactive endpoints have no saga support.
      if (widget.isInteractive && !_continueSaga) {
        await _runInteractiveStoryLoop(requestData);
      } else {
        await _runRegularStory(requestData, additionalChars);
      }
    } on StoryGenerationCancelled {
      // PERF-01 cancellation polish: the user abandoned the wizard mid-
      // generation (dispose fired cancelTask). Not an error — don't speak the
      // failure line. Just leave quietly; dispose() handles teardown.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      await _speak(_isMature
          ? "Something went wrong generating the story. Try again in a moment."
          : "Oh no, something went wrong making the story. Let's try again tomorrow. Goodnight!");
      if (mounted) Navigator.of(context).pop();
    } finally {
      // PERF-01/PERF-04: clear the task id once generation has ended, whether
      // it succeeded, threw, or was cancelled. Without this, a throw on the
      // generation path would leave _activeTaskId set, so a later dispose()
      // would fire a pointless cancel against an already-terminal task.
      // Mirrors quick_story_screen.dart, which nulls its id in the success
      // path and never re-fires after failure. The success path in
      // _runRegularStory already nulls it before reading; this is the safety
      // net for the error/cancel paths.
      _activeTaskId = null;
    }
  }

  Future<void> _runRegularStory(
    Map<String, dynamic> requestData,
    List<Map<String, dynamic>> additionalChars,
  ) async {
    // Saga continuation: run the superhero path (the only one that consumes
    // prior_saga and emits saga_state) with the saved hero's identity; the
    // backend layers its calming bedtime overlay on top.
    final continuing = _continueSaga && _saga != null;
    final profile = _heroProfile;
    final result = await ApiServiceManager.generateStory(
        characterName: requestData['character'] ?? 'Hero',
        age: requestData['age'] ?? 5,
        theme: continuing ? 'superhero' : (_settingChoice ?? 'Magical Adventure'),
        characterId: requestData['character_id']?.toString(),
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
        heroCostumeColor: continuing ? profile?.costumeColor : null,
        heroCapeStyle: continuing ? profile?.capeStyle : null,
        heroEmblem: continuing ? profile?.emblem : null,
        heroPower: continuing ? profile?.power : null,
        heroAlias: continuing ? profile?.heroName : null,
        recentVillains: continuing ? profile?.recentVillains : null,
        recentProblems: continuing ? profile?.recentProblems : null,
        priorSaga: continuing ? _saga!.toPriorSaga() : null,
        // PERF-04: capture the task id so dispose() can cancel if abandoned.
        onTaskId: (id) => _activeTaskId = id,
        onProgress: (status) {
          if (mounted) setState(() => _statusText = status);
        });
    // PERF-04: story text is in hand — nothing left to cancel.
    _activeTaskId = null;

    // Fold the completed Issue back into the saga so the next bedtime (or the
    // visual superhero flow) picks up where tonight left off. Non-fatal — the
    // story still reads if persistence fails.
    if (continuing) {
      final rawSaga = result.superheroMeta?['saga_state'];
      if (rawSaga is Map) {
        try {
          await ref.read(heroSagaControllerProvider.notifier).recordIssue(
                _characterId,
                Map<String, dynamic>.from(rawSaga),
                heroCode: _saga?.heroCode,
                title: result.title,
              );
        } catch (_) {}
      }
    }

    setState(() => _step = BedtimeStep.reading);

    // Wind-down beat: one guided breath between "it's ready" and the first
    // line, so the story starts on a settled exhale.
    await _windDownBreath();

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

    // Wind-down beat before the first segment request — for pick-a-path the
    // breath doubles as cover for the opening generation wait.
    await _windDownBreath();

    final characterName = requestData['character'] ?? 'Hero';
    final theme = _settingChoice ?? 'Magical Adventure';
    final companion = requestData['companion'] ?? '';

    Map<String, dynamic> currentSegment =
        await ApiServiceManager.generateInteractiveStory(
      characterName: characterName,
      age: requestData['age'] ?? 5,
      theme: theme,
      companion: companion,
      // Bedtime voice mode: keep the pick-a-path segments soft-edged.
      tone: 'cozy-adventure',
      includeImages: false, // audio-only: never renders image_url
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
      final choices = choicesRaw is List
          ? choicesRaw.map((c) => c.toString()).toList()
          : const <String>[];
      if (choices.length >= 2) {
        question =
            "Do you want to ${choices[0]}, or ${choices[1]}? Or something else?";
      } else if (choices.length == 1) {
        question = "Do you want to ${choices[0]}? Or something else?";
      }

      final answer = await _askQuestion(question, options: choices);
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
        includeImages: false, // audio-only: never renders image_url
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
                // Tap-to-choose chips: shown for every choice question so
                // the flow works without a mic. Kept dim — the screen should
                // stay ignorable.
                if (_choiceOptions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _choiceOptions
                        .map(
                          (option) => ActionChip(
                            label: Text(option),
                            onPressed: () => _onChipTap(option),
                            labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
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

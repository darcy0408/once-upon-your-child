// lib/screens/adult_meditation_screen.dart
//
// Adult Reflect screen — mindful breathing, grounding prompts, and thematic
// reflective questions drawn from the adult world bible themes.
// Visual style: dark #08080E background, amber-gold #BFA45A accents.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Palette ──────────────────────────────────────────────────────────────────

const Color _kBackground = Color(0xFF08080E);
const Color _kSurface = Color(0xFF12121C);
const Color _kGold = Color(0xFFBFA45A);
const Color _kGoldDim = Color(0x66BFA45A);
const Color _kText = Color(0xFFE8E2D4);
const Color _kSubtext = Color(0xFF8A8270);

// ── Reflection prompts (cycle through on each visit) ─────────────────────────

const List<String> _kReflectivePrompts = [
  "Which door do you keep coming back to?",
  "What are you still carrying that was never yours to carry?",
  "What are you trying not to feel right now?",
  "What would it mean to put it down — even for today?",
  "Where in your body does the answer already live?",
  "What part of you has been waiting to be heard?",
  "What do you need that you haven't asked for?",
  "What would you tell yourself five years ago?",
  "What feels true right now, even if it's hard?",
  "What are you ready to let soften?",
];

// ── Grounding anchors ─────────────────────────────────────────────────────────

const List<String> _kGroundingAnchors = [
  "5 things you can see",
  "4 things you can touch",
  "3 things you can hear",
  "2 things you can smell",
  "1 thing you can taste",
];

// ── Breathing patterns ────────────────────────────────────────────────────────

class _BreathPattern {
  final String name;
  final String description;
  final int inhale;   // seconds
  final int hold1;
  final int exhale;
  final int hold2;

  const _BreathPattern({
    required this.name,
    required this.description,
    required this.inhale,
    required this.hold1,
    required this.exhale,
    required this.hold2,
  });

  int get cycleDuration => inhale + hold1 + exhale + hold2;
}

const List<_BreathPattern> _kPatterns = [
  _BreathPattern(
    name: '4-7-8 Calm',
    description: 'Calms the nervous system',
    inhale: 4,
    hold1: 7,
    exhale: 8,
    hold2: 0,
  ),
  _BreathPattern(
    name: 'Box Breath',
    description: 'Builds focus and steadiness',
    inhale: 4,
    hold1: 4,
    exhale: 4,
    hold2: 4,
  ),
  _BreathPattern(
    name: 'Physiological Sigh',
    description: 'Fast reset — double inhale, long exhale',
    inhale: 2,
    hold1: 1,
    exhale: 6,
    hold2: 0,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────

class AdultMeditationScreen extends StatefulWidget {
  const AdultMeditationScreen({super.key});

  @override
  State<AdultMeditationScreen> createState() => _AdultMeditationScreenState();
}

class _AdultMeditationScreenState extends State<AdultMeditationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Breathing state
  int _patternIndex = 0;
  bool _breathing = false;
  String _breathPhase = 'Tap to begin';
  int _phaseSecondsLeft = 0;
  int _cyclesCompleted = 0;
  Timer? _breathTimer;
  int _breathElapsed = 0; // seconds into current cycle

  // Reflect state
  int _promptIndex = 0;
  String _journalDraft = '';
  List<_ReflectEntry> _entries = [];
  final TextEditingController _journalCtrl = TextEditingController();

  // Grounding state
  int _groundingStep = 0;
  bool _groundingActive = false;

  static const String _kEntriesKey = 'adult_reflect_entries';
  static const String _kPromptKey = 'adult_reflect_prompt_index';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadState();
  }

  @override
  void dispose() {
    _breathTimer?.cancel();
    _tabs.dispose();
    _journalCtrl.dispose();
    super.dispose();
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kEntriesKey) ?? [];
    final savedPrompt = prefs.getInt(_kPromptKey) ?? 0;
    setState(() {
      _entries = raw.map(_ReflectEntry.fromJson).toList();
      _promptIndex = savedPrompt % _kReflectivePrompts.length;
    });
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _kEntriesKey, _entries.map((e) => e.toJson()).toList());
  }

  Future<void> _advancePrompt() async {
    final next = (_promptIndex + 1) % _kReflectivePrompts.length;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPromptKey, next);
    setState(() => _promptIndex = next);
  }

  // ── Breathing engine ─────────────────────────────────────────────────────────

  _BreathPattern get _pattern => _kPatterns[_patternIndex];

  void _toggleBreathing() {
    if (_breathing) {
      _stopBreathing();
    } else {
      _startBreathing();
    }
  }

  void _startBreathing() {
    setState(() {
      _breathing = true;
      _breathElapsed = 0;
      _cyclesCompleted = 0;
    });
    _tick();
    _breathTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopBreathing() {
    _breathTimer?.cancel();
    setState(() {
      _breathing = false;
      _breathPhase = 'Tap to begin';
      _phaseSecondsLeft = 0;
      _breathElapsed = 0;
    });
  }

  void _tick() {
    final p = _pattern;
    final pos = _breathElapsed % p.cycleDuration;

    String phase;
    int left;

    if (pos < p.inhale) {
      phase = 'Breathe in';
      left = p.inhale - pos;
    } else if (pos < p.inhale + p.hold1) {
      phase = 'Hold';
      left = p.inhale + p.hold1 - pos;
    } else if (pos < p.inhale + p.hold1 + p.exhale) {
      phase = 'Breathe out';
      left = p.inhale + p.hold1 + p.exhale - pos;
    } else {
      phase = 'Hold';
      left = p.cycleDuration - pos;
    }

    final newCycles = _breathElapsed ~/ p.cycleDuration;

    setState(() {
      _breathPhase = phase;
      _phaseSecondsLeft = left;
      _cyclesCompleted = newCycles;
      _breathElapsed++;
    });
  }

  // ── Reflect / journal ────────────────────────────────────────────────────────

  void _saveJournalEntry() {
    final text = _journalCtrl.text.trim();
    if (text.isEmpty) return;
    final entry = _ReflectEntry(
      prompt: _kReflectivePrompts[_promptIndex],
      response: text,
      timestamp: DateTime.now(),
    );
    setState(() {
      _entries.insert(0, entry);
      if (_entries.length > 50) _entries = _entries.sublist(0, 50);
      _journalCtrl.clear();
      _journalDraft = '';
    });
    _saveEntries();
    _advancePrompt();
    FocusScope.of(context).unfocus();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _buildDarkTheme(),
      child: Scaffold(
        backgroundColor: _kBackground,
        appBar: AppBar(
          backgroundColor: _kBackground,
          foregroundColor: _kGold,
          elevation: 0,
          title: const Text(
            'Reflect',
            style: TextStyle(
              color: _kGold,
              fontFamily: 'SourceSansPro',
              fontWeight: FontWeight.w300,
              fontSize: 22,
              letterSpacing: 2,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabs,
            labelColor: _kGold,
            unselectedLabelColor: _kSubtext,
            indicatorColor: _kGold,
            indicatorWeight: 1,
            labelStyle: const TextStyle(
              fontFamily: 'SourceSansPro',
              fontSize: 13,
              letterSpacing: 1.2,
            ),
            tabs: const [
              Tab(text: 'BREATHE'),
              Tab(text: 'REFLECT'),
              Tab(text: 'GROUND'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _buildBreatheTab(),
            _buildReflectTab(),
            _buildGroundTab(),
          ],
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: _kBackground,
      colorScheme: const ColorScheme.dark(
        primary: _kGold,
        surface: _kSurface,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: _kText, fontFamily: 'SourceSansPro'),
        bodySmall: TextStyle(color: _kSubtext, fontFamily: 'SourceSansPro'),
      ),
    );
  }

  // ── Breathe tab ──────────────────────────────────────────────────────────────

  Widget _buildBreatheTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          // Pattern selector
          _SectionLabel('Choose a pattern'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_kPatterns.length, (i) {
              final selected = i == _patternIndex;
              return GestureDetector(
                onTap: _breathing
                    ? null
                    : () => setState(() => _patternIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected ? _kGold : _kSubtext,
                      width: selected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    color: selected ? _kGoldDim : Colors.transparent,
                  ),
                  child: Text(
                    _kPatterns[i].name,
                    style: TextStyle(
                      color: selected ? _kGold : _kSubtext,
                      fontFamily: 'SourceSansPro',
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _pattern.description,
            style: const TextStyle(
              color: _kSubtext,
              fontFamily: 'SourceSansPro',
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 40),

          // Breathing orb
          GestureDetector(
            onTap: _toggleBreathing,
            child: _BreathingOrb(
              breathing: _breathing,
              phase: _breathPhase,
              secondsLeft: _phaseSecondsLeft,
              pattern: _pattern,
              elapsed: _breathElapsed,
            ),
          ),

          const SizedBox(height: 32),

          if (_breathing) ...[
            Text(
              '$_cyclesCompleted ${_cyclesCompleted == 1 ? "cycle" : "cycles"} completed',
              style: const TextStyle(
                color: _kSubtext,
                fontFamily: 'SourceSansPro',
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _stopBreathing,
              child: const Text(
                'STOP',
                style: TextStyle(
                  color: _kSubtext,
                  fontFamily: 'SourceSansPro',
                  letterSpacing: 2,
                  fontSize: 12,
                ),
              ),
            ),
          ] else ...[
            const Text(
              'Tap the circle to begin',
              style: TextStyle(
                color: _kSubtext,
                fontFamily: 'SourceSansPro',
                fontSize: 13,
              ),
            ),
          ],

          const SizedBox(height: 24),
          _buildPatternGuide(),
        ],
      ),
    );
  }

  Widget _buildPatternGuide() {
    final p = _pattern;
    final parts = <String>[];
    parts.add('${p.inhale}s in');
    if (p.hold1 > 0) parts.add('${p.hold1}s hold');
    parts.add('${p.exhale}s out');
    if (p.hold2 > 0) parts.add('${p.hold2}s hold');
    return Text(
      parts.join(' · '),
      style: const TextStyle(
        color: _kSubtext,
        fontFamily: 'SourceSansPro',
        fontSize: 12,
        letterSpacing: 1,
      ),
    );
  }

  // ── Reflect tab ──────────────────────────────────────────────────────────────

  Widget _buildReflectTab() {
    final prompt = _kReflectivePrompts[_promptIndex];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Today\'s prompt'),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: _kGoldDim),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '"$prompt"',
              style: const TextStyle(
                color: _kText,
                fontFamily: 'SourceSansPro',
                fontSize: 18,
                fontWeight: FontWeight.w300,
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _journalCtrl,
            maxLines: 5,
            onChanged: (v) => setState(() => _journalDraft = v),
            style: const TextStyle(
              color: _kText,
              fontFamily: 'SourceSansPro',
              fontSize: 15,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: 'Write what comes up…',
              hintStyle: const TextStyle(color: _kSubtext),
              filled: true,
              fillColor: _kSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: _kSubtext),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: _kSubtext),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: _kGold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _advancePrompt,
                child: const Text(
                  'Different prompt',
                  style: TextStyle(
                    color: _kSubtext,
                    fontFamily: 'SourceSansPro',
                    fontSize: 13,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed:
                    _journalDraft.trim().isNotEmpty ? _saveJournalEntry : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGold,
                  foregroundColor: _kBackground,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'SourceSansPro',
                    fontSize: 13,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('SAVE'),
              ),
            ],
          ),

          if (_entries.isNotEmpty) ...[
            const SizedBox(height: 32),
            _SectionLabel('Recent reflections'),
            const SizedBox(height: 12),
            ..._entries.take(5).map((e) => _ReflectCard(entry: e)),
          ],
        ],
      ),
    );
  }

  // ── Ground tab ───────────────────────────────────────────────────────────────

  Widget _buildGroundTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('5-4-3-2-1 Grounding'),
          const SizedBox(height: 8),
          const Text(
            'Anchors you to the present moment by engaging each sense.',
            style: TextStyle(
              color: _kSubtext,
              fontFamily: 'SourceSansPro',
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          if (!_groundingActive) ...[
            Center(
              child: ElevatedButton(
                onPressed: () =>
                    setState(() {
                      _groundingActive = true;
                      _groundingStep = 0;
                    }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGold,
                  foregroundColor: _kBackground,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'BEGIN',
                  style: TextStyle(
                    fontFamily: 'SourceSansPro',
                    letterSpacing: 2,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ] else ...[
            // Progress dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _kGroundingAnchors.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: i <= _groundingStep ? 10 : 6,
                  height: i <= _groundingStep ? 10 : 6,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _groundingStep
                        ? _kGold
                        : (i == _groundingStep ? _kGold : _kSubtext),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Current anchor
            if (_groundingStep < _kGroundingAnchors.length) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  border: Border.all(color: _kGoldDim),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_kGroundingAnchors.length - _groundingStep}',
                      style: const TextStyle(
                        color: _kGold,
                        fontFamily: 'SourceSansPro',
                        fontSize: 64,
                        fontWeight: FontWeight.w200,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _kGroundingAnchors[_groundingStep],
                      style: const TextStyle(
                        color: _kText,
                        fontFamily: 'SourceSansPro',
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Take your time. Notice each one.',
                      style: TextStyle(
                        color: _kSubtext,
                        fontFamily: 'SourceSansPro',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (_groundingStep < _kGroundingAnchors.length - 1) {
                      setState(() => _groundingStep++);
                    } else {
                      setState(() => _groundingActive = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGold,
                    foregroundColor: _kBackground,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(
                    _groundingStep < _kGroundingAnchors.length - 1
                        ? 'NEXT'
                        : 'DONE',
                    style: const TextStyle(
                      fontFamily: 'SourceSansPro',
                      letterSpacing: 2,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Complete
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: _kGold, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Grounded.',
                      style: TextStyle(
                        color: _kGold,
                        fontFamily: 'SourceSansPro',
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () =>
                          setState(() {
                            _groundingActive = false;
                            _groundingStep = 0;
                          }),
                      child: const Text(
                        'Again',
                        style: TextStyle(
                          color: _kSubtext,
                          fontFamily: 'SourceSansPro',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Breathing orb ─────────────────────────────────────────────────────────────

class _BreathingOrb extends StatefulWidget {
  final bool breathing;
  final String phase;
  final int secondsLeft;
  final _BreathPattern pattern;
  final int elapsed;

  const _BreathingOrb({
    required this.breathing,
    required this.phase,
    required this.secondsLeft,
    required this.pattern,
    required this.elapsed,
  });

  @override
  State<_BreathingOrb> createState() => _BreathingOrbState();
}

class _BreathingOrbState extends State<_BreathingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_BreathingOrb old) {
    super.didUpdateWidget(old);
    if (!widget.breathing) {
      _anim.stop();
      _anim.value = 0;
      return;
    }
    final phase = widget.phase;
    if (phase == 'Breathe in') {
      _anim.animateTo(1.0,
          duration: Duration(seconds: widget.pattern.inhale),
          curve: Curves.easeInOut);
    } else if (phase == 'Breathe out') {
      _anim.animateTo(0.0,
          duration: Duration(seconds: widget.pattern.exhale),
          curve: Curves.easeInOut);
    }
    // Hold phases: stay in place
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, _) {
        return SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Transform.scale(
                scale: 0.5 + _scale.value * 0.5,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _kGoldDim, width: 1),
                  ),
                ),
              ),
              // Inner orb
              Transform.scale(
                scale: 0.55 + _scale.value * 0.35,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFF2A2410), _kBackground],
                      stops: [0.3, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kGoldDim,
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              // Phase text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.breathing ? widget.phase : 'Tap to begin',
                    style: const TextStyle(
                      color: _kGold,
                      fontFamily: 'SourceSansPro',
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.breathing && widget.secondsLeft > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${widget.secondsLeft}',
                      style: const TextStyle(
                        color: _kText,
                        fontFamily: 'SourceSansPro',
                        fontSize: 28,
                        fontWeight: FontWeight.w200,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: _kSubtext,
        fontFamily: 'SourceSansPro',
        fontSize: 11,
        letterSpacing: 2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ReflectCard extends StatelessWidget {
  final _ReflectEntry entry;
  const _ReflectCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final date = entry.timestamp;
    final dateStr =
        '${date.day} ${_month(date.month)} ${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF1E1E2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${entry.prompt}"',
            style: const TextStyle(
              color: _kSubtext,
              fontFamily: 'SourceSansPro',
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.response,
            style: const TextStyle(
              color: _kText,
              fontFamily: 'SourceSansPro',
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dateStr,
            style: const TextStyle(
              color: _kSubtext,
              fontFamily: 'SourceSansPro',
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  static String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}

// ── Data model ────────────────────────────────────────────────────────────────

class _ReflectEntry {
  final String prompt;
  final String response;
  final DateTime timestamp;

  const _ReflectEntry({
    required this.prompt,
    required this.response,
    required this.timestamp,
  });

  String toJson() =>
      '${timestamp.millisecondsSinceEpoch}|${prompt.replaceAll('|', ' ')}|$response';

  static _ReflectEntry fromJson(String raw) {
    final parts = raw.split('|');
    if (parts.length < 3) {
      return _ReflectEntry(
        prompt: '',
        response: raw,
        timestamp: DateTime.now(),
      );
    }
    return _ReflectEntry(
      prompt: parts[1],
      response: parts.sublist(2).join('|'),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(parts[0]) ?? 0),
    );
  }
}

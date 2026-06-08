import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../models.dart';
import '../../services/app_tts_service.dart';
import '../../theme/age_band_theme.dart';
import 'superhero_entry_screen.dart';

/// Full-screen "Imagine It / Make One Up" entry point.
///
/// Pushed from the scene-picker when the user taps the Imagine It hero card.
/// Owns its own speech-to-text instance so it is fully self-contained.
/// Returns true on save (selection committed), false/null on cancel.
class ImagineItScreen extends StatefulWidget {
  final WizardData wizardData;
  final TextEditingController imagineItController;
  final TextEditingController wishController;

  const ImagineItScreen({
    super.key,
    required this.wizardData,
    required this.imagineItController,
    required this.wishController,
  });

  @override
  State<ImagineItScreen> createState() => _ImagineItScreenState();
}

class _ImagineItScreenState extends State<ImagineItScreen> {
  static const _gold = Color(0xFFFFD700);

  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _speechInitialized = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _isListening = false);
      },
    );
    if (!mounted) return;
    setState(() {
      _speechAvailable = available;
      _speechInitialized = true;
    });
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (!_speechInitialized) return;
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Microphone unavailable on this device')),
      );
      return;
    }
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    unawaited(AppTtsService.instance
        .speak('Tell me your big story idea!'));
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      ),
      onResult: (result) {
        if (!mounted) return;
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;
        setState(() {
          widget.imagineItController.text = words;
          widget.wishController.text = words;
          widget.wizardData.customElements = words;
          if (result.finalResult) _isListening = false;
        });
      },
    );
  }

  void _save() {
    final value = widget.wizardData.customElements.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tell us your story idea first!')),
      );
      return;
    }
    widget.wizardData.selectedScenario = 'safe_space';
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(true);
  }

  void _cancel() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final isSprout = band.band == AgeBand.sprout;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          isSprout ? 'Make One Up!' : 'Imagine It',
          style: GoogleFonts.fredoka(
            color: _gold,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: _cancel,
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Done',
              style: GoogleFonts.fredoka(
                color: _gold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: band.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: isSprout ? _buildSproutInput() : _buildStandardInput(),
          ),
        ),
      ),
    );
  }

  // ── Standard (Explorer / Adventurer / Creator+) ────────────────────────────

  Widget _buildStandardInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold, width: 2),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C1B47), Color(0xFF1A0E36)],
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withAlpha(50),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'What\'s your adventure about?',
                  style: GoogleFonts.fredoka(
                    color: _gold,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Semantics(
                  label: 'Story idea',
                  textField: true,
                  child: TextField(
                  controller: widget.imagineItController,
                  maxLines: 5,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText:
                        'e.g. ride a magic carpet, trick a witch, swim like a fish, visit Mexico…',
                    hintStyle: const TextStyle(
                        color: _gold,
                        fontSize: 14,
                        fontStyle: FontStyle.italic),
                    filled: true,
                    fillColor: Colors.white.withAlpha(18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: _gold.withAlpha(100)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: _gold, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: _gold.withAlpha(120)),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  onChanged: (value) {
                    setState(() {
                      widget.wizardData.customElements = value;
                      widget.wishController.text = value;
                    });
                  },
                ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _speechAvailable
                    ? 'Speak your setting idea'
                    : 'Mic unavailable',
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _speechAvailable
                      ? (_isListening ? Colors.yellow : Colors.white)
                      : Colors.white38,
                ),
                onPressed: _speechAvailable ? _toggleListening : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _speechAvailable
                ? '🎤 Tap the mic and say your idea out loud.'
                : '✍️ Type your idea here. Mic is unavailable on this device.',
            style: TextStyle(
              color: Colors.white.withAlpha(170),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '✦ The more you describe, the more magical your story becomes!',
            style: TextStyle(
              color: _gold.withAlpha(180),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),
          // Setting-screen audit F-05 (Adventurer): parents glancing at a
          // free-text input on a child's screen want a visible safety cue.
          // Backend sanitizes + injection-screens the input via
          // backend/utils/sanitizer.py + [USER_INPUT] wrapping, so the line
          // is truthful, not aspirational.
          Row(
            children: [
              Icon(Icons.shield_outlined,
                  size: 14, color: Colors.white.withAlpha(130)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'We check what you write to keep stories safe.',
                  style: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _save,
              child: Text(
                'Use this idea!',
                style: GoogleFonts.fredoka(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Superhero entry for Explorer (6-8), Adventurer (9-12), and Creator
          // (13-14 — Hero Saga). Backend prompt routing has a dedicated tier for
          // each (T7_SUPERHERO_EXPLORER / T8_SUPERHERO_ADVENTURER /
          // T9_SUPERHERO_CREATOR). Not exposed to Sprout (3-5) or 15+ yet.
          if (Theme.of(context).extension<AgeBandThemeData>()?.band ==
                  AgeBand.explorer ||
              Theme.of(context).extension<AgeBandThemeData>()?.band ==
                  AgeBand.adventurer ||
              Theme.of(context).extension<AgeBandThemeData>()?.band ==
                  AgeBand.creator) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: Divider(color: _gold.withAlpha(60), thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'or',
                    style: GoogleFonts.fredoka(
                      color: _gold.withAlpha(160),
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                    child: Divider(color: _gold.withAlpha(60), thickness: 1)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _gold, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Text('🦸', style: TextStyle(fontSize: 22)),
                label: Text(
                  'Be a superhero!',
                  style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _gold,
                  ),
                ),
                onPressed: () async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => SuperheroEntryScreen(
                          wizardData: widget.wizardData),
                    ),
                  );
                  if (!mounted) return;
                  if (result == true) {
                    widget.imagineItController.text =
                        widget.wizardData.customElements;
                    widget.wishController.text =
                        widget.wizardData.customElements;
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop(true);
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Sprout (3-5) ───────────────────────────────────────────────────────────

  Widget _buildSproutInput() {
    const ideaStarters = [
      (emoji: '🪄', label: 'Magic carpet', fill: 'riding a magic carpet'),
      (emoji: '🌙', label: 'To the moon', fill: 'going to the moon'),
      (emoji: '🐠', label: 'Be a fish', fill: 'swimming like a fish'),
      (emoji: '🦅', label: 'Learn to fly', fill: 'learning to fly'),
      (emoji: '🦄', label: 'Meet a unicorn', fill: 'meeting a unicorn'),
      (emoji: '🦖', label: 'Meet a dinosaur', fill: 'meeting a dinosaur'),
      (emoji: '🐉', label: 'Dragon friend', fill: 'making friends with a dragon'),
      (emoji: '🦸', label: 'Be a superhero', fill: 'being a superhero'),
    ];
    final hasInput = widget.wizardData.customElements.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold, width: 2),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C1B47), Color(0xFF1A0E36)],
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withAlpha(55),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '✨ What\'s your big idea?',
            style: GoogleFonts.fredoka(
              color: _gold,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _speechAvailable
                ? 'It can be ANYTHING! Tap the button and tell me!'
                : 'It can be ANYTHING! Ask a grown-up to type it below.',
            style: GoogleFonts.fredoka(
              color: Colors.white.withAlpha(210),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          if (_speechAvailable) ...[
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: _isListening ? 'Stop listening' : 'Tap to talk',
              child: GestureDetector(
                onTap: _toggleListening,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? _gold : const Color(0xFF7C3FFF),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? _gold : const Color(0xFF7C3FFF))
                            .withAlpha(_isListening ? 200 : 110),
                        blurRadius: _isListening ? 28 : 16,
                        spreadRadius: _isListening ? 8 : 3,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.black87 : Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _isListening ? '🎧  Listening…' : '🎤  Tap to talk!',
                key: ValueKey(_isListening),
                style: GoogleFonts.fredoka(
                  color: _isListening ? _gold : Colors.white.withAlpha(210),
                  fontSize: 18,
                  fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
          // ── Idea tiles ──────────────────────────────────────────────────
          // Always rendered (even when an idea is already picked) so the kid
          // can switch picks. The matching tile is highlighted in gold to
          // confirm the current selection — and tapping it again re-enters
          // the same flow (e.g. Superhero → welcome-back for returning hero).
          const SizedBox(height: 22),
          Text(
            hasInput
                ? 'Tap a different idea to change it!'
                : 'Or tap an idea to get started!',
            style: GoogleFonts.fredoka(
              color: Colors.white.withAlpha(160),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: ideaStarters.map((idea) {
              final selected =
                  widget.wizardData.customElements.trim() == idea.fill;
              return GestureDetector(
                onTap: () async {
                  if (idea.label == 'Be a superhero') {
                    // Superhero Mode entry point — push the dispatcher
                    // which routes to welcome-back or costume picker.
                    final result =
                        await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => SuperheroEntryScreen(
                            wizardData: widget.wizardData),
                      ),
                    );
                    if (!mounted) return;
                    if (result == true) {
                      // SuperheroPowerScreen has already set scenario,
                      // customElements, and saved the profile. Commit
                      // by popping the ImagineIt screen too.
                      widget.imagineItController.text =
                          widget.wizardData.customElements;
                      widget.wishController.text =
                          widget.wizardData.customElements;
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop(true);
                    }
                    return;
                  }
                  setState(() {
                    widget.imagineItController.text = idea.fill;
                    widget.wizardData.customElements = idea.fill;
                    widget.wishController.text = idea.fill;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 100,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? _gold.withAlpha(50)
                        : Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? _gold : Colors.white38,
                      width: selected ? 3 : 1.5,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: _gold.withAlpha(140),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(idea.emoji,
                          style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 4),
                      Text(
                        idea.label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (hasInput) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withAlpha(30),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF2ECC71).withAlpha(160),
                    width: 1.5),
              ),
              child: Row(
                children: [
                  const Text('✅', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.wizardData.customElements.trim(),
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 17,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Semantics(
            label: 'Story idea',
            textField: true,
            child: TextField(
            controller: widget.imagineItController,
            maxLines: 1,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hasInput
                  ? 'Tap to change the idea…'
                  : '✍️  Grown-ups: type an idea here',
              hintStyle: TextStyle(
                color: Colors.white.withAlpha(100),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
              filled: true,
              fillColor: Colors.white.withAlpha(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _gold.withAlpha(70)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: _gold.withAlpha(160), width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
            ),
            onChanged: (value) {
              setState(() {
                widget.wizardData.customElements = value;
                widget.wishController.text = value;
              });
            },
          ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _save,
              child: Text(
                'Use this idea!',
                style: GoogleFonts.fredoka(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

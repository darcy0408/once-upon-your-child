// lib/story_reader_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'reading_progress_service.dart';
import 'reading_celebration_dialog.dart';
import 'reading_models.dart';
import 'phonics_helper.dart';
import 'story_narrator.dart';
import 'reading_analytics_service.dart';

class StoryReaderScreen extends StatefulWidget {
  final String title;
  final String storyText;
  final String? characterName;

  const StoryReaderScreen({
    super.key,
    required this.title,
    required this.storyText,
    this.characterName,
  });

  @override
  State<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends State<StoryReaderScreen> {
  final FlutterTts flutterTts = FlutterTts();
  final _readingService = ReadingProgressService();
  final _analyticsService = ReadingAnalyticsService();
  late final StoryNarrator _narrator;

  List<String> words = [];
  int currentWordIndex = -1;
  bool isPlaying = false;
  NarrationSettings _narrationSettings = const NarrationSettings();
  int wordsReadCount = 0;

  ScrollController scrollController = ScrollController();

  bool _learnToReadMode = false;
  ReadingProgress? _readingProgress;
  final Set<String> _wordsInteractedWith = {};

  @override
  void initState() {
    super.initState();
    _narrator = StoryNarrator();
    _setupNarrator();
    _parseWords();
    _loadReadingProgress();
    _startAnalyticsSession();
  }

  /// Start tracking reading analytics
  Future<void> _startAnalyticsSession() async {
    await _analyticsService.startSession(
      storyId: widget.title.hashCode.toString(), // Simple ID generation
      storyTitle: widget.title,
      totalWords: words.length,
    );
  }

  Future<void> _loadReadingProgress() async {
    final progress = await _readingService.loadProgress();
    setState(() {
      _readingProgress = progress;
      _learnToReadMode = progress.learnToReadModeEnabled;
    });
  }

  void _setupNarrator() {
    _narrator.onWordHighlight = (index) {
      setState(() {
        currentWordIndex = index;
        if (index >= 0) wordsReadCount = index + 1;
      });
      if (_narrationSettings.autoScroll) {
        _scrollToWord(index);
      }
    };

    _narrator.onNarrationComplete = () {
      setState(() {
        isPlaying = false;
        currentWordIndex = -1;
      });
      _showCompletionDialog();
    };

    _narrator.onPlayingStateChanged = (playing) {
      setState(() {
        isPlaying = playing;
      });
    };
  }

  void _parseWords() {
    // Split story into words for highlighting
    words = widget.storyText.split(RegExp(r'\s+'));
  }

  void _scrollToWord(int index) {
    // Auto-scroll to keep current word visible
    if (scrollController.hasClients) {
      final double position = (index / words.length) * scrollController.position.maxScrollExtent;
      scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _toggleReading() async {
    if (isPlaying) {
      await _pauseReading();
    } else {
      await _startReading();
    }
  }

  Future<void> _startReading() async {
    await _narrator.startNarration(
      widget.storyText,
      speed: _narrationSettings.speed,
      pitch: _narrationSettings.pitch,
    );
  }

  Future<void> _pauseReading() async {
    await _narrator.pauseNarration();
  }

  Future<void> _stopReading() async {
    await _narrator.stopNarration();
    setState(() {
      currentWordIndex = -1;
      wordsReadCount = 0;
    });
  }

  Future<void> _showWordDefinition(String word, int index) async {
    // PAUSE the main story narration so the child can focus on learning this word
    final wasPlaying = isPlaying;
    if (wasPlaying) {
      await _pauseReading();
    }

    // Clean the word of punctuation
    String cleanWord = word.toLowerCase().replaceAll(RegExp(r'''[.,!?;:'"!]'''), '');

    // Track word interaction for analytics
    _analyticsService.markWordRead(index, cleanWord);

    // Track word interaction for learn-to-read mode
    if (_learnToReadMode && cleanWord.isNotEmpty) {
      _wordsInteractedWith.add(cleanWord);

      // Mark word as learned
      final isNewWord = await _readingService.markWordLearned(cleanWord);

      if (isNewWord && mounted) {
        // Show celebration for new word
        WordLearnedSnackBar.show(context, cleanWord, isNew: true);
      }
    }

    // Get phonics breakdown
    final phonicsSounds = PhonicsHelper.breakIntoSounds(cleanWord);
    final phoneticPronunciation = PhonicsHelper.getPhoneticPronunciation(cleanWord);
    final syllables = PhonicsHelper.getSyllables(cleanWord);
    final isSightWord = PhonicsHelper.isSightWord(cleanWord);
    final difficulty = PhonicsHelper.getDifficultyLevel(cleanWord);
    final rhymingWords = PhonicsHelper.getRhymingWords(cleanWord);

    // Speak the individual word slowly
    await _narrator.speakWord(cleanWord, speed: _narrationSettings.speed);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                cleanWord,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            if (isSightWord)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Sight Word',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Phonetic pronunciation
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.hearing, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sounds like:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              phoneticPronunciation,
                              style: const TextStyle(fontSize: 20, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up, color: Colors.blue),
                        onPressed: () async {
                          await _narrator.speakWord(cleanWord, speed: _narrationSettings.speed);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Phonics breakdown
              const Text(
                'Letter Sounds:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: phonicsSounds.map((sound) {
                  return GestureDetector(
                    onTap: () async {
                      await _narrator.speakWord(sound, speed: 0.2);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300, width: 2),
                      ),
                      child: Text(
                        sound,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),

              // Syllables
              if (syllables.length > 1) ...[
                const Text(
                  'Syllables:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: syllables.map((syllable) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        syllable,
                        style: const TextStyle(fontSize: 18, color: Colors.purple),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Difficulty level
              Row(
                children: [
                  const Icon(Icons.bar_chart, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Level: $difficulty',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Rhyming words
              if (rhymingWords.isNotEmpty) ...[
                const Text(
                  'Rhymes with:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: rhymingWords.map((rhyme) {
                    return Chip(
                      label: Text(rhyme),
                      backgroundColor: Colors.orange.shade100,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              // Speak word slowly broken into sounds
              await _narrator.speakPhonemes(phonicsSounds, speed: _narrationSettings.speed);
              await _narrator.speakWord(cleanWord, speed: _narrationSettings.speed);
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Sound it Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCompletionDialog() async {
    // Save reading session if in learn-to-read mode
    if (_learnToReadMode && _wordsInteractedWith.isNotEmpty) {
      final result = await _readingService.processReadingSession(
        widget.storyText,
        _wordsInteractedWith.toList(),
      );

      if (mounted) {
        // Show celebration dialog with achievements
        await ReadingCelebrationDialog.show(context, result);
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '🎉 Great Job! 🎉',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, color: Colors.deepPurple),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star,
              size: 80,
              color: Colors.amber,
            ),
            const SizedBox(height: 20),
            Text(
              'You read ${wordsReadCount} words!',
              style: const TextStyle(fontSize: 20),
            ),
            if (_learnToReadMode && _wordsInteractedWith.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Learned ${_wordsInteractedWith.length} new words!',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (widget.characterName != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${widget.characterName} is proud of you!',
                  style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopReading();
              setState(() {
                currentWordIndex = -1;
                wordsReadCount = 0;
                _wordsInteractedWith.clear();
              });
            },
            child: const Text('Read Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _endAnalyticsSession();
    _narrator.dispose();
    flutterTts.stop();
    scrollController.dispose();
    super.dispose();
  }

  /// End tracking reading analytics
  Future<void> _endAnalyticsSession() async {
    await _analyticsService.endSession();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Read Along'),
            if (_learnToReadMode) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.school, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Learn Mode',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('How to Use'),
                  content: const Text(
                    '• Tap play to start reading\n'
                    '• Words will highlight as they are read\n'
                    '• Tap any word to see phonics breakdown\n'
                    '• Each sound can be tapped to hear it\n'
                    '• Adjust reading speed with the slider\n'
                    '• Learn-to-Read mode tracks your progress!',
                    style: TextStyle(fontSize: 16),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it!'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Story Title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade100, Colors.pink.shade100],
              ),
            ),
            child: Column(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.characterName != null)
                  Text(
                    'Starring ${widget.characterName}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.deepPurple.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          
          // Story Text with Word Highlighting
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200, width: 2),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  children: List.generate(words.length, (index) {
                    bool isCurrentWord = index == currentWordIndex;
                    bool isReadWord = index < currentWordIndex;
                    
                    return GestureDetector(
                      onTap: () => _showWordDefinition(words[index], index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCurrentWord 
                            ? Colors.yellow.shade400 
                            : isReadWord 
                              ? Colors.green.shade100
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isCurrentWord
                            ? [BoxShadow(
                                color: Colors.yellow.shade600.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              )]
                            : null,
                        ),
                        child: Text(
                          words[index],
                          style: TextStyle(
                            fontSize: isCurrentWord ? 22 : 20,
                            fontWeight: isCurrentWord ? FontWeight.bold : FontWeight.normal,
                            color: isReadWord 
                              ? Colors.grey.shade600 
                              : Colors.black87,
                            height: 1.5,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          
          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Play Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _toggleReading,
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 30),
                      label: Text(
                        isPlaying ? 'Pause' : 'Start Reading',
                        style: const TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        backgroundColor: isPlaying ? Colors.orange : Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _stopReading,
                      icon: const Icon(Icons.stop, size: 30),
                      label: const Text('Reset', style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Speed Control
                Row(
                  children: [
                    const Icon(Icons.speed, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    const Text('Speed:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Slider(
                        value: _narrationSettings.speed,
                        min: 0.2,
                        max: 0.8,
                        divisions: 6,
                        label: '${(_narrationSettings.speed * 2).toStringAsFixed(1)}x',
                        onChanged: (value) async {
                          setState(() {
                            _narrationSettings = _narrationSettings.copyWith(speed: value);
                          });
                          await _narrator.updateSpeed(value);
                        },
                      ),
                    ),
                    Text('${(_narrationSettings.speed * 2).toStringAsFixed(1)}x'),
                  ],
                ),
                
                // Stats
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Words Read', style: TextStyle(fontSize: 14)),
                          Text(
                            '$wordsReadCount',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Total Words', style: TextStyle(fontSize: 14)),
                          Text(
                            '${words.length}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
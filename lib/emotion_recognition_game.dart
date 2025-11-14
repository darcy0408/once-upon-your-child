// lib/emotion_recognition_game.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'character_evolution.dart';
import 'emotions_learning_system.dart';
import 'therapeutic_models.dart';

/// Game configuration for emotion recognition training
class EmotionRecognitionConfig {
  final int timeLimitSeconds;
  final int questionsPerRound;
  final List<String> emotions;
  final bool showHints;
  final DifficultyLevel difficulty;

  const EmotionRecognitionConfig({
    this.timeLimitSeconds = 30,
    this.questionsPerRound = 5,
    required this.emotions,
    this.showHints = true,
    this.difficulty = DifficultyLevel.beginner,
  });
}

enum DifficultyLevel {
  beginner,    // 3 emotions, clear expressions
  intermediate,// 5 emotions, varied expressions
  advanced,    // 7 emotions, subtle expressions
  expert,      // All emotions, complex scenarios
}

extension DifficultyLevelExtension on DifficultyLevel {
  String get displayName {
    switch (this) {
      case DifficultyLevel.beginner:
        return 'Beginner';
      case DifficultyLevel.intermediate:
        return 'Intermediate';
      case DifficultyLevel.advanced:
        return 'Advanced';
      case DifficultyLevel.expert:
        return 'Expert';
    }
  }

  int get emotionCount {
    switch (this) {
      case DifficultyLevel.beginner:
        return 3;
      case DifficultyLevel.intermediate:
        return 5;
      case DifficultyLevel.advanced:
        return 7;
      case DifficultyLevel.expert:
        return 10;
    }
  }

  Color get color {
    switch (this) {
      case DifficultyLevel.beginner:
        return Colors.green;
      case DifficultyLevel.intermediate:
        return Colors.blue;
      case DifficultyLevel.advanced:
        return Colors.orange;
      case DifficultyLevel.expert:
        return Colors.red;
    }
  }
}

/// Represents a single emotion recognition question
class EmotionQuestion {
  final String emotionId;
  final String imagePath;
  final List<String> options; // Multiple choice options
  final String correctAnswer;
  final String hint;
  final int points;

  EmotionQuestion({
    required this.emotionId,
    required this.imagePath,
    required this.options,
    required this.correctAnswer,
    required this.hint,
    this.points = 10,
  });

  bool isCorrect(String answer) => answer == correctAnswer;
}

/// Game session data
class EmotionGameSession {
  final String sessionId;
  final String characterId;
  final DifficultyLevel difficulty;
  final DateTime startTime;
  final List<EmotionQuestionResult> results;
  int currentScore;
  int timeRemaining;

  EmotionGameSession({
    required this.sessionId,
    required this.characterId,
    required this.difficulty,
    required this.startTime,
    this.results = const [],
    this.currentScore = 0,
    required this.timeRemaining,
  });

  int get correctAnswers => results.where((r) => r.isCorrect).length;
  int get totalQuestions => results.length;
  double get accuracy => totalQuestions > 0 ? correctAnswers / totalQuestions : 0.0;

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'character_id': characterId,
        'difficulty': difficulty.name,
        'start_time': startTime.toIso8601String(),
        'results': results.map((r) => r.toJson()).toList(),
        'current_score': currentScore,
        'time_remaining': timeRemaining,
      };
}

/// Result of a single question attempt
class EmotionQuestionResult {
  final String questionId;
  final String selectedAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final int timeTakenMs;
  final DateTime timestamp;

  EmotionQuestionResult({
    required this.questionId,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.timeTakenMs,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'selected_answer': selectedAnswer,
        'correct_answer': correctAnswer,
        'is_correct': isCorrect,
        'time_taken_ms': timeTakenMs,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Main emotion recognition training game screen
class EmotionRecognitionGame extends StatefulWidget {
  final String characterId;
  final DifficultyLevel difficulty;

  const EmotionRecognitionGame({
    super.key,
    required this.characterId,
    this.difficulty = DifficultyLevel.beginner,
  });

  @override
  State<EmotionRecognitionGame> createState() => _EmotionRecognitionGameState();
}

class _EmotionRecognitionGameState extends State<EmotionRecognitionGame>
    with TickerProviderStateMixin {
  late EmotionGameSession _session;
  late List<EmotionQuestion> _questions;
  late Timer _timer;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  int _currentQuestionIndex = 0;
  bool _showResult = false;
  bool _isCorrect = false;
  String _selectedAnswer = '';
  DateTime? _questionStartTime;
  bool _gameCompleted = false;

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _setupAnimations();
  }

  void _initializeGame() {
    _session = EmotionGameSession(
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      characterId: widget.characterId,
      difficulty: widget.difficulty,
      startTime: DateTime.now(),
      timeRemaining: 30, // 30 seconds per question
    );

    _questions = _generateQuestions(widget.difficulty);
    _startTimer();
    _startQuestion();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  List<EmotionQuestion> _generateQuestions(DifficultyLevel difficulty) {
    final emotionsService = EmotionsLearningService();
    final allEmotions = emotionsService.getAllEmotions();

    // Select emotions based on difficulty
    final selectedEmotions = allEmotions.take(difficulty.emotionCount).toList();

    return selectedEmotions.map((emotion) {
      // Generate multiple choice options
      final otherEmotions = allEmotions
          .where((e) => e.id != emotion.id)
          .take(3)
          .map((e) => e.name)
          .toList();

      final options = [emotion.name, ...otherEmotions]..shuffle();

      return EmotionQuestion(
        emotionId: emotion.id,
        imagePath: 'assets/emotions/${emotion.id}.png', // Placeholder path
        options: options,
        correctAnswer: emotion.name,
        hint: emotion.description,
        points: difficulty == DifficultyLevel.expert ? 20 : 10,
      );
    }).toList()..shuffle();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_session.timeRemaining > 0) {
          _session.timeRemaining--;
        } else {
          _timeUp();
        }
      });
    });
  }

  void _startQuestion() {
    _questionStartTime = DateTime.now();
    _showResult = false;
    _selectedAnswer = '';
  }

  void _selectAnswer(String answer) {
    if (_showResult) return;

    final timeTaken = DateTime.now().difference(_questionStartTime!).inMilliseconds;
    final currentQuestion = _questions[_currentQuestionIndex];
    final isCorrect = currentQuestion.isCorrect(answer);

    // Record result
    final result = EmotionQuestionResult(
      questionId: currentQuestion.emotionId,
      selectedAnswer: answer,
      correctAnswer: currentQuestion.correctAnswer,
      isCorrect: isCorrect,
      timeTakenMs: timeTaken,
      timestamp: DateTime.now(),
    );

    _session.results.add(result);

    if (isCorrect) {
      _session.currentScore += currentQuestion.points;
      _animationController.forward().then((_) => _animationController.reverse());
    }

    setState(() {
      _selectedAnswer = answer;
      _isCorrect = isCorrect;
      _showResult = true;
    });

    // Auto-advance after showing result
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _session.timeRemaining = 30; // Reset timer
      });
      _startQuestion();
    } else {
      _endGame();
    }
  }

  void _timeUp() {
    if (!_showResult) {
      _selectAnswer(''); // Time up counts as wrong
    }
  }

  void _endGame() {
    _timer.cancel();
    setState(() {
      _gameCompleted = true;
    });

    // Update character evolution
    _updateCharacterEvolution();

    // Show results after a delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _showGameResults();
      }
    });
  }

  Future<void> _updateCharacterEvolution() async {
    try {
      final characterEvolutionService = CharacterEvolutionService();

      // Update progress for emotion recognition skill
      await characterEvolutionService.updateCharacterEvolution(
        widget.characterId,
        TherapeuticGoal.emotionalRegulation, // Could be a new goal type
        'emotion_recognition', // Generic emotion for now
        _session.correctAnswers * 2, // Progress based on correct answers
      );
    } catch (e) {
      debugPrint('Error updating character evolution: $e');
    }
  }

  void _showGameResults() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Complete! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score: ${_session.currentScore}'),
            Text('Accuracy: ${(_session.accuracy * 100).round()}%'),
            Text('Correct: ${_session.correctAnswers}/${_session.totalQuestions}'),
            const SizedBox(height: 16),
            Text(
              _getPerformanceMessage(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Return to previous screen
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  String _getPerformanceMessage() {
    final accuracy = _session.accuracy;
    if (accuracy >= 0.9) return 'Outstanding! You\'re an emotion expert! 🌟';
    if (accuracy >= 0.7) return 'Great job! You\'re getting really good at this! 👍';
    if (accuracy >= 0.5) return 'Good work! Keep practicing to improve! 💪';
    return 'Keep trying! Practice makes perfect! 🌱';
  }

  @override
  void dispose() {
    _timer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gameCompleted) {
      return _buildCompletionScreen();
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.difficulty.displayName} Emotion Game'),
        backgroundColor: widget.difficulty.color,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${_session.timeRemaining}s',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
            colors: [
              widget.difficulty.color.withOpacity(0.1),
              widget.difficulty.color.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: (_currentQuestionIndex + 1) / _questions.length,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(widget.difficulty.color),
              ),
              const SizedBox(height: 8),
              Text(
                'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),

              const SizedBox(height: 32),

              // Emotion image (placeholder for now)
              Expanded(
                child: Center(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.difficulty.color,
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.face,
                        size: 80,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Question
              Text(
                'What emotion is this person feeling?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Answer options
              ...currentQuestion.options.map((option) {
                final isSelected = _selectedAnswer == option;
                final isCorrectOption = option == currentQuestion.correctAnswer;

                Color? buttonColor;
                if (_showResult) {
                  if (isCorrectOption) {
                    buttonColor = Colors.green.shade100;
                  } else if (isSelected && !isCorrectOption) {
                    buttonColor = Colors.red.shade100;
                  }
                } else if (isSelected) {
                  buttonColor = widget.difficulty.color.withOpacity(0.2);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showResult ? null : () => _selectAnswer(option),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        option,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                );
              }),

              // Result feedback
              if (_showResult) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isCorrect ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isCorrect ? Colors.green : Colors.red,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _isCorrect ? Icons.check_circle : Icons.cancel,
                        color: _isCorrect ? Colors.green : Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isCorrect ? 'Correct! 🎉' : 'Not quite right',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isCorrect ? Colors.green : Colors.red,
                        ),
                      ),
                      if (!_isCorrect) ...[
                        const SizedBox(height: 4),
                        Text(
                          'The correct answer was: ${currentQuestion.correctAnswer}',
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Score display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Score: ${_session.currentScore}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.difficulty.color.withOpacity(0.2),
            widget.difficulty.color.withOpacity(0.1),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.celebration,
              size: 100,
              color: widget.difficulty.color,
            ),
            const SizedBox(height: 24),
            Text(
              'Emotion Game Complete!',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Final Score: ${_session.currentScore}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Accuracy: ${(_session.accuracy * 100).round()}%',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick access widget for emotion recognition games
class EmotionGameLauncher extends StatelessWidget {
  final String characterId;

  const EmotionGameLauncher({
    super.key,
    required this.characterId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.face,
              size: 48,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            const Text(
              'Emotion Recognition',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Learn to recognize emotions through fun games!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EmotionRecognitionGame(
                            characterId: characterId,
                            difficulty: DifficultyLevel.beginner,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DifficultyLevel.beginner.color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Beginner'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EmotionRecognitionGame(
                            characterId: characterId,
                            difficulty: DifficultyLevel.intermediate,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DifficultyLevel.intermediate.color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Intermediate'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
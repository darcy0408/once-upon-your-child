// lib/empathy_building_exercises.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'character_evolution.dart';
import 'emotions_learning_system.dart';

/// Types of empathy building exercises
enum EmpathyExerciseType {
  perspectiveTaking,    // See situation from another's viewpoint
  emotionMatching,      // Match emotions to scenarios
  compassionateResponse, // Practice kind responses
  emotionalScenario,    // Analyze complex emotional situations
  roleReversal,         // Switch perspectives in conversations
}

extension EmpathyExerciseTypeExtension on EmpathyExerciseType {
  String get title {
    switch (this) {
      case EmpathyExerciseType.perspectiveTaking:
        return 'Perspective Taking';
      case EmpathyExerciseType.emotionMatching:
        return 'Emotion Detective';
      case EmpathyExerciseType.compassionateResponse:
        return 'Kind Responses';
      case EmpathyExerciseType.emotionalScenario:
        return 'Feeling Stories';
      case EmpathyExerciseType.roleReversal:
        return 'Role Reversal';
    }
  }

  String get description {
    switch (this) {
      case EmpathyExerciseType.perspectiveTaking:
        return 'See how others might feel in different situations';
      case EmpathyExerciseType.emotionMatching:
        return 'Figure out what emotions match different scenarios';
      case EmpathyExerciseType.compassionateResponse:
        return 'Practice responding with kindness and understanding';
      case EmpathyExerciseType.emotionalScenario:
        return 'Explore complex situations with multiple feelings';
      case EmpathyExerciseType.roleReversal:
        return 'Switch roles and see things from the other side';
    }
  }

  IconData get icon {
    switch (this) {
      case EmpathyExerciseType.perspectiveTaking:
        return Icons.visibility;
      case EmpathyExerciseType.emotionMatching:
        return Icons.search;
      case EmpathyExerciseType.compassionateResponse:
        return Icons.favorite;
      case EmpathyExerciseType.emotionalScenario:
        return Icons.book;
      case EmpathyExerciseType.roleReversal:
        return Icons.swap_horiz;
    }
  }

  Color get color {
    switch (this) {
      case EmpathyExerciseType.perspectiveTaking:
        return Colors.blue;
      case EmpathyExerciseType.emotionMatching:
        return Colors.green;
      case EmpathyExerciseType.compassionateResponse:
        return Colors.pink;
      case EmpathyExerciseType.emotionalScenario:
        return Colors.purple;
      case EmpathyExerciseType.roleReversal:
        return Colors.orange;
    }
  }
}

/// Represents a single empathy building exercise
class EmpathyExercise {
  final String id;
  final EmpathyExerciseType type;
  final String scenario;
  final String question;
  final List<EmpathyOption> options;
  final String correctExplanation;
  final String empathyLesson;
  final int points;
  final List<String> targetEmotions;

  EmpathyExercise({
    required this.id,
    required this.type,
    required this.scenario,
    required this.question,
    required this.options,
    required this.correctExplanation,
    required this.empathyLesson,
    this.points = 15,
    required this.targetEmotions,
  });
}

/// Option for empathy exercise with emotional context
class EmpathyOption {
  final String text;
  final List<String> emotions;
  final bool isCorrect;
  final String explanation;

  EmpathyOption({
    required this.text,
    required this.emotions,
    required this.isCorrect,
    required this.explanation,
  });
}

/// Session tracking for empathy exercises
class EmpathySession {
  final String sessionId;
  final String characterId;
  final DateTime startTime;
  final List<EmpathyResult> results;
  int currentScore;

  EmpathySession({
    required this.sessionId,
    required this.characterId,
    required this.startTime,
    this.results = const [],
    this.currentScore = 0,
  });

  int get correctAnswers => results.where((r) => r.isCorrect).length;
  int get totalQuestions => results.length;
  double get accuracy => totalQuestions > 0 ? correctAnswers / totalQuestions : 0.0;

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'character_id': characterId,
        'start_time': startTime.toIso8601String(),
        'results': results.map((r) => r.toJson()).toList(),
        'current_score': currentScore,
      };
}

/// Result of a single empathy exercise attempt
class EmpathyResult {
  final String exerciseId;
  final String selectedOptionText;
  final bool isCorrect;
  final int timeTakenMs;
  final DateTime timestamp;
  final String empathyLessonLearned;

  EmpathyResult({
    required this.exerciseId,
    required this.selectedOptionText,
    required this.isCorrect,
    required this.timeTakenMs,
    required this.timestamp,
    required this.empathyLessonLearned,
  });

  Map<String, dynamic> toJson() => {
        'exercise_id': exerciseId,
        'selected_option': selectedOptionText,
        'is_correct': isCorrect,
        'time_taken_ms': timeTakenMs,
        'timestamp': timestamp.toIso8601String(),
        'lesson_learned': empathyLessonLearned,
      };
}

/// Main empathy building exercises screen
class EmpathyBuildingExercises extends StatefulWidget {
  final String characterId;

  const EmpathyBuildingExercises({
    super.key,
    required this.characterId,
  });

  @override
  State<EmpathyBuildingExercises> createState() => _EmpathyBuildingExercisesState();
}

class _EmpathyBuildingExercisesState extends State<EmpathyBuildingExercises>
    with TickerProviderStateMixin {
  late EmpathySession _session;
  late List<EmpathyExercise> _exercises;
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  int _currentExerciseIndex = 0;
  bool _showResult = false;
  String _selectedAnswer = '';
  DateTime? _exerciseStartTime;
  bool _sessionCompleted = false;

  @override
  void initState() {
    super.initState();
    _initializeSession();
    _setupAnimations();
    _pageController = PageController();
  }

  void _initializeSession() {
    _session = EmpathySession(
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      characterId: widget.characterId,
      startTime: DateTime.now(),
    );

    _exercises = _generateExercises();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  List<EmpathyExercise> _generateExercises() {
    // Generate 5 exercises of different types
    final exercises = <EmpathyExercise>[];

    // Perspective Taking Exercise
    exercises.add(EmpathyExercise(
      id: 'perspective_1',
      type: EmpathyExerciseType.perspectiveTaking,
      scenario: 'Your friend Sarah didn\'t get picked for the school play. She looks really sad and keeps to herself during recess.',
      question: 'How do you think Sarah is feeling right now?',
      options: [
        EmpathyOption(
          text: 'Sarah feels happy because she can focus on other activities',
          emotions: ['happy', 'excited'],
          isCorrect: false,
          explanation: 'Sarah didn\'t get picked, so she\'s probably not feeling happy.',
        ),
        EmpathyOption(
          text: 'Sarah feels disappointed and sad about not getting the role',
          emotions: ['sad', 'disappointed'],
          isCorrect: true,
          explanation: 'Sarah wanted the role and didn\'t get it, so she feels disappointed.',
        ),
        EmpathyOption(
          text: 'Sarah feels angry at the teacher for not picking her',
          emotions: ['angry', 'frustrated'],
          isCorrect: false,
          explanation: 'Sarah might feel frustrated, but sadness is more likely the main feeling.',
        ),
      ],
      correctExplanation: 'Sarah feels disappointed and sad because she really wanted the role and didn\'t get it.',
      empathyLesson: 'Everyone feels sad when they don\'t get something they really wanted. It\'s important to be kind to friends who are feeling disappointed.',
      targetEmotions: ['sad', 'disappointed'],
    ));

    // Emotion Matching Exercise
    exercises.add(EmpathyExercise(
      id: 'emotion_match_1',
      type: EmpathyExerciseType.emotionMatching,
      scenario: 'Your classmate Alex won the science fair prize! Alex\'s face is glowing and they\'re jumping up and down with excitement.',
      question: 'Which emotions best match how Alex is feeling?',
      options: [
        EmpathyOption(
          text: 'Proud and excited about winning',
          emotions: ['proud', 'excited', 'happy'],
          isCorrect: true,
          explanation: 'Alex won the prize and is showing clear signs of happiness and excitement.',
        ),
        EmpathyOption(
          text: 'Worried about having to give a speech',
          emotions: ['worried', 'nervous'],
          isCorrect: false,
          explanation: 'Alex looks excited, not worried.',
        ),
        EmpathyOption(
          text: 'Jealous of other winners',
          emotions: ['jealous', 'envious'],
          isCorrect: false,
          explanation: 'Alex is celebrating their own win, not feeling jealous.',
        ),
      ],
      correctExplanation: 'Alex feels proud of their hard work and excited about winning the prize.',
      empathyLesson: 'When someone achieves something great, they feel proud and happy. We should celebrate with them!',
      targetEmotions: ['proud', 'excited', 'happy'],
    ));

    // Compassionate Response Exercise
    exercises.add(EmpathyExercise(
      id: 'compassion_1',
      type: EmpathyExerciseType.compassionateResponse,
      scenario: 'Your friend Mia tells you that her pet goldfish died yesterday. She has tears in her eyes and looks very sad.',
      question: 'What would be a kind and understanding response?',
      options: [
        EmpathyOption(
          text: 'Don\'t worry, you can just get another goldfish tomorrow!',
          emotions: ['dismissive'],
          isCorrect: false,
          explanation: 'This doesn\'t acknowledge Mia\'s sadness about losing her pet.',
        ),
        EmpathyOption(
          text: 'I\'m so sorry about your goldfish. That must make you feel really sad.',
          emotions: ['empathy', 'understanding'],
          isCorrect: true,
          explanation: 'This shows you understand Mia\'s feelings and care about her sadness.',
        ),
        EmpathyOption(
          text: 'Goldfish die all the time. It\'s not a big deal.',
          emotions: ['uncaring', 'dismissive'],
          isCorrect: false,
          explanation: 'This makes Mia feel like her feelings don\'t matter.',
        ),
      ],
      correctExplanation: 'Being kind means acknowledging someone\'s feelings and showing you care about what they\'re going through.',
      empathyLesson: 'When someone is sad, the kindest thing is to listen, understand their feelings, and offer comfort.',
      targetEmotions: ['sad', 'grieving'],
    ));

    // Emotional Scenario Exercise
    exercises.add(EmpathyExercise(
      id: 'scenario_1',
      type: EmpathyExerciseType.emotionalScenario,
      scenario: 'Today is your friend Jordan\'s birthday party. Jordan invited everyone in class except you. You see your classmates having fun at the party without you.',
      question: 'How might you feel in this situation, and how might Jordan feel?',
      options: [
        EmpathyOption(
          text: 'You feel happy for Jordan, and Jordan feels excited about the party',
          emotions: ['happy', 'excited'],
          isCorrect: false,
          explanation: 'You weren\'t invited, so you might feel left out.',
        ),
        EmpathyOption(
          text: 'You feel hurt and left out, and Jordan might not have realized you wanted to come',
          emotions: ['hurt', 'left_out', 'unaware'],
          isCorrect: true,
          explanation: 'You might feel bad about being excluded, and Jordan might not have meant to hurt your feelings.',
        ),
        EmpathyOption(
          text: 'You feel angry at Jordan, and Jordan feels guilty about forgetting you',
          emotions: ['angry', 'guilty'],
          isCorrect: false,
          explanation: 'While possible, hurt feelings are more likely than anger in this situation.',
        ),
      ],
      correctExplanation: 'You might feel hurt and left out, while Jordan might not have realized you wanted an invitation. Sometimes people don\'t know how their actions affect others.',
      empathyLesson: 'People can feel hurt when they\'re left out, even if it wasn\'t intentional. It\'s important to think about how our actions might affect others\' feelings.',
      targetEmotions: ['hurt', 'left_out', 'unaware'],
    ));

    // Role Reversal Exercise
    exercises.add(EmpathyExercise(
      id: 'role_reversal_1',
      type: EmpathyExerciseType.roleReversal,
      scenario: 'Imagine you\'re playing a game with your friend, and you accidentally knock over their tower of blocks. Your friend gets upset and says, "You ruined my tower!"',
      question: 'If you were your friend, how would you feel and what would you want?',
      options: [
        EmpathyOption(
          text: 'You\'d feel happy because now you can build a new tower',
          emotions: ['happy', 'excited'],
          isCorrect: false,
          explanation: 'Your friend worked hard on that tower and is upset about it being ruined.',
        ),
        EmpathyOption(
          text: 'You\'d feel frustrated and want an apology and help rebuilding',
          emotions: ['frustrated', 'disappointed'],
          isCorrect: true,
          explanation: 'Your friend put effort into building and feels bad about it being accidentally ruined.',
        ),
        EmpathyOption(
          text: 'You\'d feel angry and want to stop playing the game',
          emotions: ['angry', 'upset'],
          isCorrect: false,
          explanation: 'Frustration is more likely than extreme anger in this accidental situation.',
        ),
      ],
      correctExplanation: 'If you were your friend, you\'d feel frustrated about losing your work and would want understanding and help to fix it.',
      empathyLesson: 'When we accidentally hurt someone\'s feelings or ruin something they care about, it\'s important to understand how they feel and make it right.',
      targetEmotions: ['frustrated', 'disappointed'],
    ));

    return exercises;
  }

  void _startExercise() {
    _exerciseStartTime = DateTime.now();
    _showResult = false;
    _selectedAnswer = '';
  }

  void _selectAnswer(String answer) {
    if (_showResult) return;

    final timeTaken = DateTime.now().difference(_exerciseStartTime!).inMilliseconds;
    final currentExercise = _exercises[_currentExerciseIndex];
    final selectedOption = currentExercise.options.firstWhere(
      (option) => option.text == answer,
    );

    // Record result
    final result = EmpathyResult(
      exerciseId: currentExercise.id,
      selectedOptionText: answer,
      isCorrect: selectedOption.isCorrect,
      timeTakenMs: timeTaken,
      timestamp: DateTime.now(),
      empathyLessonLearned: currentExercise.empathyLesson,
    );

    _session.results.add(result);

    if (selectedOption.isCorrect) {
      _session.currentScore += currentExercise.points;
      _animationController.forward().then((_) => _animationController.reverse());
    }

    setState(() {
      _selectedAnswer = answer;
      _showResult = true;
    });

    // Auto-advance after showing result
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _nextExercise();
      }
    });
  }

  void _nextExercise() {
    if (_currentExerciseIndex < _exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
      _startExercise();
    } else {
      _endSession();
    }
  }

  void _endSession() {
    setState(() {
      _sessionCompleted = true;
    });

    // Update character evolution
    _updateCharacterEvolution();

    // Show results after a delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _showSessionResults();
      }
    });
  }

  Future<void> _updateCharacterEvolution() async {
    try {
      final characterEvolutionService = CharacterEvolutionService();

      // Update progress for empathy skill
      await characterEvolutionService.updateCharacterEvolution(
        widget.characterId,
        TherapeuticGoal.empathy, // This would need to be added to TherapeuticGoal enum
        'empathy_development', // Generic emotion for now
        _session.correctAnswers * 3, // Progress based on correct answers
      );
    } catch (e) {
      debugPrint('Error updating character evolution: $e');
    }
  }

  void _showSessionResults() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Empathy Exercises Complete! 🌟'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Final Score: ${_session.currentScore}'),
            Text('Accuracy: ${(_session.accuracy * 100).round()}%'),
            Text('Exercises: ${_session.correctAnswers}/${_session.totalQuestions}'),
            const SizedBox(height: 16),
            Text(
              _getEmpathyFeedback(),
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
            child: const Text('Continue Learning'),
          ),
        ],
      ),
    );
  }

  String _getEmpathyFeedback() {
    final accuracy = _session.accuracy;
    if (accuracy >= 0.9) return 'Amazing empathy skills! You\'re a true friend! 💝';
    if (accuracy >= 0.7) return 'Great job understanding others\' feelings! 🌟';
    if (accuracy >= 0.5) return 'Good work! Keep practicing empathy! 👍';
    return 'Everyone starts somewhere! Keep learning about feelings! 🌱';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionCompleted) {
      return _buildCompletionScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Empathy Building Exercises'),
        backgroundColor: Colors.pink.shade400,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Score: ${_session.currentScore}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _exercises.length,
        itemBuilder: (context, index) {
          return _buildExercisePage(_exercises[index]);
        },
      ),
    );
  }

  Widget _buildExercisePage(EmpathyExercise exercise) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            exercise.type.color.withOpacity(0.1),
            exercise.type.color.withOpacity(0.05),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: (_currentExerciseIndex + 1) / _exercises.length,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(exercise.type.color),
            ),
            const SizedBox(height: 8),
            Text(
              'Exercise ${_currentExerciseIndex + 1} of ${_exercises.length}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),

            const SizedBox(height: 24),

            // Exercise type indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: exercise.type.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: exercise.type.color, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(exercise.type.icon, color: exercise.type.color),
                  const SizedBox(width: 8),
                  Text(
                    exercise.type.title,
                    style: TextStyle(
                      color: exercise.type.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Scenario
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scenario:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            exercise.scenario,
                            style: const TextStyle(fontSize: 16, height: 1.4),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Question
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Think About:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            exercise.question,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Answer options
                    ...exercise.options.map((option) {
                      final isSelected = _selectedAnswer == option.text;
                      Color? buttonColor;
                      if (_showResult) {
                        if (option.isCorrect) {
                          buttonColor = Colors.green.shade100;
                        } else if (isSelected && !option.isCorrect) {
                          buttonColor = Colors.red.shade100;
                        }
                      } else if (isSelected) {
                        buttonColor = exercise.type.color.withOpacity(0.2);
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _showResult ? null : () => _selectAnswer(option.text),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonColor,
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: isSelected ? 4 : 1,
                            ),
                            child: Text(
                              option.text,
                              style: const TextStyle(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }),

                    // Result feedback
                    if (_showResult) ...[
                      const SizedBox(height: 16),
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.lightbulb,
                                color: Colors.amber,
                                size: 48,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Empathy Lesson:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                exercise.empathyLesson,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
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
            Colors.pink.shade200,
            Colors.pink.shade100,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite,
              size: 100,
              color: Colors.pink.shade400,
            ),
            const SizedBox(height: 24),
            const Text(
              'Empathy Exercises Complete!',
              style: TextStyle(
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
              'Understanding Others: ${(_session.accuracy * 100).round()}%',
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

/// Quick access widget for empathy building exercises
class EmpathyExercisesLauncher extends StatelessWidget {
  final String characterId;

  const EmpathyExercisesLauncher({
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
              Icons.favorite,
              size: 48,
              color: Colors.pink,
            ),
            const SizedBox(height: 16),
            const Text(
              'Empathy Building',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Learn to understand and care about others\' feelings',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EmpathyBuildingExercises(
                        characterId: characterId,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink.shade400,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Start Empathy Exercises',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
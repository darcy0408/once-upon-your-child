// lib/coping_strategy_library.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'character_evolution.dart';
import 'emotions_learning_system.dart';

/// Types of coping strategies organized by approach
enum CopingStrategyType {
  breathing,        // Deep breathing and relaxation techniques
  positiveThinking, // Positive self-talk and cognitive reframing
  physicalActivity, // Movement and exercise-based coping
  creativeOutlet,   // Art, music, writing for emotional expression
  mindfulness,      // Present moment awareness techniques
  socialSupport,    // Seeking help from others
  problemSolving,   // Step-by-step problem solving
  relaxation,       // Progressive muscle relaxation and calming techniques
}

extension CopingStrategyTypeExtension on CopingStrategyType {
  String get title {
    switch (this) {
      case CopingStrategyType.breathing:
        return 'Breathing Exercises';
      case CopingStrategyType.positiveThinking:
        return 'Positive Thinking';
      case CopingStrategyType.physicalActivity:
        return 'Physical Activity';
      case CopingStrategyType.creativeOutlet:
        return 'Creative Outlets';
      case CopingStrategyType.mindfulness:
        return 'Mindfulness';
      case CopingStrategyType.socialSupport:
        return 'Getting Support';
      case CopingStrategyType.problemSolving:
        return 'Problem Solving';
      case CopingStrategyType.relaxation:
        return 'Relaxation Techniques';
    }
  }

  String get description {
    switch (this) {
      case CopingStrategyType.breathing:
        return 'Calm your body and mind with breathing exercises';
      case CopingStrategyType.positiveThinking:
        return 'Change negative thoughts to positive ones';
      case CopingStrategyType.physicalActivity:
        return 'Use movement to release energy and feel better';
      case CopingStrategyType.creativeOutlet:
        return 'Express feelings through art, music, or writing';
      case CopingStrategyType.mindfulness:
        return 'Stay present and aware of your feelings';
      case CopingStrategyType.socialSupport:
        return 'Talk to others and get help when you need it';
      case CopingStrategyType.problemSolving:
        return 'Think step-by-step to solve problems';
      case CopingStrategyType.relaxation:
        return 'Relax your body and calm your mind';
    }
  }

  IconData get icon {
    switch (this) {
      case CopingStrategyType.breathing:
        return Icons.air;
      case CopingStrategyType.positiveThinking:
        return Icons.lightbulb;
      case CopingStrategyType.physicalActivity:
        return Icons.directions_run;
      case CopingStrategyType.creativeOutlet:
        return Icons.brush;
      case CopingStrategyType.mindfulness:
        return Icons.self_improvement;
      case CopingStrategyType.socialSupport:
        return Icons.people;
      case CopingStrategyType.problemSolving:
        return Icons.psychology;
      case CopingStrategyType.relaxation:
        return Icons.spa;
    }
  }

  Color get color {
    switch (this) {
      case CopingStrategyType.breathing:
        return Colors.blue;
      case CopingStrategyType.positiveThinking:
        return Colors.yellow;
      case CopingStrategyType.physicalActivity:
        return Colors.green;
      case CopingStrategyType.creativeOutlet:
        return Colors.purple;
      case CopingStrategyType.mindfulness:
        return Colors.teal;
      case CopingStrategyType.socialSupport:
        return Colors.pink;
      case CopingStrategyType.problemSolving:
        return Colors.orange;
      case CopingStrategyType.relaxation:
        return Colors.indigo;
    }
  }

  String get skillLearned {
    switch (this) {
      case CopingStrategyType.breathing:
        return 'Using breath to calm down and manage strong feelings';
      case CopingStrategyType.positiveThinking:
        return 'Changing negative thoughts to more helpful ones';
      case CopingStrategyType.physicalActivity:
        return 'Using movement and exercise to release emotions';
      case CopingStrategyType.creativeOutlet:
        return 'Expressing feelings through creative activities';
      case CopingStrategyType.mindfulness:
        return 'Staying present and aware of feelings without judgment';
      case CopingStrategyType.socialSupport:
        return 'Reaching out to others for help and comfort';
      case CopingStrategyType.problemSolving:
        return 'Breaking down problems into manageable steps';
      case CopingStrategyType.relaxation:
        return 'Using relaxation techniques to reduce stress';
    }
  }
}

/// Represents a specific coping strategy with instructions and practice
class CopingStrategy {
  final String id;
  final CopingStrategyType type;
  final String title;
  final String description;
  final List<String> instructions;
  final List<String> benefits;
  final List<String> whenToUse;
  final int estimatedDuration; // in minutes
  final List<String> suitableEmotions;
  final bool requiresSupplies;
  final List<String> suppliesNeeded;

  CopingStrategy({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.instructions,
    required this.benefits,
    required this.whenToUse,
    required this.estimatedDuration,
    required this.suitableEmotions,
    this.requiresSupplies = false,
    this.suppliesNeeded = const [],
  });
}

/// Interactive coping strategy practice session
class CopingPracticeSession {
  final String sessionId;
  final String characterId;
  final String strategyId;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationMinutes;
  final String effectivenessRating; // "very helpful", "somewhat helpful", "not helpful"
  final String notes;

  CopingPracticeSession({
    required this.sessionId,
    required this.characterId,
    required this.strategyId,
    required this.startTime,
    this.endTime,
    this.durationMinutes = 0,
    this.effectivenessRating = '',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'character_id': characterId,
        'strategy_id': strategyId,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'duration_minutes': durationMinutes,
        'effectiveness_rating': effectivenessRating,
        'notes': notes,
      };
}

/// Main coping strategy library screen
class CopingStrategyLibrary extends StatefulWidget {
  final String characterId;

  const CopingStrategyLibrary({
    super.key,
    required this.characterId,
  });

  @override
  State<CopingStrategyLibrary> createState() => _CopingStrategyLibraryState();
}

class _CopingStrategyLibraryState extends State<CopingStrategyLibrary>
    with TickerProviderStateMixin {
  late List<CopingStrategy> _strategies;
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  String _selectedEmotion = '';
  CopingStrategyType? _selectedType;
  bool _showPracticeMode = false;
  CopingStrategy? _selectedStrategy;
  Timer? _practiceTimer;
  int _practiceSeconds = 0;
  bool _isPracticing = false;

  @override
  void initState() {
    super.initState();
    _initializeStrategies();
    _setupAnimations();
    _pageController = PageController();
  }

  void _initializeStrategies() {
    _strategies = [
      // Breathing Strategies
      CopingStrategy(
        id: 'breathing_balloon',
        type: CopingStrategyType.breathing,
        title: 'Balloon Breathing',
        description: 'Imagine blowing up a balloon with your breath to help you relax.',
        instructions: [
          'Sit or stand comfortably with your shoulders relaxed.',
          'Place one hand on your belly.',
          'Take a slow breath in through your nose for 4 counts, feeling your belly expand like a balloon.',
          'Hold your breath for 4 counts.',
          'Breathe out slowly through your mouth for 4 counts, feeling your belly go down.',
          'Repeat 5-10 times or until you feel calmer.',
        ],
        benefits: [
          'Slows down racing thoughts',
          'Reduces physical tension',
          'Helps you feel more in control',
          'Can be done anywhere, anytime',
        ],
        whenToUse: [
          'When you feel angry or frustrated',
          'Before a test or stressful event',
          'When you can\'t sleep',
          'When you feel overwhelmed',
        ],
        estimatedDuration: 2,
        suitableEmotions: ['angry', 'worried', 'overwhelmed', 'excited'],
      ),

      CopingStrategy(
        id: 'breathing_square',
        type: CopingStrategyType.breathing,
        title: 'Square Breathing',
        description: 'Breathe in a square pattern to create calm and focus.',
        instructions: [
          'Imagine a square in your mind or trace one with your finger.',
          'Starting at the bottom left, breathe in for 4 counts as you go up the left side.',
          'Hold your breath for 4 counts as you go across the top.',
          'Breathe out for 4 counts as you go down the right side.',
          'Hold empty for 4 counts as you go across the bottom.',
          'Repeat the square pattern 3-5 times.',
        ],
        benefits: [
          'Creates a predictable rhythm',
          'Helps with focus and concentration',
          'Reduces anxiety and stress',
          'Easy to remember and use',
        ],
        whenToUse: [
          'When you feel anxious or nervous',
          'When you need to concentrate',
          'During transitions between activities',
          'When you feel scattered or unfocused',
        ],
        estimatedDuration: 3,
        suitableEmotions: ['worried', 'nervous', 'scared', 'confused'],
      ),

      // Positive Thinking Strategies
      CopingStrategy(
        id: 'positive_affirmations',
        type: CopingStrategyType.positiveThinking,
        title: 'Positive Affirmations',
        description: 'Replace negative thoughts with kind, encouraging words.',
        instructions: [
          'Notice a negative thought you\'re having about yourself.',
          'Think of the opposite positive statement.',
          'Say it out loud or in your mind 3-5 times.',
          'Try to believe the positive statement.',
          'Use it whenever the negative thought comes back.',
        ],
        benefits: [
          'Changes negative thinking patterns',
          'Builds self-confidence',
          'Reduces feelings of worthlessness',
          'Creates more positive self-talk',
        ],
        whenToUse: [
          'When you think "I\'m not good enough"',
          'After making a mistake',
          'When you feel sad or discouraged',
          'When you\'re comparing yourself to others',
        ],
        estimatedDuration: 5,
        suitableEmotions: ['sad', 'discouraged', 'worthless', 'jealous'],
      ),

      CopingStrategy(
        id: 'gratitude_thinking',
        type: CopingStrategyType.positiveThinking,
        title: 'Gratitude Thinking',
        description: 'Focus on what you\'re thankful for to shift your mood.',
        instructions: [
          'Think of 3 things you\'re grateful for right now.',
          'They can be small things like "I have a warm bed" or big things like "I have loving parents".',
          'Say each one out loud or write them down.',
          'Think about why you\'re grateful for each thing.',
          'Notice how your feelings change as you focus on gratitude.',
        ],
        benefits: [
          'Shifts focus from negative to positive',
          'Increases feelings of happiness',
          'Helps during difficult times',
          'Builds optimism and resilience',
        ],
        whenToUse: [
          'When you feel sad or down',
          'During stressful times',
          'When you\'re having a bad day',
          'Before bed to end the day positively',
        ],
        estimatedDuration: 5,
        suitableEmotions: ['sad', 'stressed', 'disappointed', 'lonely'],
      ),

      // Physical Activity Strategies
      CopingStrategy(
        id: 'progressive_jump',
        type: CopingStrategyType.physicalActivity,
        title: 'Progressive Muscle Jumps',
        description: 'Use jumping to release built-up energy and frustration.',
        instructions: [
          'Stand in a safe open space where you can jump.',
          'Start with small jumps in place.',
          'As you jump, think about or say what\'s making you upset.',
          'Gradually make your jumps bigger and more energetic.',
          'Keep jumping until you feel the tension release.',
          'Stop when you feel calmer and take deep breaths.',
        ],
        benefits: [
          'Releases physical tension and energy',
          'Provides a healthy outlet for anger',
          'Increases endorphins and improves mood',
          'Helps process emotions physically',
        ],
        whenToUse: [
          'When you feel angry or frustrated',
          'When you have lots of built-up energy',
          'After a disappointing event',
          'When you need to "shake off" bad feelings',
        ],
        estimatedDuration: 3,
        suitableEmotions: ['angry', 'frustrated', 'excited', 'energetic'],
      ),

      CopingStrategy(
        id: 'squeeze_ball',
        type: CopingStrategyType.physicalActivity,
        title: 'Stress Ball Squeeze',
        description: 'Squeeze a soft ball or make fists to release tension.',
        instructions: [
          'Get a soft stress ball, rolled-up sock, or just make a tight fist.',
          'Hold the ball in one hand.',
          'Squeeze as hard as you can while counting to 5.',
          'Release and shake out your hand.',
          'Switch to the other hand and repeat.',
          'Notice how the tension leaves your body with each squeeze.',
        ],
        benefits: [
          'Provides physical outlet for emotions',
          'Helps manage anger and frustration',
          'Can be done discreetly anywhere',
          'Reduces muscle tension',
        ],
        whenToUse: [
          'When you feel angry or want to yell',
          'During stressful situations',
          'When you need to stay quiet but feel tense',
          'When waiting makes you impatient',
        ],
        estimatedDuration: 2,
        suitableEmotions: ['angry', 'frustrated', 'impatient', 'tense'],
        requiresSupplies: true,
        suppliesNeeded: ['Soft ball, rolled sock, or towel'],
      ),

      // Creative Outlet Strategies
      CopingStrategy(
        id: 'emotion_drawing',
        type: CopingStrategyType.creativeOutlet,
        title: 'Emotion Drawing',
        description: 'Draw your feelings to understand and express them better.',
        instructions: [
          'Get paper and crayons, markers, or colored pencils.',
          'Think about how you\'re feeling right now.',
          'Draw a picture that shows your emotion.',
          'It doesn\'t have to be a perfect drawing - just express what you feel.',
          'Add colors that match your feelings.',
          'Look at your drawing and think about what it tells you.',
        ],
        benefits: [
          'Helps identify and understand emotions',
          'Provides a safe way to express feelings',
          'Can reduce emotional intensity',
          'Creates a visual record of your feelings',
        ],
        whenToUse: [
          'When you have strong feelings you don\'t understand',
          'After a difficult experience',
          'When you want to remember how you felt',
          'When talking about feelings is hard',
        ],
        estimatedDuration: 10,
        suitableEmotions: ['confused', 'sad', 'angry', 'happy', 'worried'],
        requiresSupplies: true,
        suppliesNeeded: ['Paper', 'Crayons/markers/colored pencils'],
      ),

      CopingStrategy(
        id: 'feeling_journal',
        type: CopingStrategyType.creativeOutlet,
        title: 'Feeling Journal',
        description: 'Write about your feelings to understand them better.',
        instructions: [
          'Get a notebook or journal and a pen.',
          'Write today\'s date at the top.',
          'Write "I feel..." and describe your emotions.',
          'Write about what happened to make you feel this way.',
          'Write about what you wish would happen instead.',
          'Read what you wrote and think about how you can feel better.',
        ],
        benefits: [
          'Helps organize and understand emotions',
          'Creates a record of your emotional growth',
          'Provides insight into patterns and triggers',
          'Can be private and personal',
        ],
        whenToUse: [
          'When you have confusing or mixed feelings',
          'After a difficult day',
          'When you want to understand yourself better',
          'When you need to process big emotions',
        ],
        estimatedDuration: 10,
        suitableEmotions: ['confused', 'sad', 'worried', 'happy', 'angry'],
        requiresSupplies: true,
        suppliesNeeded: ['Notebook or journal', 'Pen or pencil'],
      ),

      // Mindfulness Strategies
      CopingStrategy(
        id: 'five_senses',
        type: CopingStrategyType.mindfulness,
        title: 'Five Senses Grounding',
        description: 'Use your senses to bring yourself back to the present moment.',
        instructions: [
          'Stop and take a deep breath.',
          'Name 5 things you can SEE around you.',
          'Name 4 things you can TOUCH.',
          'Name 3 things you can HEAR.',
          'Name 2 things you can SMELL.',
          'Name 1 thing you can TASTE.',
          'Notice how being present changes how you feel.',
        ],
        benefits: [
          'Brings you back to the present moment',
          'Reduces anxiety and racing thoughts',
          'Helps during overwhelming situations',
          'Can be done anywhere, anytime',
        ],
        whenToUse: [
          'When you feel anxious or overwhelmed',
          'During panic or stressful moments',
          'When your mind is racing with worries',
          'When you feel disconnected from reality',
        ],
        estimatedDuration: 3,
        suitableEmotions: ['worried', 'overwhelmed', 'scared', 'anxious'],
      ),

      CopingStrategy(
        id: 'body_scan',
        type: CopingStrategyType.mindfulness,
        title: 'Body Scan',
        description: 'Notice how your body feels from head to toe.',
        instructions: [
          'Lie down or sit comfortably.',
          'Close your eyes and take deep breaths.',
          'Start at your toes - notice how they feel.',
          'Slowly move up your body: feet, legs, stomach, chest, arms, neck, head.',
          'Notice any tension or relaxation in each part.',
          'Breathe into tight areas to help them relax.',
          'End with a few deep breaths feeling your whole body.',
        ],
        benefits: [
          'Increases body awareness',
          'Helps identify and release tension',
          'Promotes relaxation and calm',
          'Improves mind-body connection',
        ],
        whenToUse: [
          'When you feel tense or stressed',
          'Before bed to help sleep',
          'After a busy or overwhelming day',
          'When you need to relax and unwind',
        ],
        estimatedDuration: 5,
        suitableEmotions: ['tense', 'stressed', 'tired', 'overwhelmed'],
      ),

      // Social Support Strategies
      CopingStrategy(
        id: 'trusted_adult',
        type: CopingStrategyType.socialSupport,
        title: 'Talk to a Trusted Adult',
        description: 'Share your feelings with a safe adult who can help.',
        instructions: [
          'Think of an adult you trust (parent, teacher, counselor).',
          'Find a quiet time to talk when they\'re not busy.',
          'Say something like, "I\'m having a hard time and need to talk."',
          'Share what\'s bothering you and how you feel.',
          'Listen to what they say and ask questions if you need to.',
          'Thank them for listening and helping.',
        ],
        benefits: [
          'Gets you support and understanding',
          'Helps solve problems you can\'t fix alone',
          'Makes you feel less alone',
          'Teaches you who to trust for help',
        ],
        whenToUse: [
          'When you have a big problem you can\'t solve',
          'When you feel very sad or worried',
          'When someone is hurting or bullying you',
          'When you need advice or comfort',
        ],
        estimatedDuration: 10,
        suitableEmotions: ['worried', 'sad', 'scared', 'confused'],
      ),

      CopingStrategy(
        id: 'friend_check_in',
        type: CopingStrategyType.socialSupport,
        title: 'Check In With a Friend',
        description: 'Talk to a friend about how you\'re feeling.',
        instructions: [
          'Pick a friend you trust and feel comfortable with.',
          'Find a quiet time to talk privately.',
          'Say, "I\'m feeling [emotion] and want to talk about it."',
          'Share what\'s going on and how you feel.',
          'Listen to what your friend says.',
          'Remember that friends can listen and care, even if they can\'t fix everything.',
        ],
        benefits: [
          'Makes you feel less alone',
          'Gets different perspectives on your situation',
          'Strengthens friendships',
          'Helps process emotions through talking',
        ],
        whenToUse: [
          'When you feel lonely or isolated',
          'When you want to share good news',
          'When you need someone to listen',
          'When you\'re having a hard day',
        ],
        estimatedDuration: 10,
        suitableEmotions: ['lonely', 'sad', 'happy', 'worried', 'excited'],
      ),

      // Problem Solving Strategies
      CopingStrategy(
        id: 'stop_think_act',
        type: CopingStrategyType.problemSolving,
        title: 'Stop, Think, Act',
        description: 'Pause before acting to make better choices.',
        instructions: [
          'When you feel upset, STOP what you\'re doing.',
          'Take 3 deep breaths to calm down.',
          'THINK about the situation: What happened? How do I feel? What can I do?',
          'Think of 2-3 choices for how to respond.',
          'Choose the best option and ACT on it.',
          'Check how you feel after and learn from the experience.',
        ],
        benefits: [
          'Prevents impulsive actions',
          'Helps make better decisions',
          'Reduces regrets from poor choices',
          'Builds self-control and thinking skills',
        ],
        whenToUse: [
          'When you feel like doing something you might regret',
          'During arguments or conflicts',
          'When you\'re very angry or upset',
          'When you need to make an important decision',
        ],
        estimatedDuration: 5,
        suitableEmotions: ['angry', 'frustrated', 'impulsive', 'confused'],
      ),

      // Relaxation Strategies
      CopingStrategy(
        id: 'progressive_relaxation',
        type: CopingStrategyType.relaxation,
        title: 'Progressive Muscle Relaxation',
        description: 'Tense and relax different muscle groups to release tension.',
        instructions: [
          'Lie down or sit comfortably.',
          'Start with your toes: squeeze them tight for 5 seconds, then relax.',
          'Move up your body: feet, legs, stomach, chest, arms, hands, neck, face.',
          'For each muscle group: tense for 5 seconds, then release and notice the relaxation.',
          'Take deep breaths as you go.',
          'End with your whole body feeling relaxed and calm.',
        ],
        benefits: [
          'Reduces physical tension and stress',
          'Helps with sleep difficulties',
          'Improves body awareness',
          'Can reduce anxiety and worry',
        ],
        whenToUse: [
          'When you feel tense or stressed',
          'Before bed to help sleep',
          'After a busy or overwhelming day',
          'When you have headaches from tension',
        ],
        estimatedDuration: 10,
        suitableEmotions: ['tense', 'stressed', 'anxious', 'tired'],
      ),
    ];
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

  List<CopingStrategy> _getFilteredStrategies() {
    if (_selectedEmotion.isEmpty && _selectedType == null) {
      return _strategies;
    }

    return _strategies.where((strategy) {
      bool matchesEmotion = _selectedEmotion.isEmpty ||
          strategy.suitableEmotions.contains(_selectedEmotion.toLowerCase());
      bool matchesType = _selectedType == null || strategy.type == _selectedType;
      return matchesEmotion && matchesType;
    }).toList();
  }

  void _startPractice(CopingStrategy strategy) {
    setState(() {
      _selectedStrategy = strategy;
      _showPracticeMode = true;
      _practiceSeconds = 0;
      _isPracticing = false;
    });
  }

  void _startPracticeTimer() {
    setState(() {
      _isPracticing = true;
    });

    _practiceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _practiceSeconds++;
      });
    });
  }

  void _stopPractice() {
    _practiceTimer?.cancel();
    setState(() {
      _isPracticing = false;
    });
  }

  void _completePractice(String effectiveness) {
    _practiceTimer?.cancel();

    // Update character evolution
    _updateCharacterEvolution(_selectedStrategy!, effectiveness);

    setState(() {
      _showPracticeMode = false;
      _selectedStrategy = null;
      _practiceSeconds = 0;
      _isPracticing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Great job practicing! You learned: ${_selectedStrategy!.type.skillLearned}'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _updateCharacterEvolution(CopingStrategy strategy, String effectiveness) async {
    try {
      final characterEvolutionService = CharacterEvolutionService();

      // Update progress for coping skills
      int progressIncrease = effectiveness == 'very helpful' ? 10 :
                           effectiveness == 'somewhat helpful' ? 6 : 3;

      await characterEvolutionService.updateCharacterEvolution(
        widget.characterId,
        TherapeuticGoal.emotionalRegulation, // Could be a new goal type for coping skills
        'coping_skills',
        progressIncrease,
      );
    } catch (e) {
      debugPrint('Error updating character evolution: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _practiceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showPracticeMode && _selectedStrategy != null) {
      return _buildPracticeMode();
    }

    final filteredStrategies = _getFilteredStrategies();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coping Strategy Library'),
        backgroundColor: Colors.lightGreen.shade400,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter strategies',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          if (_selectedEmotion.isNotEmpty || _selectedType != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  const Text('Filters:'),
                  const SizedBox(width: 8),
                  if (_selectedEmotion.isNotEmpty)
                    Chip(
                      label: Text(_selectedEmotion),
                      onDeleted: () => setState(() => _selectedEmotion = ''),
                    ),
                  if (_selectedType != null) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(_selectedType!.title),
                      onDeleted: () => setState(() => _selectedType = null),
                    ),
                  ],
                ],
              ),
            ),

          // Strategy grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: filteredStrategies.length,
              itemBuilder: (context, index) {
                return _buildStrategyCard(filteredStrategies[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyCard(CopingStrategy strategy) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _showStrategyDetails(strategy),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: strategy.type.color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  strategy.type.icon,
                  color: strategy.type.color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                strategy.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                strategy.description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${strategy.estimatedDuration}min',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStrategyDetails(CopingStrategy strategy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: strategy.type.color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      strategy.type.icon,
                      color: strategy.type.color,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strategy.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          strategy.type.title,
                          style: TextStyle(
                            fontSize: 16,
                            color: strategy.type.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Description
              Text(
                strategy.description,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 20),

              // Duration and supplies
              Row(
                children: [
                  Icon(Icons.access_time, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('${strategy.estimatedDuration} minutes'),
                  if (strategy.requiresSupplies) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.inventory, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(strategy.suppliesNeeded.join(', ')),
                  ],
                ],
              ),

              const SizedBox(height: 20),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Instructions
                    _buildDetailSection(
                      'How to Do It',
                      strategy.instructions,
                      Icons.list,
                      Colors.blue,
                    ),

                    const SizedBox(height: 20),

                    // Benefits
                    _buildDetailSection(
                      'Benefits',
                      strategy.benefits,
                      Icons.check_circle,
                      Colors.green,
                    ),

                    const SizedBox(height: 20),

                    // When to use
                    _buildDetailSection(
                      'When to Use',
                      strategy.whenToUse,
                      Icons.event,
                      Colors.orange,
                    ),

                    const SizedBox(height: 20),

                    // Suitable emotions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.mood, color: Colors.purple),
                              const SizedBox(width: 8),
                              const Text(
                                'Good For These Feelings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: strategy.suitableEmotions.map((emotion) {
                              return Chip(
                                label: Text(emotion),
                                backgroundColor: Colors.purple.shade100,
                                labelStyle: const TextStyle(color: Colors.purple),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Practice button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _startPractice(strategy);
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Try This Strategy'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: strategy.type.color,
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<String> items, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: color, fontSize: 16)),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 16, height: 1.4),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Coping Strategies'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emotion filter
            DropdownButtonFormField<String>(
              value: _selectedEmotion.isEmpty ? null : _selectedEmotion,
              decoration: const InputDecoration(
                labelText: 'Filter by Emotion',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('All Emotions')),
                ...['Angry', 'Sad', 'Worried', 'Happy', 'Scared', 'Frustrated', 'Excited', 'Confused']
                    .map((emotion) => DropdownMenuItem(
                  value: emotion,
                  child: Text(emotion),
                )),
              ],
              onChanged: (value) => setState(() => _selectedEmotion = value ?? ''),
            ),

            const SizedBox(height: 16),

            // Type filter
            DropdownButtonFormField<CopingStrategyType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Filter by Type',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Types')),
                ...CopingStrategyType.values.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type.title),
                )),
              ],
              onChanged: (value) => setState(() => _selectedType = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedEmotion = '';
                _selectedType = null;
              });
              Navigator.of(context).pop();
            },
            child: const Text('Clear Filters'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeMode() {
    final strategy = _selectedStrategy!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Practicing: ${strategy.title}'),
        backgroundColor: strategy.type.color,
        actions: [
          if (_isPracticing)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${_practiceSeconds ~/ 60}:${(_practiceSeconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 16,
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
              strategy.type.color.withOpacity(0.1),
              strategy.type.color.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Strategy header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                      strategy.type.icon,
                      size: 48,
                      color: strategy.type.color,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strategy.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strategy.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Practice controls
              if (!_isPracticing) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                      const Text(
                        'Ready to practice?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'This strategy takes about ${strategy.estimatedDuration} minutes.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _startPracticeTimer,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Practice'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: strategy.type.color,
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Practice in progress
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
                        const Text(
                          'Follow these steps:',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: ListView.builder(
                            itemCount: strategy.instructions.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: strategy.type.color,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        strategy.instructions[index],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _stopPractice,
                                icon: const Icon(Icons.pause),
                                label: const Text('Pause'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showCompletionDialog(),
                                icon: const Icon(Icons.check),
                                label: const Text('Complete'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('How did that work for you?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Rate how helpful this coping strategy was:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ...['Very Helpful', 'Somewhat Helpful', 'Not Helpful'].map((rating) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _completePractice(rating.toLowerCase().replaceAll(' ', '_'));
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(rating),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Quick access widget for coping strategy library
class CopingStrategyLibraryLauncher extends StatelessWidget {
  final String characterId;

  const CopingStrategyLibraryLauncher({
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
      ),
      child: Column(
        children: [
          const Icon(
            Icons.self_improvement,
            size: 48,
            color: Colors.teal,
          ),
          const SizedBox(height: 16),
          const Text(
            'Coping Strategies',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Learn healthy ways to handle emotions and stress',
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
                    builder: (_) => CopingStrategyLibrary(
                      characterId: characterId,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade400,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Explore Strategies',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
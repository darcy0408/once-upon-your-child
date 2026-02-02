// lib/conflict_resolution_stories.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'character_evolution.dart';
import 'therapeutic_models.dart';
import 'conflict_resolution_data.dart';
export 'conflict_resolution_data.dart';

/// Main conflict resolution training screen
class ConflictResolutionStories extends StatefulWidget {
  final String characterId;

  const ConflictResolutionStories({
    super.key,
    required this.characterId,
  });

  @override
  State<ConflictResolutionStories> createState() => _ConflictResolutionStoriesState();
}

class _ConflictResolutionStoriesState extends State<ConflictResolutionStories>
    with TickerProviderStateMixin {
  late List<ConflictResolutionStory> _stories;
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  int _currentStoryIndex = 0;
  bool _showChoices = false;
  bool _showResult = false;
  bool _isCorrect = false;
  ConflictChoice? _chosenChoice;

  @override
  void initState() {
    super.initState();
    _initializeStories();
    _setupAnimations();
    _pageController = PageController();
  }

  void _initializeStories() {
    _stories = ConflictStoriesData.stories;
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

  void _revealChoices() {
    setState(() {
      _showChoices = true;
    });
  }

  void _selectChoice(ConflictChoice choice) {
    setState(() {
      _chosenChoice = choice;
      _isCorrect = choice.isPeacefulSolution;
      _showResult = true;
    });

    // Update character evolution for conflict resolution skills
    _updateCharacterEvolution(choice.isPeacefulSolution);

    // Auto-advance after showing result
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _nextStory();
      }
    });
  }

  void _nextStory() {
    if (_currentStoryIndex < _stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _showChoices = false;
        _showResult = false;
        _chosenChoice = null;
      });
    } else {
      _showCompletion();
    }
  }

  void _showCompletion() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Conflict Resolution Complete! ⚖️'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You\'ve learned peaceful ways to solve problems and resolve conflicts!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Remember: Problems are opportunities to show kindness and find solutions that work for everyone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontStyle: FontStyle.italic),
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

  Future<void> _updateCharacterEvolution(bool chosePeacefulSolution) async {
    try {
      final characterEvolutionService = CharacterEvolutionService();

      // Update progress for conflict resolution skills
      await characterEvolutionService.updateCharacterEvolution(
        widget.characterId,
        TherapeuticGoal.emotionalRegulation, // Could be a new goal type for conflict resolution
        'conflict_resolution',
        chosePeacefulSolution ? 8 : 2, // More progress for peaceful solutions
      );
    } catch (e) {
      debugPrint('Error updating character evolution: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStory = _stories[_currentStoryIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conflict Resolution Training'),
        backgroundColor: Colors.amber.shade400,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${_currentStoryIndex + 1}/${_stories.length}',
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
        itemCount: _stories.length,
        itemBuilder: (context, index) {
          return _buildStoryPage(currentStory);
        },
      ),
    );
  }

  Widget _buildStoryPage(ConflictResolutionStory story) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            story.strategy.color.withValues(alpha: 0.1),
            story.strategy.color.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Strategy indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: story.strategy.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: story.strategy.color, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(story.strategy.icon, color: story.strategy.color),
                  const SizedBox(width: 8),
                  Text(
                    story.strategy.title,
                    style: TextStyle(
                      color: story.strategy.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Story title
            Text(
              story.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Story content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Scenario
                    _buildStorySection(
                      'The Situation',
                      story.scenario,
                      Icons.info_outline,
                      Colors.blue,
                    ),

                    const SizedBox(height: 16),

                    // Conflict
                    _buildStorySection(
                      'The Problem',
                      story.conflict,
                      Icons.warning,
                      Colors.orange,
                    ),

                    const SizedBox(height: 24),

                    // Interactive choice section
                    if (!_showChoices) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'What should happen next?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _revealChoices,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: story.strategy.color,
                                  padding: const EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Show Me the Choices',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (!_showResult) ...[
                      // Show choices
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Choose how to solve this problem:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...story.choices.map((choice) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => _selectChoice(choice),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade100,
                                      padding: const EdgeInsets.all(16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      choice.description,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Show result
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
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
                                _isCorrect ? 'Peaceful Solution! 🌟' : 'Think Again',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _isCorrect ? Colors.green : Colors.red,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _chosenChoice?.explanation ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Outcome: ${_chosenChoice?.outcome ?? ''}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Resolution and lesson
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'How It Was Solved:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              story.resolution,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Column(
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.lightbulb, color: Colors.amber),
                                      SizedBox(width: 8),
                                      Text(
                                        'Conflict Resolution Lesson',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    story.lesson,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Reflection questions
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.shade200, width: 2),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.question_answer, color: Colors.purple),
                                SizedBox(width: 8),
                                Text(
                                  'Think About It',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...story.reflectionQuestions.map((question) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(fontSize: 16)),
                                  Expanded(
                                    child: Text(
                                      question,
                                      style: const TextStyle(fontSize: 16, height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Navigation
            if (_showResult) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStoryIndex > 0)
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentStoryIndex--;
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                          _showChoices = false;
                          _showResult = false;
                          _chosenChoice = null;
                        });
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  ElevatedButton.icon(
                    onPressed: _nextStory,
                    icon: Icon(_currentStoryIndex < _stories.length - 1
                        ? Icons.arrow_forward
                        : Icons.check),
                    label: Text(_currentStoryIndex < _stories.length - 1
                        ? 'Next Story'
                        : 'Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: story.strategy.color,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStorySection(String title, String content, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick access widget for conflict resolution training
class ConflictResolutionStoriesLauncher extends StatelessWidget {
  final String characterId;

  const ConflictResolutionStoriesLauncher({
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
              Icons.balance,
              size: 48,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            const Text(
              'Conflict Resolution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Learn peaceful ways to solve problems and disagreements',
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
                      builder: (_) => ConflictResolutionStories(
                        characterId: characterId,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade400,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Practice Problem Solving',
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

// lib/family_relationship_stories.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'character_evolution.dart';
import 'emotions_learning_system.dart';
import 'therapeutic_models.dart';

/// Types of family relationship story themes
enum FamilyRelationshipTheme {
  familyCommunication,    // Expressing feelings and listening in families
  familyRoles,           // Understanding different family member roles
  familyChanges,         // Dealing with family transitions and changes
  siblingRelationships,  // Getting along with brothers and sisters
  familySupport,         // Supporting each other through challenges
  familyTraditions,      // Creating and maintaining family bonds
  expressingLove,        // Different ways to show family love
  familyConflict,        // Resolving disagreements in healthy ways
}

extension FamilyRelationshipThemeExtension on FamilyRelationshipTheme {
  String get title {
    switch (this) {
      case FamilyRelationshipTheme.familyCommunication:
        return 'Family Communication';
      case FamilyRelationshipTheme.familyRoles:
        return 'Family Roles';
      case FamilyRelationshipTheme.familyChanges:
        return 'Family Changes';
      case FamilyRelationshipTheme.siblingRelationships:
        return 'Siblings';
      case FamilyRelationshipTheme.familySupport:
        return 'Family Support';
      case FamilyRelationshipTheme.familyTraditions:
        return 'Family Traditions';
      case FamilyRelationshipTheme.expressingLove:
        return 'Showing Love';
      case FamilyRelationshipTheme.familyConflict:
        return 'Family Disagreements';
    }
  }

  String get description {
    switch (this) {
      case FamilyRelationshipTheme.familyCommunication:
        return 'Learn to express feelings and listen to family members';
      case FamilyRelationshipTheme.familyRoles:
        return 'Understand what each family member does and why';
      case FamilyRelationshipTheme.familyChanges:
        return 'Handle changes in the family with understanding';
      case FamilyRelationshipTheme.siblingRelationships:
        return 'Get along better with brothers and sisters';
      case FamilyRelationshipTheme.familySupport:
        return 'Support each other through good times and challenges';
      case FamilyRelationshipTheme.familyTraditions:
        return 'Create special traditions that bring families together';
      case FamilyRelationshipTheme.expressingLove:
        return 'Show love in many different ways';
      case FamilyRelationshipTheme.familyConflict:
        return 'Solve family disagreements peacefully';
    }
  }

  IconData get icon {
    switch (this) {
      case FamilyRelationshipTheme.familyCommunication:
        return Icons.chat;
      case FamilyRelationshipTheme.familyRoles:
        return Icons.family_restroom;
      case FamilyRelationshipTheme.familyChanges:
        return Icons.change_circle;
      case FamilyRelationshipTheme.siblingRelationships:
        return Icons.diversity_3;
      case FamilyRelationshipTheme.familySupport:
        return Icons.support;
      case FamilyRelationshipTheme.familyTraditions:
        return Icons.celebration;
      case FamilyRelationshipTheme.expressingLove:
        return Icons.favorite;
      case FamilyRelationshipTheme.familyConflict:
        return Icons.balance;
    }
  }

  Color get color {
    switch (this) {
      case FamilyRelationshipTheme.familyCommunication:
        return Colors.blue;
      case FamilyRelationshipTheme.familyRoles:
        return Colors.green;
      case FamilyRelationshipTheme.familyChanges:
        return Colors.orange;
      case FamilyRelationshipTheme.siblingRelationships:
        return Colors.purple;
      case FamilyRelationshipTheme.familySupport:
        return Colors.teal;
      case FamilyRelationshipTheme.familyTraditions:
        return Colors.pink;
      case FamilyRelationshipTheme.expressingLove:
        return Colors.red;
      case FamilyRelationshipTheme.familyConflict:
        return Colors.indigo;
    }
  }

  String get familySkillLearned {
    switch (this) {
      case FamilyRelationshipTheme.familyCommunication:
        return 'Expressing feelings and listening to family members';
      case FamilyRelationshipTheme.familyRoles:
        return 'Understanding and appreciating family member contributions';
      case FamilyRelationshipTheme.familyChanges:
        return 'Adapting to changes with patience and understanding';
      case FamilyRelationshipTheme.siblingRelationships:
        return 'Building positive relationships with siblings';
      case FamilyRelationshipTheme.familySupport:
        return 'Supporting family through challenges and celebrations';
      case FamilyRelationshipTheme.familyTraditions:
        return 'Creating and maintaining meaningful family traditions';
      case FamilyRelationshipTheme.expressingLove:
        return 'Showing love in ways that match each family member';
      case FamilyRelationshipTheme.familyConflict:
        return 'Resolving disagreements with respect and understanding';
    }
  }
}

/// Represents a family relationship story with emotional learning elements
class FamilyRelationshipStory {
  final String id;
  final FamilyRelationshipTheme theme;
  final String title;
  final String scenario;
  final List<String> familyMembers;
  final String challenge;
  final String resolution;
  final String familyLesson;
  final List<String> discussionQuestions;
  final int recommendedAge;

  FamilyRelationshipStory({
    required this.id,
    required this.theme,
    required this.title,
    required this.scenario,
    required this.familyMembers,
    required this.challenge,
    required this.resolution,
    required this.familyLesson,
    required this.discussionQuestions,
    this.recommendedAge = 8,
  });
}

/// Interactive elements within family relationship stories
class FamilyStoryInteraction {
  final String id;
  final String prompt;
  final List<String> choices;
  final String correctChoice;
  final String explanation;
  final String familySkillDemonstrated;

  FamilyStoryInteraction({
    required this.id,
    required this.prompt,
    required this.choices,
    required this.correctChoice,
    required this.explanation,
    required this.familySkillDemonstrated,
  });
}

/// Main family relationship stories screen
class FamilyRelationshipStories extends StatefulWidget {
  final String characterId;

  const FamilyRelationshipStories({
    super.key,
    required this.characterId,
  });

  @override
  State<FamilyRelationshipStories> createState() => _FamilyRelationshipStoriesState();
}

class _FamilyRelationshipStoriesState extends State<FamilyRelationshipStories>
    with TickerProviderStateMixin {
  late List<FamilyRelationshipStory> _stories;
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  int _currentStoryIndex = 0;
  bool _showInteractions = false;
  int _currentInteractionIndex = 0;
  String _selectedChoice = '';
  bool _showFeedback = false;
  bool _isCorrect = false;

  @override
  void initState() {
    super.initState();
    _initializeStories();
    _setupAnimations();
    _pageController = PageController();
  }

  void _initializeStories() {
    _stories = _generateFamilyStories();
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

  List<FamilyRelationshipStory> _generateFamilyStories() {
    return [
      // Family Communication Story
      FamilyRelationshipStory(
        id: 'family_comm_1',
        theme: FamilyRelationshipTheme.familyCommunication,
        title: 'The Family Meeting',
        scenario: 'Every week, the Johnson family has a special "family meeting" where everyone shares how their week went and talks about their feelings. This week, Jamie has been feeling worried about school but hasn\'t told anyone.',
        familyMembers: ['Mom', 'Dad', 'Jamie (10 years old)', 'Alex (7 years old)'],
        challenge: 'Jamie feels nervous about sharing feelings at the family meeting and stays quiet while others talk.',
        resolution: 'Mom notices Jamie is quiet and gently asks, "Jamie, is there anything you\'d like to share?" Jamie takes a deep breath and says, "I\'ve been feeling worried about my math test." The whole family listens carefully and Dad says, "It\'s okay to feel worried. Let\'s practice math together tonight." Jamie feels much better after sharing.',
        familyLesson: 'Family meetings create a safe space where everyone can share their feelings. When we listen to each other with love, we strengthen our family bonds and help each other through worries.',
        discussionQuestions: [
          'Why do you think Jamie was nervous about sharing feelings?',
          'How did the family help Jamie feel better?',
          'What are some feelings you might want to share with your family?',
          'How does sharing feelings make families stronger?'
        ],
      ),

      // Family Roles Story
      FamilyRelationshipStory(
        id: 'family_roles_1',
        theme: FamilyRelationshipTheme.familyRoles,
        title: 'Everyone Helps',
        scenario: 'The Martinez family is preparing for a big family dinner. Everyone has different jobs to help make the dinner special. Mom is cooking, Dad is setting the table, and the kids have their own important jobs too.',
        familyMembers: ['Mom', 'Dad', 'Sofia (9 years old)', 'Carlos (6 years old)', 'Abuela'],
        challenge: 'Carlos says, "I don\'t want to help! I just want to play!" He feels like his job of folding napkins isn\'t important.',
        resolution: 'Mom explains, "Every job in our family is important. You folding the napkins means our guests will have nice napkins for dinner. And Sofia arranging flowers makes the table beautiful. We all work together to show our love." Carlos helps fold the napkins and feels proud when everyone compliments how nice the table looks.',
        familyLesson: 'Every family member has an important role, no matter how small it seems. When we all contribute our unique skills and help each other, we create something beautiful together.',
        discussionQuestions: [
          'What job did each family member have?',
          'Why was Carlos\' job important?',
          'How did helping make Carlos feel?',
          'What special jobs do people in your family have?'
        ],
      ),

      // Family Changes Story
      FamilyRelationshipStory(
        id: 'family_changes_1',
        theme: FamilyRelationshipTheme.familyChanges,
        title: 'A New Baby Sister',
        scenario: 'The Chen family is excited because Mom is going to have a baby! They\'ve been waiting for months. Today, the new baby sister arrives home from the hospital. Emma (8 years old) has mixed feelings about the new addition to the family.',
        familyMembers: ['Mom', 'Dad', 'Emma (8 years old)', 'Baby Lily'],
        challenge: 'Emma feels jealous that the baby gets so much attention. She misses having Mom and Dad all to herself and worries they won\'t love her as much.',
        resolution: 'Dad notices Emma seems quiet and sits down with her. "Emma, we love you just as much as always. Lily needs extra attention because she\'s so little, but you\'re our big girl who helps take care of her. You\'re still our special Emma." Emma helps feed the baby and feels proud to be such a good big sister.',
        familyLesson: 'Families change and grow, and that\'s okay. Love doesn\'t get divided - it grows bigger to include everyone. New family members bring new love and new ways to care for each other.',
        discussionQuestions: [
          'How did Emma feel about the new baby?',
          'What did Dad say to help Emma?',
          'How did Emma\'s feelings change?',
          'How do families change and stay the same?'
        ],
      ),

      // Sibling Relationships Story
      FamilyRelationshipStory(
        id: 'siblings_1',
        theme: FamilyRelationshipTheme.siblingRelationships,
        title: 'The Sharing Game',
        scenario: 'It\'s Saturday afternoon and the Garcia siblings, Maria (10) and Jose (7), want to play with the same toy car. They both love racing it around the living room track they built with blocks.',
        familyMembers: ['Mom', 'Dad', 'Maria (10 years old)', 'Jose (7 years old)'],
        challenge: 'Maria grabs the car first and says, "It\'s mine! I had it first!" Jose starts to cry and says, "You\'re not being fair!" They start arguing about whose turn it is.',
        resolution: 'Mom hears the arguing and comes to help. "Let\'s take turns fairly," she says. "Maria can play for 5 minutes, then Jose for 5 minutes. Or you could race together - one drives and one builds the track!" The siblings decide to work together, with Maria driving and Jose adding jumps to the track. They have the most fun they\'ve ever had playing with the car.',
        familyLesson: 'Brothers and sisters can be each other\'s best friends when they learn to share, take turns, and work together. Sibling relationships grow stronger when we treat each other with kindness and find ways to play together.',
        discussionQuestions: [
          'Why were Maria and Jose arguing?',
          'How did Mom help solve the problem?',
          'What did the siblings decide to do?',
          'How can brothers and sisters be good friends?'
        ],
      ),

      // Family Support Story
      FamilyRelationshipStory(
        id: 'family_support_1',
        theme: FamilyRelationshipTheme.familySupport,
        title: 'Team Family',
        scenario: 'Dad has been feeling tired and worried because he lost his job. The whole Thompson family is working together to get through this difficult time. Everyone is helping in different ways to support each other.',
        familyMembers: ['Mom', 'Dad', 'Sarah (11 years old)', 'Mike (9 years old)'],
        challenge: 'Sarah feels scared about the family\'s money worries. She doesn\'t know how to help and feels helpless.',
        resolution: 'During dinner, the family talks about their feelings. Sarah says, "I\'m scared about money." Dad hugs her and says, "We\'re all scared, but we\'re a team. You help by being brave and doing your chores without complaining." Sarah helps Mom make extra cookies to sell at the school bake sale. The family works together and Dad finds a new job. They realize their love and teamwork got them through the hard time.',
        familyLesson: 'Families support each other through good times and challenging times. When we share our worries, work together, and show love, we can overcome any difficulty as a strong family team.',
        discussionQuestions: [
          'How did each family member help?',
          'What did Sarah learn about family support?',
          'How did talking about feelings help the family?',
          'How can families support each other?'
        ],
      ),

      // Family Traditions Story
      FamilyRelationshipStory(
        id: 'traditions_1',
        theme: FamilyRelationshipTheme.familyTraditions,
        title: 'Sunday Story Time',
        scenario: 'The Patel family has a special tradition every Sunday evening. After dinner, everyone gathers in the living room for "story time." Each person takes turns telling a story about something that happened during the week.',
        familyMembers: ['Mom', 'Dad', 'Priya (8 years old)', 'Arjun (6 years old)'],
        challenge: 'This week, Arjun doesn\'t have an interesting story to tell. He feels left out and wishes he had something exciting to share like his sister Priya.',
        resolution: 'When it\'s Arjun\'s turn, he says, "I don\'t have a big story, but I helped Mom plant flowers today and we saw a butterfly." Everyone listens carefully and Dad says, "That\'s a wonderful story about helping and seeing something beautiful!" The family decides to start a new tradition of drawing pictures of their "small stories" to share. Arjun feels proud that his small moment mattered.',
        familyLesson: 'Family traditions create special memories and make everyone feel included. Every story matters, from big adventures to small moments of joy. Traditions help us stay connected and celebrate what makes each family member special.',
        discussionQuestions: [
          'What was the family\'s Sunday tradition?',
          'How did Arjun feel about sharing his story?',
          'What new tradition did the family start?',
          'Why are family traditions important?'
        ],
      ),

      // Expressing Love Story
      FamilyRelationshipStory(
        id: 'love_expression_1',
        theme: FamilyRelationshipTheme.expressingLove,
        title: 'Love Languages',
        scenario: 'The Rivera family members all show love in different ways. Mom shows love by cooking special meals. Dad shows love by fixing things around the house. Miguel (9 years old) shows love by drawing pictures. Sometimes they don\'t understand each other\'s ways of showing love.',
        familyMembers: ['Mom', 'Dad', 'Miguel (9 years old)', 'Isabella (7 years old)'],
        challenge: 'Miguel feels like Dad doesn\'t love him because Dad doesn\'t say "I love you" very often. Miguel wishes Dad would be more like Mom, who always gives hugs and says loving words.',
        resolution: 'During a family talk, Dad explains, "I show love by taking care of our home and making sure everything works. That\'s how my family showed love when I was growing up." Miguel shares that he shows love through drawings. The family learns that everyone expresses love differently, and that\'s okay. They start a "love notes" jar where everyone can write or draw how they feel loved.',
        familyLesson: 'People show love in many different ways - through words, actions, gifts, time together, or physical touch. Learning to recognize and appreciate different love languages helps families feel loved and connected.',
        discussionQuestions: [
          'How does each family member show love?',
          'How did Miguel feel about Dad\'s way of showing love?',
          'What did the family learn about love?',
          'How do you like to show love to your family?'
        ],
      ),

      // Family Conflict Story
      FamilyRelationshipStory(
        id: 'family_conflict_1',
        theme: FamilyRelationshipTheme.familyConflict,
        title: 'The Big Cleanup',
        scenario: 'It\'s Saturday morning and the whole Wilson family needs to clean the house before Grandma comes to visit. Everyone has different ideas about how to divide up the work fairly.',
        familyMembers: ['Mom', 'Dad', 'Tyler (10 years old)', 'Zoe (8 years old)'],
        challenge: 'Tyler wants to vacuum but Zoe wants to do it. They start arguing about who gets to do which chores. Mom and Dad try to help but everyone is getting frustrated.',
        resolution: 'Dad suggests they have a "family meeting" to solve the problem. "Let\'s take turns choosing chores we like," he says. Tyler chooses vacuuming, Zoe chooses dusting, Mom chooses kitchen, and Dad chooses bathrooms. They work together and finish quickly. When Grandma arrives, she says, "What a clean and happy home! I can tell this family works well together."',
        familyLesson: 'Families sometimes disagree, but we can solve problems by talking calmly, listening to each other, and finding solutions that work for everyone. Working through disagreements peacefully makes families stronger.',
        discussionQuestions: [
          'Why were Tyler and Zoe arguing?',
          'How did the family solve the problem?',
          'What would you do if you disagreed with your family about chores?',
          'How does solving problems together make families stronger?'
        ],
      ),
    ];
  }

  void _startStory() {
    setState(() {
      _showInteractions = false;
      _currentInteractionIndex = 0;
      _selectedChoice = '';
      _showFeedback = false;
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
      });
      _startStory();
    } else {
      _showCompletion();
    }
  }

  void _showCompletion() {
    // Update character evolution for family relationship skills
    _updateCharacterEvolution();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Family Stories Complete! 🏠'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You\'ve explored important family relationships through stories!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Remember: Families grow stronger when we communicate, support each other, and work through challenges together.',
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

  Future<void> _updateCharacterEvolution() async {
    try {
      final characterEvolutionService = CharacterEvolutionService();

      // Update progress for family relationship skills
      await characterEvolutionService.updateCharacterEvolution(
        widget.characterId,
        TherapeuticGoal.socialSkills, // Could be a new goal type for family relationships
        'family_relationships',
        _stories.length * 4, // Progress based on stories completed
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Relationship Stories'),
        backgroundColor: Colors.green.shade400,
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
          return _buildStoryPage(_stories[index]);
        },
      ),
    );
  }

  Widget _buildStoryPage(FamilyRelationshipStory story) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            story.theme.color.withOpacity(0.1),
            story.theme.color.withOpacity(0.05),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Theme indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: story.theme.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: story.theme.color, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(story.theme.icon, color: story.theme.color),
                  const SizedBox(width: 8),
                  Text(
                    story.theme.title,
                    style: TextStyle(
                      color: story.theme.color,
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
                      'The Family Story',
                      story.scenario,
                      Icons.home,
                      Colors.green,
                    ),

                    const SizedBox(height: 16),

                    // Challenge
                    _buildStorySection(
                      'The Challenge',
                      story.challenge,
                      Icons.warning,
                      Colors.orange,
                    ),

                    const SizedBox(height: 16),

                    // Resolution
                    _buildStorySection(
                      'How They Solved It',
                      story.resolution,
                      Icons.check_circle,
                      Colors.blue,
                    ),

                    const SizedBox(height: 24),

                    // Family lesson
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200, width: 2),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.family_restroom, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'Family Lesson',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            story.familyLesson,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Discussion questions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200, width: 2),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.question_answer, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Family Talk',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...story.discussionQuestions.map((question) => Padding(
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
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Navigation
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
                      });
                      _startStory();
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
                    backgroundColor: story.theme.color,
                  ),
                ),
              ],
            ),
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
            color: Colors.black.withOpacity(0.1),
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

/// Quick access widget for family relationship stories
class FamilyRelationshipStoriesLauncher extends StatelessWidget {
  final String characterId;

  const FamilyRelationshipStoriesLauncher({
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
              Icons.family_restroom,
              size: 48,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            const Text(
              'Family Relationship Stories',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Learn about family communication, roles, and supporting each other',
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
                      builder: (_) => FamilyRelationshipStories(
                        characterId: characterId,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade400,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Explore Family Stories',
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

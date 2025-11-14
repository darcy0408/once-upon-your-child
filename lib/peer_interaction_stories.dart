// lib/peer_interaction_stories.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'character_evolution.dart';
import 'emotions_learning_system.dart';

/// Types of peer interaction story themes
enum PeerInteractionTheme {
  makingFriends,        // Learning to approach and befriend others
  sharingCooperation,   // Working together and sharing resources
  conflictResolution,   // Resolving disagreements peacefully
  socialCues,          // Reading social signals and body language
  inclusion,           // Including others and fighting exclusion
  friendshipDynamics,  // Understanding friendship maintenance
  peerPressure,        // Handling negative peer influence
  kindness,            // Acts of kindness and helping others
}

extension PeerInteractionThemeExtension on PeerInteractionTheme {
  String get title {
    switch (this) {
      case PeerInteractionTheme.makingFriends:
        return 'Making Friends';
      case PeerInteractionTheme.sharingCooperation:
        return 'Sharing & Teamwork';
      case PeerInteractionTheme.conflictResolution:
        return 'Solving Problems Together';
      case PeerInteractionTheme.socialCues:
        return 'Reading Social Signals';
      case PeerInteractionTheme.inclusion:
        return 'Including Everyone';
      case PeerInteractionTheme.friendshipDynamics:
        return 'Being a Good Friend';
      case PeerInteractionTheme.peerPressure:
        return 'Standing Up for Yourself';
      case PeerInteractionTheme.kindness:
        return 'Acts of Kindness';
    }
  }

  String get description {
    switch (this) {
      case PeerInteractionTheme.makingFriends:
        return 'Learn how to approach others and start new friendships';
      case PeerInteractionTheme.sharingCooperation:
        return 'Discover the joy of working together and sharing';
      case PeerInteractionTheme.conflictResolution:
        return 'Find peaceful ways to solve disagreements with friends';
      case PeerInteractionTheme.socialCues:
        return 'Understand what facial expressions and body language mean';
      case PeerInteractionTheme.inclusion:
        return 'Learn why it\'s important to include everyone';
      case PeerInteractionTheme.friendshipDynamics:
        return 'Keep friendships strong with trust and support';
      case PeerInteractionTheme.peerPressure:
        return 'Make good choices even when friends disagree';
      case PeerInteractionTheme.kindness:
        return 'Small acts of kindness make big differences';
    }
  }

  IconData get icon {
    switch (this) {
      case PeerInteractionTheme.makingFriends:
        return Icons.people;
      case PeerInteractionTheme.sharingCooperation:
        return Icons.handshake;
      case PeerInteractionTheme.conflictResolution:
        return Icons.balance;
      case PeerInteractionTheme.socialCues:
        return Icons.visibility;
      case PeerInteractionTheme.inclusion:
        return Icons.group_add;
      case PeerInteractionTheme.friendshipDynamics:
        return Icons.favorite;
      case PeerInteractionTheme.peerPressure:
        return Icons.shield;
      case PeerInteractionTheme.kindness:
        return Icons.volunteer_activism;
    }
  }

  Color get color {
    switch (this) {
      case PeerInteractionTheme.makingFriends:
        return Colors.blue;
      case PeerInteractionTheme.sharingCooperation:
        return Colors.green;
      case PeerInteractionTheme.conflictResolution:
        return Colors.orange;
      case PeerInteractionTheme.socialCues:
        return Colors.purple;
      case PeerInteractionTheme.inclusion:
        return Colors.pink;
      case PeerInteractionTheme.friendshipDynamics:
        return Colors.red;
      case PeerInteractionTheme.peerPressure:
        return Colors.indigo;
      case PeerInteractionTheme.kindness:
        return Colors.teal;
    }
  }

  String get socialSkillLearned {
    switch (this) {
      case PeerInteractionTheme.makingFriends:
        return 'Approaching others with confidence and kindness';
      case PeerInteractionTheme.sharingCooperation:
        return 'Working together and sharing resources fairly';
      case PeerInteractionTheme.conflictResolution:
        return 'Using words to solve problems peacefully';
      case PeerInteractionTheme.socialCues:
        return 'Reading facial expressions and body language';
      case PeerInteractionTheme.inclusion:
        return 'Making sure everyone feels welcome';
      case PeerInteractionTheme.friendshipDynamics:
        return 'Supporting friends and building trust';
      case PeerInteractionTheme.peerPressure:
        return 'Making choices that are right for you';
      case PeerInteractionTheme.kindness:
        return 'Performing small acts of kindness daily';
    }
  }
}

/// Represents a peer interaction story with social learning elements
class PeerInteractionStory {
  final String id;
  final PeerInteractionTheme theme;
  final String title;
  final String scenario;
  final List<String> characters;
  final String challenge;
  final String resolution;
  final String socialLesson;
  final List<String> discussionQuestions;
  final int recommendedAge;

  PeerInteractionStory({
    required this.id,
    required this.theme,
    required this.title,
    required this.scenario,
    required this.characters,
    required this.challenge,
    required this.resolution,
    required this.socialLesson,
    required this.discussionQuestions,
    this.recommendedAge = 8,
  });
}

/// Interactive elements within peer interaction stories
class StoryInteraction {
  final String id;
  final String prompt;
  final List<String> choices;
  final String correctChoice;
  final String explanation;
  final String socialSkillDemonstrated;

  StoryInteraction({
    required this.id,
    required this.prompt,
    required this.choices,
    required this.correctChoice,
    required this.explanation,
    required this.socialSkillDemonstrated,
  });
}

/// Main peer interaction stories screen
class PeerInteractionStories extends StatefulWidget {
  final String characterId;

  const PeerInteractionStories({
    super.key,
    required this.characterId,
  });

  @override
  State<PeerInteractionStories> createState() => _PeerInteractionStoriesState();
}

class _PeerInteractionStoriesState extends State<PeerInteractionStories>
    with TickerProviderStateMixin {
  late List<PeerInteractionStory> _stories;
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
    _stories = _generatePeerStories();
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

  List<PeerInteractionStory> _generatePeerStories() {
    return [
      // Making Friends Story
      PeerInteractionStory(
        id: 'making_friends_1',
        theme: PeerInteractionTheme.makingFriends,
        title: 'The New Kid at School',
        scenario: 'Today is Alex\'s first day at a new school. Alex feels nervous about making friends. During recess, Alex sees a group of kids playing tag and wants to join them.',
        characters: ['Alex', 'Jordan', 'Taylor', 'Sam'],
        challenge: 'Alex is too shy to ask if they can play with the other kids.',
        resolution: 'Alex takes a deep breath and says, "Hi! Can I play tag with you?" The kids smile and say, "Sure! You\'re on Jordan\'s team!" They all play together and become friends.',
        socialLesson: 'Making friends starts with being brave enough to say hello. Everyone feels nervous sometimes, but kindness opens doors to new friendships.',
        discussionQuestions: [
          'How do you think Alex felt before joining the game?',
          'What brave thing did Alex do?',
          'How would you feel if someone asked to play with you?',
          'What\'s one way you can make a new friend this week?'
        ],
      ),

      // Sharing & Cooperation Story
      PeerInteractionStory(
        id: 'sharing_coop_1',
        theme: PeerInteractionTheme.sharingCooperation,
        title: 'The Group Art Project',
        scenario: 'Ms. Johnson gives the class a big art project. Everyone needs to work together to create a beautiful mural for the school hallway. Each student has different art supplies and talents.',
        characters: ['Emma', 'Liam', 'Sophia', 'Noah'],
        challenge: 'Emma has the best markers but doesn\'t want to share them because she wants her part to look perfect.',
        resolution: 'Emma remembers how much fun it is to work together. She shares her markers and helps Liam with his drawing. Sophia teaches Emma how to blend colors. They create an amazing mural that everyone loves!',
        socialLesson: 'Sharing and working together makes everything better. When we help each other, we can create something more beautiful than anyone could make alone.',
        discussionQuestions: [
          'Why didn\'t Emma want to share at first?',
          'How did sharing help the group?',
          'What talents did each friend bring to the project?',
          'When have you shared something and it made things better?'
        ],
      ),

      // Conflict Resolution Story
      PeerInteractionStory(
        id: 'conflict_resolution_1',
        theme: PeerInteractionTheme.conflictResolution,
        title: 'The Broken Toy',
        scenario: 'During playtime, Jamie accidentally breaks Riley\'s favorite toy car while they were playing together. Riley gets very upset and starts to cry.',
        characters: ['Jamie', 'Riley', 'Ms. Carter'],
        challenge: 'Riley is angry and says, "You broke my toy! You\'re not my friend anymore!" Jamie feels bad but doesn\'t know what to say.',
        resolution: 'Jamie says, "I\'m really sorry I broke your toy. It was an accident. Can we fix it together or find another way to play?" Riley calms down and they decide to build a new car out of blocks. They become even better friends.',
        socialLesson: 'Accidents happen, but we can always fix things with kind words and working together. True friends help each other through mistakes.',
        discussionQuestions: [
          'How did Riley feel when the toy broke?',
          'What did Jamie do to make things better?',
          'How would you feel if someone broke something of yours?',
          'What\'s a kind way to solve problems with friends?'
        ],
      ),

      // Social Cues Story
      PeerInteractionStory(
        id: 'social_cues_1',
        theme: PeerInteractionTheme.socialCues,
        title: 'Reading the Signs',
        scenario: 'During lunch, Casey notices that their friend Morgan looks sad. Morgan is sitting alone, poking at their food, and not talking to anyone.',
        characters: ['Casey', 'Morgan', 'Teacher'],
        challenge: 'Casey wants to help Morgan feel better but isn\'t sure if Morgan wants to talk.',
        resolution: 'Casey notices Morgan\'s sad face and quiet behavior. Casey gently asks, "Are you okay? You look a little sad today." Morgan shares that they\'re worried about a test. Casey listens and helps Morgan study. Morgan feels much better.',
        socialLesson: 'Paying attention to how others look and act helps us know when they need a friend. A kind word and listening ear can make a big difference.',
        discussionQuestions: [
          'What signs showed that Morgan was sad?',
          'How did Casey know Morgan needed help?',
          'What would you do if you saw a friend looking sad?',
          'Why is it important to notice how others feel?'
        ],
      ),

      // Inclusion Story
      PeerInteractionStory(
        id: 'inclusion_1',
        theme: PeerInteractionTheme.inclusion,
        title: 'The Game of Tag',
        scenario: 'At recess, a group of kids are playing tag. They\'re having so much fun running and laughing. Casey watches from the sidelines, wishing they could join but feeling too shy to ask.',
        characters: ['Casey', 'Group of kids', 'Alex'],
        challenge: 'The kids are so busy playing they don\'t notice Casey wants to join. Casey feels left out.',
        resolution: 'Alex from the group notices Casey watching and says, "Hey Casey! Want to play tag with us? You can be on my team!" Everyone cheers and includes Casey in the game. They take turns being "it" so everyone gets to run and tag.',
        socialLesson: 'Everyone wants to feel included and have fun with friends. Noticing when someone feels left out and inviting them to join makes the world a kinder place.',
        discussionQuestions: [
          'How do you think Casey felt watching the game?',
          'What did Alex do to help?',
          'How would the game be better with Casey included?',
          'When have you included someone who felt left out?'
        ],
      ),

      // Friendship Dynamics Story
      PeerInteractionStory(
        id: 'friendship_1',
        theme: PeerInteractionTheme.friendshipDynamics,
        title: 'The Secret Keeper',
        scenario: 'Jordan tells their best friend Taylor a secret about liking someone at school. Taylor promises not to tell anyone. Later, some other kids ask Taylor about the secret.',
        characters: ['Jordan', 'Taylor', 'Other kids'],
        challenge: 'The other kids keep asking Taylor about Jordan\'s secret. Taylor feels pressured to tell them.',
        resolution: 'Taylor remembers that friends keep promises. Taylor says, "I promised Jordan I wouldn\'t tell, so I can\'t share the secret." The other kids understand and respect Taylor for being a good friend. Jordan is so happy to have such a trustworthy friend.',
        socialLesson: 'Trust is the foundation of friendship. Keeping promises and respecting secrets shows you value your friendship and care about your friend\'s feelings.',
        discussionQuestions: [
          'Why is keeping secrets important in friendship?',
          'How did Taylor show she was a good friend?',
          'What would happen if friends couldn\'t trust each other?',
          'How can you show your friends you can be trusted?'
        ],
      ),

      // Peer Pressure Story
      PeerInteractionStory(
        id: 'peer_pressure_1',
        theme: PeerInteractionTheme.peerPressure,
        title: 'The Right Choice',
        scenario: 'During lunch, Casey\'s friends want to play a game that involves running in the hallway where they\'re not supposed to. They say, "Come on Casey, everyone\'s doing it! It\'ll be fun!"',
        characters: ['Casey', 'Friends', 'Teacher'],
        challenge: 'Casey\'s friends are pressuring Casey to break the rules, saying "Don\'t be a scaredy-cat!" Casey wants to be liked but knows the rules are important.',
        resolution: 'Casey says, "I want to play, but I don\'t want to get in trouble. Let\'s find a fun game we can play in the right place." The friends agree and they have a great time playing tag on the playground instead. Casey feels good about making a smart choice.',
        socialLesson: 'Being a good friend means making choices that keep everyone safe and happy. You can still have fun with friends while following rules and doing the right thing.',
        discussionQuestions: [
          'Why did Casey\'s friends want to break the rules?',
          'What brave choice did Casey make?',
          'How did Casey\'s choice affect the friendship?',
          'When have you made a choice to do the right thing?'
        ],
      ),

      // Kindness Story
      PeerInteractionStory(
        id: 'kindness_1',
        theme: PeerInteractionTheme.kindness,
        title: 'The Little Things',
        scenario: 'It\'s a rainy day at school. Riley forgot their umbrella and gets soaked walking to class. Riley looks cold and unhappy. Casey notices and wants to help.',
        characters: ['Casey', 'Riley', 'Classmates'],
        challenge: 'Casey wants to help Riley but isn\'t sure what to do.',
        resolution: 'Casey shares their extra sweatshirt with Riley so they can dry off. Casey also draws a funny picture to make Riley laugh. Riley smiles and says, "Thank you for being so kind!" The small acts of kindness make both Casey and Riley feel warm inside.',
        socialLesson: 'Small acts of kindness can make a big difference in someone\'s day. When we notice others\' needs and help in little ways, we create more happiness in the world.',
        discussionQuestions: [
          'What small things did Casey do to help Riley?',
          'How do you think Riley felt after Casey helped?',
          'What are some small acts of kindness you can do?',
          'How does helping others make you feel?'
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
    // Update character evolution for social skills
    _updateCharacterEvolution();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Social Stories Complete! 🌟'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You\'ve explored important social skills through stories!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Remember: Kindness, sharing, and understanding make the best friends.',
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

      // Update progress for social skills
      await characterEvolutionService.updateCharacterEvolution(
        widget.characterId,
        TherapeuticGoal.socialSkills, // This would need to be added to TherapeuticGoal enum
        'social_skills_development',
        _stories.length * 5, // Progress based on stories completed
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
        title: const Text('Peer Interaction Stories'),
        backgroundColor: Colors.lightBlue.shade400,
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

  Widget _buildStoryPage(PeerInteractionStory story) {
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
                      'The Situation',
                      story.scenario,
                      Icons.info_outline,
                      Colors.blue,
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
                      Colors.green,
                    ),

                    const SizedBox(height: 24),

                    // Social lesson
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200, width: 2),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lightbulb, color: Colors.amber),
                              SizedBox(width: 8),
                              Text(
                                'Social Lesson',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            story.socialLesson,
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

/// Quick access widget for peer interaction stories
class PeerInteractionStoriesLauncher extends StatelessWidget {
  final String characterId;

  const PeerInteractionStoriesLauncher({
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
            Icons.groups,
            size: 48,
            color: Colors.lightBlue,
          ),
          const SizedBox(height: 16),
          const Text(
            'Peer Interaction Stories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Learn social skills through stories about making friends and getting along',
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
                    builder: (_) => PeerInteractionStories(
                      characterId: characterId,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue.shade400,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Explore Social Stories',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
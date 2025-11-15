// lib/conflict_resolution_stories.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'character_evolution.dart';
import 'emotions_learning_system.dart';

/// Types of conflict resolution strategies
enum ConflictResolutionStrategy {
  usingWords,          // Using calm words instead of actions
  findingCompromise,   // Finding solutions that work for everyone
  takingTurns,         // Fair sharing and turn-taking
  apologizing,         // Saying sorry and forgiving
  gettingHelp,         // Asking adults for help when needed
  understandingViews,  // Seeing the situation from others' perspectives
  iStatements,         // Using "I feel" statements to express emotions
  problemSolving,      // Step-by-step problem solving approach
}

extension ConflictResolutionStrategyExtension on ConflictResolutionStrategy {
  String get title {
    switch (this) {
      case ConflictResolutionStrategy.usingWords:
        return 'Using Words';
      case ConflictResolutionStrategy.findingCompromise:
        return 'Finding Compromise';
      case ConflictResolutionStrategy.takingTurns:
        return 'Taking Turns';
      case ConflictResolutionStrategy.apologizing:
        return 'Apologizing';
      case ConflictResolutionStrategy.gettingHelp:
        return 'Getting Help';
      case ConflictResolutionStrategy.understandingViews:
        return 'Understanding Others';
      case ConflictResolutionStrategy.iStatements:
        return 'I Statements';
      case ConflictResolutionStrategy.problemSolving:
        return 'Problem Solving';
    }
  }

  String get description {
    switch (this) {
      case ConflictResolutionStrategy.usingWords:
        return 'Use calm words to express feelings instead of actions';
      case ConflictResolutionStrategy.findingCompromise:
        return 'Find solutions that work for everyone involved';
      case ConflictResolutionStrategy.takingTurns:
        return 'Take turns fairly and share resources equally';
      case ConflictResolutionStrategy.apologizing:
        return 'Say sorry when you hurt others and forgive mistakes';
      case ConflictResolutionStrategy.gettingHelp:
        return 'Ask trusted adults for help with big problems';
      case ConflictResolutionStrategy.understandingViews:
        return 'Try to see the situation from the other person\'s side';
      case ConflictResolutionStrategy.iStatements:
        return 'Use "I feel" statements to express your emotions';
      case ConflictResolutionStrategy.problemSolving:
        return 'Follow steps to solve problems peacefully';
    }
  }

  IconData get icon {
    switch (this) {
      case ConflictResolutionStrategy.usingWords:
        return Icons.chat;
      case ConflictResolutionStrategy.findingCompromise:
        return Icons.handshake;
      case ConflictResolutionStrategy.takingTurns:
        return Icons.access_time;
      case ConflictResolutionStrategy.apologizing:
        return Icons.healing;
      case ConflictResolutionStrategy.gettingHelp:
        return Icons.help;
      case ConflictResolutionStrategy.understandingViews:
        return Icons.visibility;
      case ConflictResolutionStrategy.iStatements:
        return Icons.person;
      case ConflictResolutionStrategy.problemSolving:
        return Icons.lightbulb;
    }
  }

  Color get color {
    switch (this) {
      case ConflictResolutionStrategy.usingWords:
        return Colors.blue;
      case ConflictResolutionStrategy.findingCompromise:
        return Colors.green;
      case ConflictResolutionStrategy.takingTurns:
        return Colors.orange;
      case ConflictResolutionStrategy.apologizing:
        return Colors.pink;
      case ConflictResolutionStrategy.gettingHelp:
        return Colors.purple;
      case ConflictResolutionStrategy.understandingViews:
        return Colors.teal;
      case ConflictResolutionStrategy.iStatements:
        return Colors.indigo;
      case ConflictResolutionStrategy.problemSolving:
        return Colors.amber;
    }
  }

  String get skillLearned {
    switch (this) {
      case ConflictResolutionStrategy.usingWords:
        return 'Using calm words to express feelings and solve problems';
      case ConflictResolutionStrategy.findingCompromise:
        return 'Finding solutions that satisfy everyone involved';
      case ConflictResolutionStrategy.takingTurns:
        return 'Sharing fairly and respecting others\' turns';
      case ConflictResolutionStrategy.apologizing:
        return 'Taking responsibility and forgiving others\' mistakes';
      case ConflictResolutionStrategy.gettingHelp:
        return 'Seeking adult help for difficult situations';
      case ConflictResolutionStrategy.understandingViews:
        return 'Considering others\' feelings and perspectives';
      case ConflictResolutionStrategy.iStatements:
        return 'Expressing feelings using "I" statements';
      case ConflictResolutionStrategy.problemSolving:
        return 'Following steps to resolve conflicts peacefully';
    }
  }
}

/// Represents an interactive conflict resolution story
class ConflictResolutionStory {
  final String id;
  final ConflictResolutionStrategy strategy;
  final String title;
  final String scenario;
  final List<String> characters;
  final String conflict;
  final List<ConflictChoice> choices;
  final String resolution;
  final String lesson;
  final List<String> reflectionQuestions;

  ConflictResolutionStory({
    required this.id,
    required this.strategy,
    required this.title,
    required this.scenario,
    required this.characters,
    required this.conflict,
    required this.choices,
    required this.resolution,
    required this.lesson,
    required this.reflectionQuestions,
  });
}

/// Interactive choice in conflict resolution story
class ConflictChoice {
  final String description;
  final bool isPeacefulSolution;
  final String explanation;
  final String outcome;

  ConflictChoice({
    required this.description,
    required this.isPeacefulSolution,
    required this.explanation,
    required this.outcome,
  });
}

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
  String _selectedChoice = '';
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
    _stories = _generateConflictStories();
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

  List<ConflictResolutionStory> _generateConflictStories() {
    return [
      // Using Words Story
      ConflictResolutionStory(
        id: 'using_words_1',
        strategy: ConflictResolutionStrategy.usingWords,
        title: 'The Soccer Game',
        scenario: 'During recess, Alex and Jordan are playing soccer. Jordan accidentally kicks the ball too hard and it hits Alex in the leg. Alex feels hurt and gets angry.',
        characters: ['Alex', 'Jordan', 'Teacher'],
        conflict: 'Alex wants to push Jordan back, but knows that might not be the best choice.',
        choices: [
          ConflictChoice(
            description: 'Push Jordan back and say "You did that on purpose!"',
            isPeacefulSolution: false,
            explanation: 'Using actions instead of words can hurt others and make the situation worse.',
            outcome: 'Jordan gets scared and runs away. The teacher has to stop the game and talk to both kids.',
          ),
          ConflictChoice(
            description: 'Take a deep breath and say "Ouch! That hurt! Please be more careful."',
            isPeacefulSolution: true,
            explanation: 'Using calm words helps others understand how you feel and gives them a chance to make it right.',
            outcome: 'Jordan says sorry and is more careful. They continue playing and become better friends.',
          ),
          ConflictChoice(
            description: 'Just walk away without saying anything',
            isPeacefulSolution: false,
            explanation: 'Walking away doesn\'t solve the problem and might make Jordan not understand what happened.',
            outcome: 'Jordan doesn\'t know why Alex is upset and feels confused. The problem isn\'t really solved.',
          ),
        ],
        resolution: 'Alex chooses to use words instead of actions. "Ouch! That really hurt my leg. Can you please be more careful?" Jordan feels bad and apologizes. They talk about playing more safely and become better friends.',
        lesson: 'Words are powerful tools for solving problems. When we use calm words to express our feelings, we give others a chance to understand and make things right. Actions can hurt, but words can heal.',
        reflectionQuestions: [
          'Why is it better to use words instead of pushing?',
          'How did using words help Alex and Jordan?',
          'What words would you use if someone accidentally hurt you?',
          'How do words help solve problems better than actions?'
        ],
      ),

      // Finding Compromise Story
      ConflictResolutionStory(
        id: 'compromise_1',
        strategy: ConflictResolutionStrategy.findingCompromise,
        title: 'The Last Cookie',
        scenario: 'After dinner, there\'s one chocolate chip cookie left. Both Maria (8 years old) and her brother Carlos (6 years old) want it. They start arguing about who should get it.',
        characters: ['Maria', 'Carlos', 'Mom'],
        conflict: 'Maria says "I saw it first!" Carlos says "But I\'m smaller so I should get it!" They can\'t agree.',
        choices: [
          ConflictChoice(
            description: 'Maria grabs the cookie quickly and eats it all',
            isPeacefulSolution: false,
            explanation: 'Taking something without agreement hurts feelings and doesn\'t solve the sharing problem.',
            outcome: 'Carlos cries and feels unfair. Maria feels guilty but the cookie is gone. They both feel bad.',
          ),
          ConflictChoice(
            description: 'Break the cookie in half and share it equally',
            isPeacefulSolution: true,
            explanation: 'Finding a compromise where both get some of what they want is fair and makes everyone happy.',
            outcome: 'Both kids get to enjoy the cookie. They learn that sharing can make good things even better.',
          ),
          ConflictChoice(
            description: 'Let Mom decide who gets the whole cookie',
            isPeacefulSolution: false,
            explanation: 'Sometimes adults need to help, but kids can solve many problems themselves by compromising.',
            outcome: 'Mom gives the cookie to Carlos because he\'s younger. Maria feels unfair and learns nothing about sharing.',
          ),
        ],
        resolution: 'Maria suggests, "Let\'s break it in half and share!" Carlos agrees. They each get half the cookie and feel happy about their fair solution. Mom smiles and says, "That\'s a great compromise!"',
        lesson: 'Compromise means finding solutions where everyone gets some of what they want. When we work together to find fair solutions, everyone can be happy and problems become opportunities to be kind.',
        reflectionQuestions: [
          'How did breaking the cookie in half help solve the problem?',
          'Why is compromise better than fighting over who gets everything?',
          'What\'s another way Maria and Carlos could have shared the cookie?',
          'How do compromises make friendships stronger?'
        ],
      ),

      // Taking Turns Story
      ConflictResolutionStory(
        id: 'taking_turns_1',
        strategy: ConflictResolutionStrategy.takingTurns,
        title: 'The Swing Set',
        scenario: 'At the playground, Tyler has been swinging for a long time. Jamie has been waiting patiently but really wants a turn. Tyler says he wants to swing "just a little longer."',
        characters: ['Tyler', 'Jamie', 'Other kids'],
        conflict: 'Jamie feels impatient and wants Tyler to get off the swing right now.',
        choices: [
          ConflictChoice(
            description: 'Push Tyler off the swing and take your turn',
            isPeacefulSolution: false,
            explanation: 'Using force hurts others and doesn\'t teach fair sharing.',
            outcome: 'Tyler falls and gets hurt. Other kids see and no one wants to play with Jamie anymore.',
          ),
          ConflictChoice(
            description: 'Wait patiently and ask "Can I have a turn when you\'re done?"',
            isPeacefulSolution: true,
            explanation: 'Being patient and asking politely shows respect for others\' turns.',
            outcome: 'Tyler says "Okay, just two more minutes!" Jamie waits and gets a great turn. They become playground friends.',
          ),
          ConflictChoice(
            description: 'Tell the teacher that Tyler won\'t share',
            isPeacefulSolution: false,
            explanation: 'Sometimes adults help, but kids should try to solve sharing problems first.',
            outcome: 'Teacher makes Tyler get off, but Tyler feels unfair and Jamie feels like a tattletale.',
          ),
        ],
        resolution: 'Jamie waits a moment and then asks politely, "Tyler, can I please have a turn when you\'re done swinging?" Tyler says, "Sure, just two more minutes!" Jamie waits patiently and gets a long turn. They take turns for the rest of recess.',
        lesson: 'Taking turns shows we respect others and value fairness. When we wait patiently and ask kindly, we usually get what we want and make friends in the process.',
        reflectionQuestions: [
          'Why is it important to take turns?',
          'How did asking politely help Jamie?',
          'What would you do if someone wouldn\'t share?',
          'How does taking turns make the playground more fun for everyone?'
        ],
      ),

      // Apologizing Story
      ConflictResolutionStory(
        id: 'apologizing_1',
        strategy: ConflictResolutionStrategy.apologizing,
        title: 'The Broken Vase',
        scenario: 'During playtime at home, Sam accidentally knocks over Mom\'s favorite vase while running through the living room. The vase breaks into pieces on the floor. Mom comes in and sees what happened.',
        characters: ['Sam', 'Mom'],
        conflict: 'Sam feels scared and wants to hide what happened, but knows Mom will find out.',
        choices: [
          ConflictChoice(
            description: 'Try to hide the broken pieces and pretend nothing happened',
            isPeacefulSolution: false,
            explanation: 'Hiding mistakes makes trust problems and doesn\'t solve the real issue.',
            outcome: 'Mom finds the mess later and is more upset because Sam wasn\'t honest. Trust is broken.',
          ),
          ConflictChoice(
            description: 'Tell Mom what happened and say "I\'m really sorry I broke your vase"',
            isPeacefulSolution: true,
            explanation: 'Being honest and apologizing shows responsibility and helps fix relationships.',
            outcome: 'Mom understands it was an accident. They clean up together and Mom forgives Sam.',
          ),
          ConflictChoice(
            description: 'Blame it on the dog or say "I don\'t know how it broke"',
            isPeacefulSolution: false,
            explanation: 'Lying makes problems worse and breaks trust with the people we care about.',
            outcome: 'Mom doesn\'t believe the lie. Sam gets in more trouble for not being honest.',
          ),
        ],
        resolution: 'Sam says, "Mom, I\'m really sorry. I was running and accidentally knocked over your vase. It broke." Mom says, "Thank you for telling me the truth. Accidents happen. Let\'s clean it up together." They talk about being more careful and Sam helps pick up the pieces.',
        lesson: 'Apologizing when we make mistakes shows we care about others\' feelings and take responsibility for our actions. Saying sorry helps heal hurt feelings and rebuild trust.',
        reflectionQuestions: [
          'Why is apologizing important?',
          'How did apologizing help Sam and Mom?',
          'What should you say when you apologize?',
          'How does apologizing make relationships stronger?'
        ],
      ),

      // Getting Help Story
      ConflictResolutionStory(
        id: 'getting_help_1',
        strategy: ConflictResolutionStrategy.gettingHelp,
        title: 'The Big Bully',
        scenario: 'At school, a bigger kid named Blake keeps taking Alex\'s lunch money and calling names. Alex feels scared and doesn\'t know what to do. Alex has tried asking Blake to stop, but it doesn\'t work.',
        characters: ['Alex', 'Blake', 'Teacher', 'Friends'],
        conflict: 'Alex wants the bullying to stop but is afraid to tell anyone.',
        choices: [
          ConflictChoice(
            description: 'Try to fight Blake to get the money back',
            isPeacefulSolution: false,
            explanation: 'Fighting makes problems worse and can hurt people.',
            outcome: 'Alex gets hurt and both kids get in trouble. The bullying might continue.',
          ),
          ConflictChoice(
            description: 'Tell a trusted adult like the teacher what\'s happening',
            isPeacefulSolution: true,
            explanation: 'Getting help from adults keeps everyone safe and solves big problems.',
            outcome: 'Teacher talks to both kids and makes a plan to keep Alex safe. Bullying stops.',
          ),
          ConflictChoice(
            description: 'Just give Blake the money every day to avoid trouble',
            isPeacefulSolution: false,
            explanation: 'Giving in to bullying teaches that bullying works and makes it continue.',
            outcome: 'Blake keeps taking money. Alex feels more scared and helpless.',
          ),
        ],
        resolution: 'Alex tells the teacher, "Blake keeps taking my lunch money and calling me names. I\'m scared." The teacher listens carefully and says, "Thank you for telling me. Bullying is not okay and we\'ll make it stop." The teacher talks to Blake and makes a safety plan. Blake learns that bullying hurts people and stops.',
        lesson: 'When problems are too big or scary to solve alone, it\'s brave and smart to get help from trusted adults. Teachers, parents, and counselors are there to keep kids safe and solve difficult problems.',
        reflectionQuestions: [
          'Why was it important for Alex to get help?',
          'How did telling the teacher help solve the problem?',
          'Who are trusted adults you can talk to about problems?',
          'Why is getting help a sign of strength, not weakness?'
        ],
      ),

      // Understanding Others' Views Story
      ConflictResolutionStory(
        id: 'understanding_views_1',
        strategy: ConflictResolutionStrategy.understandingViews,
        title: 'The Team Captain',
        scenario: 'During gym class, the teacher asks everyone to pick team captains. Most kids vote for athletic kids, but some quieter kids get chosen too. Jamie really wanted to be captain but wasn\'t picked. Jamie feels disappointed and thinks the choices were unfair.',
        characters: ['Jamie', 'Teacher', 'Classmates', 'Team Captains'],
        conflict: 'Jamie feels left out and thinks the teacher should have picked differently.',
        choices: [
          ConflictChoice(
            description: 'Complain loudly that the choices were unfair and refuse to play',
            isPeacefulSolution: false,
            explanation: 'Complaining without understanding others\' views hurts feelings and stops the fun.',
            outcome: 'Other kids feel bad and the game doesn\'t happen. Jamie feels more alone.',
          ),
          ConflictChoice(
            description: 'Try to understand why certain kids were picked and focus on having fun',
            isPeacefulSolution: true,
            explanation: 'Understanding others\' perspectives helps us accept different outcomes and still enjoy activities.',
            outcome: 'Jamie learns that different skills matter in different games. Everyone has fun playing.',
          ),
          ConflictChoice(
            description: 'Tell the teacher the picks were wrong and demand a re-vote',
            isPeacefulSolution: false,
            explanation: 'Demanding changes without understanding can seem bossy and hurt others\' feelings.',
            outcome: 'Teacher feels caught in the middle. Other kids feel Jamie is being unfair.',
          ),
        ],
        resolution: 'Jamie thinks about it and realizes that different kids have different strengths - some are fast runners, others are good at strategy. Jamie decides to be the best team player possible and cheers for teammates. The game is super fun and Jamie gets complimented for being a great sport.',
        lesson: 'Everyone sees situations differently based on their own experiences and feelings. When we try to understand others\' perspectives, we can accept different outcomes and find ways to be happy even when things don\'t go exactly as we hoped.',
        reflectionQuestions: [
          'How did understanding others\' views help Jamie?',
          'Why did different kids get picked for different reasons?',
          'How would you feel if you weren\'t picked for something you wanted?',
          'How does understanding others make conflicts easier to solve?'
        ],
      ),

      // I Statements Story
      ConflictResolutionStory(
        id: 'i_statements_1',
        strategy: ConflictResolutionStrategy.iStatements,
        title: 'The Loud Music',
        scenario: 'After school, Jamie is trying to do homework but sibling Taylor keeps playing loud music in the next room. Jamie can\'t concentrate and feels frustrated.',
        characters: ['Jamie', 'Taylor', 'Mom'],
        conflict: 'Jamie wants Taylor to turn down the music but doesn\'t want to start a fight.',
        choices: [
          ConflictChoice(
            description: 'Yell "Turn down that stupid music! You\'re so annoying!"',
            isPeacefulSolution: false,
            explanation: 'Yelling with "you" statements blames others and makes them defensive.',
            outcome: 'Taylor yells back. They argue and Mom has to intervene. No one is happy.',
          ),
          ConflictChoice(
            description: 'Say "I feel frustrated when the music is loud because I can\'t concentrate on my homework"',
            isPeacefulSolution: true,
            explanation: 'I statements express your feelings without blaming others, making it easier to solve problems.',
            outcome: 'Taylor understands and turns down the music. They work out a compromise about quiet time.',
          ),
          ConflictChoice(
            description: 'Just suffer quietly and not say anything',
            isPeacefulSolution: false,
            explanation: 'Not expressing feelings doesn\'t solve problems and can build up resentment.',
            outcome: 'Jamie stays frustrated and homework takes longer. Taylor doesn\'t know there\'s a problem.',
          ),
        ],
        resolution: 'Jamie goes to Taylor and says, "I feel frustrated when the music is really loud because I can\'t concentrate on my homework. Can you turn it down a little?" Taylor says, "Oh, I didn\'t realize it bothered you. Sure!" They agree on quiet hours for homework time.',
        lesson: 'I statements help us express our feelings without blaming others. Instead of saying "You\'re too loud," we say "I feel frustrated when it\'s loud." This makes it easier for others to understand and help solve the problem.',
        reflectionQuestions: [
          'How is an "I statement" different from a "You statement"?',
          'Why did the I statement work better than yelling?',
          'What\'s an I statement you could use when you feel frustrated?',
          'How do I statements help solve problems peacefully?'
        ],
      ),

      // Problem Solving Story
      ConflictResolutionStory(
        id: 'problem_solving_1',
        strategy: ConflictResolutionStrategy.problemSolving,
        title: 'The Science Project',
        scenario: 'For the science fair, partners Jamie and Sam need to build a model volcano. But they disagree on how to do it. Jamie wants to use baking soda and vinegar. Sam wants to use a chemical reaction with yeast.',
        characters: ['Jamie', 'Sam', 'Teacher'],
        conflict: 'Both kids want to do it their way and can\'t agree on a plan.',
        choices: [
          ConflictChoice(
            description: 'Jamie insists on doing it their way and ignores Sam\'s ideas',
            isPeacefulSolution: false,
            explanation: 'Ignoring others\' ideas doesn\'t solve problems and makes partners feel unimportant.',
            outcome: 'Sam feels left out and doesn\'t help much. The project isn\'t as good as it could be.',
          ),
          ConflictChoice(
            description: 'Follow problem-solving steps: 1) Listen to ideas, 2) Find common ground, 3) Try a compromise',
            isPeacefulSolution: true,
            explanation: 'Following steps to solve problems helps find solutions that work for everyone.',
            outcome: 'They combine both ideas into an amazing volcano that wins first place!',
          ),
          ConflictChoice(
            description: 'Give up and ask the teacher to assign different partners',
            isPeacefulSolution: false,
            explanation: 'Giving up without trying to solve the problem misses opportunities to learn and succeed.',
            outcome: 'They don\'t learn to work together and miss out on a great project experience.',
          ),
        ],
        resolution: 'Jamie and Sam decide to use the problem-solving steps their teacher taught: 1) Listen to each other\'s ideas, 2) Find what they agree on (both want an awesome volcano), 3) Try combining ideas. They create a volcano that erupts twice - once with baking soda and once with yeast! It wins first place.',
        lesson: 'Problems can be solved step by step. When we listen to each other, find common ground, and try creative compromises, we can find solutions that are better than anyone thought of alone.',
        reflectionQuestions: [
          'What were the problem-solving steps Jamie and Sam used?',
          'How did combining ideas make their project better?',
          'What\'s a problem you solved by listening to others?',
          'Why is it important to try solving problems before giving up?'
        ],
      ),
    ];
  }

  void _showChoices() {
    setState(() {
      _showChoices = true;
    });
  }

  void _selectChoice(ConflictChoice choice) {
    setState(() {
      _selectedChoice = choice.description;
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
        _selectedChoice = '';
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
            story.strategy.color.withOpacity(0.1),
            story.strategy.color.withOpacity(0.05),
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
                color: story.strategy.color.withOpacity(0.2),
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
                              color: Colors.black.withOpacity(0.1),
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
                                onPressed: _showChoices,
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
                              color: Colors.black.withOpacity(0.1),
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
                              color: Colors.black.withOpacity(0.1),
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
                          _selectedChoice = '';
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
      ),
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
    );
  }
}
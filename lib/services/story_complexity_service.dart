class AgeGroup {
  final String name;
  final int minAge;
  final int maxAge;
  final int minWords;
  final int maxWords;
  final String vocabularyLevel;
  final List<String> exampleWords;
  final String complexityDescription;

  const AgeGroup({
    required this.name,
    required this.minAge,
    required this.maxAge,
    required this.minWords,
    required this.maxWords,
    required this.vocabularyLevel,
    required this.exampleWords,
    required this.complexityDescription,
  });
}

class StoryComplexityService {
  static const List<AgeGroup> ageGroups = [
    AgeGroup(
      name: 'Early Childhood',
      minAge: 3,
      maxAge: 5,
      minWords: 100,
      maxWords: 150,
      vocabularyLevel: 'Basic nouns and verbs',
      exampleWords: ['cat', 'dog', 'run', 'jump', 'happy', 'sad', 'big', 'small'],
      complexityDescription: 'Very simple stories with basic vocabulary and short sentences',
    ),
    AgeGroup(
      name: 'Early Elementary',
      minAge: 6,
      maxAge: 8,
      minWords: 150,
      maxWords: 250,
      vocabularyLevel: 'Sight words and phonics',
      exampleWords: ['the', 'and', 'you', 'it', 'in', 'said', 'for', 'what', 'friend', 'school'],
      complexityDescription: 'Simple stories with sight words, basic phonics, and simple plot',
    ),
    AgeGroup(
      name: 'Upper Elementary',
      minAge: 9,
      maxAge: 12,
      minWords: 250,
      maxWords: 400,
      vocabularyLevel: 'Grade-level vocabulary',
      exampleWords: ['beautiful', 'important', 'different', 'together', 'adventure', 'discover', 'wonderful', 'carefully'],
      complexityDescription: 'More complex stories with grade-appropriate vocabulary and multi-step plots',
    ),
    AgeGroup(
      name: 'Early Teen',
      minAge: 13,
      maxAge: 15,
      minWords: 400,
      maxWords: 600,
      vocabularyLevel: 'Advanced vocabulary',
      exampleWords: ['extraordinary', 'challenging', 'responsibility', 'determination', 'perspective', 'significant'],
      complexityDescription: 'Complex themes with advanced vocabulary and character development',
    ),
    AgeGroup(
      name: 'Late Teen/Adult',
      minAge: 16,
      maxAge: 99,
      minWords: 600,
      maxWords: 800,
      vocabularyLevel: 'Mature vocabulary',
      exampleWords: ['philosophical', 'consequential', 'transformative', 'resilience', 'empathy', 'authenticity'],
      complexityDescription: 'Mature themes with sophisticated vocabulary and deep emotional exploration',
    ),
  ];

  /// Returns guidance for the provided age group.
  static Map<String, dynamic> getAgeGuidelines(int age) {
    final ageGroup = getAgeGroup(age);
    return {
      'length_guideline': '${ageGroup.minWords}-${ageGroup.maxWords} words',
      'word_count_min': ageGroup.minWords,
      'word_count_max': ageGroup.maxWords,
      'vocabulary_level': ageGroup.vocabularyLevel,
      'sentence_structure': _getSentenceComplexity(age),
      'vocabulary_examples': ageGroup.exampleWords.join(', '),
      'concepts': _getThemeComplexity(age),
      'special_instructions': ageGroup.complexityDescription,
    };
  }

  static AgeGroup getAgeGroup(int age) {
    for (final group in ageGroups) {
      if (age >= group.minAge && age <= group.maxAge) {
        return group;
      }
    }
    // Default to adult group for ages above 16
    return ageGroups.last;
  }

  static Map<String, dynamic> getStoryGuidelines(int age) {
    final ageGroup = getAgeGroup(age);

    return {
      'age_group': ageGroup.name,
      'min_words': ageGroup.minWords,
      'max_words': ageGroup.maxWords,
      'vocabulary_level': ageGroup.vocabularyLevel,
      'example_words': ageGroup.exampleWords,
      'complexity_description': ageGroup.complexityDescription,
      'target_word_count': (ageGroup.minWords + ageGroup.maxWords) ~/ 2,
      'reading_level': _getReadingLevel(age),
      'sentence_complexity': _getSentenceComplexity(age),
      'theme_complexity': _getThemeComplexity(age),
    };
  }

  static String _getReadingLevel(int age) {
    if (age <= 5) return 'Pre-K/Emergent Reader';
    if (age <= 8) return 'Early Reader';
    if (age <= 12) return 'Developing Reader';
    if (age <= 15) return 'Advanced Reader';
    return 'Adult Reader';
  }

  static String _getSentenceComplexity(int age) {
    if (age <= 5) return 'Simple 3-5 word sentences';
    if (age <= 8) return 'Simple to compound sentences';
    if (age <= 12) return 'Compound and complex sentences';
    if (age <= 15) return 'Complex sentences with clauses';
    return 'Sophisticated sentence structures';
  }

  static String _getThemeComplexity(int age) {
    if (age <= 5) return 'Basic emotions and simple experiences';
    if (age <= 8) return 'Friendship, family, and school experiences';
    if (age <= 12) return 'Personal growth, challenges, and relationships';
    if (age <= 15) return 'Identity, social issues, and emotional complexity';
    return 'Deep emotional exploration and life experiences';
  }

  /// Creates an instruction block that can be dropped into AI prompts.
  static String buildAgeInstructions(int age) {
    final guidelines = getAgeGuidelines(age);
    return '''
AGE-APPROPRIATE GUIDELINES FOR ${age}-YEAR-OLD:
✓ LENGTH: ${guidelines['length_guideline']} (strict requirement)
✓ VOCABULARY: ${guidelines['vocabulary_level']}
✓ SENTENCE STYLE: ${guidelines['sentence_structure']}
✓ WORD EXAMPLES: ${guidelines['vocabulary_examples']}
✓ CONCEPTS: ${guidelines['concepts']}
✓ SPECIAL NOTES: ${guidelines['special_instructions']}
''';
  }

  static String generateComplexityPrompt(int age, String emotionName, String emotionDescription) {
    final guidelines = getStoryGuidelines(age);
    final ageGroup = getAgeGroup(age);

    return '''
Create a therapeutic story for a ${ageGroup.name} child (age $age) experiencing the emotion: $emotionName.

STORY REQUIREMENTS:
- Word count: ${guidelines['min_words']}-${guidelines['max_words']} words (target: ${guidelines['target_word_count']})
- Reading level: ${guidelines['reading_level']}
- Sentence complexity: ${guidelines['sentence_complexity']}
- Theme complexity: ${guidelines['theme_complexity']}

VOCABULARY GUIDELINES:
- Use ${guidelines['vocabulary_level']}
- Include words like: ${ageGroup.exampleWords.take(6).join(', ')}
- Avoid complex words unless essential to the emotional theme

STORY STRUCTURE:
- Simple beginning that introduces the character and their feeling
- Middle that explores the emotion through relatable experiences
- Positive resolution that validates feelings and offers hope
- Include 1-2 specific coping strategies appropriate for this age

EMOTIONAL FOCUS:
$emotionDescription

Make the story engaging, age-appropriate, and therapeutically valuable.
''';
  }

  static Map<String, dynamic> validateStoryComplexity(String story, int age) {
    final guidelines = getStoryGuidelines(age);
    final wordCount = story.split(RegExp(r'\s+')).length;

    final issues = <String>[];

    if (wordCount < guidelines['min_words']) {
      issues.add('Story too short (${wordCount} words, minimum ${guidelines['min_words']})');
    }
    if (wordCount > guidelines['max_words']) {
      issues.add('Story too long (${wordCount} words, maximum ${guidelines['max_words']})');
    }

    // Check for age-appropriate vocabulary (basic check)
    final complexWords = _findComplexWords(story, age);
    if (complexWords.isNotEmpty) {
      issues.add('May contain complex words: ${complexWords.take(3).join(', ')}');
    }

    return {
      'word_count': wordCount,
      'target_range': '${guidelines['min_words']}-${guidelines['max_words']}',
      'is_valid': issues.isEmpty,
      'issues': issues,
      'age_appropriate_score': _calculateAgeAppropriateness(story, age),
    };
  }

  static List<String> _findComplexWords(String story, int age) {
    final ageGroup = getAgeGroup(age);
    final simpleWords = ageGroup.exampleWords.toSet();

    final words = story.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 6) // Only check longer words
        .toSet();

    return words.where((word) => !simpleWords.contains(word)).toList();
  }

  static double _calculateAgeAppropriateness(String story, int age) {
    // Simple scoring based on word length and complexity
    final words = story.split(RegExp(r'\s+'));
    final avgWordLength = words.map((w) => w.length).reduce((a, b) => a + b) / words.length;

    // Younger ages prefer shorter words
    final targetAvgLength = age <= 8 ? 4.0 : age <= 12 ? 5.0 : 6.0;
    final lengthScore = 1.0 - (avgWordLength - targetAvgLength).abs() / 3.0;

    return lengthScore.clamp(0.0, 1.0);
  }
}

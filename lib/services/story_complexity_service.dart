class StoryComplexityService {
  /// Returns guidance for the provided age group.
  static Map<String, dynamic> getAgeGuidelines(int age) {
    if (age <= 5) {
      return {
        'length_guideline': '100-150 words',
        'word_count_min': 100,
        'word_count_max': 150,
        'vocabulary_level': 'very simple vocabulary (CVC + sight words)',
        'sentence_structure': 'very short sentences (3-6 words)',
        'vocabulary_examples': 'cat, dog, happy, sad, run, jump, play',
        'concepts': 'concrete, tangible ideas only',
        'special_instructions': 'Use rhyme/repetition, no abstract concepts.',
      };
    } else if (age <= 8) {
      return {
        'length_guideline': '150-250 words',
        'word_count_min': 150,
        'word_count_max': 250,
        'vocabulary_level': 'simple (sight words + basic phonics)',
        'sentence_structure': 'short, clear sentences',
        'vocabulary_examples': 'sight words + CVC words (cat, bat, sit)',
        'concepts': 'simple cause and effect',
        'special_instructions': 'Include dialogue and phonics-friendly words.',
      };
    } else if (age <= 12) {
      return {
        'length_guideline': '250-400 words',
        'word_count_min': 250,
        'word_count_max': 400,
        'vocabulary_level': 'grade-level vocabulary',
        'sentence_structure': 'mix of simple and complex sentences',
        'vocabulary_examples':
            'adventurous, curious, determined, nervous, excited',
        'concepts': 'character growth and multi-layer plots',
        'special_instructions': 'Highlight problem-solving and emotional depth.',
      };
    } else if (age <= 15) {
      return {
        'length_guideline': '400-600 words',
        'word_count_min': 400,
        'word_count_max': 600,
        'vocabulary_level': 'advanced and expressive',
        'sentence_structure': 'sophisticated sentence variety',
        'vocabulary_examples': 'contemplated, ambivalent, resilient, nuanced',
        'concepts': 'complex themes and moral dilemmas',
        'special_instructions':
            'Layer emotions, identity exploration, and real-world parallels.',
      };
    } else {
      return {
        'length_guideline': '600-800 words',
        'word_count_min': 600,
        'word_count_max': 800,
        'vocabulary_level': 'mature / literary vocabulary',
        'sentence_structure': 'complex, literary prose',
        'vocabulary_examples':
            'introspective, existential, paradoxical, cathartic',
        'concepts': 'philosophical questions and mature themes',
        'special_instructions':
            'Use literary devices, symbolism, and deep psychology.',
      };
    }
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
}

import 'package:flutter/material.dart';
import '../../feelings_wheel_data.dart';
import '../wizard_story_screen.dart';

/// Helper to map WizardData to API-ready payload
class WizardDataMapper {
  static Map<String, dynamic> mapToStoryRequest(WizardData data) {
    // 1. Map Age
    final int age = data.characterAge;

    // 2. Map Emotion (Take the first one if multiple, or map simplified ones)
    Map<String, dynamic>? currentFeeling;
    if (data.selectedEmotionChips.isNotEmpty) {
      final chipLabel = data.selectedEmotionChips.first;
      currentFeeling = _mapChipToFeeling(chipLabel);
    }

    // 3. Map Archetype to Character Traits or Details
    final characterDetails = _mapArchetypeToDetails(
      data.selectedArchetypeId,
      data.personalitySliders,
    );
    
    // Add appearance to details
    if (data.selectedOutfit.isNotEmpty) {
      characterDetails['outfit'] = data.selectedOutfit;
    }

    if (data.pets.isNotEmpty) {
      characterDetails['pets'] = data.pets;
    }

    // 4. Map Scenario to Theme
    final theme = _mapScenarioToTheme(data.selectedScenario);

    return {
      'characterName': data.characterName,
      'age': age,
      'theme': theme,
      'companion': (data.selectedCompanions.isNotEmpty) 
          ? data.selectedCompanions.join(', ')
          : null,
      'additionalCharacters': data.additionalCharacters,
      'characterDetails': characterDetails,
      'currentFeeling': currentFeeling,
      // Default settings for wizard stories
      'lengthGuideline': 'Short', 
      'rhymeTimeMode': false,
      'learningToReadMode': false, // Could be toggled based on age < 5
      'includeIllustrations': true, // User requested illustrations
    };
  }

  static String _mapScenarioToTheme(String? scenarioId) {
    switch (scenarioId) {
      case 'school_jitters':
        return 'First Day of School';
      case 'big_feelings':
        return 'Managing Big Emotions';
      case 'making_friends':
        return 'Making New Friends';
      case 'being_brave':
        return 'Facing a Fear';
      case 'calm_moments':
        return 'Relaxation and Mindfulness';
      case 'creative_ideas':
        return 'Creativity and Imagination';
      default:
        return 'Magical Adventure';
    }
  }

  static Map<String, dynamic> _mapChipToFeeling(String chipLabel) {
    // defaults
    String emotionName = 'Happy';
    String emotionEmoji = '😊';
    String description = 'Feeling good';
    List<String> coping = ['Smile', 'Share joy'];

    // Map simplified chips to complex FeelingWheelData
    // Chips: Shining Bright, Being Brave, Making Friends, Calm Moments, Creative Ideas, Feeling Happy/Sad/Mad
    
    if (chipLabel.contains('Sad')) {
      emotionName = 'Sad';
      emotionEmoji = '😢';
      final details = FeelingDetails.forFeeling(const SelectedFeeling(
        core: 'Sad', secondary: 'Sad', tertiary: 'Sad', 
        emoji: '😢', eyeType: '', mouthType: '', color:  Color(0xFF6495ED)
      ));
      description = details.description;
      coping = details.coping;
    } else if (chipLabel.contains('Mad')) {
      emotionName = 'Mad';
      emotionEmoji = '😠';
      final details = FeelingDetails.forFeeling(const SelectedFeeling(
        core: 'Angry', secondary: 'Mad', tertiary: 'Mad',
        emoji: '😠', eyeType: '', mouthType: '', color: Color(0xFFFF6B6B)
      ));
      description = details.description;
      coping = details.coping;
    } else if (chipLabel.contains('Brave')) {
      emotionName = 'Scared'; // Needs bravery
      emotionEmoji = '😨';
      description = 'Feeling a bit scared but ready to be brave';
      coping = ['Take a deep breath', 'Stand tall', 'Remember you are strong'];
    } else if (chipLabel.contains('Calm')) {
      emotionName = 'Calm';
      emotionEmoji = '😌';
      description = 'Feeling peaceful and relaxed';
      coping = ['Breathe slowly', 'Close eyes', 'Listen to nature'];
    } else if (chipLabel.contains('Creative')) {
      emotionName = 'Inspired';
      emotionEmoji = '🎨';
      description = 'Wanting to make something new';
      coping = ['Draw', 'Build', 'Imagine'];
    }
    
    return {
      'emotion_name': emotionName,
      'emotion_emoji': emotionEmoji,
      'emotion_description': description,
      'intensity': 3, // Default medium intensity
      'physical_signs': 'Feeling it in the body',
      'coping_strategies': coping,
    };
  }

  static Map<String, dynamic> _mapArchetypeToDetails(
    String? archetypeId, 
    Map<String, int> sliders
  ) {
    final Map<String, dynamic> details = {
      'personality_sliders': sliders,
      'strengths': <String>[],
      'interests': <String>[],
    };

    if (archetypeId != null) {
      if (archetypeId.contains('Adventurer')) {
        details['strengths'] = ['Bravery', 'Curiosity'];
        details['interests'] = ['Exploring', 'Maps', 'Nature'];
      } else if (archetypeId.contains('Thinker')) {
         details['strengths'] = ['Problem solving', 'Focus'];
         details['interests'] = ['Puzzles', 'Reading', 'Science'];
      } else if (archetypeId.contains('Artist')) {
         details['strengths'] = ['Creativity', 'Vision'];
         details['interests'] = ['Painting', 'Colors', 'Music'];
      } else if (archetypeId.contains('Helper')) {
         details['strengths'] = ['Kindness', 'Empathy'];
         details['interests'] = ['Animals', 'Helping friends'];
      } else if (archetypeId.contains('Athlete')) {
         details['strengths'] = ['Energy', 'Teamwork'];
         details['interests'] = ['Sports', 'Running', 'Games'];
      }
    }
    return details;
  }
}

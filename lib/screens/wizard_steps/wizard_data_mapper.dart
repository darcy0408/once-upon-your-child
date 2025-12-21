import 'package:flutter/material.dart';
import '../../feelings_wheel_data.dart';
import '../wizard_story_screen.dart';
import '../../data/companion_data.dart';
import '../../data/mood_physics.dart';
import '../../data/scenario_data.dart';

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

    // 4. Map Scenario to Theme and new Fields
    String theme = 'Magical Adventure';
    String conflictHook = '';  // Default to empty string instead of null
    String sensoryPalette = '';  // Default to empty string instead of null

    if (data.selectedScenario != null) {
      final scenarioCard = ScenarioData.getById(data.selectedScenario!);
      if (scenarioCard != null) {
        theme = scenarioCard.title;
        conflictHook = scenarioCard.conflictHook;
        sensoryPalette = scenarioCard.sensoryPalette;
      }
    }

    // Extract companion names and categorize them
    final companionNames = data.companionNames.isNotEmpty
        ? data.companionNames
        : data.selectedCompanions;

    // Separate companions into pets vs other characters
    final List<Map<String, dynamic>> companionsPets = [];
    final List<Map<String, dynamic>> companionsOther = [];

    for (final companionName in companionNames) {
      // Check if this companion is one of the main character's pets
      final isPet = data.pets.any((pet) => pet['name'] == companionName);

      if (isPet) {
        // Find the pet details
        final petDetails = data.pets.firstWhere((pet) => pet['name'] == companionName);
        companionsPets.add(petDetails);
      } else {
        // It's another character or magical creature
        // Check if it's one of our special Power-Pairing companions and pass their full details/ability
        final companionData = _getCompanionData(companionName);
        if (companionData != null) {
           companionsOther.add({
             'name': companionData.name,
             'description': companionData.description,
             'signaturePower': companionData.signaturePower,
             'powerConstraint': companionData.powerConstraint,
             'sensoryTell': companionData.sensoryTell,
           });
        } else {
           // Standard friend/sibling
           companionsOther.add({'name': companionName});
        }
      }
    }

    // 5. Map Mood Physics based on emotion
    Map<String, dynamic>? moodPhysics;
    if (data.selectedEmotionChips.isNotEmpty) {
      moodPhysics = _mapMoodToPhysics(data.selectedEmotionChips.first);
    }

    return {
      'character': data.characterName,
      'age': age,
      'theme': theme,
      'conflictHook': conflictHook, // NEW
      'sensoryPalette': sensoryPalette, // NEW
      // Send structured companion data
      'companion_pets': companionsPets, // Pets with species info
      'companion_characters': companionsOther, // Now a list of detailed maps
      'additionalCharacters': data.additionalCharacters, 
      'characterDetails': characterDetails,
      'currentFeeling': currentFeeling,
      'sparkTool': data.selectedSparkTool, // NEW: Spark Tool
      'moodPhysics': moodPhysics, // NEW: Mood Physics
      // Story mode settings from wizard
      'storyLength': data.storyLength, // quick, standard, or epic
      'rhymeTimeMode': data.rhymeTimeMode,
      'learningToReadMode': data.learningToReadMode,
      'interactiveMode': data.interactiveMode,
      'includeIllustrations': data.includeIllustrations
    };
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
      // Find the full archetype data to get the special ability
      try {
        // We import CharacterArchetypes from archetype_card.dart. 
        // Note: Ideally this data should be shared cleanly, but for now we search by name.
        // We access CharacterArchetypes.all to find the match.
        // Since we can't import the widget file easily here without circular depends if not careful,
        // we'll use a local lookup or assume the caller passed it.
        // Actually, we can import it. Let's rely on the string matching logic for now
        // but enhance it to pass the specific ability if we can.
        
        // Specific mapping logic based on the new names
        if (archetypeId.contains('Storm Rider') || archetypeId.contains('Adventurer')) {
          details['strengths'] = ['Bravery', 'Curiosity'];
          details['interests'] = ['Exploring', 'Maps', 'Nature'];
          details['special_ability'] = 'Can command wind and weather to soar through storms';
        } else if (archetypeId.contains('Riddle-Solver') || archetypeId.contains('Thinker')) {
           details['strengths'] = ['Problem solving', 'Focus'];
           details['interests'] = ['Puzzles', 'Reading', 'Science'];
           details['special_ability'] = 'Can decipher secret maps and unlock ancient mysteries';
        } else if (archetypeId.contains('Master Creator') || archetypeId.contains('Artist')) {
           details['strengths'] = ['Creativity', 'Vision'];
           details['interests'] = ['Painting', 'Colors', 'Music'];
           details['special_ability'] = 'Has a magic paintbrush that brings drawings to life';
        } else if (archetypeId.contains('Heart Healer') || archetypeId.contains('Helper')) {
           details['strengths'] = ['Kindness', 'Empathy'];
           details['interests'] = ['Animals', 'Helping friends'];
           details['special_ability'] = 'Can sense emotions and heal broken spirits with kindness';
        } else if (archetypeId.contains('Lightning Runner') || archetypeId.contains('Athlete')) {
           details['strengths'] = ['Energy', 'Teamwork'];
           details['interests'] = ['Sports', 'Running', 'Games'];
           details['special_ability'] = 'Moves faster than sound and leaves trails of stardust';
        } else if (archetypeId.contains('Animal Whisperer') || archetypeId.contains('Shy')) {
           details['strengths'] = ['Kindness', 'Nature Magic']; 
           details['interests'] = ['Animals', 'Nature', 'Secrets'];
           details['special_ability'] = 'Can talk to animals and move unseen like a shadow';
        }
      } catch (e) {
        debugPrint('Error mapping archetype details: $e');
      }
    }
    return details;
  }


  static CompanionData? _getCompanionData(String name) {
    try {
      return magicCompanions.firstWhere((c) => name.contains(c.id) || name.contains(c.name));
    } catch (e) {
      return null;
    }
  }

  static Map<String, dynamic>? _mapMoodToPhysics(String chipLabel) {
    try {
      MoodPhysics? physics;
      if (chipLabel.contains('Sad') || chipLabel.contains('Blue')) {
        physics = moodPhysicsRules.firstWhere((r) => r.id == 'blue');
      } else if (chipLabel.contains('Mad') || chipLabel.contains('Stormy')) {
        physics = moodPhysicsRules.firstWhere((r) => r.id == 'stormy');
      } else if (chipLabel.contains('Creative') || chipLabel.contains('Inspired')) {
        physics = moodPhysicsRules.firstWhere((r) => r.id == 'creative');
      } else if (chipLabel.contains('Calm') || chipLabel.contains('Peaceful')) {
        physics = moodPhysicsRules.firstWhere((r) => r.id == 'peaceful');
      } else if (chipLabel.contains('Brave') || chipLabel.contains('Scared')) {
        physics = moodPhysicsRules.firstWhere((r) => r.id == 'brave');
      } else if (chipLabel.contains('Happy') || chipLabel.contains('Joyful')) {
        physics = moodPhysicsRules.firstWhere((r) => r.id == 'joyful');
      } else if (chipLabel.contains('Friendly')) {
        physics = moodPhysicsRules.firstWhere((r) => r.id == 'friendly');
      }

      if (physics != null) {
        return {
          'mood': physics.moodName,
          'worldRule': physics.worldRule,
          'sensoryChange': physics.sensoryChange,
        };
      }
    } catch (e) {
      debugPrint('Error mapping mood physics: $e');
    }
    return null;
  }
}

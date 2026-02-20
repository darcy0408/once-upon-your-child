import '../models/generated_avatar.dart';

/// WizardData - Collects all wizard selections
class WizardData {
  // Step 1: Hero Creator
  String? selectedArchetypeId;
  String? characterId; // To link to existing or saved character
  String characterGender = 'Girl'; // Default, toggleable in Step 1
  Map<String, int> personalitySliders = {
    'energy': 50,
    'sociability': 50,
    'creativity': 50,
    'confidence': 50,
    'empathy': 50,
    'adventurousness': 50,
  };
  String characterName = '';
  int characterAge = 8;
  String selectedHairStyle = '';
  String selectedSkinTone = '';
  String selectedOutfit = '';
  GeneratedAvatar? generatedAvatar; // AI-generated avatar
  String? customAvatarPath; // Path to a custom avatar image (local file) for story illustrations

  // Advanced character features
  List<String> fears = [];
  List<String> strengths = [];
  String? comfortItem;

  // Custom Pets & Additional Characters
  List<Map<String, String>> pets = [];
  Map<String, GeneratedAvatar> petAvatars = {}; // NEW: Map of pet name to generated avatar
  List<String> additionalCharacters = [];

  // Step 2: Feeling Selection
  String? selectedScenario;
  List<String> selectedEmotionChips = [];
  String? parentalNote;

  // Step 3: Companion Selector
  List<String> selectedCompanions = [];
  List<String> companionNames = [];

  // Step 4: Story Settings
  bool rhymeTimeMode = false;
  bool learningToReadMode = false;
  bool interactiveMode = false;
  bool includeIllustrations = true; // Default to true
  String storyLength = 'standard'; // Options: 'quick', 'standard', 'epic'
  String customElements = ''; // Free-form text: "What do you want in your story?"
  String? selectedSparkTool;
  
  // Guardian Mode / Therapeutic Features
  String? lifeChallenge;

  // Helper methods
  bool get isStep1Complete =>
      selectedArchetypeId != null && characterName.isNotEmpty;

  bool get isStep2Complete => true; // Feeling section removed

  bool get isStep3Complete => true; // selectedCompanions is optional

  bool get isComplete =>
      isStep1Complete && isStep3Complete;

  Map<String, dynamic> toJson() {
    return {
      'characterId': characterId,
      'gender': characterGender,
      'archetype': selectedArchetypeId,
      'personality': personalitySliders,
      'name': characterName,
      'age': characterAge,
      'appearance': {
        'hair': selectedHairStyle,
        'skin': selectedSkinTone,
        'outfit': selectedOutfit,
      },
      if (generatedAvatar != null) 'generated_avatar': generatedAvatar!.toJson(),
      'fears': fears,
      'strengths': strengths,
      'comfortItem': comfortItem,
      'pets': pets,
      'petAvatars': petAvatars.map((key, value) => MapEntry(key, value.toJson())),
      'additionalCharacters': additionalCharacters,
      'scenario': selectedScenario,
      'emotions': selectedEmotionChips,
      'parentalNote': parentalNote,
      'companions': selectedCompanions,
      'companionNames': companionNames,
      'rhymeTimeMode': rhymeTimeMode,
      'learningToReadMode': learningToReadMode,
      'interactiveMode': interactiveMode,
      'includeIllustrations': includeIllustrations,
      'storyLength': storyLength,
      'customElements': customElements,
      'lifeChallenge': lifeChallenge,
    };
  }
}

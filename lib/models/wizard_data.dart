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
  String favoriteColor = 'Gold'; // Default favorite color
  String selectedHairStyle = '';
  String selectedSkinTone = '';
  String selectedOutfit = '';
  GeneratedAvatar? generatedAvatar; // AI-generated avatar
  String?
      customAvatarPath; // Path to a custom avatar image (local file) for story illustrations

  // Advanced character features
  List<String> fears = [];
  List<String> strengths = [];
  String? comfortItem;

  // Custom Pets & Additional Characters
  List<Map<String, String>> pets = [];
  Map<String, GeneratedAvatar> petAvatars =
      {}; // AI-generated magical pet avatars
  Map<String, String> petPhotos = {}; // Real pet photos: name → base64 jpeg
  List<String> additionalCharacters = [];

  // Step 2: Feeling Selection
  String? selectedScenario;
  List<String> selectedEmotionChips = [];
  String? selectedFeeling;
  String? selectedTrigger;
  String? selectedBodySignal;
  String? selectedCopingTool;
  String? selectedRepairGoal;
  String? parentHiddenContext;
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
  String customElements =
      ''; // Free-form text: "What do you want in your story?"
  String? selectedGenre; // e.g. 'mystery', 'comedy', null = no genre
  String? selectedSparkTool;

  // Guardian Mode / Therapeutic Features
  String? lifeChallenge;

  // Feature 4: Story DNA (parent-authored context behind math gate)
  String? storyDnaContext; // "What's in their world?" chip
  String? storyDnaOutcome; // "What magic would help most?" chip
  String? storyDnaAvoid; // "Any words/topics to avoid?" free text

  // Feature 3: Superpower Profile (child-facing — narrative therapy externalization)
  String? heroSuperpower; // e.g. "Kindness Magic"
  String?
      heroQuest; // e.g. "Making new friends" — maps silently to lifeChallenge

  // Helper methods
  bool get isStep1Complete =>
      selectedArchetypeId != null && characterName.isNotEmpty;

  bool get isStep2Complete => true; // Feeling section removed

  bool get isStep3Complete => true; // selectedCompanions is optional

  bool get isComplete => isStep1Complete && isStep3Complete;

  Map<String, dynamic> toJson() {
    return {
      'characterId': characterId,
      'gender': characterGender,
      'archetype': selectedArchetypeId,
      'personality': personalitySliders,
      'name': characterName,
      'age': characterAge,
      'favoriteColor': favoriteColor,
      'appearance': {
        'hair': selectedHairStyle,
        'skin': selectedSkinTone,
        'outfit': selectedOutfit,
      },
      if (generatedAvatar != null)
        'generated_avatar': generatedAvatar!.toJson(),
      'fears': fears,
      'strengths': strengths,
      'comfortItem': comfortItem,
      'pets': pets,
      'petAvatars':
          petAvatars.map((key, value) => MapEntry(key, value.toJson())),
      'additionalCharacters': additionalCharacters,
      'scenario': selectedScenario,
      'emotions': selectedEmotionChips,
      'selectedFeeling': selectedFeeling,
      'selectedTrigger': selectedTrigger,
      'selectedBodySignal': selectedBodySignal,
      'selectedCopingTool': selectedCopingTool,
      'selectedRepairGoal': selectedRepairGoal,
      'parentHiddenContext': parentHiddenContext,
      'parentalNote': parentalNote,
      'companions': selectedCompanions,
      'companionNames': companionNames,
      'rhymeTimeMode': rhymeTimeMode,
      'learningToReadMode': learningToReadMode,
      'interactiveMode': interactiveMode,
      'includeIllustrations': includeIllustrations,
      'storyLength': storyLength,
      'customElements': customElements,
      'selectedGenre': selectedGenre,
      'lifeChallenge': lifeChallenge,
    };
  }
}

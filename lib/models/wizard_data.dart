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
  String?
      selectedCharacterAssetPath; // Flutter asset path of the preset character PNG picked in the carousel

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

  /// Adult relatives in the story — Premium "whole family" tier.
  /// Each entry: {'name': 'Sarah', 'relation': 'mom'|'dad'|'grandma'|...}.
  /// Treated as supportive adult presence in the prompt — not peers, not villains.
  List<Map<String, String>> adultRelatives = [];

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
  Map<String, String> companionCustomNames = {}; // id → user's custom name

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

  // Superhero Mode (ages 3-5) — costume customization + selected power.
  // Backend keys: hero_costume_color, hero_cape_style, hero_emblem, hero_power.
  String? heroCostumeColor; // 'red' | 'blue' | 'green' | 'yellow' | 'purple' | 'pink'
  String? heroCapeStyle;    // 'none' | 'matching' | 'rainbow'
  String? heroEmblem;       // 'star' | 'lightning' | 'heart' | 'moon' | 'paw' | 'rainbow'
  String? heroPower;        // one of 8 IDs: super_speed | flying | super_strength |
                            // super_hearing | super_smile | super_hugs | super_whisper | super_sharing
  String? heroCatchphrase;  // optional signature line the hero says at the story
                            // climax (Explorer 6-8 / Adventurer 9-12). Backend key:
                            // hero_catchphrase. Absent = unchanged story behavior.
  String? heroPortraitUrl;  // data URI of the AI superhero portrait built from the
                            // child's avatar (Explorer/Adventurer). Null until the
                            // reveal screen generates it; best-effort, never required.
  String? heroNemesisId;    // C4: Adventurer-chosen arch-villain id (key in backend
                            // ADVENTURER_VILLAINS). Null = let the server surprise-pick.
                            // Backend key: hero_nemesis_id.

  // Creator band (12-14): optional reflection prompt from character creation
  String? characterDesire; // e.g. "What does your character want more than anything?"

  /// Returns a deep copy of this WizardData.
  WizardData clone() {
    final c = WizardData();
    c.selectedArchetypeId = selectedArchetypeId;
    c.characterId = characterId;
    c.characterGender = characterGender;
    c.personalitySliders = Map<String, int>.from(personalitySliders);
    c.characterName = characterName;
    c.characterAge = characterAge;
    c.favoriteColor = favoriteColor;
    c.selectedHairStyle = selectedHairStyle;
    c.selectedSkinTone = selectedSkinTone;
    c.selectedOutfit = selectedOutfit;
    c.generatedAvatar = generatedAvatar;
    c.customAvatarPath = customAvatarPath;
    c.selectedCharacterAssetPath = selectedCharacterAssetPath;
    c.fears = List<String>.from(fears);
    c.strengths = List<String>.from(strengths);
    c.comfortItem = comfortItem;
    c.pets = pets.map((p) => Map<String, String>.from(p)).toList();
    c.petAvatars = Map.from(petAvatars);
    c.petPhotos = Map<String, String>.from(petPhotos);
    c.additionalCharacters = List<String>.from(additionalCharacters);
    c.adultRelatives = adultRelatives.map((r) => Map<String, String>.from(r)).toList();
    c.selectedScenario = selectedScenario;
    c.selectedEmotionChips = List<String>.from(selectedEmotionChips);
    c.selectedFeeling = selectedFeeling;
    c.selectedTrigger = selectedTrigger;
    c.selectedBodySignal = selectedBodySignal;
    c.selectedCopingTool = selectedCopingTool;
    c.selectedRepairGoal = selectedRepairGoal;
    c.parentHiddenContext = parentHiddenContext;
    c.parentalNote = parentalNote;
    c.selectedCompanions = List<String>.from(selectedCompanions);
    c.companionNames = List<String>.from(companionNames);
    c.companionCustomNames = Map<String, String>.from(companionCustomNames);
    c.rhymeTimeMode = rhymeTimeMode;
    c.learningToReadMode = learningToReadMode;
    c.interactiveMode = interactiveMode;
    c.includeIllustrations = includeIllustrations;
    c.storyLength = storyLength;
    c.customElements = customElements;
    c.selectedGenre = selectedGenre;
    c.selectedSparkTool = selectedSparkTool;
    c.lifeChallenge = lifeChallenge;
    c.storyDnaContext = storyDnaContext;
    c.storyDnaOutcome = storyDnaOutcome;
    c.storyDnaAvoid = storyDnaAvoid;
    c.heroSuperpower = heroSuperpower;
    c.heroQuest = heroQuest;
    c.heroCostumeColor = heroCostumeColor;
    c.heroCapeStyle = heroCapeStyle;
    c.heroEmblem = heroEmblem;
    c.heroPower = heroPower;
    c.heroCatchphrase = heroCatchphrase;
    c.heroPortraitUrl = heroPortraitUrl;
    c.heroNemesisId = heroNemesisId;
    c.characterDesire = characterDesire;
    return c;
  }

  // Helper methods
  // A story is "step 1 complete" with a name plus an identity. The identity is
  // normally an archetype, but Superhero Mode supplies it via heroPower and
  // never sets selectedArchetypeId. Without this OR, a kid who jumps to the
  // Story-type page (via a progress-dot tap, bypassing the archetype page) and
  // launches Superhero Mode landed on Magic Review with the "Make my story"
  // button permanently greyed out and no explanation. wizard_data_mapper
  // already routes the superhero tier off heroPower (MT-118), so treating it as
  // a valid identity here keeps the two in step.
  bool get isStep1Complete =>
      (selectedArchetypeId != null ||
          (heroPower != null && heroPower!.trim().isNotEmpty)) &&
      characterName.isNotEmpty;

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
      if (customAvatarPath != null) 'customAvatarPath': customAvatarPath,
      if (selectedCharacterAssetPath != null)
        'selectedCharacterAssetPath': selectedCharacterAssetPath,
      'fears': fears,
      'strengths': strengths,
      'comfortItem': comfortItem,
      'pets': pets,
      'petAvatars':
          petAvatars.map((key, value) => MapEntry(key, value.toJson())),
      'additionalCharacters': additionalCharacters,
      'adultRelatives': adultRelatives,
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
      'companionCustomNames': companionCustomNames,
      'rhymeTimeMode': rhymeTimeMode,
      'learningToReadMode': learningToReadMode,
      'interactiveMode': interactiveMode,
      'includeIllustrations': includeIllustrations,
      'storyLength': storyLength,
      'customElements': customElements,
      'selectedGenre': selectedGenre,
      'selectedSparkTool': selectedSparkTool,
      'lifeChallenge': lifeChallenge,
      'storyDnaContext': storyDnaContext,
      'storyDnaOutcome': storyDnaOutcome,
      'storyDnaAvoid': storyDnaAvoid,
      'heroSuperpower': heroSuperpower,
      'heroQuest': heroQuest,
      // Superhero Mode — snake_case keys to match backend payload.
      'hero_costume_color': heroCostumeColor,
      'hero_cape_style': heroCapeStyle,
      'hero_emblem': heroEmblem,
      'hero_power': heroPower,
      'hero_catchphrase': heroCatchphrase,
      'hero_nemesis_id': heroNemesisId,
      'characterDesire': characterDesire,
    };
  }

  /// Restores a [WizardData] instance from a [toJson] snapshot.
  /// Unknown or missing keys are ignored — partial restores are safe.
  static WizardData fromJson(Map<String, dynamic> json) {
    final d = WizardData();
    d.characterId = json['characterId'] as String?;
    d.characterGender = (json['gender'] as String?) ?? 'Girl';
    d.selectedArchetypeId = json['archetype'] as String?;
    if (json['personality'] is Map) {
      d.personalitySliders = Map<String, int>.from(
        (json['personality'] as Map).map(
          (k, v) => MapEntry(k as String, (v as num).toInt()),
        ),
      );
    }
    d.characterName = (json['name'] as String?) ?? '';
    d.characterAge = (json['age'] as num?)?.toInt() ?? 8;
    d.favoriteColor = (json['favoriteColor'] as String?) ?? 'Gold';
    if (json['appearance'] is Map) {
      final a = json['appearance'] as Map;
      d.selectedHairStyle = (a['hair'] as String?) ?? '';
      d.selectedSkinTone = (a['skin'] as String?) ?? '';
      d.selectedOutfit = (a['outfit'] as String?) ?? '';
    }
    d.customAvatarPath = json['customAvatarPath'] as String?;
    d.selectedCharacterAssetPath =
        json['selectedCharacterAssetPath'] as String?;
    d.fears = List<String>.from((json['fears'] as List?) ?? []);
    d.strengths = List<String>.from((json['strengths'] as List?) ?? []);
    d.comfortItem = json['comfortItem'] as String?;
    d.pets = ((json['pets'] as List?) ?? [])
        .map((p) => Map<String, String>.from(p as Map))
        .toList();
    d.additionalCharacters =
        List<String>.from((json['additionalCharacters'] as List?) ?? []);
    d.adultRelatives = ((json['adultRelatives'] as List?) ?? [])
        .map((r) => Map<String, String>.from(r as Map))
        .toList();
    d.selectedScenario = json['scenario'] as String?;
    d.selectedEmotionChips =
        List<String>.from((json['emotions'] as List?) ?? []);
    d.selectedFeeling = json['selectedFeeling'] as String?;
    d.selectedTrigger = json['selectedTrigger'] as String?;
    d.selectedBodySignal = json['selectedBodySignal'] as String?;
    d.selectedCopingTool = json['selectedCopingTool'] as String?;
    d.selectedRepairGoal = json['selectedRepairGoal'] as String?;
    d.parentHiddenContext = json['parentHiddenContext'] as String?;
    d.parentalNote = json['parentalNote'] as String?;
    d.selectedCompanions =
        List<String>.from((json['companions'] as List?) ?? []);
    d.companionNames =
        List<String>.from((json['companionNames'] as List?) ?? []);
    if (json['companionCustomNames'] is Map) {
      d.companionCustomNames = Map<String, String>.from(
          json['companionCustomNames'] as Map);
    }
    d.rhymeTimeMode = (json['rhymeTimeMode'] as bool?) ?? false;
    d.learningToReadMode = (json['learningToReadMode'] as bool?) ?? false;
    d.interactiveMode = (json['interactiveMode'] as bool?) ?? false;
    d.includeIllustrations = (json['includeIllustrations'] as bool?) ?? true;
    d.storyLength = (json['storyLength'] as String?) ?? 'standard';
    d.customElements = (json['customElements'] as String?) ?? '';
    d.selectedGenre = json['selectedGenre'] as String?;
    d.selectedSparkTool = json['selectedSparkTool'] as String?;
    d.lifeChallenge = json['lifeChallenge'] as String?;
    d.storyDnaContext = json['storyDnaContext'] as String?;
    d.storyDnaOutcome = json['storyDnaOutcome'] as String?;
    d.storyDnaAvoid = json['storyDnaAvoid'] as String?;
    d.heroSuperpower = json['heroSuperpower'] as String?;
    d.heroQuest = json['heroQuest'] as String?;
    // Superhero Mode — accept both snake_case (preferred, backend-aligned) and
    // legacy camelCase, in case an older snapshot exists.
    d.heroCostumeColor =
        (json['hero_costume_color'] ?? json['heroCostumeColor']) as String?;
    d.heroCapeStyle =
        (json['hero_cape_style'] ?? json['heroCapeStyle']) as String?;
    d.heroEmblem = (json['hero_emblem'] ?? json['heroEmblem']) as String?;
    d.heroPower = (json['hero_power'] ?? json['heroPower']) as String?;
    d.heroCatchphrase =
        (json['hero_catchphrase'] ?? json['heroCatchphrase']) as String?;
    d.heroNemesisId =
        (json['hero_nemesis_id'] ?? json['heroNemesisId']) as String?;
    d.characterDesire = json['characterDesire'] as String?;
    return d;
  }
}

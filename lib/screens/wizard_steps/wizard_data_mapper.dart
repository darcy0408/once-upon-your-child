import 'package:flutter/material.dart';
import 'package:story_weaver_app/feelings_wheel_data.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/data/companion_data.dart';
import 'package:story_weaver_app/data/companion_personality_data.dart';
import 'package:story_weaver_app/data/mood_physics.dart';
import 'package:story_weaver_app/data/scenario_data.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/utils/input_sanitizer.dart';

/// Helper to map WizardData to API-ready payload
class WizardDataMapper {
  static Map<String, dynamic> mapToStoryRequest(WizardData data) {
    // 1. Map Age
    final int age = data.characterAge;

    // 2. Map Emotion (prefer structured Big Feelings fields, fall back to chips)
    Map<String, dynamic>? currentFeeling;
    if (data.selectedFeeling != null &&
        data.selectedFeeling!.trim().isNotEmpty) {
      currentFeeling = _mapStructuredFeeling(data);
    } else if (data.selectedEmotionChips.isNotEmpty) {
      final chipLabel = data.selectedEmotionChips.first;
      currentFeeling = _mapChipToFeeling(chipLabel, age);
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

    // Gender is always available — used by illustration prompt
    characterDetails['gender'] = data.characterGender;

    // Hair/skin from manual picks (may be empty if user skipped that step)
    if (data.selectedHairStyle.isNotEmpty) {
      characterDetails['hair'] = data.selectedHairStyle;
    }
    if (data.selectedSkinTone.isNotEmpty) {
      characterDetails['skin'] = data.selectedSkinTone;
    }

    if (data.pets.isNotEmpty) {
      characterDetails['pets'] = data.pets;
    }

    // Add generated avatar data if available.
    // Backend illustration code looks for 'avatar' key; keep 'generatedAvatar' for
    // backwards compat with other callers.
    if (data.generatedAvatar != null) {
      final avatarJson = data.generatedAvatar!.toJson();
      characterDetails['generatedAvatar'] = avatarJson;

      // Flatten attributes so backend can read avatar['hairColor'] etc. directly.
      // GeneratedAvatar.toJson() nests them under 'attributes' with snake_case keys;
      // the backend gemini_image_generator reads camelCase at the avatar root level.
      final attrs = data.generatedAvatar!.attributes;
      final flatAvatar = Map<String, dynamic>.from(avatarJson)
        ..['hairColor'] = attrs['hair_color'] ?? attrs['hairColor'] ?? ''
        ..['hairStyle'] = attrs['hair_style'] ?? attrs['hairStyle'] ?? ''
        ..['skinColor'] = attrs['skin_tone'] ?? attrs['skinTone'] ?? ''
        ..['topType'] = attrs['outfit'] ?? attrs['topType'] ?? '';
      characterDetails['avatar'] = flatAvatar; // illustration backend key

      // Promote hair/skin to top-level if not already set by manual picks
      if (characterDetails['hair'] == null) {
        final h = attrs['hair_color'] ?? attrs['hairColor'];
        if (h != null && h.isNotEmpty) characterDetails['hair'] = h;
      }
      if (characterDetails['skin'] == null) {
        final s = attrs['skin_tone'] ?? attrs['skinTone'];
        if (s != null && s.isNotEmpty) characterDetails['skin'] = s;
      }
      // Pass the generated image as a reference photo for illustration consistency
      if (data.generatedAvatar!.imageBase64.isNotEmpty) {
        characterDetails['custom_avatar_base64'] =
            data.generatedAvatar!.imageBase64;
      }
    }

    // 4. Map Scenario to Theme and new Fields
    String theme = 'Magical Adventure';
    String conflictHook = ''; // Default to empty string instead of null
    String sensoryPalette = ''; // Default to empty string instead of null
    String worldBible = '';

    // MT-118: dispatch on the sturdier `heroPower` signal rather than
    // `selectedScenario`. After the superhero flow (costume/cape/emblem/power)
    // the wizard pops back to Pick Place, where any scene tap rewrites
    // `selectedScenario` to that scene id — silently demoting the request
    // off the superhero path (theme='superhero' lost, hero* fields stripped).
    // `heroPower` survives those subsequent steps, so it's a more honest
    // "this is a superhero adventure" marker.
    final hasHeroPower =
        data.heroPower != null && data.heroPower!.trim().isNotEmpty;
    if (hasHeroPower) {
      theme = 'superhero';
      // Intentionally skip conflictHook / sensoryPalette / worldBible — the
      // superhero prompt chain owns those, and feeding it a Rainbow World
      // world bible produces the exact non-canonical drift MT-121 chases.
    } else if (data.selectedScenario != null) {
      final scenarioCard = ScenarioData.getById(data.selectedScenario!);
      if (scenarioCard != null) {
        theme = scenarioCard.titleForAge(age);
        conflictHook = scenarioCard.conflictHookForAge(age);
        sensoryPalette = scenarioCard.sensoryPalette;
        worldBible = scenarioCard.worldBibleForAge(age);
      }
    }

    // Extract companion names and categorize them
    final companionNames = data.companionNames.isNotEmpty
        ? data.companionNames
        : data.selectedCompanions;

    // Build a reverse map: default name → companion ID (for custom name lookup)
    final Map<String, String> nameToId = {};
    if (data.companionNames.isNotEmpty &&
        data.selectedCompanions.length == data.companionNames.length) {
      for (var i = 0; i < data.companionNames.length; i++) {
        nameToId[data.companionNames[i]] = data.selectedCompanions[i];
      }
    }

    // Separate companions into pets vs other characters
    final List<Map<String, dynamic>> companionsPets = [];
    final List<Map<String, dynamic>> companionsOther = [];

    for (final companionName in companionNames) {
      // Check if this companion is one of the main character's pets
      final isPet = data.pets.any((pet) => pet['name'] == companionName);

      if (isPet) {
        // Find the pet details
        final petDetails = Map<String, dynamic>.from(
          data.pets.firstWhere((pet) => pet['name'] == companionName),
        );
        // Add avatar if available
        if (data.petAvatars.containsKey(companionName)) {
          petDetails['avatar_data'] = data.petAvatars[companionName]!.toJson();
        }
        companionsPets.add(petDetails);
      } else {
        // It's another character or magical creature
        // Check if it's one of our special Power-Pairing companions and pass their full details/ability
        final companionData = _getCompanionData(companionName);
        final companionId = nameToId[companionName];
        final customName = companionId != null
            ? data.companionCustomNames[companionId]
            : null;
        final displayName =
            (customName != null && customName.trim().isNotEmpty)
                ? customName.trim()
                : companionData?.name ?? companionName;

        // Resolve band-specific behavior pattern, falling back to the generic one.
        final bandName = ageBandFromAge(age <= 0 ? 8 : age).name;
        final bandKey = '${bandName}_$companionId';
        final bandBehavior = companionBehaviorPatterns[bandKey] ??
            companionData?.behaviorPattern ??
            '';

        if (companionData != null) {
          companionsOther.add({
            'name': displayName,
            'description': companionData.description,
            'signaturePower': companionData.signaturePower,
            'powerConstraint': companionData.powerConstraint,
            'sensoryTell': companionData.sensoryTell,
            'behaviorPattern': bandBehavior,
          });
        } else if (bandBehavior.isNotEmpty) {
          // Band-specific companion without a magicCompanions entry.
          companionsOther.add({
            'name': displayName,
            'behaviorPattern': bandBehavior,
          });
        } else {
          // Standard friend/sibling — no special data.
          companionsOther.add({'name': displayName});
        }
      }
    }

    // 5. Map Mood Physics based on emotion
    Map<String, dynamic>? moodPhysics;
    if (data.selectedFeeling != null &&
        data.selectedFeeling!.trim().isNotEmpty) {
      moodPhysics = _mapMoodToPhysics(data.selectedFeeling!);
    } else if (data.selectedEmotionChips.isNotEmpty) {
      moodPhysics = _mapMoodToPhysics(data.selectedEmotionChips.first);
    }

    // 6a. Add Creator-band character desire as narrative motivation
    if (data.characterDesire != null && data.characterDesire!.trim().isNotEmpty) {
      characterDetails['character_desire'] =
          InputSanitizer.sanitizeText(data.characterDesire!, maxLength: 200);
    }

    // 6. Merge hero superpower into character strengths (Feature 3)
    if (data.heroSuperpower != null) {
      final sanitizedPower = InputSanitizer.sanitizeSuperpower(data.heroSuperpower!);
      final strengths =
          List<String>.from(characterDetails['strengths'] as List);
      if (sanitizedPower.isNotEmpty && !strengths.contains(sanitizedPower)) {
        strengths.insert(0, sanitizedPower);
      }
      characterDetails['strengths'] = strengths;
    }

    // Combine parentalNote + Story DNA into therapeutic_prompt for the backend.
    // All user-entered text is sanitized against prompt injection.
    final List<String> therapeuticParts = [];
    if (data.parentalNote != null && data.parentalNote!.trim().isNotEmpty) {
      therapeuticParts.add('Parent note: ${InputSanitizer.sanitizeParentalNote(data.parentalNote!)}');
    }
    if (data.storyDnaContext != null) {
      therapeuticParts.add('Current situation: ${InputSanitizer.sanitizeText(data.storyDnaContext!, maxLength: InputSanitizer.maxDnaContext)}');
    }
    if (data.storyDnaOutcome != null) {
      therapeuticParts.add('Desired outcome: ${InputSanitizer.sanitizeText(data.storyDnaOutcome!, maxLength: InputSanitizer.maxDnaContext)}');
    }
    if (data.storyDnaAvoid != null && data.storyDnaAvoid!.trim().isNotEmpty) {
      therapeuticParts.add('Avoid: ${InputSanitizer.sanitizeAvoid(data.storyDnaAvoid!)}');
    }
    final String? therapeuticPrompt =
        therapeuticParts.isNotEmpty ? therapeuticParts.join(' | ') : null;

    return {
      'character': data.characterName.isNotEmpty
          ? InputSanitizer.sanitizeName(data.characterName)
          : 'Hero',
      // MT-126: forward saved character UUID so the backend can attribute the
      // Story row and inject the PRIOR ADVENTURES prompt block on subsequent
      // generations. Absent on guest/quick-create flows; backend treats null
      // as "no recall, no FK" and short-circuits.
      if (data.characterId != null && data.characterId!.trim().isNotEmpty)
        'character_id': data.characterId,
      'age': age,
      'theme': theme,
      'conflictHook': conflictHook,
      'sensoryPalette': sensoryPalette,
      'worldBible': worldBible,
      // Send structured companion data
      'companion_pets': companionsPets,
      'companion_characters': companionsOther,
      // Adult relatives are sent as structured dicts with is_adult_relative: true
      // so the backend prompt builder renders them in the dedicated ADULT FAMILY
      // section rather than GUESTS. The relation is prepended to the name for
      // readability in the prompt (e.g. "Mom Sarah", "Grandpa Joe").
      'additionalCharacters': [
        ...data.additionalCharacters,
        ...data.adultRelatives
            .where((r) => (r['name'] ?? '').trim().isNotEmpty)
            .map((r) {
              final n = r['name']!.trim();
              final rel = (r['relation'] ?? '').trim();
              final relTitle = rel.isNotEmpty
                  ? rel[0].toUpperCase() + rel.substring(1)
                  : '';
              final displayName = relTitle.isNotEmpty ? '$relTitle $n' : n;
              return {
                'name': displayName,
                'is_adult_relative': true,
              };
            }),
      ],
      // Structured copy for future backend-prompt support without churning
      // the main payload key. Backend may read this when ready.
      'adultRelatives': data.adultRelatives
          .where((r) => (r['name'] ?? '').trim().isNotEmpty)
          .map((r) => {
                'name': r['name']!.trim(),
                'relation': r['relation'] ?? 'relative',
              })
          .toList(),
      'characterDetails': characterDetails,
      'currentFeeling': currentFeeling,
      'moodPhysics': moodPhysics,
      if (data.selectedTrigger != null &&
          data.selectedTrigger!.trim().isNotEmpty)
        'feelingTrigger': data.selectedTrigger!.trim(),
      if (data.selectedBodySignal != null &&
          data.selectedBodySignal!.trim().isNotEmpty)
        'bodySignal': data.selectedBodySignal!.trim(),
      if (data.selectedCopingTool != null &&
          data.selectedCopingTool!.trim().isNotEmpty)
        'copingTool': data.selectedCopingTool!.trim(),
      if (data.selectedRepairGoal != null &&
          data.selectedRepairGoal!.trim().isNotEmpty)
        'repairGoal': data.selectedRepairGoal!.trim(),
      'customElements': InputSanitizer.sanitizeCustomElements([
        if (data.selectedGenre != null) 'Genre: ${data.selectedGenre}',
        if (data.customElements.isNotEmpty) data.customElements,
      ].join(' | ')),
      // Story mode settings from wizard
      'storyLength': data.storyLength,
      'rhymeTimeMode': data.rhymeTimeMode,
      'learningToReadMode': data.learningToReadMode,
      'interactiveMode': data.interactiveMode,
      'includeIllustrations': data.includeIllustrations,
      // Resolved lifeChallenge: Guardian Mode takes priority over Superpower Quest
      'lifeChallenge': data.lifeChallenge != null
          ? InputSanitizer.sanitizeLifeChallenge(data.lifeChallenge!)
          : (data.heroQuest != null
              ? InputSanitizer.sanitizeQuest(_questToLifeChallenge(data.heroQuest!))
              : null),
      // Story DNA: parent-authored therapeutic context (Feature 4)
      if (therapeuticPrompt != null) 'therapeutic_prompt': therapeuticPrompt,
      // Superhero Mode (ages 3-5 / 6-8). MT-118: gate on heroPower presence
      // rather than selectedScenario — the latter gets overwritten by any
      // scene pick on the page the user is popped back to after the
      // superhero flow. ApiServiceManager.generateStory translates these
      // camelCase keys to snake_case (`hero_costume_color`, …) on the wire.
      if (data.heroPower != null && data.heroPower!.trim().isNotEmpty) ...{
        'heroCostumeColor': data.heroCostumeColor,
        'heroCapeStyle': data.heroCapeStyle,
        'heroEmblem': data.heroEmblem,
        'heroPower': data.heroPower,
        // B3 catchphrase — optional; only emitted when the kid picked one.
        if (data.heroCatchphrase != null &&
            data.heroCatchphrase!.trim().isNotEmpty)
          'heroCatchphrase': data.heroCatchphrase!.trim(),
        // C4 nemesis — optional; only emitted when the kid chose an arch-villain
        // (null = server surprise-picks).
        if (data.heroNemesisId != null &&
            data.heroNemesisId!.trim().isNotEmpty)
          'heroNemesisId': data.heroNemesisId!.trim(),
      },
    };
  }

  static Map<String, dynamic> _mapStructuredFeeling(WizardData data) {
    final emotionName = _normalizeFeelingName(data.selectedFeeling!);
    final emotionEmoji = _emojiForFeeling(emotionName);
    final description = _descriptionForFeeling(emotionName);
    final coping = <String>{
      if (data.selectedCopingTool != null &&
          data.selectedCopingTool!.trim().isNotEmpty)
        data.selectedCopingTool!.trim(),
      ..._defaultCopingForFeeling(emotionName),
    }.toList();

    return {
      'emotion_name': emotionName,
      'emotion_emoji': emotionEmoji,
      'emotion_description': description,
      'intensity': 3,
      'physical_signs': data.selectedBodySignal?.trim().isNotEmpty == true
          ? data.selectedBodySignal!.trim()
          : 'Feeling it in the body',
      'coping_strategies': coping,
      if (data.selectedTrigger != null &&
          data.selectedTrigger!.trim().isNotEmpty)
        'trigger': data.selectedTrigger!.trim(),
      if (data.selectedRepairGoal != null &&
          data.selectedRepairGoal!.trim().isNotEmpty)
        'repair_goal': data.selectedRepairGoal!.trim(),
    };
  }

  static String _normalizeFeelingName(String rawFeeling) {
    switch (rawFeeling.trim().toLowerCase()) {
      case 'mad':
      case 'angry':
      case 'annoyed':
      case 'irritated':
      case 'furious':
      case 'hurt-mad':
      case 'left-out mad':
        return 'Angry';
      case 'sad':
        return 'Sad';
      case 'worried':
      case 'nervous':
      case 'uneasy':
      case 'shaky':
      case 'jumpy':
      case 'unsure':
      case 'what-if-y':
        return 'Worried';
      case 'scared':
      case 'anxious':
        return 'Scared';
      case 'frustrated':
      case 'stuck':
      case 'bothered':
      case 'mixed up':
      case 'overwhelmed':
      case 'impatient':
      case 'ready-to-pop':
      case 'trying-so-hard':
        return 'Frustrated';
      case 'embarrassed':
      case 'awkward':
      case 'red-faced':
      case 'wish-i-could-hide':
      case 'exposed':
        return 'Embarrassed';
      case 'excited':
      case 'bouncy':
      case 'hyper':
      case 'proud':
      case "can't-wait":
      case 'can’t-wait':
      case 'buzzy':
        return 'Excited';
      default:
        return rawFeeling.trim().isEmpty ? 'Happy' : rawFeeling.trim();
    }
  }

  static String _emojiForFeeling(String feeling) {
    switch (feeling.toLowerCase()) {
      case 'angry':         return '😠';
      case 'sad':           return '😢';
      case 'worried':       return '😟';
      case 'scared':        return '😨';
      case 'frustrated':    return '😤';
      case 'embarrassed':   return '😳';
      case 'excited':       return '🤩';
      // Mature feelings — adolescent
      case 'grief':         return '🖤';
      case 'resentful':     return '😤';
      case 'envious':       return '💚';
      case 'restless':      return '🌀';
      case 'hopeful':       return '🌅';
      // Mature feelings — adult
      case 'melancholy':    return '🌧️';
      case 'contentment':   return '☀️';
      case 'indignation':   return '⚡';
      case 'dread':         return '🕳️';
      case 'anticipation':  return '⏳';
      // Mature aliases from younger feelings
      case 'betrayed':      return '🤕';
      case 'repulsed':      return '🤢';
      case 'energized':     return '🤸';
      case 'irritated':     return '😒';
      case 'despondent':    return '☁️';
      case 'disappointed':  return '😔';
      case 'blocked':       return '🧱';
      case 'anxious':       return '❓';
      case 'exposed':       return '🫣';
      default:              return '😊';
    }
  }

  static String _descriptionForFeeling(String feeling) {
    switch (feeling.toLowerCase()) {
      case 'angry':         return 'Feeling really upset and full of big energy';
      case 'sad':           return 'Feeling hurt, heavy, or like crying';
      case 'worried':       return 'Feeling jumpy, unsure, or full of what-if thoughts';
      case 'scared':        return 'Feeling worried, shaky, or unsure';
      case 'frustrated':    return 'Feeling stuck when something is hard or not working';
      case 'embarrassed':   return 'Feeling red-faced, awkward, or like you want to hide';
      case 'excited':       return 'Feeling buzzy, bouncy, or very ready for what comes next';
      // Mature feelings — adolescent
      case 'grief':         return 'Deep loss that lingers, often in waves';
      case 'resentful':     return 'Anger that has hardened over time, often from feeling wronged';
      case 'envious':       return 'Wanting what someone else has; a signal about your own desires';
      case 'restless':      return 'Unable to settle; an inner tension seeking release';
      case 'hopeful':       return 'Quiet belief that things can get better, even without certainty';
      // Mature feelings — adult
      case 'melancholy':    return 'A bittersweet ache, often beautiful and heavy at once';
      case 'contentment':   return 'Quiet satisfaction with what is; no urgency to change anything';
      case 'indignation':   return 'Righteous anger at injustice; a call to stand for something';
      case 'dread':         return 'The weight of what is coming; anticipating difficulty or loss';
      case 'anticipation':  return 'Expectant tension before something unknown; could go either way';
      // Mature aliases
      case 'betrayed':      return 'Hurt and angry because someone you trusted let you down';
      case 'repulsed':      return 'A visceral aversion — body and mind both recoil';
      case 'energized':     return 'Elevated energy seeking an outlet; alive and awake';
      case 'irritated':     return 'Low-grade frustration; something is grating without release';
      case 'despondent':    return 'Weighed down and withdrawn; the world feels heavy';
      case 'disappointed':  return 'What you hoped for did not materialise; an unmet expectation';
      case 'blocked':       return 'Unable to move forward; effort meets an invisible wall';
      case 'anxious':       return 'Persistent worry that loops; the mind hunting for dangers';
      case 'exposed':       return 'Uncomfortably visible; seen in a way that feels unsafe';
      default:              return 'Feeling something important in the body and mind';
    }
  }

  static List<String> _defaultCopingForFeeling(String feeling) {
    switch (feeling.toLowerCase()) {
      case 'angry':
        return ['Take a dragon breath', 'Ask for help', 'Use gentle words'];
      case 'sad':
        return ['Get a hug', 'Talk to someone safe', 'Take a quiet breath'];
      case 'worried':
        return ['Spot three safe things', 'Take a slow breath', 'Ask what the first step is'];
      case 'scared':
        return ['Hold a grown-up hand', 'Take a slow breath', 'Ask for help'];
      case 'frustrated':
        return ['Try again', 'Ask for help', 'Take a break'];
      case 'embarrassed':
        return ['Take one steady breath', 'Ask for a do-over', 'Tell the truth simply'];
      case 'excited':
        return ['Take one settling breath', 'Tell someone your idea', 'Slow down enough to choose'];
      // Mature feelings — adolescent
      case 'grief':
        return ['Let yourself feel it', 'Talk to someone safe', 'Write or draw it out'];
      case 'resentful':
        return ['Name what was unfair', 'Physical release', "Write a letter you don't send"];
      case 'envious':
        return ['Notice what you have', 'Let it be information', 'Talk about it honestly'];
      case 'restless':
        return ['Move your body', 'Narrow your focus', 'Write it down'];
      case 'hopeful':
        return ['Stay with it', 'Take one small step', 'Share the feeling'];
      // Mature feelings — adult
      case 'melancholy':
        return ['Sit with it a while', 'Create something', 'Reach out gently'];
      case 'contentment':
        return ['Savour the moment', 'Express gratitude', 'Share it with someone'];
      case 'indignation':
        return ['Speak the truth clearly', 'Channel it into action', 'Write your perspective'];
      case 'dread':
        return ['Name the specific fear', 'Stay in the present', 'Talk to someone trusted'];
      case 'anticipation':
        return ['Breathe and ground yourself', 'Prepare what you can', 'Lean into the uncertainty'];
      // Mature aliases
      case 'betrayed':
        return ['Name what was broken', 'Give yourself space', 'Decide what you need'];
      case 'repulsed':
        return ['Step away', 'Take a breath', 'Wash hands or move'];
      case 'energized':
        return ['Direct it somewhere', 'Move your body', 'Channel it creatively'];
      case 'irritated':
        return ['Deep breath', 'Walk away', 'Ask for space'];
      case 'despondent':
        return ['Gentle hug', 'Soft music', 'Talk to someone'];
      case 'disappointed':
        return ['Talk about it', 'Find new perspective', 'Give yourself time'];
      case 'blocked':
        return ['Ask for help', 'Take a break', 'Try a different angle'];
      case 'anxious':
        return ['Ground yourself (5-4-3-2-1)', 'Name the actual fear', 'Take a slow breath'];
      case 'exposed':
        return ['Take a breath', 'Find one safe person', 'Remind yourself of your worth'];
      default:
        return ['Take a breath', 'Ask for help'];
    }
  }

  static Map<String, dynamic> _mapChipToFeeling(String chipLabel, int age) {
    final normalizedChip = chipLabel.trim().toLowerCase();
    // defaults
    String emotionName = 'Happy';
    String emotionEmoji = '😊';
    String description = 'Feeling good';
    List<String> coping = ['Smile', 'Share joy'];

    // Map simplified chips to complex FeelingWheelData
    // Chips: Shining Bright, Being Brave, Making Friends, Calm Moments, Creative Ideas, Feeling Happy/Sad/Mad

    if (normalizedChip.contains('sad')) {
      emotionName = 'Sad';
      emotionEmoji = '😢';
      final details = FeelingDetails.forFeeling(const SelectedFeeling(
          core: 'Sad',
          secondary: 'Sad',
          tertiary: 'Sad',
          emoji: '😢',
          eyeType: '',
          mouthType: '',
          color: Color(0xFF6495ED)));
      description = details.description;
      coping = details.copingForAge(age);
    } else if (normalizedChip.contains('angry') ||
        normalizedChip.contains('mad') ||
        normalizedChip.contains('annoyed')) {
      emotionName = 'Angry';
      emotionEmoji = '😠';
      final details = FeelingDetails.forFeeling(const SelectedFeeling(
          core: 'Angry',
          secondary: 'Mad',
          tertiary: 'Mad',
          emoji: '😠',
          eyeType: '',
          mouthType: '',
          color: Color(0xFFFF6B6B)));
      description = details.description;
      coping = details.copingForAge(age);
    } else if (normalizedChip.contains('worried') ||
        normalizedChip.contains('nervous') ||
        normalizedChip.contains('uneasy')) {
      emotionName = 'Worried';
      emotionEmoji = '😟';
      description = 'Feeling jumpy, shaky, or full of what-if thoughts';
      coping = [
        'Spot three safe things',
        'Take a slow breath',
        'Ask one true question'
      ];
    } else if (normalizedChip.contains('frustrated') ||
        normalizedChip.contains('stuck') ||
        normalizedChip.contains('overwhelmed')) {
      emotionName = 'Frustrated';
      emotionEmoji = '😤';
      description = 'Feeling stuck, bothered, or like the problem is too much';
      coping = [
        'Shake out the stuck sparks',
        'Take a restart minute',
        'Ask for one clue'
      ];
    } else if (normalizedChip.contains('embarrassed') ||
        normalizedChip.contains('awkward') ||
        normalizedChip.contains('red-faced')) {
      emotionName = 'Embarrassed';
      emotionEmoji = '😳';
      description = 'Feeling awkward, exposed, or like you want to hide';
      coping = [
        'Take one steady breath',
        'Tell the truth simply',
        'Ask for a do-over'
      ];
    } else if (normalizedChip.contains('excited') ||
        normalizedChip.contains('bouncy') ||
        normalizedChip.contains('hyper') ||
        normalizedChip.contains('proud')) {
      emotionName = 'Excited';
      emotionEmoji = '🤩';
      description = 'Feeling buzzy, bouncy, or very ready for something big';
      coping = [
        'Bounce once, then pause',
        'Tell someone your idea',
        'Slow down enough to think'
      ];
    } else if (normalizedChip.contains('brave')) {
      emotionName = 'Scared'; // Needs bravery
      emotionEmoji = '😨';
      description = 'Feeling a bit scared but ready to be brave';
      coping = ['Take a deep breath', 'Stand tall', 'Remember you are strong'];
    } else if (normalizedChip.contains('calm')) {
      emotionName = 'Calm';
      emotionEmoji = '😌';
      description = 'Feeling peaceful and relaxed';
      coping = ['Breathe slowly', 'Close eyes', 'Listen to nature'];
    } else if (normalizedChip.contains('creative')) {
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
      String? archetypeId, Map<String, int> sliders) {
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

        // Match all band-specific names for each archetype.
        // Sprout: "Brave Hero!", Explorer: "The Brave Explorer",
        // Adventurer: "The Quiz Whiz", Creator+: "Logic Architect"
        if (archetypeId.contains('Quiz Whiz') ||
            archetypeId.contains('Quiz-Whiz') ||
            archetypeId.contains('Brave Hero') ||
            archetypeId.contains('Brave Explorer') ||
            archetypeId.contains('Logic Architect') ||
            archetypeId.contains('Thinker')) {
          details['strengths'] = ['Intelligence', 'Problem solving', 'Focus'];
          details['interests'] = ['Puzzles', 'Brain teasers', 'Brave adventures'];
          details['specialAbility'] =
              'Can solve any quiz, puzzle, or brain teaser with clever thinking — and has the courage to face anything';
        // Sprout: "Art Maker!", Explorer: "The Art Wizard",
        // Adventurer: "The Master Creator", Creator+: "Vision Architect"
        } else if (archetypeId.contains('Master Creator') ||
            archetypeId.contains('Art Maker') ||
            archetypeId.contains('Art Wizard') ||
            archetypeId.contains('Vision Architect') ||
            archetypeId.contains('Artist')) {
          details['strengths'] = ['Creativity', 'Vision', 'Imagination'];
          details['interests'] = ['Painting', 'Inventing', 'Making things'];
          details['specialAbility'] =
              'Has a magic paintbrush that brings drawings to life';
        // Sprout: "Super Fast!", Explorer: "The Speed Star",
        // Adventurer: "The Lightning Runner", Creator+: "Kinetic Specialist"
        } else if (archetypeId.contains('Lightning Runner') ||
            archetypeId.contains('Super Fast') ||
            archetypeId.contains('Speed Star') ||
            archetypeId.contains('Kinetic Specialist') ||
            archetypeId.contains('Athlete')) {
          details['strengths'] = ['Speed', 'Energy', 'Determination', 'Teamwork'];
          details['interests'] = ['Running', 'Sports', 'Racing', 'Games'];
          details['specialAbility'] =
              'Moves faster than sound and leaves trails of stardust';
        // Sprout: "Animal Friend!", Explorer+: "The Animal Whisperer",
        // Creator+: "Ecological Whisperer"
        } else if (archetypeId.contains('Animal Whisperer') ||
            archetypeId.contains('Animal Friend') ||
            archetypeId.contains('Ecological Whisperer') ||
            archetypeId.contains('Shy')) {
          details['strengths'] = ['Kindness', 'Nature Magic', 'Observation'];
          details['interests'] = ['Animals', 'Nature', 'Secrets'];
          details['specialAbility'] =
              'Can talk to animals and move unseen like a shadow';
        } else if (archetypeId.contains('Soul Mender') ||
            archetypeId.contains('Heart Healer') ||
            archetypeId.contains('Helper')) {
          details['strengths'] = ['Kindness', 'Empathy'];
          details['interests'] = ['Animals', 'Helping friends'];
          details['specialAbility'] =
              'Can sense emotions and heal broken spirits with kindness';
        }
      } catch (e) {
        debugPrint('Error mapping archetype details: $e');
      }
    }
    return details;
  }

  static CompanionData? _getCompanionData(String name) {
    try {
      final lower = name.toLowerCase();
      return magicCompanions.firstWhere((c) =>
          lower.contains(c.id) ||
          lower.contains(c.name.toLowerCase()) ||
          // Robin may be stored under old key "rockin' robin"
          (c.id == 'robin' && lower.contains('robin')));
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
      } else if (chipLabel.contains('Creative') ||
          chipLabel.contains('Inspired')) {
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

  /// Maps child-facing Superpower Quest labels to backend lifeChallenge strings.
  static String _questToLifeChallenge(String quest) {
    const map = <String, String>{
      'Making new friends': 'Making New Friends',
      'Taming big feelings': 'Big Feelings',
      'Being brave when scared': 'Anxiety & Fears',
      'Sharing and taking turns': 'Sharing & Cooperation',
      'Trying something new': 'Trying New Things',
      "Standing up for what's right": 'Standing Up for Yourself',
    };
    return map[quest] ?? quest;
  }
}

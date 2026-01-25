// ignore_for_file: unused_element

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'superhero_name_generator.dart';
import 'avatar_builder_screen.dart';
import 'avatar_models.dart';
import 'character_traits_data.dart';
import 'customizable_avatar_widget.dart';
import 'appearance_options.dart';
import 'interest_options.dart';
import 'services/progression_service.dart';
import 'services/achievement_service.dart';
import 'achievement_celebration_dialog.dart';
import 'config/environment.dart';
import 'services/character_analytics.dart';
import 'services/character_template_service.dart';
import 'theme/app_theme.dart';
import 'widgets/loading_overlay.dart';
import 'screens/avatar_picker_screen.dart';
import 'screens/midjourney_avatar_picker_screen.dart';
import 'services/avatar_service.dart';

import 'package:flutter/foundation.dart';
import 'services/isar_service.dart';
import 'models/local/character_local.dart';
class CharacterCreationScreenEnhanced extends StatefulWidget {
  const CharacterCreationScreenEnhanced({super.key});

  @override
  State<CharacterCreationScreenEnhanced> createState() =>
      _CharacterCreationScreenEnhancedState();
}

class _CharacterCreationScreenEnhancedState
    extends State<CharacterCreationScreenEnhanced> {
  final _formKey = GlobalKey<FormState>();
  final _progressionService = ProgressionService();
  final _achievementService = AchievementService();
  bool _isLoading = false;
  bool _hasFantasyMode = false;
  bool _hasAnimalEarsTails = false;
  bool _hasPremium = false;
  bool _useTemplateMode = true;
  CharacterTemplate? _selectedTemplate;

  // Basic Info
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _characterStyle = 'Regular Kid'; // Character appearance/personality
  String _isA = 'Girl'; // For story pronouns

  // Character Type
  String _characterType = 'Everyday Kid';

  // Superhero Specific
  final _superheroNameController = TextEditingController();
  final _superpowerController = TextEditingController();
  final _missionController = TextEditingController();

  // Appearance
  String _skinTone = 'Light';
  String _hairStyle = 'Short & Flat';
  String _hairColor = 'Brown';
  String _eyeColor = 'Brown';
  final _outfitController = TextEditingController();
  CharacterAvatar _avatar = CharacterAvatar.defaultAvatar;
  String? _selectedOutfitPreset;
  bool _avatarCustomized = false;

  // New avataaars system (DiceBear)
  String? _avatarParams; // JSON string of avataaars customization

  // Midjourney custom avatars
  String? _midjourneyAvatarId; // Selected Midjourney avatar ID

  final Map<String, double> _personalitySliderValues =
      CharacterTraitsData.defaultSliderValues();
  final Set<String> _selectedQuickLikes = <String>{};
  final Set<String> _selectedQuickDislikes = <String>{};
  final Set<String> _selectedFearOptions = <String>{};
  final Set<String> _selectedGoalChallengeOptions = <String>{};
  String? _selectedComfortOption;

  // Interests & Preferences
  final _likesController = TextEditingController();
  final _dislikesController = TextEditingController();

  // Growth & Challenges
  final _fearsController = TextEditingController();
  final _goalsChallengesController = TextEditingController();
  final _comfortItemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleNameChanged);
    _outfitController.addListener(_handleOutfitChanged);
    _loadUnlocks();
  }

  Future<void> _loadUnlocks() async {
    final hasFantasy = await _progressionService.hasAccessToFeature(
      UnlockableFeatures.fantasyMode,
    );
    final hasAnimal = await _progressionService.hasAccessToFeature(
      UnlockableFeatures.animalEarsTails,
    );
    final hasPremium = await _progressionService.hasPremiumAccess();

    if (mounted) {
      setState(() {
        _hasFantasyMode = hasFantasy;
        _hasAnimalEarsTails = hasAnimal;
        _hasPremium = hasPremium;
      });
    }
  }

  void _applyTemplate(CharacterTemplate template) {
    setState(() {
      _selectedTemplate = template;
      _useTemplateMode = true;
      _characterStyle = template.characterStyle;
      _characterType = template.characterType;
      _selectedOutfitPreset = template.suggestedOutfit;
      if (template.suggestedOutfit != null) {
        _outfitController.text = template.suggestedOutfit!;
      }
      _selectedComfortOption = template.comfortItem;
      _personalitySliderValues
        ..clear()
        ..addAll(CharacterTraitsData.defaultSliderValues())
        ..addAll(
          template.personality.map((key, value) => MapEntry(
                key,
                value.clamp(0, 100).toDouble(),
              )),
        );
      _selectedQuickLikes
        ..clear()
        ..addAll(template.likes);
      _selectedQuickDislikes
        ..clear()
        ..addAll(template.dislikes);
      if (_ageController.text.trim().isEmpty) {
        _ageController.text = template.suggestedAge.toString();
      }
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = template.name;
      }
    });

    _applyStylePreset(template.characterStyle);
    _applyGenderPreset(_isA);

    CharacterAnalytics.trackTemplateSelected(
      templateKey: template.key,
      templateName: template.name,
      hasCustomName: _nameController.text.trim().isNotEmpty &&
          _nameController.text.trim() != template.name,
    );
  }

  void _handleNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleOutfitChanged() {
    final trimmed = _outfitController.text.trim();
    if (_selectedOutfitPreset != null &&
        trimmed != _selectedOutfitPreset &&
        mounted) {
      setState(() => _selectedOutfitPreset = null);
    }
  }

  void _updateAvatar(CharacterAvatar newAvatar, {bool userDriven = true}) {
    setState(() {
      _avatar = newAvatar;
      if (userDriven) {
        _avatarCustomized = true;
      }
    });
  }

  void _applyGenderPreset(String gender) {
    if (_avatarCustomized) return;
    final lower = gender.toLowerCase();
    if (lower == 'girl') {
      _updateAvatar(
        _avatar.copyWith(
          hairStyle: 'LongHairStraight',
          clothingStyle: 'ShirtScoopNeck',
          clothingColor: 'PastelPink',
          mouthType: 'Smile',
          eyeType: 'Happy',
        ),
        userDriven: false,
      );
    } else if (lower == 'boy') {
      _updateAvatar(
        _avatar.copyWith(
          hairStyle: 'ShortHairShortFlat',
          clothingStyle: 'Hoodie',
          clothingColor: 'Blue03',
          mouthType: 'Smile',
          eyeType: 'Happy',
        ),
        userDriven: false,
      );
    }
  }

  void _applyStylePreset(String style) {
    if (_avatarCustomized) return;
    switch (style) {
      case 'Creative Artist':
        _updateAvatar(
          _avatar.copyWith(
            clothingStyle: 'GraphicShirt',
            clothingColor: 'PastelPink',
            hairStyle: 'LongHairCurly',
          ),
          userDriven: false,
        );
        break;
      case 'Sporty Kid':
        _updateAvatar(
          _avatar.copyWith(
            clothingStyle: 'CollarSweater',
            clothingColor: 'Blue02',
            hairStyle: 'ShortHairShortWaved',
          ),
          userDriven: false,
        );
        break;
      case 'Young Scientist':
        _updateAvatar(
          _avatar.copyWith(
            clothingStyle: 'BlazerShirt',
            clothingColor: 'Gray01',
            hairStyle: 'ShortHairShortCurly',
          ),
          userDriven: false,
        );
        break;
      default:
        _updateAvatar(
          _avatar.copyWith(
            clothingStyle: 'Hoodie',
            clothingColor: 'Blue03',
          ),
          userDriven: false,
        );
    }
  }

  List<String> _splitCSV(String text) {
    if (text.trim().isEmpty) return <String>[];
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Map<String, int> _buildPersonalitySliderPayload() {
    final payload = <String, int>{};
    _personalitySliderValues.forEach((key, value) {
      payload[key] = value.clamp(0, 100).round();
    });
    return payload;
  }

  List<String> _combinedInterests(
      Set<String> quickSelections, TextEditingController controller) {
    final manualEntries = _splitCSV(controller.text);
    final combined = <String>[];
    combined.addAll(quickSelections);
    for (final entry in manualEntries) {
      if (!quickSelections.contains(entry)) {
        combined.add(entry);
      }
    }
    return combined;
  }

  List<String> _combinedGrowthSelections(
      Set<String> quickSelections, TextEditingController controller) {
    return _combinedInterests(quickSelections, controller);
  }

  String? _resolveComfortItem() {
    if (_selectedComfortOption != null) {
      return _selectedComfortOption;
    }
    final text = _comfortItemController.text.trim();
    return text.isEmpty ? null : text;
  }

  String _characterPossessive() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'this character\'s';
    return name.toLowerCase().endsWith('s') ? '$name\'' : '$name\'s';
  }

  Future<void> _openAvatarBuilder() async {
    final seedName = _nameController.text.trim().isEmpty
        ? 'My Character'
        : _nameController.text.trim();

    final initial = EnhancedCharacter(
      name: seedName,
      avatar: _avatar,
    );

    final result = await Navigator.push<EnhancedCharacter>(
      context,
      MaterialPageRoute(
        builder: (context) => AvatarBuilderScreen(
          initialCharacter: initial,
          isEdit: true,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _avatar = result.avatar;
        _avatarCustomized = true;
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = result.name;
        }
        _hairColor = result.avatar.hairColor;
      });
    }
  }

  Future<void> _openAvataarsPicker() async {
    debugPrint('[Character Creation] Opening Avataaars Picker...');
    try {
      // Initialize avatar service (pass null for web compatibility - caching will be disabled)
      debugPrint('[Character Creation] Initializing avatar service...');
      final avatarService = AvatarService(isar: null);
      await avatarService.initialize();
      debugPrint('[Character Creation] Avatar service initialized successfully');

      final age = int.tryParse(_ageController.text.trim()) ?? 8;
      debugPrint('[Character Creation] Character age: $age');

      // Parse existing params if any
      Map<String, String>? initialSelection;
      if (_avatarParams != null) {
        try {
          initialSelection = Map<String, String>.from(json.decode(_avatarParams!));
          debugPrint('[Character Creation] Loaded initial selections: $initialSelection');
        } catch (e) {
          debugPrint('[Character Creation] Error parsing existing params: $e');
        }
      }

      debugPrint('[Character Creation] Navigating to Avatar Picker Screen...');
      if (!mounted) return;
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => AvatarPickerScreen(
            characterAge: age,
            avatarService: avatarService,
            initialSelection: initialSelection,
          ),
        ),
      );

      debugPrint('[Character Creation] Returned from Avatar Picker with result: $result');
      if (mounted && result != null) {
        setState(() {
          _avatarParams = result;
        });
        debugPrint('[Character Creation] Avatar params saved: $_avatarParams');
      }
    } catch (e) {
      debugPrint('[Character Creation] Error in avatar picker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open avatar picker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openMidjourneyPicker() async {
    try {
      debugPrint('[Character Creation] Opening Midjourney avatar picker...');
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => MidjourneyAvatarPickerScreen(
            initialSelectedAvatar: _midjourneyAvatarId,
          ),
        ),
      );

      debugPrint('[Character Creation] Returned from Midjourney picker with result: $result');
      if (result != null) {
        setState(() {
          _midjourneyAvatarId = result;
        });
        debugPrint('[Character Creation] Midjourney avatar saved: $_midjourneyAvatarId');
      }
    } catch (e) {
      debugPrint('[Character Creation] Error in Midjourney picker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open Midjourney picker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAvatarSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Customize Avatar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          CustomizableAvatarWidget(
            avatar: _avatar,
            size: 140,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _openAvatarBuilder,
                icon: const Icon(Icons.brush, size: 18),
                label: const Text('AI Avatar', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openAvataarsPicker,
                icon: const Icon(Icons.person, size: 18),
                label: Text(
                  _avatarParams != null ? 'Edit Avataaars' : 'Avataaars',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openMidjourneyPicker,
                icon: const Icon(Icons.collections, size: 18),
                label: Text(
                  _midjourneyAvatarId != null ? 'Change Avatar' : 'Gallery',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateModeToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('Templates'),
          selected: _useTemplateMode,
          onSelected: (_) => setState(() => _useTemplateMode = true),
          selectedColor: Colors.deepPurple,
          labelStyle: TextStyle(
            color: _useTemplateMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        ChoiceChip(
          label: const Text('Custom'),
          selected: !_useTemplateMode,
          onSelected: (_) {
            setState(() {
              _useTemplateMode = false;
              _selectedTemplate = null;
            });
          },
          selectedColor: Colors.deepPurple,
          labelStyle: TextStyle(
            color: !_useTemplateMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateSection() {
    final templates = CharacterTemplateService.getTemplates();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'One-tap templates',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick a template to auto-fill traits. You can still tweak anything after.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: templates.map((template) {
            final isSelected = _selectedTemplate?.key == template.key;
            return SizedBox(
              width: MediaQuery.of(context).size.width > 640
                  ? 260
                  : double.infinity,
              child: Card(
                elevation: isSelected ? 6 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected ? template.color : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                template.color.withValues(alpha: 0.15),
                            child: Icon(template.icon, color: template.color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              template.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        template.description,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: template.strengths
                            .map((s) => Chip(
                                  label: Text(s),
                                  backgroundColor:
                                      template.color.withValues(alpha: 0.15),
                                  labelStyle: TextStyle(
                                      color: template.color,
                                      fontWeight: FontWeight.w700),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _applyTemplate(template),
                        icon: Icon(
                          isSelected ? Icons.check_circle : Icons.flash_on,
                        ),
                        label: Text(
                            isSelected ? 'Template Selected' : 'Use Template'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isSelected ? template.color : Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _createCharacter() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill in all required fields'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    final url = Uri.parse('${Environment.backendUrl}/create-character');

    try {
      final ageValue = int.tryParse(_ageController.text.trim());
      // Clamp age to supported range to avoid edge-case crashes in analytics/backends.
      final int ageToSend = (ageValue ?? 7).clamp(3, 99).toInt();
      // Simplified character creation - only send essential data
      final body = {
        'name': _nameController.text.trim(),
        'age': ageToSend,
        'gender': _isA, // Send Boy/Girl for story pronouns
        'character_type': _characterType,
        'character_style': _characterStyle,
        'skin_tone': _skinTone,
        'hairstyle': _hairStyle,
        if (_selectedTemplate != null) 'template_key': _selectedTemplate!.key,

        // Only include superhero fields if selected
        if (_characterType == 'Superhero') ...{
          'superhero_name': _superheroNameController.text.trim().isNotEmpty
              ? _superheroNameController.text.trim()
              : 'Super ${_nameController.text.trim()}',
          'magic_type': _superpowerController.text.trim().isNotEmpty
              ? _superpowerController.text.trim()
              : 'Super Strength',
        },

        // Basic appearance (optional)
        if (_hairColor.isNotEmpty) ...{
          'hair': _hairColor,
          'hair_color': _hairColor,
        },
        if (_eyeColor.isNotEmpty) ...{
          'eyes': _eyeColor,
          'eye_color': _eyeColor,
        },
        if (_outfitController.text.trim().isNotEmpty)
          'outfit': _outfitController.text.trim(),

        // Avatar configuration
        'avatar': _avatar.toJson(),

        // Avataaars customization (DiceBear)
        if (_avatarParams != null) 'avatar_params': _avatarParams,

        // Only include likes/dislikes if specified
        if (_selectedQuickLikes.isNotEmpty)
          'likes': _selectedQuickLikes.toList(),
        if (_selectedQuickDislikes.isNotEmpty)
          'dislikes': _selectedQuickDislikes.toList(),
      };

      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode(body),
      );

      if (!mounted) return;

      if (resp.statusCode == 201) {
        // Save character locally for offline access
        try {
          final responseData = json.decode(resp.body);
          final localChar = CharacterLocal.fromJson(responseData);
          await IsarService.saveCharacter(localChar);
          debugPrint('Character saved locally: ${localChar.name}');
        } catch (e) {
          debugPrint('Failed to save character locally: $e');
          // Continue even if local save fails - the server has it
        }

        try {
          final achievements =
              await _achievementService.recordCharacterCreated();
          await _progressionService.incrementCharactersCreated();
          if (mounted && achievements.isNotEmpty) {
            await AchievementCelebrationDialog.show(context, achievements);
          }
        } catch (e) {
          debugPrint('Progress/achievement tracking failed: $e');
        }

        try {
          await CharacterAnalytics.trackCharacterCreation(
            characterName: _nameController.text.trim(),
            age: ageToSend,
            gender: _isA,
            traits: _selectedQuickLikes.toList(),
            templateKey: _selectedTemplate?.key,
          );
        } catch (e) {
          debugPrint('Character analytics failed: $e');
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_nameController.text.trim()} was created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to create character. Server error: ${resp.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on http.ClientException catch (e) {
      _showErrorSnackBar('Network Error: ${e.message}');
    } on SocketException catch (e) {
      _showErrorSnackBar('Connection Error: ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('Character Creation Error: $e');
      debugPrint('Stack Trace: $stackTrace');
      _showErrorSnackBar('An unexpected error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    _ageController.dispose();
    _superheroNameController.dispose();
    _superpowerController.dispose();
    _missionController.dispose();
    _outfitController.removeListener(_handleOutfitChanged);
    _outfitController.dispose();
    _likesController.dispose();
    _dislikesController.dispose();
    _fearsController.dispose();
    _goalsChallengesController.dispose();
    _comfortItemController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: _isLoading ? 'Creating your character...' : null,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create a Character'),
          backgroundColor: Colors.deepPurple,
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTemplateModeToggle(),
                const SizedBox(height: 12),
                _buildBasicInfoSection(),
                const SizedBox(height: 20),
                _buildCharacterTypeSection(),
                const SizedBox(height: 20),
                if (_characterType == 'Superhero') ...[
                  _buildSuperheroSection(),
                  const SizedBox(height: 20),
                ],
                _buildAppearanceSection(),
                if (_useTemplateMode) ...[
                  const SizedBox(height: 20),
                  _buildTemplateSection(),
                ],
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createCharacter,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(_isLoading ? 'Creating...' : 'Create Character'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSectionCard(
      'Basic Information',
      Icons.person,
      [
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Name *',
            hintText: 'e.g., Emma, Jake, Alex',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon: const Icon(Icons.badge),
          ),
          maxLength: 50,
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Name is required' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _isA,
          decoration: InputDecoration(
            labelText: 'Gender *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          items: ['Boy', 'Girl']
              .map((gender) => DropdownMenuItem(
                    value: gender,
                    child: Text(gender),
                  ))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _isA = value);
            _applyGenderPreset(value);
          },
          validator: (v) => v == null ? 'Please select gender' : null,
        ),
        const SizedBox(height: 12),
        // Character Avatar Preview
        Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Character Preview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Use key to force rebuild when colors change
                KeyedSubtree(
                  key: ValueKey('${_avatar.hashCode}-${_nameController.text}'),
                  child: CustomizableAvatarWidget(
                    avatar: _avatar,
                    size: 120,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _nameController.text.isEmpty
                      ? 'Your Character'
                      : _nameController.text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _ageController,
                decoration: InputDecoration(
                  labelText: 'Age *',
                  hintText: '3-99',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[50],
                  prefixIcon: const Icon(Icons.cake),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final age = int.tryParse(v.trim());
                  if (age == null) return 'Invalid number';
                  if (age < 3 || age > 99) {
                    return 'Age must be 3-99';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _isA,
                decoration: InputDecoration(
                  labelText: 'Is a: *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: const [
                  DropdownMenuItem(value: 'Girl', child: Text('Girl')),
                  DropdownMenuItem(value: 'Boy', child: Text('Boy')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _isA = v);
                  _applyGenderPreset(v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _characterStyle,
          decoration: InputDecoration(
            labelText: 'Character Style *',
            hintText: 'Choose appearance and personality',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon: const Icon(Icons.style),
          ),
          items: const [
            DropdownMenuItem(value: 'Regular Kid', child: Text('Regular Kid')),
            DropdownMenuItem(value: 'Girly Girl', child: Text('Girly Girl')),
            DropdownMenuItem(value: 'Tomboy', child: Text('Tomboy')),
            DropdownMenuItem(value: 'Sporty Kid', child: Text('Sporty Kid')),

            DropdownMenuItem(value: 'Explorer', child: Text('Explorer')),
            DropdownMenuItem(
                value: 'Couch Potato', child: Text('Couch Potato')),
            DropdownMenuItem(
                value: 'Creative Artist', child: Text('Creative Artist')),
            DropdownMenuItem(
                value: 'Young Scientist', child: Text('Young Scientist')),
          ],
          onChanged: (v) {
            final value = v ?? 'Regular Kid';
            setState(() => _characterStyle = value);
            _applyStylePreset(value);
          },
        ),
      ],
    );
  }

  Widget _buildCharacterTypeSection() {
    final types = [
      {
        'name': 'Superhero',
        'icon': Icons.flash_on,
        'color': Colors.red,
        'locked': !_hasPremium,
        'unlockMsg': 'Premium feature - Use BYOK or subscribe'
      },
      {
        'name': 'Princess/Prince',
        'icon': Icons.castle,
        'color': Colors.pink,
        'locked': false
      },
      {
        'name': 'Explorer',
        'icon': Icons.explore,
        'color': Colors.orange,
        'locked': false
      },
      {
        'name': 'Wizard/Witch',
        'icon': Icons.auto_fix_high,
        'color': Colors.purple,
        'locked': !_hasFantasyMode,
        'unlockMsg': 'Unlock at 5 stories!'
      },
      {
        'name': 'Scientist',
        'icon': Icons.science,
        'color': Colors.blue,
        'locked': false
      },
      {
        'name': 'Animal Friend',
        'icon': Icons.pets,
        'color': Colors.green,
        'locked': !_hasAnimalEarsTails,
        'unlockMsg': 'Unlock at 10 stories!'
      },
      {
        'name': 'Everyday Kid',
        'icon': Icons.child_care,
        'color': Colors.teal,
        'locked': false
      },
    ];

    return _buildSectionCard(
      'Character Type',
      Icons.stars,
      [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((type) {
            final typeName = type['name'] as String;
            final isSelected = _characterType == typeName;
            final isLocked = type['locked'] as bool;
            final unlockMsg = type['unlockMsg'] as String?;

            return GestureDetector(
              onTap: isLocked && unlockMsg != null
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(unlockMsg),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  : null,
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLocked)
                      const Icon(Icons.lock, size: 16, color: Colors.grey)
                    else
                      Icon(
                        type['icon'] as IconData,
                        size: 18,
                        color:
                            isSelected ? Colors.white : type['color'] as Color,
                      ),
                    const SizedBox(width: 6),
                    Text(typeName),
                  ],
                ),
                selected: isSelected,
                onSelected: isLocked
                    ? null
                    : (selected) {
                        setState(() => _characterType = typeName);
                      },
                selectedColor: type['color'] as Color,
                backgroundColor: isLocked ? Colors.grey.shade200 : null,
                labelStyle: TextStyle(
                  color: isLocked
                      ? Colors.grey
                      : (isSelected ? Colors.white : Colors.black87),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _generateRandomSuperhero() {
    final idea = SuperheroNameGenerator.generateCompleteIdea(
      challenge: _nameController.text.trim(),
    );
    setState(() {
      _superheroNameController.text = idea.name;
      _superpowerController.text = idea.powerTheme;
      _missionController.text = idea.mission;
    });
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('${idea.catchPhrase} ${idea.supportAction}'),
        backgroundColor: Colors.purple.shade300,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildSuperheroSection() {
    return _buildSectionCard(
      'Superhero Details',
      Icons.flash_on,
      [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Generate random ideas:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            ElevatedButton.icon(
              onPressed: _generateRandomSuperhero,
              icon: const Icon(Icons.casino, size: 20),
              label: const Text('Random'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _superheroNameController,
          decoration: InputDecoration(
            labelText: 'Superhero Name',
            hintText: 'e.g., Lightning Kid, Star Guardian',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.red[50],
            prefixIcon: const Icon(Icons.shield),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _superpowerController,
          decoration: InputDecoration(
            labelText: 'Superpower',
            hintText: 'e.g., Flying, Super Strength, Invisibility',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.red[50],
            prefixIcon: const Icon(Icons.bolt),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _missionController,
          decoration: InputDecoration(
            labelText: 'Mission/What They Protect',
            hintText: 'e.g., Protecting their neighborhood, Helping animals',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.red[50],
            prefixIcon: const Icon(Icons.flag),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildAppearanceSection() {
    return _buildSectionCard(
      'Appearance',
      Icons.face,
      [
        _buildColorChoiceRow(
          title: 'Skin Tone',
          options: skinToneOptions,
          selectedValue: _skinTone,
          onSelected: (value) => setState(() {
            _skinTone = value;
            _avatar = _avatar.copyWith(skinColor: value);
            _avatarCustomized = true;
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _hairStyle,
          decoration: InputDecoration(
            labelText: 'Hair Style',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon: const Icon(Icons.face_retouching_natural),
          ),
          items: hairStyleOptions.map((style) {
            return DropdownMenuItem(value: style, child: Text(style));
          }).toList(),
          onChanged: (value) => setState(() {
            _hairStyle = value ?? _hairStyle;
            _avatar = _avatar.copyWith(
                hairStyle: _mapHairStyleToAvataaars(value ?? _hairStyle));
            _avatarCustomized = true;
          }),
        ),
        const SizedBox(height: 12),
        _buildColorChoiceRow(
          title: 'Hair Color',
          options: hairColorOptions,
          selectedValue: _hairColor,
          onSelected: (value) => setState(() {
            _hairColor = value;
            _avatar = _avatar.copyWith(hairColor: value);
            _avatarCustomized = true;
          }),
        ),
        const SizedBox(height: 12),
        _buildColorChoiceRow(
          title: 'Eye Color',
          options: eyeColorOptions,
          selectedValue: _eyeColor,
          onSelected: (value) => setState(() {
            _eyeColor = value;
            // Eye color stored for backend, but not used in avatar (DiceBear limitation)
          }),
        ),
        const SizedBox(height: 12),
        _buildOutfitPresetPicker(),
        const SizedBox(height: 12),
        TextFormField(
          controller: _outfitController,
          decoration: InputDecoration(
            labelText: 'Favorite Outfit/Costume',
            hintText: 'Describe their outfit or costume idea',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon: const Icon(Icons.checkroom),
          ),
        ),
      ],
    );
  }

  String _mapHairStyleToAvataaars(String friendlyName) {
    switch (friendlyName) {
      case 'Short & Flat':
        return 'ShortHairShortFlat';
      case 'Short & Curly':
        return 'ShortHairShortCurly';
      case 'Short & Wavy':
        return 'ShortHairShortWaved';
      case 'Long & Straight':
        return 'LongHairStraight';
      case 'Long & Curly':
        return 'LongHairCurly';
      case 'Big Hair':
        return 'LongHairBigHair';
      case 'Bun':
        return 'LongHairBun';
      case 'Braids':
        return 'LongHairBraids';
      case 'Ponytail':
        return 'LongHairPonytail';
      default:
        return 'ShortHairShortFlat';
    }
  }

  Widget _buildPersonalitySection() {
    final possessive = _characterPossessive();
    return _buildSectionCard(
      'Personality Dials',
      Icons.psychology,
      [
        Text(
          'Slide to show how $possessive acts in real life. These dials teach the AI who they really are.',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ...CharacterTraitsData.personalitySliders
            .map((slider) => _buildPersonalitySlider(slider)),
      ],
    );
  }

  Widget _buildPersonalitySlider(PersonalitySliderDefinition slider) {
    final value = _personalitySliderValues[slider.key] ?? 50;
    final description = slider.describeValue(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  slider.label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${value.round()}/100',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            slider.helperText,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSliderEndpoint(slider.leftIcon, slider.leftLabel, true),
              const SizedBox(width: 8),
              _buildSliderEndpoint(slider.rightIcon, slider.rightLabel, false),
            ],
          ),
          Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 100,
            label: value.round().toString(),
            activeColor: Colors.deepPurple,
            onChanged: (newValue) {
              setState(() {
                _personalitySliderValues[slider.key] = newValue;
              });
            },
          ),
          Text(
            description,
            style: TextStyle(
              color: Colors.deepPurple.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderEndpoint(IconData icon, String label, bool isLeftAligned) {
    return Expanded(
      child: Row(
        mainAxisAlignment:
            isLeftAligned ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Icon(icon, size: 18, color: Colors.deepPurple),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              textAlign: isLeftAligned ? TextAlign.start : TextAlign.end,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorChoiceRow({
    required String title,
    required List<AppearanceColorOption> options,
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = option.label == selectedValue;
            return ChoiceChip(
              avatar: _buildColorSwatch(option.color),
              label: Text(option.label),
              selected: isSelected,
              selectedColor: Colors.deepPurple,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (value) {
                if (value) onSelected(option.label);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildColorSwatch(Color color) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.black26),
      ),
    );
  }

  Widget _buildOutfitPresetPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Outfit Ideas',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          'Tap a card to autofill an outfit',
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: outfitPresetOptions.map((option) {
            final isSelected = option.label == _selectedOutfitPreset;
            return ChoiceChip(
              avatar: Icon(
                option.icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.deepPurple,
              ),
              label: Text(option.label),
              selected: isSelected,
              selectedColor: Colors.deepPurple,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _selectedOutfitPreset = option.label;
                    _outfitController.text = option.label;
                  } else {
                    _selectedOutfitPreset = null;
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInterestsSection() {
    return _buildSectionCard(
      'Interests & Preferences',
      Icons.favorite,
      [
        _buildInterestChipGroup(
          title: 'Favorite things to include in stories',
          subtitle: 'Tap all the things that light them up',
          options: commonLikeOptions,
          selections: _selectedQuickLikes,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _likesController,
          decoration: InputDecoration(
            labelText: 'Other favorite things',
            hintText: 'e.g., dinosaurs, painting, soccer',
            helperText: 'Add custom likes, separated by commas',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.green[50],
            prefixIcon: const Icon(Icons.thumb_up),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        _buildInterestChipGroup(
          title: 'Things they try to avoid',
          subtitle: 'Helps the story steer clear of no-go zones',
          options: commonDislikeOptions,
          selections: _selectedQuickDislikes,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _dislikesController,
          decoration: InputDecoration(
            labelText: 'Other dislikes',
            hintText: 'e.g., loud noises, broccoli, being late',
            helperText: 'Add custom dislikes, separated by commas',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.orange[50],
            prefixIcon: const Icon(Icons.thumb_down),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildGrowthSection() {
    return _buildSectionCard(
      'Growth & Big Feelings',
      Icons.spa,
      [
        _buildInterestChipGroup(
          title: 'What makes them worry?',
          subtitle: 'Pick feelings the story should gently help with',
          options: commonFearOptions,
          selections: _selectedFearOptions,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _fearsController,
          decoration: InputDecoration(
            labelText: 'Other fears/worries',
            hintText: 'e.g., the dark, new schools',
            helperText: 'Separate with commas',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.purple[50],
            prefixIcon: const Icon(Icons.shield_outlined),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        _buildInterestChipGroup(
          title: 'What they\'re working on (goals or challenges)',
          subtitle: 'Stories can help them grow and cheer them on',
          options: commonGoalOptions,
          selections: _selectedGoalChallengeOptions,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _goalsChallengesController,
          decoration: InputDecoration(
            labelText: 'Other goals or challenges',
            hintText:
                'e.g., being braver, making new friends, learning to share',
            helperText: 'Separate with commas',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.amber[50],
            prefixIcon: const Icon(Icons.emoji_events),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        _buildSingleChoiceChipGroup(
          title: 'Favorite comfort',
          subtitle: 'Stories can include this when things feel big',
          options: commonComfortOptions,
          selectedValue: _selectedComfortOption,
          onSelected: (value) {
            setState(() => _selectedComfortOption = value);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _comfortItemController,
          decoration: InputDecoration(
            labelText: 'Other comfort item',
            hintText: 'e.g., Nana’s bracelet',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.teal[50],
            prefixIcon: const Icon(Icons.favorite_border),
          ),
        ),
      ],
    );
  }

  Widget _buildInterestChipGroup({
    required String title,
    required String subtitle,
    required List<InterestOption> options,
    required Set<String> selections,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selections.contains(option.label);
            return ChoiceChip(
              avatar: Icon(
                option.icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.deepPurple,
              ),
              label: Text(option.label),
              selected: isSelected,
              selectedColor: Colors.deepPurple,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (value) {
                setState(() {
                  if (value) {
                    selections.add(option.label);
                  } else {
                    selections.remove(option.label);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSingleChoiceChipGroup({
    required String title,
    required String subtitle,
    required List<InterestOption> options,
    required String? selectedValue,
    required ValueChanged<String?> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = option.label == selectedValue;
            return ChoiceChip(
              avatar: Icon(
                option.icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.deepPurple,
              ),
              label: Text(option.label),
              selected: isSelected,
              selectedColor: Colors.deepPurple,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (value) => onSelected(value ? option.label : null),
            );
          }).toList(),
        ),
      ],
    );
  }
}

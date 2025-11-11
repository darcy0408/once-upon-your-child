import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'superhero_name_generator.dart';
import 'character_traits_data.dart';
import 'appearance_options.dart';
import 'interest_options.dart';

class CharacterEditScreen extends StatefulWidget {
  final Character character;

  const CharacterEditScreen({super.key, required this.character});

  @override
  State<CharacterEditScreen> createState() => _CharacterEditScreenState();
}

class _CharacterEditScreenState extends State<CharacterEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Basic Info
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late String _characterStyle;
  late String _isA;

  // Character Type
  late String _characterType;

  // Superhero Specific
  late final TextEditingController _superheroNameController;
  late final TextEditingController _superpowerController;
  late final TextEditingController _missionController;

  // Appearance
  late String _hairColor;
  late String _eyeColor;
  late final TextEditingController _outfitController;
  String? _selectedOutfitPreset;

  // Personality
  late final Map<String, double> _personalitySliderValues;

  // Interests & Preferences
  final Set<String> _selectedQuickLikes = <String>{};
  final Set<String> _selectedQuickDislikes = <String>{};
  final Set<String> _selectedFearOptions = <String>{};
  final Set<String> _selectedGoalChallengeOptions = <String>{};
  String? _selectedComfortOption;
  late final TextEditingController _likesController;
  late final TextEditingController _dislikesController;
  final TextEditingController _fearsController = TextEditingController();
  final TextEditingController _goalsChallengesController = TextEditingController();
  final TextEditingController _comfortItemController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Initialize with existing character data
    _nameController = TextEditingController(text: widget.character.name);
    _ageController =
        TextEditingController(text: widget.character.age.toString());
    _isA = widget.character.gender ?? 'Girl'; // Load existing gender as "Is a:"
    _characterStyle =
        widget.character.characterStyle ?? 'Regular Kid'; // Default character style

    _characterType = widget.character.role ?? 'Everyday Kid';

    _superheroNameController = TextEditingController();
    _superpowerController =
        TextEditingController(text: widget.character.magicType ?? '');
    _missionController = TextEditingController();

    _hairColor = widget.character.hair ?? 'Brown';
    _eyeColor = widget.character.eyes ?? 'Brown';
    _outfitController =
        TextEditingController(text: widget.character.outfit ?? '');
    _outfitController.addListener(_handleOutfitChanged);
    for (final option in outfitPresetOptions) {
      if (option.label.toLowerCase() ==
          _outfitController.text.trim().toLowerCase()) {
        _selectedOutfitPreset = option.label;
        break;
      }
    }

    _personalitySliderValues = CharacterTraitsData.defaultSliderValues();
    final existingSliders = widget.character.personalitySliders;
    if (existingSliders != null) {
      for (final slider in CharacterTraitsData.personalitySliders) {
        final rawValue = existingSliders[slider.key];
        if (rawValue != null) {
          _personalitySliderValues[slider.key] = _coerceSliderDouble(rawValue);
        }
      }
    }

    final manualLikes = _extractManualInterests(
      widget.character.likes ?? const <String>[],
      commonLikeOptions,
      _selectedQuickLikes,
    );
    final manualDislikes = _extractManualInterests(
      widget.character.dislikes ?? const <String>[],
      commonDislikeOptions,
      _selectedQuickDislikes,
    );
    _likesController = TextEditingController(manualLikes.join(', '));
    _dislikesController = TextEditingController(manualDislikes.join(', '));

    _initializeGrowthSelections(
      widget.character.fears ?? const <String>[],
      commonFearOptions,
      _selectedFearOptions,
      _fearsController,
    );
    _initializeGrowthSelections(
      widget.character.goals ?? const <String>[],
      commonGoalOptions,
      _selectedGoalChallengeOptions,
      _goalsChallengesController,
    );
    final existingChallenge = widget.character.challenge?.trim() ?? '';
    if (existingChallenge.isNotEmpty) {
      final matchesOption =
          commonGoalOptions.any((option) => option.label == existingChallenge);
      if (matchesOption) {
        _selectedGoalChallengeOptions.add(existingChallenge);
      } else {
        final current = _goalsChallengesController.text.trim();
        final entries = <String>[];
        if (current.isNotEmpty) {
          entries.add(current);
        }
        entries.add(existingChallenge);
        _goalsChallengesController.text = entries.join(', ');
      }
    }
    final existingComfort = widget.character.comfortItem ?? '';
    if (existingComfort.isNotEmpty &&
        commonComfortOptions
            .any((option) => option.label == existingComfort)) {
      _selectedComfortOption = existingComfort;
    } else {
      _comfortItemController.text = existingComfort;
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

  List<String> _extractManualInterests(
    List<String> source,
    List<InterestOption> options,
    Set<String> selection,
  ) {
    final labels = options.map((o) => o.label).toSet();
    final manual = <String>[];
    for (final entry in source) {
      if (labels.contains(entry)) {
        selection.add(entry);
      } else {
        manual.add(entry);
      }
    }
    return manual;
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

  void _initializeGrowthSelections(
    List<String> source,
    List<InterestOption> options,
    Set<String> selection,
    TextEditingController controller,
  ) {
    final manual = _extractManualInterests(source, options, selection);
    controller.text = manual.join(', ');
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

  double _coerceSliderDouble(dynamic value) {
    if (value is num) {
      return value.clamp(0, 100).toDouble();
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) {
        return parsed.clamp(0, 100);
      }
    }
    return 50;
  }

  void _handleOutfitChanged() {
    final trimmed = _outfitController.text.trim();
    if (_selectedOutfitPreset != null &&
        trimmed.toLowerCase() != _selectedOutfitPreset!.toLowerCase() &&
        mounted) {
      setState(() => _selectedOutfitPreset = null);
    }
  }

  Map<String, int> _buildPersonalitySliderPayload() {
    final payload = <String, int>{};
    _personalitySliderValues.forEach((key, value) {
      payload[key] = value.clamp(0, 100).round();
    });
    return payload;
  }

  Future<void> _updateCharacter() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill in all required fields'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    final url =
        Uri.parse('http://127.0.0.1:5000/characters/${widget.character.id}');

    // Build role based on character type
    String role = _characterType;
    if (_characterType == 'Superhero' &&
        _superheroNameController.text.isNotEmpty) {
      role = 'Superhero (${_superheroNameController.text.trim()})';
    }

    try {
      final comfortValue = _resolveComfortItem();
      final body = {
        'name': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? widget.character.age,
        'gender': _isA, // Send Boy/Girl for story pronouns
        'character_style': _characterStyle, // Character appearance/personality
        'role': role,
        'character_type': _characterType,

        // Superhero specific
        if (_characterType == 'Superhero') ...{
          'magic_type': _superpowerController.text.trim().isEmpty
              ? 'Super Strength'
              : _superpowerController.text.trim(),
          'superhero_name': _superheroNameController.text.trim(),
          'mission': _missionController.text.trim(),
        },

        // Appearance
        'hair': _hairColor,
        'eyes': _eyeColor,
        'outfit': _outfitController.text.trim(),

        'personality_sliders': _buildPersonalitySliderPayload(),

        // Interests
        'likes': _combinedInterests(_selectedQuickLikes, _likesController),
        'dislikes':
            _combinedInterests(_selectedQuickDislikes, _dislikesController),

        // Growth
        'fears':
            _combinedGrowthSelections(_selectedFearOptions, _fearsController),
        'goals': _combinedGrowthSelections(
            _selectedGoalChallengeOptions, _goalsChallengesController),
        if (comfortValue != null) 'comfort_item': comfortValue,
      };

      final resp = await http.patch(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode(body),
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${_nameController.text.trim()} updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context)
            .pop(true); // Return true to indicate changes were made
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to update character. Server error: ${resp.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('An error occurred: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCharacter() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Character?'),
        content: Text(
            'Are you sure you want to delete ${widget.character.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final url =
        Uri.parse('http://127.0.0.1:5000/characters/${widget.character.id}');

    try {
      final resp = await http.delete(url);

      if (!mounted) return;

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Character deleted'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop(true); // Return true to refresh list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete character'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.character.name}'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete Character',
            onPressed: _deleteCharacter,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBasicInfoSection(),
              const SizedBox(height: 20),
              _buildCharacterTypeSection(),
              const SizedBox(height: 20),
              if (_characterType == 'Superhero') ...[
                _buildSuperheroSection(),
                const SizedBox(height: 20),
              ],
              _buildAppearanceSection(),
              const SizedBox(height: 20),
              _buildPersonalitySection(),
              const SizedBox(height: 20),
              _buildInterestsSection(),
              const SizedBox(height: 20),
              _buildGrowthSection(),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _updateCharacter,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isLoading ? 'Saving...' : 'Save Changes'),
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

  // Reuse the same section builders from the enhanced creation screen
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
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _ageController,
                decoration: InputDecoration(
                  labelText: 'Age *',
                  hintText: '5-12',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[50],
                  prefixIcon: const Icon(Icons.cake),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (int.tryParse(v.trim()) == null) return 'Invalid';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _isA,
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
                onChanged: (v) => setState(() => _isA = v ?? 'Girl'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _characterStyle,
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
            DropdownMenuItem(
                value: 'Couch Potato', child: Text('Couch Potato')),
            DropdownMenuItem(
                value: 'Creative Artist', child: Text('Creative Artist')),
            DropdownMenuItem(
                value: 'Young Scientist', child: Text('Young Scientist')),
            DropdownMenuItem(
                value: 'Playful Puppy', child: Text('Playful Puppy')),
            DropdownMenuItem(value: 'Curious Cat', child: Text('Curious Cat')),
            DropdownMenuItem(value: 'Brave Bird', child: Text('Brave Bird')),
            DropdownMenuItem(
                value: 'Gentle Bunny', child: Text('Gentle Bunny')),
            DropdownMenuItem(value: 'Wise Fox', child: Text('Wise Fox')),
            DropdownMenuItem(
                value: 'Magical Dragon', child: Text('Magical Dragon')),
          ],
          onChanged: (v) =>
              setState(() => _characterStyle = v ?? 'Regular Kid'),
        ),
      ],
    );
  }

  Widget _buildCharacterTypeSection() {
    final types = [
      {'name': 'Superhero', 'icon': Icons.flash_on, 'color': Colors.red},
      {'name': 'Princess/Prince', 'icon': Icons.castle, 'color': Colors.pink},
      {'name': 'Explorer', 'icon': Icons.explore, 'color': Colors.orange},
      {
        'name': 'Wizard/Witch',
        'icon': Icons.auto_fix_high,
        'color': Colors.purple
      },
      {'name': 'Scientist', 'icon': Icons.science, 'color': Colors.blue},
      {'name': 'Animal Friend', 'icon': Icons.pets, 'color': Colors.green},
      {'name': 'Everyday Kid', 'icon': Icons.child_care, 'color': Colors.teal},
    ];

    return _buildSectionCard(
      'Character Type',
      Icons.stars,
      [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((type) {
            final isSelected = _characterType == type['name'];
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    type['icon'] as IconData,
                    size: 18,
                    color: isSelected ? Colors.white : type['color'] as Color,
                  ),
                  const SizedBox(width: 6),
                  Text(type['name'] as String),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _characterType = type['name'] as String);
              },
              selectedColor: type['color'] as Color,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
          title: 'Hair Color',
          options: hairColorOptions,
          selectedValue: _hairColor,
          onSelected: (value) => setState(() => _hairColor = value),
        ),
        const SizedBox(height: 12),
        _buildColorChoiceRow(
          title: 'Eye Color',
          options: eyeColorOptions,
          selectedValue: _eyeColor,
          onSelected: (value) => setState(() => _eyeColor = value),
        ),
        const SizedBox(height: 12),
        _buildOutfitPresetPicker(),
        const SizedBox(height: 12),
        TextFormField(
          controller: _outfitController,
          decoration: InputDecoration(
            labelText: 'Favorite Outfit/Costume',
            hintText: 'Describe it so the story can show it off',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon: const Icon(Icons.checkroom),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalitySection() {
    return _buildSectionCard(
      'Personality Dials',
      Icons.psychology,
      [
        const Text(
          'Tweak the sliders so stories describe this kid exactly like they are at home.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ...CharacterTraitsData.personalitySliders
            .map((slider) => _buildPersonalitySlider(slider))
            .toList(),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
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

  Widget _buildSliderEndpoint(
      IconData icon, String label, bool isLeftAligned) {
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
          style: const TextStyle(fontWeight: FontWeight.w700),
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
          'Tap to autofill an outfit description',
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
          title: 'Favorite things to mention',
          subtitle: 'Tap everything that makes adventures extra fun',
          options: commonLikeOptions,
          selections: _selectedQuickLikes,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _likesController,
          decoration: InputDecoration(
            labelText: 'Other likes',
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
          title: 'Things to avoid',
          subtitle: 'Stories steer clear of these',
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
          title: 'Fears/Worries',
          subtitle: 'Tap the ones that feel true right now',
          options: commonFearOptions,
          selections: _selectedFearOptions,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _fearsController,
          decoration: InputDecoration(
            labelText: 'Other fears/worries',
            hintText: 'Separate with commas',
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
            hintText: 'e.g., being braver, making new friends, learning to share',
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
          title: 'Comfort item',
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
            hintText: 'e.g., Dad’s lucky bracelet',
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
              onSelected: (value) =>
                  onSelected(value ? option.label : null),
            );
          }).toList(),
        ),
      ],
    );
  }


}

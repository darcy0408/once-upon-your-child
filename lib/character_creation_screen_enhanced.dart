import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'superhero_name_generator.dart';
import 'avatar_builder_screen.dart';
import 'avatar_models.dart';
import 'customizable_avatar_widget.dart';

class CharacterCreationScreenEnhanced extends StatefulWidget {
  const CharacterCreationScreenEnhanced({super.key});

  @override
  State<CharacterCreationScreenEnhanced> createState() =>
      _CharacterCreationScreenEnhancedState();
}

class _CharacterCreationScreenEnhancedState
    extends State<CharacterCreationScreenEnhanced> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

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
  String _hairColor = 'Brown';
  String _eyeColor = 'Brown';
  final _outfitController = TextEditingController();
  CharacterAvatar _avatar = CharacterAvatar.defaultAvatar;

  // Personality
  final Set<String> _selectedTraits = {};

  // Interests & Preferences
  final _likesController = TextEditingController();
  final _dislikesController = TextEditingController();

  // Therapeutic Elements
  final _fearsController = TextEditingController();
  final _strengthsController = TextEditingController();
  final _goalsController = TextEditingController();
  final _challengesController = TextEditingController();
  final _comfortItemController = TextEditingController();

  List<String> _splitCSV(String text) {
    if (text.trim().isEmpty) return <String>[];
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
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
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = result.name;
        }
        _hairColor = result.avatar.hairColor;
      });
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
            color: Colors.black.withOpacity(0.08),
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
          ElevatedButton.icon(
            onPressed: _openAvatarBuilder,
            icon: const Icon(Icons.brush),
            label: const Text('Edit Avatar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
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
    final url = Uri.parse('http://127.0.0.1:5000/create-character');

    // Build role based on character type
    String role = _characterType;
    if (_characterType == 'Superhero' &&
        _superheroNameController.text.isNotEmpty) {
      role = 'Superhero (${_superheroNameController.text.trim()})';
    }

    try {
      final ageValue = int.tryParse(_ageController.text.trim());
      final ageToSend =
          (ageValue == null || ageValue < 3 || ageValue > 100) ? 7 : ageValue;
      final body = {
        'name': _nameController.text.trim(),
        'age': ageToSend,
        'gender': _isA, // Send Boy/Girl for story pronouns
        'character_style': _characterStyle, // Character appearance/personality
        'role': role,
        'character_type': _characterType,
        'avatar': _avatar.toJson(),

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

        // Personality
        'traits': _selectedTraits.toList(),

        // Interests
        'likes': _splitCSV(_likesController.text),
        'dislikes': _splitCSV(_dislikesController.text),

        // Therapeutic
        'fears': _splitCSV(_fearsController.text),
        'strengths': _splitCSV(_strengthsController.text),
        'goals': _splitCSV(_goalsController.text),
        'challenge': _challengesController.text.trim().isEmpty
            ? null
            : _challengesController.text.trim(),
        'comfort_item': _comfortItemController.text.trim().isEmpty
            ? null
            : _comfortItemController.text.trim(),
      };

      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode(body),
      );

      if (!mounted) return;

      if (resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_nameController.text.trim()} was created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
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

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _superheroNameController.dispose();
    _superpowerController.dispose();
    _missionController.dispose();
    _outfitController.dispose();
    _likesController.dispose();
    _dislikesController.dispose();
    _fearsController.dispose();
    _strengthsController.dispose();
    _goalsController.dispose();
    _challengesController.dispose();
    _comfortItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              _buildAvatarSection(),
              const SizedBox(height: 20),
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
              _buildTherapeuticSection(),
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
                  hintText: '3-100',
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
                  if (age < 3 || age > 100) {
                    return 'Age must be 3-100';
                  }
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
    final focusHint = _challengesController.text.trim().isNotEmpty
        ? _challengesController.text.trim()
        : _goalsController.text.trim();
    final idea =
        SuperheroNameGenerator.generateCompleteIdea(challenge: focusHint);
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
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _hairColor,
                decoration: InputDecoration(
                  labelText: 'Hair Color',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: const [
                  DropdownMenuItem(value: 'Brown', child: Text('Brown')),
                  DropdownMenuItem(value: 'Black', child: Text('Black')),
                  DropdownMenuItem(value: 'Blonde', child: Text('Blonde')),
                  DropdownMenuItem(value: 'Red', child: Text('Red')),
                  DropdownMenuItem(value: 'Auburn', child: Text('Auburn')),
                  DropdownMenuItem(value: 'Gray', child: Text('Gray')),
                  DropdownMenuItem(value: 'Silver', child: Text('Silver')),
                  DropdownMenuItem(value: 'Gold', child: Text('Gold')),
                  DropdownMenuItem(value: 'Bronze', child: Text('Bronze')),
                  DropdownMenuItem(
                      value: 'Colorful',
                      child: Text('Colorful (Rainbow/Fantasy)')),
                ],
                onChanged: (v) => setState(() => _hairColor = v ?? 'Brown'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _eyeColor,
                decoration: InputDecoration(
                  labelText: 'Eye Color',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: const [
                  DropdownMenuItem(value: 'Brown', child: Text('Brown')),
                  DropdownMenuItem(value: 'Blue', child: Text('Blue')),
                  DropdownMenuItem(value: 'Green', child: Text('Green')),
                  DropdownMenuItem(value: 'Hazel', child: Text('Hazel')),
                  DropdownMenuItem(value: 'Gray', child: Text('Gray')),
                  DropdownMenuItem(value: 'Amber', child: Text('Amber')),
                  DropdownMenuItem(value: 'Silver', child: Text('Silver')),
                  DropdownMenuItem(value: 'Gold', child: Text('Gold')),
                ],
                onChanged: (v) => setState(() => _eyeColor = v ?? 'Brown'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _outfitController,
          decoration: InputDecoration(
            labelText: 'Favorite Outfit/Costume',
            hintText: 'e.g., Blue cape, Flower dress, Space suit',
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
    final traits = [
      'Brave',
      'Shy',
      'Creative',
      'Curious',
      'Kind',
      'Funny',
      'Thoughtful',
      'Energetic',
      'Patient',
      'Determined',
      'Friendly',
      'Imaginative',
      'Caring',
      'Adventurous',
      'Smart',
    ];

    return _buildSectionCard(
      'Personality Traits',
      Icons.psychology,
      [
        const Text('Select traits that describe this character:',
            style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: traits.map((trait) {
            final isSelected = _selectedTraits.contains(trait);
            return FilterChip(
              label: Text(trait),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTraits.add(trait);
                  } else {
                    _selectedTraits.remove(trait);
                  }
                });
              },
              selectedColor: Colors.deepPurple.shade100,
              checkmarkColor: Colors.deepPurple,
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
        TextFormField(
          controller: _likesController,
          decoration: InputDecoration(
            labelText: 'Likes',
            hintText: 'e.g., dinosaurs, painting, soccer',
            helperText: 'Separate with commas',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.green[50],
            prefixIcon: const Icon(Icons.thumb_up),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _dislikesController,
          decoration: InputDecoration(
            labelText: 'Dislikes',
            hintText: 'e.g., loud noises, broccoli, being late',
            helperText: 'Separate with commas',
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

  Widget _buildTherapeuticSection() {
    return _buildSectionCard(
      'Growth & Challenges',
      Icons.spa,
      [
        const Text(
          'These help create therapeutic stories that support emotional growth',
          style: TextStyle(
              fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _strengthsController,
          decoration: InputDecoration(
            labelText: 'Strengths/What They\'re Good At',
            hintText: 'e.g., making friends, solving puzzles, being brave',
            helperText: 'Separate with commas',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.blue[50],
            prefixIcon: const Icon(Icons.star),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _fearsController,
          decoration: InputDecoration(
            labelText: 'Fears/Worries',
            hintText: 'e.g., the dark, being alone, trying new things',
            helperText: 'Separate with commas',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.purple[50],
            prefixIcon: const Icon(Icons.shield_outlined),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _goalsController,
          decoration: InputDecoration(
            labelText: 'Goals/What They Want to Achieve',
            hintText:
                'e.g., make more friends, overcome shyness, learn to swim',
            helperText: 'Separate with commas',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.amber[50],
            prefixIcon: const Icon(Icons.flag_outlined),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _challengesController,
          decoration: InputDecoration(
            labelText: 'Current Challenge',
            hintText: 'e.g., Learning to be patient, dealing with change',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.pink[50],
            prefixIcon: const Icon(Icons.trending_up),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _comfortItemController,
          decoration: InputDecoration(
            labelText: 'Comfort Item',
            hintText: 'e.g., a teddy bear, special blanket, lucky charm',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.teal[50],
            prefixIcon: const Icon(Icons.favorite_border),
          ),
        ),
      ],
    );
  }
}

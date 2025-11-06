import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'superhero_name_generator.dart';

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

  // Personality
  late final Set<String> _selectedTraits;

  // Interests & Preferences
  late final TextEditingController _likesController;
  late final TextEditingController _dislikesController;

  // Therapeutic Elements
  late final TextEditingController _fearsController;
  late final TextEditingController _strengthsController;
  late final TextEditingController _goalsController;
  late final TextEditingController _challengesController;
  late final TextEditingController _comfortItemController;

  @override
  void initState() {
    super.initState();

    // Initialize with existing character data
    _nameController = TextEditingController(text: widget.character.name);
    _ageController =
        TextEditingController(text: widget.character.age.toString());
    _isA = widget.character.gender ?? 'Girl'; // Load existing gender as "Is a:"
    _characterStyle = 'Regular Kid'; // Default character style

    _characterType = 'Everyday Kid'; // Default, will be overridden if available

    _superheroNameController = TextEditingController();
    _superpowerController =
        TextEditingController(text: widget.character.magicType ?? '');
    _missionController = TextEditingController();

    _hairColor = 'Brown';
    _eyeColor = 'Brown';
    _outfitController = TextEditingController();

    _selectedTraits = {};

    _likesController =
        TextEditingController(text: (widget.character.likes ?? []).join(', '));
    _dislikesController = TextEditingController(
        text: (widget.character.dislikes ?? []).join(', '));

    _fearsController =
        TextEditingController(text: (widget.character.fears ?? []).join(', '));
    _strengthsController = TextEditingController();
    _goalsController = TextEditingController();
    _challengesController =
        TextEditingController(text: widget.character.challenge ?? '');
    _comfortItemController =
        TextEditingController(text: widget.character.comfortItem ?? '');
  }

  List<String> _splitCSV(String text) {
    if (text.trim().isEmpty) return <String>[];
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
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
              _buildTherapeuticSection(),
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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'emotion_models.dart';
import 'emotion_picker_widget.dart';
import 'enhanced_character_avatar.dart';

class CharacterEditScreenEnhanced extends StatefulWidget {
  final Character character;

  const CharacterEditScreenEnhanced({super.key, required this.character});

  @override
  State<CharacterEditScreenEnhanced> createState() => _CharacterEditScreenEnhancedState();
}

class _CharacterEditScreenEnhancedState extends State<CharacterEditScreenEnhanced> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Basic Info
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late String _gender;

  // Appearance
  late String _hairColor;
  late String _eyeColor;
  late String _skinTone;
  late String _hairstyle;

  // Emotion
  EmotionState? _currentEmotion;

  // Interests
  late final TextEditingController _likesController;
  late final TextEditingController _dislikesController;

  @override
  void initState() {
    super.initState();

    // Initialize with existing character data
    _nameController = TextEditingController(text: widget.character.name);
    _ageController = TextEditingController(text: widget.character.age.toString());
    _gender = widget.character.gender ?? 'Girl';

    _hairColor = widget.character.hair ?? 'Brown';
    _eyeColor = widget.character.eyes ?? 'Brown';
    _skinTone = widget.character.skinTone ?? 'Medium';
    _hairstyle = widget.character.hairstyle ?? 'Straight';

    // Initialize emotion if exists
    if (widget.character.currentEmotionCore != null && widget.character.currentEmotion != null) {
      try {
        final core = CoreEmotion.values.firstWhere(
          (e) => e.name.toLowerCase() == widget.character.currentEmotionCore!.toLowerCase(),
          orElse: () => CoreEmotion.joy,
        );
        _currentEmotion = EmotionState(
          core: core,
          specific: widget.character.currentEmotion!,
          faceKey: '${core.name}_${widget.character.currentEmotion!.toLowerCase()}',
        );
      } catch (e) {
        _currentEmotion = null;
      }
    }

    _likesController = TextEditingController(
      text: (widget.character.likes ?? []).join(', ')
    );
    _dislikesController = TextEditingController(
      text: (widget.character.dislikes ?? []).join(', ')
    );
  }

  List<String> _splitCSV(String text) {
    if (text.trim().isEmpty) return <String>[];
    return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> _updateCharacter() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    final url = Uri.parse('http://127.0.0.1:5000/characters/${widget.character.id}');

    try {
      final body = {
        'name': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? widget.character.age,
        'gender': _gender,

        // Appearance
        'hair': _hairColor,
        'eyes': _eyeColor,
        'skin_tone': _skinTone,
        'hairstyle': _hairstyle,

        // Emotion
        if (_currentEmotion != null) ...{
          'current_emotion': _currentEmotion!.specific,
          'current_emotion_core': _currentEmotion!.core.name,
        },

        // Interests
        'likes': _splitCSV(_likesController.text),
        'dislikes': _splitCSV(_dislikesController.text),

        // Keep existing data
        'role': widget.character.role,
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
            content: Text('${_nameController.text.trim()} updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update character. Server error: ${resp.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e'), backgroundColor: Colors.red),
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
        content: Text('Are you sure you want to delete ${widget.character.name}? This cannot be undone.'),
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
    final url = Uri.parse('http://127.0.0.1:5000/characters/${widget.character.id}');

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
        Navigator.of(context).pop(true);
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
    _likesController.dispose();
    _dislikesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Create a temporary character with current values for avatar preview
    final previewCharacter = Character(
      id: widget.character.id,
      name: _nameController.text,
      age: int.tryParse(_ageController.text) ?? widget.character.age,
      role: widget.character.role,
      gender: _gender,
      hair: _hairColor,
      eyes: _eyeColor,
      skinTone: _skinTone,
      hairstyle: _hairstyle,
    );

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
              // Avatar Preview
              Center(
                child: Column(
                  children: [
                    EnhancedCharacterAvatar(
                      character: previewCharacter,
                      emotionState: _currentEmotion,
                      size: 150,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Live Preview',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildBasicInfoSection(),
              const SizedBox(height: 20),

              _buildAppearanceSection(),
              const SizedBox(height: 20),

              _buildEmotionSection(),
              const SizedBox(height: 20),

              _buildInterestsSection(),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _updateCharacter,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isLoading ? 'Saving...' : 'Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          onChanged: (_) => setState(() {}), // Refresh avatar preview
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _gender,
                decoration: InputDecoration(
                  labelText: 'Gender *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: const [
                  DropdownMenuItem(value: 'Girl', child: Text('Girl')),
                  DropdownMenuItem(value: 'Boy', child: Text('Boy')),
                ],
                onChanged: (v) => setState(() => _gender = v ?? 'Girl'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppearanceSection() {
    return _buildSectionCard(
      'Appearance',
      Icons.face,
      [
        // Skin Tone
        DropdownButtonFormField<String>(
          value: _skinTone,
          decoration: InputDecoration(
            labelText: 'Skin Tone *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon: const Icon(Icons.palette),
          ),
          items: const [
            DropdownMenuItem(value: 'Very Fair', child: Text('Very Fair')),
            DropdownMenuItem(value: 'Fair', child: Text('Fair')),
            DropdownMenuItem(value: 'Light', child: Text('Light')),
            DropdownMenuItem(value: 'Light-Medium', child: Text('Light-Medium')),
            DropdownMenuItem(value: 'Medium', child: Text('Medium')),
            DropdownMenuItem(value: 'Medium-Tan', child: Text('Medium-Tan')),
            DropdownMenuItem(value: 'Tan', child: Text('Tan')),
            DropdownMenuItem(value: 'Brown', child: Text('Brown')),
            DropdownMenuItem(value: 'Dark Brown', child: Text('Dark Brown')),
            DropdownMenuItem(value: 'Very Dark', child: Text('Very Dark')),
          ],
          onChanged: (v) => setState(() => _skinTone = v ?? 'Medium'),
        ),
        const SizedBox(height: 12),

        // Hair Color and Hairstyle
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _hairColor,
                decoration: InputDecoration(
                  labelText: 'Hair Color *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: const [
                  DropdownMenuItem(value: 'Black', child: Text('Black')),
                  DropdownMenuItem(value: 'Brown', child: Text('Brown')),
                  DropdownMenuItem(value: 'Blonde', child: Text('Blonde')),
                  DropdownMenuItem(value: 'Red', child: Text('Red')),
                  DropdownMenuItem(value: 'Auburn', child: Text('Auburn')),
                  DropdownMenuItem(value: 'Gray', child: Text('Gray')),
                  DropdownMenuItem(value: 'White', child: Text('White')),
                ],
                onChanged: (v) => setState(() => _hairColor = v ?? 'Brown'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _hairstyle,
                decoration: InputDecoration(
                  labelText: 'Hairstyle *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: const [
                  DropdownMenuItem(value: 'Straight', child: Text('Straight')),
                  DropdownMenuItem(value: 'Wavy', child: Text('Wavy')),
                  DropdownMenuItem(value: 'Curly', child: Text('Curly')),
                  DropdownMenuItem(value: 'Braids', child: Text('Braids')),
                  DropdownMenuItem(value: 'Ponytail', child: Text('Ponytail')),
                  DropdownMenuItem(value: 'Pigtails', child: Text('Pigtails')),
                  DropdownMenuItem(value: 'Bun', child: Text('Bun')),
                  DropdownMenuItem(value: 'Short', child: Text('Short')),
                  DropdownMenuItem(value: 'Long', child: Text('Long')),
                  DropdownMenuItem(value: 'Afro', child: Text('Afro')),
                ],
                onChanged: (v) => setState(() => _hairstyle = v ?? 'Straight'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Eye Color
        DropdownButtonFormField<String>(
          value: _eyeColor,
          decoration: InputDecoration(
            labelText: 'Eye Color *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon: const Icon(Icons.remove_red_eye),
          ),
          items: const [
            DropdownMenuItem(value: 'Brown', child: Text('Brown')),
            DropdownMenuItem(value: 'Blue', child: Text('Blue')),
            DropdownMenuItem(value: 'Green', child: Text('Green')),
            DropdownMenuItem(value: 'Hazel', child: Text('Hazel')),
            DropdownMenuItem(value: 'Gray', child: Text('Gray')),
            DropdownMenuItem(value: 'Amber', child: Text('Amber')),
          ],
          onChanged: (v) => setState(() => _eyeColor = v ?? 'Brown'),
        ),
      ],
    );
  }

  Widget _buildEmotionSection() {
    return _buildSectionCard(
      'How Are You Feeling?',
      Icons.mood,
      [
        const Text(
          'Use the feelings wheel to express how you\'re feeling right now',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),

        EmotionPickerWidget(
          initialEmotion: _currentEmotion,
          onEmotionSelected: (emotion) {
            setState(() {
              _currentEmotion = emotion;
            });
          },
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
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config/environment.dart';

class CharacterCreationScreen extends StatefulWidget {
  const CharacterCreationScreen({super.key});

  @override
  State<CharacterCreationScreen> createState() => _CharacterCreationScreenState();
}

class _CharacterCreationScreenState extends State<CharacterCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers for each form field
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _roleController = TextEditingController();
  final _magicTypeController = TextEditingController();
  final _challengeController = TextEditingController();
  final _likesController = TextEditingController();
  final _dislikesController = TextEditingController();
  final _fearsController = TextEditingController();
  final _comfortItemController = TextEditingController();

  // Character style and type
  String _characterStyle = 'Regular Kid'; // default
  String _isA = 'Girl'; // default (for story pronouns)

  // Helper to split comma lists safely
  List<String> _splitCSV(String text) {
    if (text.trim().isEmpty) return <String>[];
    return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> _createCharacter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final url = Uri.parse('${Environment.backendUrl}/create-character');

    try {
      final body = {
        'name': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'role': _roleController.text.trim().isEmpty ? 'Hero' : _roleController.text.trim(),
        'gender': _isA, // Send Boy/Girl for story pronouns
        'character_style': _characterStyle, // Character appearance/personality
        'magic_type': _magicTypeController.text.trim().isEmpty ? null : _magicTypeController.text.trim(),
        'challenge': _challengeController.text.trim().isEmpty ? null : _challengeController.text.trim(),
        'likes': _splitCSV(_likesController.text),
        'dislikes': _splitCSV(_dislikesController.text),
        'fears': _splitCSV(_fearsController.text),
        'comfort_item': _comfortItemController.text.trim().isEmpty ? null : _comfortItemController.text.trim(),
        'traits': <String>[], // keep as before
      };

      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode(body),
      );

      if (!mounted) return;

      if (resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_nameController.text.trim()} was created successfully!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true); // return true so caller can refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create character. Server error: ${resp.statusCode}'), backgroundColor: Colors.red),
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

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _roleController.dispose();
    _magicTypeController.dispose();
    _challengeController.dispose();
    _likesController.dispose();
    _dislikesController.dispose();
    _fearsController.dispose();
    _comfortItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gap = const SizedBox(height: 12);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a New Character'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextField(controller: _nameController, label: 'Name'),
                gap,
                _buildTextField(controller: _ageController, label: 'Age', keyboardType: TextInputType.number),
                gap,
                // Character Style dropdown
                DropdownButtonFormField<String>(
                  value: _characterStyle,
                  decoration: const InputDecoration(
                    labelText: 'Character Style',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Regular Kid', child: Text('Regular Kid')),
                    DropdownMenuItem(value: 'Girly Girl', child: Text('Girly Girl')),
                    DropdownMenuItem(value: 'Tomboy', child: Text('Tomboy')),
                    DropdownMenuItem(value: 'Sporty Kid', child: Text('Sporty Kid')),
                    DropdownMenuItem(value: 'Couch Potato', child: Text('Couch Potato')),
                    DropdownMenuItem(value: 'Creative Artist', child: Text('Creative Artist')),
                    DropdownMenuItem(value: 'Young Scientist', child: Text('Young Scientist')),
                    DropdownMenuItem(value: 'Playful Puppy', child: Text('Playful Puppy')),
                    DropdownMenuItem(value: 'Curious Cat', child: Text('Curious Cat')),
                    DropdownMenuItem(value: 'Brave Bird', child: Text('Brave Bird')),
                    DropdownMenuItem(value: 'Gentle Bunny', child: Text('Gentle Bunny')),
                    DropdownMenuItem(value: 'Wise Fox', child: Text('Wise Fox')),
                    DropdownMenuItem(value: 'Magical Dragon', child: Text('Magical Dragon')),
                  ],
                  onChanged: (v) => setState(() => _characterStyle = v ?? 'Regular Kid'),
                ),
                gap,
                // Is a: dropdown (for story language)
                DropdownButtonFormField<String>(
                  value: _isA,
                  decoration: const InputDecoration(
                    labelText: 'Is a:',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Girl', child: Text('Girl')),
                    DropdownMenuItem(value: 'Boy', child: Text('Boy')),
                  ],
                  onChanged: (v) => setState(() => _isA = v ?? 'Girl'),
                ),
                gap,
                _buildTextField(controller: _roleController, label: 'Role (e.g., Prince, Explorer)'),
                gap,
                _buildTextField(controller: _magicTypeController, label: 'Magic Type (e.g., Nature, Stars)'),
                gap,
                _buildTextField(controller: _challengeController, label: 'Challenge (e.g., Being shy)'),
                gap,
                _buildTextField(controller: _likesController, label: 'Likes (comma-separated)'),
                gap,
                _buildTextField(controller: _dislikesController, label: 'Dislikes (comma-separated)'),
                gap,
                _buildTextField(controller: _fearsController, label: 'Fears (comma-separated)'),
                gap,
                _buildTextField(controller: _comfortItemController, label: 'Comfort Item (e.g., a special blanket)'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createCharacter,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create Character'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a value for $label';
        }
        if (label == 'Age' && int.tryParse(value.trim()) == null) {
          return 'Please enter a valid number for age';
        }
        return null;
      },
    );
  }
}


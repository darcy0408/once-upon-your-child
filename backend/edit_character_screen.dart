import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class EditCharacterScreen extends StatefulWidget {
  final Character character;
  const EditCharacterScreen({super.key, required this.character});

  @override
  State<EditCharacterScreen> createState() => _EditCharacterScreenState();
}

class _EditCharacterScreenState extends State<EditCharacterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late final TextEditingController _name = TextEditingController(text: widget.character.name);
  late final TextEditingController _age = TextEditingController(text: widget.character.age.toString());
  late final TextEditingController _role = TextEditingController(text: widget.character.role);
  late String _gender = widget.character.gender ?? '';

  late final TextEditingController _magic = TextEditingController(text: widget.character.magicType ?? '');
  late final TextEditingController _challenge = TextEditingController(text: widget.character.challenge ?? '');
  late final TextEditingController _likes = TextEditingController(text: (widget.character.likes ?? []).join(', '));
  late final TextEditingController _dislikes = TextEditingController(text: (widget.character.dislikes ?? []).join(', '));
  late final TextEditingController _fears = TextEditingController(text: (widget.character.fears ?? []).join(', '));
  late final TextEditingController _comfort = TextEditingController(text: widget.character.comfortItem ?? '');

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _role.dispose();
    _magic.dispose();
    _challenge.dispose();
    _likes.dispose();
    _dislikes.dispose();
    _fears.dispose();
    _comfort.dispose();
    super.dispose();
  }

  List<String> _csvToList(String s) =>
      s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final url = Uri.parse('http://127.0.0.1:5000/characters/${widget.character.id}');

    final body = {
      'name': _name.text.trim(),
      'age': int.tryParse(_age.text.trim()) ?? widget.character.age,
      'gender': _gender.isEmpty ? null : _gender,
      'role': _role.text.trim(),
      'magic_type': _magic.text.trim(),
      'challenge': _challenge.text.trim(),
      'likes': _csvToList(_likes.text),
      'dislikes': _csvToList(_dislikes.text),
      'fears': _csvToList(_fears.text),
      'comfort_item': _comfort.text.trim(),
    };

    try {
      final resp = await http.patch(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(body),
      );
      if (!mounted) return;

      if (resp.statusCode == 200) {
        // success → return to previous screen and signal refresh
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed (${resp.statusCode})')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final genders = const ['', 'Girl', 'Boy', 'Non-binary', 'Other'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Character'),
        backgroundColor: Colors.deepPurple,
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _field('Name', _name, validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                _field('Age', _age, keyboardType: TextInputType.number, validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  return int.tryParse(v) == null ? 'Enter a number' : null;
                }),
                _field('Role', _role, hint: 'Princess, Explorer, Knight...'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  items: genders.map((g) => DropdownMenuItem(value: g, child: Text(g.isEmpty ? 'Unspecified' : g))).toList(),
                  onChanged: (v) => setState(() => _gender = v ?? ''),
                ),
                const SizedBox(height: 12),
                _field('Magic Type', _magic, hint: 'Nature, Stars, Time...'),
                _field('Challenge', _challenge, hint: 'Being shy, fear of dark...'),
                _field('Likes (comma separated)', _likes),
                _field('Dislikes (comma separated)', _dislikes),
                _field('Fears (comma separated)', _fears),
                _field('Comfort Item', _comfort),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                    label: const Text('Save Changes'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {String? hint, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: c,
        keyboardType: keyboardType ?? TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
        ),
        validator: validator,
      ),
    );
  }
}

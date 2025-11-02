// lib/character_creation_screen_v3.dart
// Refactored character builder with green theme, emotion picker, and better UX

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'emotion_models.dart';
import 'emotion_picker_widget.dart';
import 'avatar_preset_selector.dart';
import 'character_customization_constants.dart';
import 'emotion_avatar_widget.dart';

class CharacterCreationScreenV3 extends StatefulWidget {
  const CharacterCreationScreenV3({super.key});

  @override
  State<CharacterCreationScreenV3> createState() => _CharacterCreationScreenV3State();
}

class _CharacterCreationScreenV3State extends State<CharacterCreationScreenV3> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  // Appearance
  String _skinTone = 'mediumWarm';
  String _hairStyle = 'Long Straight';
  String _hairColor = 'darkBrown';
  String _clothingStyle = 'Casual';
  String _clothingColor = 'royalBlue';

  // Gender (for story pronouns only)
  String _isA = 'Girl';

  // Emotion
  EmotionState? _emotionState;

  // Selected preset
  AvatarPreset? _selectedPreset;

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _applyPreset(AvatarPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _skinTone = preset.skinTone;
      _hairStyle = preset.hairStyle;
      _hairColor = preset.hairColor.toLowerCase().replaceAll(' ', '');
    });
  }

  Future<void> _createCharacter() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_emotionState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select how you\'re feeling'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/create-character'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'age': int.parse(_ageController.text.trim()),
          'gender': _isA,
          'hair': _hairColor,
          'eyes': 'Brown', // Could be expanded
          // Store emotion for therapeutic storytelling
          'emotion_core': _emotionState!.core.name,
          'emotion_specific': _emotionState!.specific,
          'emotion_face_key': _emotionState!.faceKey,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_nameController.text} created successfully!'),
            backgroundColor: CharacterCustomization.accentGreen,
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception('Failed to create character');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CharacterCustomization.primaryBackground,
      appBar: AppBar(
        title: const Text(
          'Create Your Character',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2d5a3d),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Main scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Live Avatar Preview
                    Center(
                      child: Column(
                        children: [
                          EmotionAvatarLarge(
                            emotionState: _emotionState,
                            characterName: _nameController.text.isEmpty
                                ? 'Your Character'
                                : _nameController.text,
                          ),
                          const SizedBox(height: 8),
                          if (_emotionState != null)
                            Text(
                              'Feeling: ${_emotionState!.specific}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF7fd3a8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Avatar Preset Selector
                    AvatarPresetSelector(
                      selectedPreset: _selectedPreset,
                      onPresetSelected: _applyPreset,
                    ),
                    const SizedBox(height: 24),

                    // Basic Info Section
                    _buildSection(
                      title: 'Basic Info',
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'Name',
                          hint: 'e.g., Alex, Sam, Riley',
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _ageController,
                          label: 'Age',
                          hint: 'Enter age',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        _buildDropdown(
                          label: 'Is a:',
                          value: _isA,
                          items: ['Girl', 'Boy'],
                          onChanged: (v) => setState(() => _isA = v!),
                          hint: 'For story pronouns',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Appearance Section
                    _buildSection(
                      title: 'Appearance',
                      children: [
                        _buildSkinTonePicker(),
                        const SizedBox(height: 20),
                        _buildDropdown(
                          label: 'Hair Style',
                          value: _hairStyle,
                          items: CharacterCustomization.hairStyles,
                          onChanged: (v) => setState(() => _hairStyle = v!),
                        ),
                        const SizedBox(height: 16),
                        _buildHairColorPicker(),
                        const SizedBox(height: 20),
                        _buildDropdown(
                          label: 'Clothing Style',
                          value: _clothingStyle,
                          items: CharacterCustomization.clothingStyles,
                          onChanged: (v) => setState(() => _clothingStyle = v!),
                        ),
                        const SizedBox(height: 16),
                        _buildClothingColorPicker(),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Emotion Picker Section
                    EmotionPickerWidget(
                      initialEmotion: _emotionState,
                      onEmotionSelected: (emotion) {
                        setState(() => _emotionState = emotion);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CharacterCustomization.secondaryBackground,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createCharacter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CharacterCustomization.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Create Character'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CharacterCustomization.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CharacterCustomization.borderGreen,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: CharacterCustomization.lightGreen,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: CharacterCustomization.softGreen),
        hintStyle: TextStyle(color: CharacterCustomization.softGreen.withOpacity(0.5)),
        filled: true,
        fillColor: CharacterCustomization.primaryBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CharacterCustomization.borderGreen),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CharacterCustomization.borderGreen),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: CharacterCustomization.accentGreen,
            width: 2,
          ),
        ),
      ),
      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: CharacterCustomization.lightGreen,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(
              fontSize: 12,
              color: CharacterCustomization.softGreen,
            ),
          ),
        ],
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: CharacterCustomization.secondaryBackground,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: CharacterCustomization.primaryBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CharacterCustomization.borderGreen),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CharacterCustomization.borderGreen),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: CharacterCustomization.accentGreen,
                width: 2,
              ),
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSkinTonePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Skin Tone',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: CharacterCustomization.lightGreen,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: CharacterCustomization.skinTones.entries.map((entry) {
            final isSelected = _skinTone == entry.key;
            return GestureDetector(
              onTap: () => setState(() => _skinTone = entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: entry.value.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? CharacterCustomization.accentGreen
                        : CharacterCustomization.borderGreen,
                    width: isSelected ? 4 : 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: CharacterCustomization.accentGreen.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHairColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hair Color',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: CharacterCustomization.lightGreen,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: CharacterCustomization.hairColors.entries.map((entry) {
            final isSelected = _hairColor == entry.key;
            return GestureDetector(
              onTap: () => setState(() => _hairColor = entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: entry.value.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? CharacterCustomization.accentGreen
                        : CharacterCustomization.borderGreen,
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: CharacterCustomization.accentGreen.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildClothingColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Clothing Color',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: CharacterCustomization.lightGreen,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: CharacterCustomization.clothingColors.entries.map((entry) {
            final isSelected = _clothingColor == entry.key;
            return GestureDetector(
              onTap: () => setState(() => _clothingColor = entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: entry.value.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? CharacterCustomization.accentGreen
                        : CharacterCustomization.borderGreen,
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: CharacterCustomization.accentGreen.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

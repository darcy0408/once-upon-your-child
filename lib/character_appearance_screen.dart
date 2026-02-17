// lib/character_appearance_screen.dart

import 'package:flutter/material.dart';
import 'character_appearance.dart';

class CharacterAppearanceScreen extends StatefulWidget {
  final String characterName;
  final CharacterAppearance? existingAppearance;

  const CharacterAppearanceScreen({
    super.key,
    required this.characterName,
    this.existingAppearance,
  });

  @override
  State<CharacterAppearanceScreen> createState() => _CharacterAppearanceScreenState();
}

class _CharacterAppearanceScreenState extends State<CharacterAppearanceScreen> {
  late HairColor _hairColor;
  late HairLength _hairLength;
  late HairStyle _hairStyle;
  late EyeColor _eyeColor;
  late SkinTone _skinTone;
  late ClothingStyle _clothingStyle;
  late ClothingColors _clothingColors;
  late BodyBuild _bodyBuild;

  @override
  void initState() {
    super.initState();

    // Initialize with existing appearance or defaults
    if (widget.existingAppearance != null) {
      _hairColor = widget.existingAppearance!.hairColor;
      _hairLength = widget.existingAppearance!.hairLength;
      _hairStyle = widget.existingAppearance!.hairStyle;
      _eyeColor = widget.existingAppearance!.eyeColor;
      _skinTone = widget.existingAppearance!.skinTone;
      _clothingStyle = widget.existingAppearance!.clothingStyle;
      _clothingColors = widget.existingAppearance!.clothingColors;
      _bodyBuild = widget.existingAppearance!.bodyBuild;
    } else {
      // Defaults
      _hairColor = HairColor.brown;
      _hairLength = HairLength.medium;
      _hairStyle = HairStyle.straight;
      _eyeColor = EyeColor.brown;
      _skinTone = SkinTone.medium;
      _clothingStyle = ClothingStyle.casual;
      _clothingColors = ClothingColors.bright;
      _bodyBuild = BodyBuild.average;
    }
  }

  void _saveAppearance() {
    final appearance = CharacterAppearance(
      characterName: widget.characterName,
      hairColor: _hairColor,
      hairLength: _hairLength,
      hairStyle: _hairStyle,
      eyeColor: _eyeColor,
      skinTone: _skinTone,
      clothingStyle: _clothingStyle,
      clothingColors: _clothingColors,
      bodyBuild: _bodyBuild,
    );

    Navigator.pop(context, appearance);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.characterName}\'s Appearance'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _saveAppearance,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview card
            _buildPreviewCard(),
            const SizedBox(height: 24),

            // Skin Tone
            _buildSection(
              title: 'Skin Tone',
              icon: Icons.face,
              child: _buildSkinToneSelector(),
            ),
            const SizedBox(height: 20),

            // Hair Color
            _buildSection(
              title: 'Hair Color',
              icon: Icons.color_lens,
              child: _buildHairColorSelector(),
            ),
            const SizedBox(height: 20),

            // Hair Length
            _buildSection(
              title: 'Hair Length',
              icon: Icons.straighten,
              child: _buildDropdown<HairLength>(
                value: _hairLength,
                items: HairLength.values,
                onChanged: (value) => setState(() => _hairLength = value!),
                getDisplayName: (value) => value.displayName,
              ),
            ),
            const SizedBox(height: 20),

            // Hair Style
            _buildSection(
              title: 'Hair Style',
              icon: Icons.style,
              child: _buildDropdown<HairStyle>(
                value: _hairStyle,
                items: HairStyle.values,
                onChanged: (value) => setState(() => _hairStyle = value!),
                getDisplayName: (value) => value.displayName,
              ),
            ),
            const SizedBox(height: 20),

            // Eye Color
            _buildSection(
              title: 'Eye Color',
              icon: Icons.remove_red_eye,
              child: _buildDropdown<EyeColor>(
                value: _eyeColor,
                items: EyeColor.values,
                onChanged: (value) => setState(() => _eyeColor = value!),
                getDisplayName: (value) => value.displayName,
              ),
            ),
            const SizedBox(height: 20),

            // Clothing Style
            _buildSection(
              title: 'Clothing Style',
              icon: Icons.checkroom,
              child: _buildClothingStyleSelector(),
            ),
            const SizedBox(height: 20),

            // Clothing Colors
            _buildSection(
              title: 'Clothing Colors',
              icon: Icons.palette,
              child: _buildDropdown<ClothingColors>(
                value: _clothingColors,
                items: ClothingColors.values,
                onChanged: (value) => setState(() => _clothingColors = value!),
                getDisplayName: (value) => value.displayName,
              ),
            ),
            const SizedBox(height: 20),

            // Body Build
            _buildSection(
              title: 'Body Build',
              icon: Icons.accessibility,
              child: _buildDropdown<BodyBuild>(
                value: _bodyBuild,
                items: BodyBuild.values,
                onChanged: (value) => setState(() => _bodyBuild = value!),
                getDisplayName: (value) => value.displayName,
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            Center(
              child: ElevatedButton.icon(
                onPressed: _saveAppearance,
                icon: const Icon(Icons.save, size: 28),
                label: const Text('Save Appearance', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _skinTone.emoji,
                  style: const TextStyle(fontSize: 40),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.characterName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            _buildPreviewRow('Hair', '${_hairLength.displayName} ${_hairColor.displayName} (${_hairStyle.displayName})'),
            _buildPreviewRow('Eyes', _eyeColor.displayName),
            _buildPreviewRow('Skin', _skinTone.displayName),
            _buildPreviewRow('Outfit', '${_clothingStyle.displayName} in ${_clothingColors.displayName}'),
            _buildPreviewRow('Build', _bodyBuild.displayName),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.purple),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildSkinToneSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SkinTone.values.map((tone) {
        final isSelected = _skinTone == tone;
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tone.emoji),
              const SizedBox(width: 8),
              Text(tone.displayName),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() => _skinTone = tone);
            }
          },
          selectedColor: Colors.purple.shade200,
        );
      }).toList(),
    );
  }

  Widget _buildHairColorSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: HairColor.values.map((color) {
        final isSelected = _hairColor == color;
        return ChoiceChip(
          label: Text(color.displayName),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() => _hairColor = color);
            }
          },
          selectedColor: Colors.purple.shade200,
        );
      }).toList(),
    );
  }

  Widget _buildClothingStyleSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ClothingStyle.values.map((style) {
        final isSelected = _clothingStyle == style;
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(style.icon),
              const SizedBox(width: 8),
              Text(style.displayName),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() => _clothingStyle = style);
            }
          },
          selectedColor: Colors.purple.shade200,
        );
      }).toList(),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
    required String Function(T) getDisplayName,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(getDisplayName(item)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

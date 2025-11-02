// lib/avatar_builder_screen.dart
// Avatar Builder Screen matching React web app features
// Therapeutic design with Sunset Jungle theme

import 'package:flutter/material.dart';
import 'sunset_jungle_theme.dart';
import 'avatar_models.dart';
import 'customizable_avatar_widget.dart';

class AvatarBuilderScreen extends StatefulWidget {
  final EnhancedCharacter? initialCharacter;
  final bool isEdit;

  const AvatarBuilderScreen({
    super.key,
    this.initialCharacter,
    this.isEdit = false,
  });

  @override
  State<AvatarBuilderScreen> createState() => _AvatarBuilderScreenState();
}

class _AvatarBuilderScreenState extends State<AvatarBuilderScreen> {
  late TextEditingController _nameController;
  late CharacterAvatar _currentAvatar;

  // Customization options matching React app with additional white/fair tones
  final List<SkinToneOption> _skinTones = [
    SkinToneOption('PorcelainWhite', Color(0xFFFFF5E6)),
    SkinToneOption('VeryPale', Color(0xFFFFE8D1)),
    SkinToneOption('Light', Color(0xFFFFDFC4)),
    SkinToneOption('Pale', Color(0xFFF0C8A0)),
    SkinToneOption('Beige', Color(0xFFEECBA8)),
    SkinToneOption('Tanned', Color(0xFFE0AC7E)),
    SkinToneOption('Yellow', Color(0xFFD49A6A)),
    SkinToneOption('Brown', Color(0xFFC68642)),
    SkinToneOption('DarkBrown', Color(0xFFA67C52)),
    SkinToneOption('Black', Color(0xFF8D5524)),
    SkinToneOption('DeepBrown', Color(0xFF6D4C41)),
    SkinToneOption('VeryDark', Color(0xFF4A2C12)),
  ];

  final List<HairStyleOption> _hairStyles = [
    HairStyleOption('ShortHairShortFlat', 'Short Straight'),
    HairStyleOption('ShortHairShortCurly', 'Short Curly'),
    HairStyleOption('ShortHairShortWaved', 'Short Wavy'),
    HairStyleOption('LongHairStraight', 'Long Straight'),
    HairStyleOption('LongHairCurly', 'Long Curly'),
    HairStyleOption('LongHairBigHair', 'Big Hair'),
    HairStyleOption('LongHairBun', 'Bun'),
    HairStyleOption('LongHairBraids', 'Braids'),
    HairStyleOption('LongHairPonytail', 'Ponytail'),
  ];

  final List<HairColorOption> _hairColors = [
    HairColorOption('Blonde', Color(0xFFF4D03F)),
    HairColorOption('Brown', Color(0xFF8B4513)),
    HairColorOption('Black', Color(0xFF2C3E50)),
    HairColorOption('Red', Color(0xFFC0392B)),
    HairColorOption('Auburn', Color(0xFFA04000)),
    HairColorOption('PastelPink', Color(0xFFFF6B9D)),
    HairColorOption('BlondeGolden', Color(0xFFFFD700)),
    HairColorOption('SilverGray', Color(0xFFBDC3C7)),
    HairColorOption('Platinum', Color(0xFFE8E8E8)),
  ];

  final Map<String, List<ClothingOption>> _clothingCategories = {
    'Casual 👕': [
      ClothingOption('Hoodie', 'Hoodie'),
      ClothingOption('ShirtCrewNeck', 'Crew Neck'),
      ClothingOption('ShirtScoopNeck', 'Scoop Neck'),
    ],
    'Sporty ⚽': [
      ClothingOption('CollarSweater', 'Sweater'),
      ClothingOption('Overall', 'Overall'),
    ],
    'Dress 👗': [
      ClothingOption('BlazerShirt', 'Blazer Shirt'),
      ClothingOption('BlazerSweater', 'Blazer Sweater'),
    ],
    'Fancy ✨': [
      ClothingOption('GraphicShirt', 'Graphic Shirt'),
    ],
  };

  String _selectedClothingCategory = 'Casual 👕';

  final List<ClothingColorOption> _clothingColors = [
    ClothingColorOption('White', Color(0xFFFFFFFF)),
    ClothingColorOption('Pink', Color(0xFFFF69B4)),
    ClothingColorOption('LightPink', Color(0xFFFFB6C1)),
    ClothingColorOption('Purple', Color(0xFF9B59B6)),
    ClothingColorOption('Lavender', Color(0xFFE6B3FF)),
    ClothingColorOption('Coral', Color(0xFFFF6B6B)),
    ClothingColorOption('Peach', Color(0xFFFFB88C)),
    ClothingColorOption('Blue03', Color(0xFF5DADE2)),
    ClothingColorOption('Red', Color(0xFFE74C3C)),
    ClothingColorOption('Gray01', Color(0xFF95A5A6)),
    ClothingColorOption('Black', Color(0xFF2C3E50)),
    ClothingColorOption('PastelGreen', Color(0xFF58D68D)),
    ClothingColorOption('PastelYellow', Color(0xFFF4D03F)),
    ClothingColorOption('Mint', Color(0xFF98D8C8)),
    ClothingColorOption('Turquoise', Color(0xFF40E0D0)),
    ClothingColorOption('Heather', Color(0xFF3498DB)),
  ];

  final List<ExpressionOption> _eyeExpressions = [
    ExpressionOption('Happy', 'Happy 😊'),
    ExpressionOption('Dizzy', 'Sad 😢'),
    ExpressionOption('Surprised', 'Surprised 😮'),
    ExpressionOption('Default', 'Calm 😌'),
    ExpressionOption('EyeRoll', 'Brave 💪'),
  ];

  final List<ExpressionOption> _mouthExpressions = [
    ExpressionOption('Smile', 'Smile 😊'),
    ExpressionOption('Concerned', 'Concerned 😟'),
    ExpressionOption('Default', 'Neutral 😐'),
    ExpressionOption('Twinkle', 'Excited 🤩'),
    ExpressionOption('Serious', 'Serious 😠'),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialCharacter?.name ?? '',
    );
    _currentAvatar = widget.initialCharacter?.avatar ??
        CharacterAvatar.defaultAvatar;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _updateAvatar(CharacterAvatar newAvatar) {
    setState(() {
      _currentAvatar = newAvatar;
    });
  }

  void _saveCharacter() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a character name!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final character = EnhancedCharacter(
      id: widget.initialCharacter?.id,
      name: name,
      avatar: _currentAvatar,
      timestamp: DateTime.now(),
    );

    Navigator.of(context).pop(character);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌿 '),
            Text(widget.isEdit ? 'Edit Character' : 'Create Character'),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: SunsetJungleTheme.headerGradient,
          ),
        ),
      ),
      backgroundColor: SunsetJungleTheme.creamLight,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar Preview Section
              _buildAvatarPreview(),
              const SizedBox(height: 16),

              // Customization Options
              _buildSkinToneSection(),
              const SizedBox(height: 12),
              _buildHairStyleSection(),
              const SizedBox(height: 12),
              _buildHairColorSection(),
              const SizedBox(height: 12),
              _buildClothingSection(),
              const SizedBox(height: 12),
              _buildClothingColorSection(),
              const SizedBox(height: 12),
              _buildEyeExpressionSection(),
              const SizedBox(height: 12),
              _buildMouthExpressionSection(),
              const SizedBox(height: 16),

              // Save Section
              _buildSaveSection(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPreview() {
    return Center(
      child: Column(
        children: [
          Text(
            'Your Avatar',
            style: SunsetJungleTheme.sectionTitleStyle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Container(
            width: 150,
            height: 150,
            decoration: SunsetJungleTheme.avatarCanvasDecoration,
            child: Center(
              child: CustomizableAvatarWidget(
                avatar: _currentAvatar,
                size: 135,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkinToneSection() {
    return _buildOptionGroup(
      title: 'Skin Tone',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _skinTones.map((tone) {
          final isSelected = _currentAvatar.skinColor == tone.value;
          return _buildColorSwatch(
            color: tone.color,
            isSelected: isSelected,
            onTap: () => _updateAvatar(
              _currentAvatar.copyWith(skinColor: tone.value),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHairStyleSection() {
    return _buildOptionGroup(
      title: 'Hair Style',
      child: DropdownButtonFormField<String>(
        value: _currentAvatar.hairStyle,
        decoration: SunsetJungleTheme.inputDecoration(),
        items: _hairStyles.map((style) {
          return DropdownMenuItem(
            value: style.value,
            child: Text(style.label),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            _updateAvatar(_currentAvatar.copyWith(hairStyle: value));
          }
        },
      ),
    );
  }

  Widget _buildHairColorSection() {
    return _buildOptionGroup(
      title: 'Hair Color',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _hairColors.map((color) {
          final isSelected = _currentAvatar.hairColor == color.value;
          return _buildColorSwatch(
            color: color.color,
            isSelected: isSelected,
            onTap: () => _updateAvatar(
              _currentAvatar.copyWith(hairColor: color.value),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildClothingSection() {
    final currentCategory = _clothingCategories[_selectedClothingCategory]!;

    return _buildOptionGroup(
      title: 'Clothing Style',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _clothingCategories.keys.map((category) {
              final isSelected = _selectedClothingCategory == category;
              return OutlinedButton(
                onPressed: () {
                  setState(() {
                    _selectedClothingCategory = category;
                  });
                },
                style: isSelected
                    ? ElevatedButton.styleFrom(
                        backgroundColor: SunsetJungleTheme.sunsetCoral,
                        foregroundColor: SunsetJungleTheme.creamLight,
                        side: BorderSide.none,
                      )
                    : SunsetJungleTheme.outlinedButtonStyle,
                child: Text(category),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Clothing dropdown
          DropdownButtonFormField<String>(
            value: _currentAvatar.clothingStyle,
            decoration: SunsetJungleTheme.inputDecoration(),
            items: currentCategory.map((item) {
              return DropdownMenuItem(
                value: item.value,
                child: Text(item.label),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _updateAvatar(_currentAvatar.copyWith(clothingStyle: value));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClothingColorSection() {
    return _buildOptionGroup(
      title: 'Clothing Color',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _clothingColors.map((color) {
          final isSelected = _currentAvatar.clothingColor == color.value;
          return _buildColorSwatch(
            color: color.color,
            isSelected: isSelected,
            onTap: () => _updateAvatar(
              _currentAvatar.copyWith(clothingColor: color.value),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEyeExpressionSection() {
    return _buildOptionGroup(
      title: 'Eyes Expression',
      child: DropdownButtonFormField<String>(
        value: _currentAvatar.eyeType,
        decoration: SunsetJungleTheme.inputDecoration(),
        items: _eyeExpressions.map((expr) {
          return DropdownMenuItem(
            value: expr.value,
            child: Text(expr.label),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            _updateAvatar(_currentAvatar.copyWith(eyeType: value));
          }
        },
      ),
    );
  }

  Widget _buildMouthExpressionSection() {
    return _buildOptionGroup(
      title: 'Mouth Expression',
      child: DropdownButtonFormField<String>(
        value: _currentAvatar.mouthType,
        decoration: SunsetJungleTheme.inputDecoration(),
        items: _mouthExpressions.map((expr) {
          return DropdownMenuItem(
            value: expr.value,
            child: Text(expr.label),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            _updateAvatar(_currentAvatar.copyWith(mouthType: value));
          }
        },
      ),
    );
  }

  Widget _buildSaveSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: SunsetJungleTheme.saveSectionDecoration,
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: SunsetJungleTheme.inputDecoration(
              hintText: 'Enter character name...',
              labelText: 'Character Name',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: SunsetJungleTheme.jungleForest,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveCharacter,
              style: SunsetJungleTheme.primaryButtonStyle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  widget.isEdit ? 'Update Character' : 'Save Character',
                  style: SunsetJungleTheme.buttonTextStyle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionGroup({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: SunsetJungleTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SunsetJungleTheme.sectionTitleStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildColorSwatch({
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? SunsetJungleTheme.sunsetCoral
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: SunsetJungleTheme.sunsetCoral.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(
                Icons.check,
                color: Colors.white,
                size: 18,
                shadows: [
                  Shadow(
                    color: Colors.black45,
                    blurRadius: 3,
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

// Helper classes for customization options
class SkinToneOption {
  final String value;
  final Color color;
  SkinToneOption(this.value, this.color);
}

class HairStyleOption {
  final String value;
  final String label;
  HairStyleOption(this.value, this.label);
}

class HairColorOption {
  final String value;
  final Color color;
  HairColorOption(this.value, this.color);
}

class ClothingOption {
  final String value;
  final String label;
  ClothingOption(this.value, this.label);
}

class ClothingColorOption {
  final String value;
  final Color color;
  ClothingColorOption(this.value, this.color);
}

class ExpressionOption {
  final String value;
  final String label;
  ExpressionOption(this.value, this.label);
}

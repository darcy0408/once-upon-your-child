import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/generated_avatar.dart';
import '../services/avatar_generation_service.dart';
import '../services/avatar_generation_state.dart';

/// Full-screen overlay for creating personalized avatars
class AvatarCreatorOverlay extends StatefulWidget {
  final String characterName;
  final int age;
  final VoidCallback onCancel;
  final Function(GeneratedAvatar) onAvatarCreated;
  final bool allowAsync; // Whether to allow background generation

  const AvatarCreatorOverlay({
    super.key,
    required this.characterName,
    required this.age,
    required this.onCancel,
    required this.onAvatarCreated,
    this.allowAsync = true, // Default to allowing async
  });

  @override
  State<AvatarCreatorOverlay> createState() => _AvatarCreatorOverlayState();
}

class _AvatarCreatorOverlayState extends State<AvatarCreatorOverlay> {
  final _avatarService = AvatarGenerationService();
  final TextEditingController _hairDetailsController = TextEditingController();

  // Selected features
  String _selectedStyle = 'pixar';
  String _selectedHairStyle = 'Long Curly';
  String _selectedHairColor = 'Brown';
  String _selectedSkinTone = 'Medium Tan';
  String _selectedOutfit = 'Explorer Jacket';

  // State
  bool _isGenerating = false;
  GeneratedAvatar? _generatedAvatar;
  int _rerollCount = 0;
  final int _maxRerolls = 3;
  String? _errorMessage;

  // Options
  final List<String> _styles = ['pixar', 'watercolor', 'cartoon', 'clay'];

  final List<String> _hairStyles = [
    'Long Curly',
    'Short Spiky',
    'Braided',
    'Bob Cut',
    'Ponytail',
    'Afro',
    'Straight Long',
    'Wavy Shoulder',
  ];

  final List<String> _hairColors = [
    'Black',
    'Brown',
    'Blonde',
    'Red',
    'Auburn',
    'Gray',
    'Blue',
    'Purple',
    'Pink',
    'Green',
  ];

  final List<String> _skinTones = [
    'Very Light',
    'Light',
    'Medium Light',
    'Medium Tan',
    'Tan',
    'Brown',
    'Dark Brown',
    'Very Dark',
  ];

  final List<String> _outfits = [
    'T-Shirt and Jeans',
    'Dress',
    'Superhero Cape',
    'Explorer Jacket',
    'Sports Jersey',
    'Hoodie',
    'School Uniform',
    'Princess Gown',
    'Wizard Robes',
    'Casual Outfit',
  ];

  @override
  void dispose() {
    _hairDetailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isGenerating
                      ? _buildGeneratingState()
                      : _generatedAvatar != null
                          ? _buildAvatarPreview()
                          : _buildFeatureSelection(),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFD93D), Color(0xFFFFA500)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: widget.onCancel,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Create Your Magic Avatar',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose your style:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildStyleSelector(),
          const SizedBox(height: 30),
          _buildDropdown('Hair Style', _selectedHairStyle, _hairStyles, (val) {
            setState(() => _selectedHairStyle = val!);
          }),
          const SizedBox(height: 12),
          _buildHairDetailsField(),
          const SizedBox(height: 20),
          _buildDropdown('Hair Color', _selectedHairColor, _hairColors, (val) {
            setState(() => _selectedHairColor = val!);
          }),
          const SizedBox(height: 20),
          _buildDropdown('Skin Tone', _selectedSkinTone, _skinTones, (val) {
            setState(() => _selectedSkinTone = val!);
          }),
          const SizedBox(height: 20),
          _buildDropdown('Outfit', _selectedOutfit, _outfits, (val) {
            setState(() => _selectedOutfit = val!);
          }),
          const SizedBox(height: 30),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStyleSelector() {
    return Wrap(
      spacing: 10,
      children: _styles.map((style) {
        final isSelected = style == _selectedStyle;
        return ChoiceChip(
          label: Text(style.toUpperCase()),
          selected: isSelected,
          onSelected: (selected) {
            setState(() => _selectedStyle = style);
          },
          selectedColor: const Color(0xFFFFD93D),
          backgroundColor: Colors.white,
        );
      }).toList(),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHairDetailsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hair details (optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          'If none of the styles fit, describe the hair here.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _hairDetailsController,
          maxLines: 2,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: 'Example: short twists with a side part',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade500),
            ),
          ),
        ),
      ],
    );
  }

  Map<String, String> _buildFeatures() {
    final features = <String, String>{
      'hair_style': _selectedHairStyle,
      'hair_color': _selectedHairColor,
      'skin_tone': _selectedSkinTone,
      'outfit': _selectedOutfit,
      'expression': 'Happy',
    };
    final hairDetails = _hairDetailsController.text.trim();
    if (hairDetails.isNotEmpty) {
      features['hair_details'] = hairDetails;
    }
    return features;
  }

  Widget _buildGeneratingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD93D)),
          ),
          const SizedBox(height: 30),
          const Text(
            'Creating your magic portrait...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          const Text(
            'This may take 1-2 minutes',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 5),
          const Text(
            'The AI is painting every detail!',
            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              base64Decode(_generatedAvatar!.imageBase64.split(',').last),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 30),
        if (_rerollCount < _maxRerolls)
          OutlinedButton.icon(
            onPressed: _rerollAvatar,
            icon: const Icon(Icons.refresh),
            label: Text('Try Another (${_maxRerolls - _rerollCount} left)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
      ],
    );
  }

  Widget _buildFooter() {
    if (_generatedAvatar != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => widget.onAvatarCreated(_generatedAvatar!),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'That looks like me!',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Async generation button (recommended)
          if (widget.allowAsync)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateAvatarAsync,
                icon: const Icon(Icons.rocket_launch, color: Colors.white),
                label: const Text(
                  'Generate in Background',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (widget.allowAsync) const SizedBox(height: 12),
          if (widget.allowAsync)
            const Text(
              'Continue with your story while your avatar generates!',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          if (widget.allowAsync) const SizedBox(height: 12),
          // Sync generation button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isGenerating ? null : _generateAvatar,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Color(0xFFFFD93D), width: 2),
              ),
              child: Text(
                widget.allowAsync ? 'Wait Here Instead' : 'Generate My Avatar',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Start avatar generation in background and close dialog
  Future<void> _generateAvatarAsync() async {
    debugPrint('🚀 Starting ASYNC avatar generation...');
    final features = _buildFeatures();

    // Save callback reference before closing dialog
    final onAvatarCreated = widget.onAvatarCreated;

    // Mark as generating in global state
    AvatarGenerationState().startGeneration();

    // Close the dialog immediately
    widget.onCancel();

    // Start generation in background (don't await)
    _avatarService.generateAvatar(
      characterName: widget.characterName,
      age: widget.age,
      style: _selectedStyle,
      features: features,
    ).then((avatar) {
      // Success - update state and notify
      AvatarGenerationState().completeGeneration(avatar);
      // Use saved callback reference (safe after widget disposal)
      onAvatarCreated(avatar);
    }).catchError((error) {
      // Failure - update state with error
      AvatarGenerationState().failGeneration(error.toString());
    });
  }

  /// Generate avatar synchronously (wait for result)
  Future<void> _generateAvatar() async {
    debugPrint('🎨 Starting SYNC avatar generation...');
    debugPrint('   Character: ${widget.characterName}, Age: ${widget.age}');
    debugPrint('   Style: $_selectedStyle');
    debugPrint('   Hair: $_selectedHairStyle ($_selectedHairColor)');
    debugPrint('   Skin: $_selectedSkinTone, Outfit: $_selectedOutfit');

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final avatar = await _avatarService.generateAvatar(
        characterName: widget.characterName,
        age: widget.age,
        style: _selectedStyle,
        features: _buildFeatures(),
      );

      debugPrint('✅ Avatar generated successfully!');

      if (mounted) {
        setState(() {
          _generatedAvatar = avatar;
          _isGenerating = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Avatar generation error: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage = 'Oops! Our magic paintbrush needs a moment. Try again!\n\nError: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}';
        });
      }
    }
  }

  Future<void> _rerollAvatar() async {
    if (_rerollCount >= _maxRerolls) return;

    debugPrint('🔄 Re-rolling avatar (attempt ${_rerollCount + 1}/$_maxRerolls)');

    setState(() {
      _isGenerating = true;
      _rerollCount++;
    });

    try {
      final avatar = await _avatarService.regenerateAvatar(
        characterName: widget.characterName,
        age: widget.age,
        style: _selectedStyle,
        features: _buildFeatures(),
      );

      debugPrint('✅ Avatar re-rolled successfully!');

      if (mounted) {
        setState(() {
          _generatedAvatar = avatar;
          _isGenerating = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Avatar re-roll error: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage = 'Oops! The re-roll magic fizzled. Try again!\n\nError: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}';
        });
      }
    }
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/avatar_service.dart';

/// Avatar Picker Screen - Visual customization interface for avataaars
///
/// Allows kids to customize their avatar by selecting:
/// - Skin tone
/// - Hair style & color
/// - Eyes, eyebrows, mouth
/// - Clothing & color
/// - Accessories (glasses, etc.)
class AvatarPickerScreen extends StatefulWidget {
  final int characterAge;
  final Map<String, String>? initialSelection;
  final AvatarService avatarService;

  const AvatarPickerScreen({
    super.key,
    required this.characterAge,
    required this.avatarService,
    this.initialSelection,
  });

  @override
  State<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends State<AvatarPickerScreen> {
  late Map<String, String> _selections;
  String? _previewSvg;
  bool _isLoadingPreview = false;

  // Avataaars options (will eventually come from allowlists.json)
  final Map<String, List<Map<String, String>>> _avatarOptions = {
    'skinColor': [
      {'value': 'tanned', 'label': 'Tan'},
      {'value': 'yellow', 'label': 'Light'},
      {'value': 'pale', 'label': 'Pale'},
      {'value': 'light', 'label': 'Fair'},
      {'value': 'brown', 'label': 'Brown'},
      {'value': 'darkBrown', 'label': 'Dark Brown'},
      {'value': 'black', 'label': 'Dark'},
    ],
    'top': [
      {'value': 'noHair', 'label': 'No Hair'},
      {'value': 'shortCurly', 'label': 'Short Curly'},
      {'value': 'shortFlat', 'label': 'Short Flat'},
      {'value': 'shortRound', 'label': 'Short Round'},
      {'value': 'shortWaved', 'label': 'Short Wavy'},
      {'value': 'sides', 'label': 'Sides'},
      {'value': 'theCaesar', 'label': 'Caesar'},
      {'value': 'longButNotTooLong', 'label': 'Shoulder Length'},
      {'value': 'bob', 'label': 'Bob Cut'},
      {'value': 'bun', 'label': 'Bun'},
      {'value': 'curly', 'label': 'Curly'},
      {'value': 'curvy', 'label': 'Wavy'},
      {'value': 'dreads', 'label': 'Dreads'},
      {'value': 'fro', 'label': 'Afro'},
      {'value': 'froBand', 'label': 'Afro + Band'},
      {'value': 'miaWallace', 'label': 'Sleek Bob'},
      {'value': 'straight01', 'label': 'Straight'},
      {'value': 'straight02', 'label': 'Straight Sleek'},
      {'value': 'shaggy', 'label': 'Shaggy'},
      {'value': 'shaggyMullet', 'label': 'Mullet'},
      {'value': 'hijab', 'label': 'Hijab'},
      {'value': 'turban', 'label': 'Turban'},
      {'value': 'winterHat1', 'label': 'Winter Hat'},
      {'value': 'hat', 'label': 'Hat'},
      {'value': 'eyepatch', 'label': 'Eyepatch'},
    ],
    'hairColor': [
      {'value': 'auburn', 'label': 'Auburn'},
      {'value': 'black', 'label': 'Black'},
      {'value': 'blonde', 'label': 'Blonde'},
      {'value': 'blondeGolden', 'label': 'Golden Blonde'},
      {'value': 'brown', 'label': 'Brown'},
      {'value': 'brownDark', 'label': 'Dark Brown'},
      {'value': 'pastelPink', 'label': 'Pink'},
      {'value': 'blue', 'label': 'Blue'},
      {'value': 'platinum', 'label': 'Platinum'},
      {'value': 'red', 'label': 'Red'},
      {'value': 'silverGray', 'label': 'Silver'},
    ],
    'eyes': [
      {'value': 'default', 'label': 'Default'},
      {'value': 'happy', 'label': 'Happy'},
      {'value': 'hearts', 'label': 'Hearts'},
      {'value': 'surprised', 'label': 'Surprised'},
      {'value': 'wink', 'label': 'Wink'},
      {'value': 'winkWacky', 'label': 'Wacky Wink'},
      {'value': 'cry', 'label': 'Crying'},
      {'value': 'close', 'label': 'Closed'},
      {'value': 'squint', 'label': 'Squint'},
      {'value': 'side', 'label': 'Side Glance'},
      {'value': 'dizzy', 'label': 'Dizzy'},
      {'value': 'eyeRoll', 'label': 'Eye Roll'},
    ],
    'eyebrows': [
      {'value': 'default', 'label': 'Default'},
      {'value': 'defaultNatural', 'label': 'Natural'},
      {'value': 'angry', 'label': 'Angry'},
      {'value': 'angryNatural', 'label': 'Angry Natural'},
      {'value': 'flatNatural', 'label': 'Flat'},
      {'value': 'raisedExcited', 'label': 'Excited'},
      {'value': 'raisedExcitedNatural', 'label': 'Excited Natural'},
      {'value': 'sadConcerned', 'label': 'Sad'},
      {'value': 'sadConcernedNatural', 'label': 'Sad Natural'},
      {'value': 'unibrowNatural', 'label': 'Unibrow'},
      {'value': 'upDown', 'label': 'Up-Down'},
      {'value': 'upDownNatural', 'label': 'Up-Down Natural'},
      {'value': 'frownNatural', 'label': 'Frown'},
    ],
    'mouth': [
      {'value': 'default', 'label': 'Default'},
      {'value': 'smile', 'label': 'Smile'},
      {'value': 'twinkle', 'label': 'Twinkle'},
      {'value': 'serious', 'label': 'Serious'},
      {'value': 'tongue', 'label': 'Tongue Out'},
      {'value': 'eating', 'label': 'Eating'},
      {'value': 'grimace', 'label': 'Grimace'},
      {'value': 'sad', 'label': 'Sad'},
      {'value': 'screamOpen', 'label': 'Scream'},
      {'value': 'vomit', 'label': 'Sick'},
      {'value': 'disbelief', 'label': 'Disbelief'},
      {'value': 'concerned', 'label': 'Concerned'},
    ],
    'clothing': [
      {'value': 'hoodie', 'label': 'Hoodie'},
      {'value': 'shirtCrewNeck', 'label': 'T-Shirt'},
      {'value': 'shirtVNeck', 'label': 'V-Neck'},
      {'value': 'shirtScoopNeck', 'label': 'Scoop Neck'},
      {'value': 'graphicShirt', 'label': 'Graphic Tee'},
      {'value': 'blazerAndShirt', 'label': 'Blazer'},
      {'value': 'blazerAndSweater', 'label': 'Blazer + Sweater'},
      {'value': 'collarAndSweater', 'label': 'Sweater'},
      {'value': 'overall', 'label': 'Overalls'},
    ],
    'clothesColor': [
      {'value': 'black', 'label': 'Black'},
      {'value': 'blue01', 'label': 'Blue'},
      {'value': 'blue02', 'label': 'Dark Blue'},
      {'value': 'blue03', 'label': 'Light Blue'},
      {'value': 'gray01', 'label': 'Gray'},
      {'value': 'gray02', 'label': 'Dark Gray'},
      {'value': 'heather', 'label': 'Heather'},
      {'value': 'pastelBlue', 'label': 'Pastel Blue'},
      {'value': 'pastelGreen', 'label': 'Pastel Green'},
      {'value': 'pastelOrange', 'label': 'Pastel Orange'},
      {'value': 'pastelRed', 'label': 'Pastel Red'},
      {'value': 'pastelYellow', 'label': 'Pastel Yellow'},
      {'value': 'pink', 'label': 'Pink'},
      {'value': 'red', 'label': 'Red'},
      {'value': 'white', 'label': 'White'},
    ],
    'accessories': [
      {'value': 'blank', 'label': 'None'},
      {'value': 'prescription01', 'label': 'Round Glasses'},
      {'value': 'prescription02', 'label': 'Square Glasses'},
      {'value': 'round', 'label': 'Round Frames'},
      {'value': 'sunglasses', 'label': 'Sunglasses'},
      {'value': 'wayfarers', 'label': 'Wayfarers'},
      {'value': 'kurt', 'label': 'Headband'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _selections = widget.initialSelection ?? {};
    _updatePreview();
  }

  Future<void> _updatePreview() async {
    setState(() => _isLoadingPreview = true);

    try {
      debugPrint('[Avatar Picker] Fetching preview with selections: $_selections');
      final svg = await widget.avatarService.fetchAvatarSvg(
        age: widget.characterAge,
        seed: 'preview-${DateTime.now().millisecondsSinceEpoch}',
        userOverrides: _selections,
      );
      debugPrint('[Avatar Picker] Received SVG: ${svg?.substring(0, 100)}...');
      if (mounted) {
        setState(() {
          _previewSvg = svg;
          _isLoadingPreview = false;
        });
      }
    } catch (e) {
      debugPrint('[Avatar Picker] Error fetching preview: $e');
      if (mounted) {
        setState(() => _isLoadingPreview = false);
      }
    }
  }

  void _selectOption(String category, String value) {
    setState(() {
      _selections[category] = value;
    });
    _updatePreview();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Your Avatar'),
        actions: [
          TextButton(
            onPressed: () {
              // Return selections as JSON string
              final jsonString = json.encode(_selections);
              Navigator.pop(context, jsonString);
            },
            child: const Text(
              'Save',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live preview at top
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Center(
              child: _isLoadingPreview
                  ? const CircularProgressIndicator()
                  : _previewSvg != null
                      ? SizedBox(
                          width: 150,
                          height: 150,
                          child: SvgPicture.string(
                            _previewSvg!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : const Icon(Icons.person, size: 150),
            ),
          ),

          // Customization options
          Expanded(
            child: ListView(
              children: [
                _buildSection('Skin Tone', 'skinColor'),
                _buildSection('Hair Style', 'top'),
                _buildSection('Hair Color', 'hairColor'),
                _buildSection('Eyes', 'eyes'),
                _buildSection('Eyebrows', 'eyebrows'),
                _buildSection('Mouth', 'mouth'),
                _buildSection('Clothing', 'clothing'),
                _buildSection('Clothing Color', 'clothesColor'),
                _buildSection('Accessories', 'accessories'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String category) {
    final options = _avatarOptions[category] ?? [];
    final currentValue = _selections[category];

    return ExpansionTile(
      title: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (currentValue != null) ...[
            const SizedBox(width: 8),
            Chip(
              label: Text(
                options.firstWhere(
                  (opt) => opt['value'] == currentValue,
                  orElse: () => {'label': currentValue},
                )['label']!,
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: Colors.blue[100],
            ),
          ],
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final value = option['value']!;
              final label = option['label']!;
              final isSelected = currentValue == value;

              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => _selectOption(category, value),
                selectedColor: Colors.blue[300],
                backgroundColor: Colors.grey[200],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

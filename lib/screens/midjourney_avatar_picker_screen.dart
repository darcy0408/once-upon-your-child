import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter/foundation.dart';
/// Midjourney Avatar Picker Screen
///
/// Displays custom Midjourney-generated avatars in a grid with:
/// - Lazy loading for performance
/// - Filtering by age, skin tone, hair, gender
/// - Selection and save functionality
class MidjourneyAvatarPickerScreen extends StatefulWidget {
  final String? initialSelectedAvatar;

  const MidjourneyAvatarPickerScreen({
    super.key,
    this.initialSelectedAvatar,
  });

  @override
  State<MidjourneyAvatarPickerScreen> createState() => _MidjourneyAvatarPickerScreenState();
}

class _MidjourneyAvatarPickerScreenState extends State<MidjourneyAvatarPickerScreen> {
  Map<String, dynamic>? _metadata;
  List<AvatarItem> _allAvatars = [];
  List<AvatarItem> _filteredAvatars = [];
  String? _selectedAvatarId;
  bool _isLoading = true;

  // Filters
  String? _selectedAgeGroup;
  String? _selectedSkinTone;
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    _selectedAvatarId = widget.initialSelectedAvatar;
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/avatars/midjourney/metadata.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;

      setState(() {
        _metadata = data;
        _allAvatars = (data['avatars'] as Map<String, dynamic>).entries.map((entry) {
          final avatarData = entry.value as Map<String, dynamic>;
          return AvatarItem(
            id: avatarData['id'] as String,
            filename: avatarData['filename'] as String,
            age: avatarData['age'] as int?,
            ageGroup: avatarData['ageGroup'] as String?,
            skinTone: avatarData['skinTone'] as String?,
            hairColor: avatarData['hairColor'] as String?,
            hairStyle: avatarData['hairStyle'] as String?,
            gender: avatarData['gender'] as String?,
            tags: (avatarData['tags'] as List?)?.cast<String>() ?? [],
          );
        }).toList();

        _filteredAvatars = List.from(_allAvatars);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading avatar metadata: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading avatars: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredAvatars = _allAvatars.where((avatar) {
        if (_selectedAgeGroup != null && avatar.ageGroup != _selectedAgeGroup) {
          return false;
        }
        if (_selectedSkinTone != null && avatar.skinTone != _selectedSkinTone) {
          return false;
        }
        if (_selectedGender != null && avatar.gender != _selectedGender) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedAgeGroup = null;
      _selectedSkinTone = null;
      _selectedGender = null;
      _filteredAvatars = List.from(_allAvatars);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Avatar'),
        actions: [
          if (_selectedAvatarId != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context, _selectedAvatarId);
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter bar
                _buildFilterBar(),

                // Avatar count
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    '${_filteredAvatars.length} avatars',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ),

                // Avatar grid
                Expanded(
                  child: _filteredAvatars.isEmpty
                      ? const Center(
                          child: Text(
                            'No avatars match your filters.\nTry adjusting or clearing filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: _filteredAvatars.length,
                          itemBuilder: (context, index) {
                            return _buildAvatarCard(_filteredAvatars[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterBar() {
    final hasFilters = _selectedAgeGroup != null ||
                       _selectedSkinTone != null ||
                       _selectedGender != null;

    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey[100],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'Age',
                        value: _selectedAgeGroup,
                        onTap: () => _showFilterDialog('ageGroup'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Skin Tone',
                        value: _selectedSkinTone,
                        onTap: () => _showFilterDialog('skinTone'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Gender',
                        value: _selectedGender,
                        onTap: () => _showFilterDialog('gender'),
                      ),
                    ],
                  ),
                ),
              ),
              if (hasFilters)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearFilters,
                  tooltip: 'Clear filters',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    String? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Chip(
        label: Text(
          value == null ? label : '$label: $value',
          style: const TextStyle(fontSize: 12),
        ),
        backgroundColor: value != null ? Colors.blue[100] : Colors.grey[200],
        deleteIcon: value != null ? const Icon(Icons.arrow_drop_down, size: 18) : const Icon(Icons.add, size: 18),
        onDeleted: onTap,
      ),
    );
  }

  void _showFilterDialog(String filterType) {
    if (_metadata == null) return;

    final categories = _metadata!['categories'] as Map<String, dynamic>;
    List<String> options = [];
    String title = '';
    String? currentValue;

    switch (filterType) {
      case 'ageGroup':
        options = (categories['ageGroups'] as List).cast<String>();
        title = 'Select Age Group';
        currentValue = _selectedAgeGroup;
        break;
      case 'skinTone':
        options = (categories['skinTones'] as List).cast<String>();
        title = 'Select Skin Tone';
        currentValue = _selectedSkinTone;
        break;
      case 'gender':
        options = (categories['genders'] as List).cast<String>();
        title = 'Select Gender';
        currentValue = _selectedGender;
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Any'),
                leading: Radio<String?>(
                  value: null,
                  groupValue: currentValue,
                  onChanged: (value) {
                    Navigator.pop(context);
                    setState(() {
                      switch (filterType) {
                        case 'ageGroup':
                          _selectedAgeGroup = null;
                          break;
                        case 'skinTone':
                          _selectedSkinTone = null;
                          break;
                        case 'gender':
                          _selectedGender = null;
                          break;
                      }
                      _applyFilters();
                    });
                  },
                ),
              ),
              ...options.map((option) => ListTile(
                title: Text(_formatLabel(option)),
                leading: Radio<String>(
                  value: option,
                  groupValue: currentValue,
                  onChanged: (value) {
                    Navigator.pop(context);
                    setState(() {
                      switch (filterType) {
                        case 'ageGroup':
                          _selectedAgeGroup = value;
                          break;
                        case 'skinTone':
                          _selectedSkinTone = value;
                          break;
                        case 'gender':
                          _selectedGender = value;
                          break;
                      }
                      _applyFilters();
                    });
                  },
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLabel(String value) {
    // Convert "very-light" to "Very Light"
    return value.split('-').map((word) =>
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  Widget _buildAvatarCard(AvatarItem avatar) {
    final isSelected = _selectedAvatarId == avatar.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAvatarId = avatar.id;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/avatars/midjourney/${avatar.filename}',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.person, size: 50),
                  );
                },
              ),
              if (isSelected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar metadata model
class AvatarItem {
  final String id;
  final String filename;
  final int? age;
  final String? ageGroup;
  final String? skinTone;
  final String? hairColor;
  final String? hairStyle;
  final String? gender;
  final List<String> tags;

  AvatarItem({
    required this.id,
    required this.filename,
    this.age,
    this.ageGroup,
    this.skinTone,
    this.hairColor,
    this.hairStyle,
    this.gender,
    this.tags = const [],
  });
}

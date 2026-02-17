import 'package:flutter/material.dart';
import '../models/generated_avatar.dart';
import '../services/avatar_service.dart';
import '../ui/widgets/magical_avatar.dart';

/// Avatar Gallery Selector - Shows pre-made curated avatar options
class AvatarGallerySelector extends StatefulWidget {
  final Function(GeneratedAvatar) onAvatarSelected;
  final VoidCallback onCancel;

  const AvatarGallerySelector({
    super.key,
    required this.onAvatarSelected,
    required this.onCancel,
  });

  @override
  State<AvatarGallerySelector> createState() => _AvatarGallerySelectorState();
}

class _AvatarGallerySelectorState extends State<AvatarGallerySelector> {
  final AvatarService _avatarService = AvatarService();
  List<String> _avatars = [];
  Map<String, List<String>> _filterOptions = {};

  // Active filters
  String? _selectedAgeGroup;
  String? _selectedSkinTone;
  String? _selectedGender;
  String? _selectedHairColor;

  bool _isLoading = true;
  String? _selectedAvatarPath;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _avatarService.initialize();

    if (mounted) {
      setState(() {
        _filterOptions = _avatarService.getCuratedOptions();
        _isLoading = false;
      });
      _refreshAvatars();
    }
  }

  void _refreshAvatars() {
    setState(() {
      _avatars = _avatarService.getCuratedAvatars(
        ageGroup: _selectedAgeGroup,
        skinTone: _selectedSkinTone,
        gender: _selectedGender,
        hairColor: _selectedHairColor,
      );
    });
  }

  void _selectAvatar(String assetPath) {
    setState(() {
      _selectedAvatarPath = assetPath;
    });

    final avatarId = assetPath.split('/').last.split('.').first;
    final avatar = GeneratedAvatar(
      id: avatarId,
      imageBase64: assetPath,
      seed: avatarId,
      style: 'pixar',
      attributes: {
        'ageGroup': _selectedAgeGroup ?? 'all',
        'skinTone': _selectedSkinTone ?? 'all',
      },
      generatedAt: DateTime.now(),
    );

    widget.onAvatarSelected(avatar);
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = _selectedAgeGroup != null ||
        _selectedSkinTone != null ||
        _selectedHairColor != null ||
        _selectedGender != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF2C1B47),
              Color(0xFF5C3A84),
              Color(0xFF4A2F72),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(52),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFC44D), Color(0xFFFF9F43)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: Color(0xFF3B2363), size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Choose Your Look',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B2363),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close, color: Color(0xFF3B2363)),
                  ),
                ],
              ),
            ),

            // Chip filters (no dropdowns)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(237),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withAlpha(120)),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterSection(
                      title: 'Age',
                      icon: Icons.cake_outlined,
                      options: _filterOptions['ageGroups'] ?? const [],
                      selectedValue: _selectedAgeGroup,
                      onChanged: (value) {
                        setState(() => _selectedAgeGroup = value);
                        _refreshAvatars();
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildFilterSection(
                      title: 'Skin Tone',
                      icon: Icons.palette_outlined,
                      options: _filterOptions['skinTones'] ?? const [],
                      selectedValue: _selectedSkinTone,
                      onChanged: (value) {
                        setState(() => _selectedSkinTone = value);
                        _refreshAvatars();
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildFilterSection(
                      title: 'Hair Color',
                      icon: Icons.brush_outlined,
                      options: _filterOptions['hairColors'] ?? const [],
                      selectedValue: _selectedHairColor,
                      onChanged: (value) {
                        setState(() => _selectedHairColor = value);
                        _refreshAvatars();
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildFilterSection(
                      title: 'Vibe',
                      icon: Icons.auto_awesome_outlined,
                      options: _filterOptions['genders'] ?? const [],
                      selectedValue: _selectedGender,
                      onChanged: (value) {
                        setState(() => _selectedGender = value);
                        _refreshAvatars();
                      },
                    ),
                    if (hasActiveFilters) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedAgeGroup = null;
                            _selectedSkinTone = null;
                            _selectedHairColor = null;
                            _selectedGender = null;
                          });
                          _refreshAvatars();
                        },
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Show all looks'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF5C3A84),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Gallery Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _avatars.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_off,
                                size: 64,
                                color: Colors.white.withAlpha(204),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No heroes match this combo yet.\nTry a different vibe!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(230),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: RadialGradient(
                              colors: [Color(0x447E57C2), Color(0x002C1B47)],
                              radius: 1.2,
                              center: Alignment(-0.2, -0.8),
                            ),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final maxWidth = constraints.maxWidth;
                              final crossAxisCount = maxWidth >= 820
                                  ? 4
                                  : maxWidth >= 560
                                      ? 3
                                      : 2;

                              return GridView.builder(
                                padding: const EdgeInsets.all(20),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 1.0,
                                ),
                                itemCount: _avatars.length,
                                itemBuilder: (context, index) {
                                  final assetPath = _avatars[index];
                                  final isSelected =
                                      _selectedAvatarPath == assetPath;

                                  return GestureDetector(
                                    onTap: () => _selectAvatar(assetPath),
                                    child: MagicalAvatar(
                                      assetPath: assetPath,
                                      size: 150,
                                      borderWidth: isSelected ? 4 : 0,
                                      glowColor: isSelected
                                          ? const Color(0xFFFFC44D)
                                          : Colors.transparent,
                                      enableParticles: isSelected,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
  }) {
    if (options.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF4A2F72)),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4A2F72),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedValue == option;
            return ChoiceChip(
              label: Text(
                _friendlyLabelFor(option),
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF3B2363)
                      : const Color(0xFF4A2F72),
                  fontWeight: FontWeight.w600,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFFFFD98A),
              backgroundColor: const Color(0xFFF4ECFF),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFFFFB347)
                    : const Color(0xFFD9C6F0),
              ),
              onSelected: (_) {
                onChanged(isSelected ? null : option);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  String _friendlyLabelFor(String value) {
    switch (value) {
      case 'masculine':
        return 'Boyish';
      case 'feminine':
        return 'Girlish';
      case 'androgynous':
        return 'Mixed';
      default:
        return value
            .split('-')
            .map((segment) => segment.isEmpty
                ? segment
                : '${segment[0].toUpperCase()}${segment.substring(1)}')
            .join(' ');
    }
  }
}

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

    // Create avatar object
    final avatarId = assetPath.split('/').last.split('.').first;
    final avatar = GeneratedAvatar(
      id: avatarId,
      imageBase64: assetPath, // Storing asset path for local rendering
      seed: avatarId,
      style: 'pixar',
      attributes: {
        'ageGroup': _selectedAgeGroup ?? 'any',
        'skinTone': _selectedSkinTone ?? 'any',
      },
      generatedAt: DateTime.now(),
    );

    widget.onAvatarSelected(avatar);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
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
                color: Color(0xFFFFD93D),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.collections, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Choose Your Look',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterDropdown('Age', _filterOptions['ageGroups'], _selectedAgeGroup, (v) {
                      setState(() => _selectedAgeGroup = v);
                      _refreshAvatars();
                    }),
                    const SizedBox(width: 12),
                    _buildFilterDropdown('Skin', _filterOptions['skinTones'], _selectedSkinTone, (v) {
                      setState(() => _selectedSkinTone = v);
                      _refreshAvatars();
                    }),
                    const SizedBox(width: 12),
                    _buildFilterDropdown('Hair Color', _filterOptions['hairColors'], _selectedHairColor, (v) {
                      setState(() => _selectedHairColor = v);
                      _refreshAvatars();
                    }),
                    const SizedBox(width: 12),
                    _buildFilterDropdown('Style', _filterOptions['genders'], _selectedGender, (v) {
                      setState(() => _selectedGender = v);
                      _refreshAvatars();
                    }),
                    if (_selectedAgeGroup != null || _selectedSkinTone != null || _selectedHairColor != null || _selectedGender != null) ...[
                      const SizedBox(width: 12),
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
                        label: const Text('Clear Filters'),
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
                              Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No avatars match these filters.\nTry clearing some filters!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4, // Responsive ideally, but 4 is safe for tablet/dialog
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: _avatars.length,
                          itemBuilder: (context, index) {
                            final assetPath = _avatars[index];
                            final isSelected = _selectedAvatarPath == assetPath;

                            return GestureDetector(
                              onTap: () => _selectAvatar(assetPath),
                              child: MagicalAvatar(
                                assetPath: assetPath,
                                size: 150,
                                borderWidth: isSelected ? 4 : 0,
                                glowColor: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
                                enableParticles: isSelected,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    List<String>? options,
    String? currentValue,
    ValueChanged<String?> onChanged,
  ) {
    if (options == null || options.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: currentValue != null ? const Color(0xFFFFF3E0) : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: currentValue != null ? const Color(0xFFFFD93D) : Colors.grey[300]!,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          hint: Text(label, style: const TextStyle(fontSize: 14)),
          icon: const Icon(Icons.arrow_drop_down),
          isDense: true,
          onChanged: onChanged,
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('Any $label', style: const TextStyle(color: Colors.grey)),
            ),
            ...options.map((opt) => DropdownMenuItem(
              value: opt,
              child: Text(
                opt.split('-').map((s) => s[0].toUpperCase() + s.substring(1)).join(' '),
                style: const TextStyle(color: Colors.black87),
              ),
            )),
          ],
        ),
      ),
    );
  }
}


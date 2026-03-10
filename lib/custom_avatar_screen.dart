import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'avatar_models.dart';
import 'config/environment.dart';
import 'services/api_service_manager.dart';
import 'theme/app_theme.dart';

class CustomAvatarScreen extends StatefulWidget {
  final String? initialName;
  final int? initialAge;

  const CustomAvatarScreen({
    super.key,
    this.initialName,
    this.initialAge,
  });

  @override
  State<CustomAvatarScreen> createState() => _CustomAvatarScreenState();
}

class _CustomAvatarScreenState extends State<CustomAvatarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  String _gender = 'girl';
  String _eyeColor = 'Brown';
  String _hairColor = 'Brown';
  String _favoriteColor = 'Blue';

  Uint8List? _imageBytes; // In-memory bytes — works on web + native
  bool _isGenerating = false;
  String? _generatedImageBase64; // Pure base64, no data: prefix

  final List<String> _eyeColors = ['Brown', 'Blue', 'Green', 'Hazel', 'Grey'];
  final List<String> _hairColors = [
    'Black',
    'Brown',
    'Blonde',
    'Red',
    'Grey',
    'Pink',
  ];
  final List<String> _favoriteColors = [
    'Red',
    'Blue',
    'Green',
    'Yellow',
    'Purple',
    'Pink',
    'Orange',
    'Teal',
    'Gold',
  ];
  static const Map<String, Color> _eyeColorSwatches = {
    'Brown': Color(0xFF6D4C41),
    'Blue': Color(0xFF4FC3F7),
    'Green': Color(0xFF66BB6A),
    'Hazel': Color(0xFF8D6E63),
    'Grey': Color(0xFF90A4AE),
  };
  static const Map<String, Color> _hairColorSwatches = {
    'Black': Color(0xFF1B1B1F),
    'Brown': Color(0xFF6D4C41),
    'Blonde': Color(0xFFFFE082),
    'Red': Color(0xFFE57373),
    'Grey': Color(0xFFB0BEC5),
    'Pink': Color(0xFFF48FB1),
  };
  static const Map<String, Color> _favoriteColorSwatches = {
    'Red': Color(0xFFE53935),
    'Blue': Color(0xFF1E88E5),
    'Green': Color(0xFF43A047),
    'Yellow': Color(0xFFFDD835),
    'Purple': Color(0xFF8E24AA),
    'Pink': Color(0xFFD81B60),
    'Orange': Color(0xFFFB8C00),
    'Teal': Color(0xFF00897B),
    'Gold': Color(0xFFFFD700),
  };

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName ?? '';
    _ageController.text = widget.initialAge?.toString() ?? '7';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
        });
      }
    }
  }

  Future<void> _generateAvatar() async {
    if (!_formKey.currentState!.validate() || _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please complete all fields and add a photo.')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final baseUrl = Environment.backendUrl;
      final url = Uri.parse('$baseUrl/avatar/generate-custom-avatar');

      Future<http.Response> sendRequest() async {
        final request = http.MultipartRequest('POST', url);
        final authHeaders = await ApiServiceManager.authHeaders();
        // Only add Authorization header — Content-Type is set automatically for multipart
        if (authHeaders.containsKey('Authorization')) {
          request.headers['Authorization'] = authHeaders['Authorization']!;
        }
        // fromBytes works on all platforms including web (no dart:io needed)
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            _imageBytes!,
            filename: 'photo.jpg',
          ),
        );
        request.fields['character_name'] = _nameController.text;
        request.fields['age'] = _ageController.text;
        request.fields['gender'] = _gender;
        request.fields['eye_color'] = _eyeColor;
        request.fields['hair_color'] = _hairColor;
        request.fields['favorite_color'] = _favoriteColor;
        debugPrint('📡 Sending custom avatar request to $url');
        final streamedResponse =
            await request.send().timeout(const Duration(minutes: 3));
        return http.Response.fromStream(streamedResponse);
      }

      http.Response response = await sendRequest();
      if (response.statusCode == 401) {
        debugPrint(
            '⚠️ Custom avatar request returned 401; refreshing auth and retrying once');
        await ApiServiceManager.resetAndReauthenticate();
        response = await sendRequest();
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final avatarData = data['avatar'];
          final raw = avatarData['image_base64'] as String;
          // Strip any data: prefix that may be present
          final base64Only = raw.contains(',') ? raw.split(',').last : raw;

          if (mounted) {
            setState(() {
              _generatedImageBase64 = base64Only;
              _isGenerating = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Magical Avatar Created! ✨')),
            );
          }
        } else {
          throw Exception(data['message'] ?? 'Generation failed');
        }
      } else {
        String serverMessage = 'Server error: ${response.statusCode}';
        try {
          final body = json.decode(response.body) as Map<String, dynamic>;
          final message = body['message']?.toString();
          if (message != null && message.trim().isNotEmpty) {
            serverMessage = message;
          }
        } catch (_) {}
        throw Exception(serverMessage);
      }
    } catch (e) {
      debugPrint('❌ Error generating custom avatar: $e');
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.quicksand(
        color: AppColors.goldLight,
        fontWeight: FontWeight.w700,
      ),
      prefixIcon: Icon(icon, color: AppColors.gold),
      filled: true,
      fillColor: const Color(0xFF2C1B47),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.gold.withAlpha(70)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.gold.withAlpha(70)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.gold, width: 2),
      ),
    );
  }

  Widget _buildVisualColorPicker({
    required String title,
    required IconData icon,
    required List<String> options,
    required Map<String, Color> swatches,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF2C1B47),
        border: Border.all(color: AppColors.gold.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.quicksand(
                  color: AppColors.goldLight,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = option == selected;
              final color = swatches[option] ?? Colors.white;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelected(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: isSelected
                        ? const Color(0xFFFFD54F).withAlpha(36)
                        : Colors.white.withAlpha(12),
                    border: Border.all(
                      color: isSelected ? AppColors.gold : Colors.white24,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(color: Colors.white30),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        option,
                        style: GoogleFonts.quicksand(
                          color: Colors.white,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Magical Avatar Creator',
          style: GoogleFonts.cinzelDecorative(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppGradients.magicalBackground),
        child: Stack(
          children: [
            Positioned(
              top: 90,
              left: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(38),
                ),
              ),
            ),
            Positioned(
              right: -60,
              bottom: 140,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.goldLight.withAlpha(55),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 110, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create a hero that looks like you',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzelDecorative(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Color(0x55000000), blurRadius: 10),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Snap or upload a photo, then we paint it into story magic.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.quicksand(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withAlpha(230),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // ── Photo picker ─────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.white.withAlpha(30),
                        border: Border.all(color: Colors.white.withAlpha(95)),
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _isGenerating ? null : _pickFromGallery,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.gold.withAlpha(220),
                                  width: 2.4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.gold.withAlpha(90),
                                    blurRadius: 18,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _imageBytes != null
                                  ? Image.memory(
                                      _imageBytes!,
                                      fit: BoxFit.cover,
                                      width: 200,
                                      height: 200,
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.add_photo_alternate_rounded,
                                          size: 64,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Tap to choose a photo',
                                          style: GoogleFonts.fredoka(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isGenerating ? null : _takePhoto,
                                  icon: const Icon(Icons.camera_alt_rounded),
                                  label: const Text('Camera'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF5F4BDB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isGenerating ? null : _pickFromGallery,
                                  icon: const Icon(Icons.photo_library_rounded),
                                  label: const Text('Upload'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7A3FC8),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_imageBytes != null) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _isGenerating
                                  ? null
                                  : () => setState(() {
                                        _imageBytes = null;
                                      }),
                              icon: const Icon(Icons.refresh_rounded,
                                  color: Colors.white),
                              label: Text(
                                'Retake',
                                style: GoogleFonts.quicksand(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ── Form fields ──────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.white.withAlpha(20),
                        border: Border.all(color: Colors.white.withAlpha(70)),
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _fieldDecoration(
                                label: 'Hero Name', icon: Icons.person_rounded),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Enter a name'
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _ageController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _fieldDecoration(
                                label: 'Age (3-99)', icon: Icons.cake_rounded),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter age';
                              }
                              final age = int.tryParse(value);
                              if (age == null) return 'Enter a valid number';
                              if (age < 3 || age > 99) {
                                return 'Age must be between 3 and 99';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: const Color(0xFF2C1B47),
                              border: Border.all(
                                  color: AppColors.gold.withAlpha(70)),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 360;

                                Widget genderPicker = SegmentedButton<String>(
                                  style: SegmentedButton.styleFrom(
                                    backgroundColor: Colors.white.withAlpha(18),
                                    foregroundColor: Colors.white70,
                                    selectedBackgroundColor: AppColors.gold,
                                    selectedForegroundColor:
                                        const Color(0xFF1A0D2E),
                                    side: BorderSide(
                                        color: AppColors.gold.withAlpha(120)),
                                  ),
                                  segments: const [
                                    ButtonSegment(
                                      value: 'girl',
                                      label: Text('Girl'),
                                      icon: Icon(Icons.female),
                                    ),
                                    ButtonSegment(
                                      value: 'boy',
                                      label: Text('Boy'),
                                      icon: Icon(Icons.male),
                                    ),
                                  ],
                                  selected: {_gender},
                                  onSelectionChanged:
                                      (Set<String> newSelection) {
                                    setState(() {
                                      _gender = newSelection.first;
                                    });
                                  },
                                );

                                if (isNarrow) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.wc_rounded,
                                              color: AppColors.gold, size: 20),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Gender',
                                            style: GoogleFonts.quicksand(
                                              color: AppColors.goldLight,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      genderPicker,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Icon(Icons.wc_rounded,
                                        color: AppColors.gold, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Gender',
                                      style: GoogleFonts.quicksand(
                                        color: AppColors.goldLight,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: genderPicker),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildVisualColorPicker(
                            title: 'Eye Color',
                            icon: Icons.visibility_rounded,
                            options: _eyeColors,
                            swatches: _eyeColorSwatches,
                            selected: _eyeColor,
                            onSelected: (value) =>
                                setState(() => _eyeColor = value),
                          ),
                          const SizedBox(height: 12),
                          _buildVisualColorPicker(
                            title: 'Hair Color',
                            icon: Icons.face_retouching_natural,
                            options: _hairColors,
                            swatches: _hairColorSwatches,
                            selected: _hairColor,
                            onSelected: (value) =>
                                setState(() => _hairColor = value),
                          ),
                          const SizedBox(height: 12),
                          _buildVisualColorPicker(
                            title: 'Favorite Color (Clothes)',
                            icon: Icons.auto_awesome_rounded,
                            options: _favoriteColors,
                            swatches: _favoriteColorSwatches,
                            selected: _favoriteColor,
                            onSelected: (value) =>
                                setState(() => _favoriteColor = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // ── Generate / result ────────────────────────────────────
                    if (_isGenerating)
                      Column(
                        children: [
                          const CircularProgressIndicator(
                              color: AppColors.gold),
                          const SizedBox(height: 10),
                          Text(
                            'Brewing your magical avatar...',
                            style: GoogleFonts.fredoka(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '(Usually about a minute)',
                            style: GoogleFonts.quicksand(
                              color: Colors.white.withAlpha(225),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    else if (_generatedImageBase64 != null)
                      Column(
                        children: [
                          Container(
                            height: 300,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: AppColors.gold, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(60),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.memory(
                              base64Decode(_generatedImageBase64!),
                              fit: BoxFit.contain,
                              width: double.infinity,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              // Store as data URI — works on web + native
                              final dataUri =
                                  'data:image/png;base64,$_generatedImageBase64';
                              final customAvatar =
                                  CharacterAvatar.defaultAvatar.copyWith(
                                customImagePath: dataUri,
                                isCustom: true,
                              );
                              Navigator.pop(context, customAvatar);
                            },
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Use This Avatar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF208D62),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 15, horizontal: 30),
                            ),
                          ),
                        ],
                      )
                    else
                      ElevatedButton(
                        onPressed: _generateAvatar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Generate Magic Avatar ✨',
                          style: GoogleFonts.fredoka(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../../models.dart';
import '../../config/environment.dart';
import '../../services/api_service_manager.dart';
import '../../theme/app_theme.dart';

class CustomPetAvatarScreen extends StatefulWidget {
  final String petName;
  final String species;
  final String breedDescription;
  final String ownerFavoriteColor;

  const CustomPetAvatarScreen({
    super.key,
    required this.petName,
    required this.species,
    required this.breedDescription,
    required this.ownerFavoriteColor,
  });

  @override
  State<CustomPetAvatarScreen> createState() => _CustomPetAvatarScreenState();
}

class _CustomPetAvatarScreenState extends State<CustomPetAvatarScreen> {
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isGenerating = false;
  String? _generatedImagePath;
  GeneratedAvatar? _generatedAvatarData;

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (pickedFile != null) {
      final pickedBytes = kIsWeb ? await pickedFile.readAsBytes() : null;
      setState(() {
        _selectedImage = pickedFile;
        _selectedImageBytes = pickedBytes;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final pickedBytes = kIsWeb ? await pickedFile.readAsBytes() : null;
      setState(() {
        _selectedImage = pickedFile;
        _selectedImageBytes = pickedBytes;
      });
    }
  }

  Future<void> _generatePetAvatar() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a photo of your pet.')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final baseUrl = Environment.backendUrl;
      final url = Uri.parse('$baseUrl/avatar/generate-pet-avatar');

      var request = http.MultipartRequest('POST', url);
      if (kIsWeb) {
        final bytes =
            _selectedImageBytes ?? await _selectedImage!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            bytes,
            filename: _selectedImage!.name.isNotEmpty
                ? _selectedImage!.name
                : 'pet_photo.png',
          ),
        );
      } else {
        request.files.add(
            await http.MultipartFile.fromPath('photo', _selectedImage!.path));
      }
      request.fields['pet_name'] = widget.petName;
      request.fields['species'] = widget.species;
      request.fields['breed_description'] = widget.breedDescription;
      request.fields['owner_favorite_color'] = widget.ownerFavoriteColor;
      final headers = await ApiServiceManager.authHeaders();
      headers.forEach((key, value) {
        if (key.toLowerCase() != 'content-type') {
          request.headers[key] = value;
        }
      });

      debugPrint('📡 Sending custom pet avatar request to $url');
      final streamedResponse =
          await request.send().timeout(const Duration(minutes: 3));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 206) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final avatarData = data['avatar'];
          final imageBase64 = avatarData['image_base64'] as String;

          final localPath = await _saveImageLocally(imageBase64);

          if (mounted) {
            setState(() {
              _generatedAvatarData = GeneratedAvatar.fromJson(avatarData);
              _generatedImagePath = localPath;
              _isGenerating = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  response.statusCode == 206
                      ? "We kept your pet's real photo — magical transformation is temporarily unavailable"
                      : 'Magical Pet Avatar Created! ✨',
                ),
              ),
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
      debugPrint('❌ Error generating custom pet avatar: $e');
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

  Future<String> _saveImageLocally(String base64String) async {
    final normalizedDataUri = base64String.startsWith('data:image')
        ? base64String
        : 'data:image/png;base64,${base64String.split(',').last}';
    final bytes = base64Decode(normalizedDataUri.split(',').last);

    if (kIsWeb) {
      return normalizedDataUri;
    }

    final directory = await getApplicationDocumentsDirectory();
    final avatarsDir = Directory(path.join(directory.path, 'pet_avatars'));
    if (!await avatarsDir.exists()) {
      await avatarsDir.create(recursive: true);
    }

    final fileName = 'pet_avatar_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(path.join(avatarsDir.path, fileName));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  ImageProvider<Object>? _selectedImageProvider() {
    if (_selectedImage == null) return null;
    if (kIsWeb) {
      if (_selectedImageBytes != null) {
        return MemoryImage(_selectedImageBytes!);
      }
      if (_selectedImage!.path.startsWith('blob:') ||
          _selectedImage!.path.startsWith('http') ||
          _selectedImage!.path.startsWith('data:image')) {
        return NetworkImage(_selectedImage!.path);
      }
      return null;
    }
    return FileImage(File(_selectedImage!.path));
  }

  ImageProvider<Object>? _generatedImageProvider() {
    final imagePath = _generatedImagePath;
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('data:image')) {
      return MemoryImage(base64Decode(imagePath.split(',').last));
    }
    if (imagePath.startsWith('blob:') || imagePath.startsWith('http')) {
      return NetworkImage(imagePath);
    }
    if (!kIsWeb) {
      return FileImage(File(imagePath));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Magical Pet Creator',
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
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 110, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Transform ${widget.petName} into Magic',
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
                    'Snap a photo of your pet to see them in your story.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.quicksand(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(230),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                          onTap: _isGenerating ? null : _takePhoto,
                          child: Container(
                            height: 300,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFFFD700).withAlpha(220),
                                width: 2.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withAlpha(90),
                                  blurRadius: 18,
                                  spreadRadius: 1,
                                ),
                              ],
                              image: _selectedImage != null
                                  ? DecorationImage(
                                      image: _selectedImageProvider()!,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _selectedImage == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 64,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Tap to photograph your pet',
                                        style: GoogleFonts.fredoka(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
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
                                label: const Text('Gallery'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7A3FC8),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isGenerating)
                    Column(
                      children: [
                        const CircularProgressIndicator(
                            color: Color(0xFFFFD700)),
                        const SizedBox(height: 16),
                        Text(
                          'Weaving pet magic...',
                          style: GoogleFonts.fredoka(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else if (_generatedImagePath != null)
                    Column(
                      children: [
                        Container(
                          height: 300,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFFFFD700), width: 2),
                            image: DecorationImage(
                              image: _generatedImageProvider()!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context, _generatedAvatarData);
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Use This Pet Avatar'),
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
                      onPressed: _generatePetAvatar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9B3FD8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Generate Magical Pet ✨',
                        style: GoogleFonts.fredoka(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

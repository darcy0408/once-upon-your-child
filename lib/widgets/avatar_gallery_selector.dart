import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/generated_avatar.dart';
import '../config/environment.dart';

/// Avatar Gallery Selector - Shows pre-made avatar options
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
  List<Map<String, dynamic>> _avatars = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedAvatarId;

  @override
  void initState() {
    super.initState();
    _loadAvatars();
  }

  Future<void> _loadAvatars() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = Environment.backendUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/avatar/gallery/list-avatars'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _avatars = List<Map<String, dynamic>>.from(data['avatars']);
            _isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load avatars');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load avatars. Please try again.';
      });
      debugPrint('Error loading avatars: $e');
    }
  }

  Future<void> _selectAvatar(String avatarId) async {
    setState(() {
      _selectedAvatarId = avatarId;
    });

    try {
      final baseUrl = Environment.backendUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/avatar/gallery/select-avatar/$avatarId'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final avatarData = data['avatar'];

          // Convert to GeneratedAvatar format
          // Note: Using URL as placeholder for imageBase64 since gallery avatars are pre-made
          final avatar = GeneratedAvatar(
            id: avatarData['id'],
            imageBase64: '$baseUrl${avatarData['image_url']}', // URL stored as base64 field for compatibility
            seed: avatarData['id'], // Use ID as seed for consistency
            style: avatarData['style'] ?? 'pixar',
            attributes: {}, // Empty attributes for gallery avatars
            generatedAt: DateTime.now(),
          );

          widget.onAvatarSelected(avatar);
        } else {
          throw Exception(data['message'] ?? 'Failed to select avatar');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _selectedAvatarId = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select avatar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          borderRadius: BorderRadius.circular(20),
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
                      'Choose Your Avatar',
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

            // Gallery Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading avatars...'),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(_errorMessage!),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadAvatars,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _buildGalleryGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryGrid() {
    final baseUrl = Environment.backendUrl;

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _avatars.length,
      itemBuilder: (context, index) {
        final avatar = _avatars[index];
        final avatarId = avatar['id'];
        final imageUrl = '$baseUrl${avatar['url']}';
        final isSelected = _selectedAvatarId == avatarId;

        return GestureDetector(
          onTap: () => _selectAvatar(avatarId),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[300]!,
                width: isSelected ? 4 : 2,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, size: 40),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[100],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                  if (isSelected)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

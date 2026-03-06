import 'dart:math';
import 'package:flutter/material.dart';
import '../models/generated_avatar.dart';
import '../services/avatar_service.dart';
import '../ui/widgets/magical_avatar.dart';
import '../screens/byok_setup_wizard.dart';
import 'avatar_tweak_panel.dart';

const int _kBatchSize = 12;

/// Avatar Gallery Selector - Shows pre-made curated avatar options
class AvatarGallerySelector extends StatefulWidget {
  final Function(GeneratedAvatar) onAvatarSelected;
  final VoidCallback onCancel;

  /// Whether the current user has premium access (enables hair/eye tweak).
  final bool isPremium;

  const AvatarGallerySelector({
    super.key,
    required this.onAvatarSelected,
    required this.onCancel,
    this.isPremium = false,
  });

  @override
  State<AvatarGallerySelector> createState() => _AvatarGallerySelectorState();
}

class _AvatarGallerySelectorState extends State<AvatarGallerySelector> {
  final AvatarService _avatarService = AvatarService();
  final _rng = Random();

  /// Full filtered pool
  List<String> _pool = [];
  /// Current displayed batch
  List<String> _batch = [];
  /// Tracks which pool indices have been shown this round
  List<int> _remaining = [];

  bool _isLoading = true;
  String? _selectedAvatarPath;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _avatarService.initialize();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _refreshPool();
      }
    } catch (e) {
      debugPrint('AvatarGallerySelector: Failed to initialize: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _refreshPool() {
    _pool = _avatarService.getCuratedAvatars();
    _remaining = List.generate(_pool.length, (i) => i);
    _remaining.shuffle(_rng);
    _nextBatch();
  }

  void _nextBatch() {
    if (_remaining.isEmpty) {
      // Seen everything — reshuffle for another round
      _remaining = List.generate(_pool.length, (i) => i);
      _remaining.shuffle(_rng);
    }
    final take = _remaining.length < _kBatchSize ? _remaining.length : _kBatchSize;
    final indices = _remaining.sublist(0, take);
    _remaining = _remaining.sublist(take);
    final newBatch = indices.map((i) => _pool[i]).toList();
    setState(() {
      _batch = newBatch;
    });
    // Precache all images in the new batch so they appear simultaneously
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final path in newBatch) {
        precacheImage(AssetImage(path), context);
      }
    });
  }

  void _selectAvatar(String assetPath) {
    // Show the AvatarTweakPanel; don't fire onAvatarSelected yet.
    setState(() => _selectedAvatarPath = assetPath);
  }

  void _confirmAvatar(String imageData) {
    final avatarId = imageData.startsWith('assets/')
        ? imageData.split('/').last.split('.').first
        : 'tweaked_${DateTime.now().millisecondsSinceEpoch}';
    widget.onAvatarSelected(GeneratedAvatar(
      id: avatarId,
      imageBase64: imageData,
      seed: avatarId,
      style: 'pixar',
      attributes: const {},
      generatedAt: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedAvatarPath != null) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: AvatarTweakPanel(
          assetPath: _selectedAvatarPath!,
          isPremium: widget.isPremium,
          onConfirm: (imageData) {
            Navigator.pop(context);
            _confirmAvatar(imageData);
          },
          onBack: () => setState(() => _selectedAvatarPath = null),
        ),
      );
    }
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2C1B47), Color(0xFF5C3A84), Color(0xFF4A2F72)],
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
            _buildHeader(),
            _buildGrid(),
            _buildShuffleFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
          const Icon(Icons.auto_awesome, color: Color(0xFF3B2363), size: 28),
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
    );
  }

  Widget _buildGrid() {
    if (_isLoading) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_pool.isEmpty) {
      return Expanded(
        child: Center(
          child: Text(
            'No characters found.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withAlpha(230), fontSize: 16),
          ),
        ),
      );
    }
    return Expanded(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0x447E57C2), Color(0x002C1B47)],
            radius: 1.2,
            center: Alignment(-0.2, -0.8),
          ),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final cols = constraints.maxWidth >= 820
              ? 4
              : constraints.maxWidth >= 560
                  ? 3
                  : 2;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            itemCount: _batch.length,
            itemBuilder: (context, index) {
              final assetPath = _batch[index];
              final isSelected = _selectedAvatarPath == assetPath;
              return GestureDetector(
                onTap: () => _selectAvatar(assetPath),
                child: MagicalAvatar(
                  assetPath: assetPath,
                  size: 150,
                  borderWidth: isSelected ? 4 : 0,
                  glowColor:
                      isSelected ? const Color(0xFFFFC44D) : Colors.transparent,
                  enableParticles: isSelected,
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildShuffleFooter() {
    if (_isLoading || _pool.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  '${_pool.length} characters to discover',
                  style: TextStyle(
                    color: Colors.white.withAlpha(153),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _nextBatch,
                icon: const Text('🎲', style: TextStyle(fontSize: 18)),
                label: const Text(
                  'Shuffle!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E57C2),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Custom avatar upsell — shown to all users as a teaser
          GestureDetector(
            onTap: () => _showCustomAvatarGate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF9F43)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withAlpha(80),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('✨', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text(
                    'Create a custom avatar that looks like me!',
                    style: TextStyle(
                      color: Color(0xFF3B2363),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomAvatarGate(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Text('✨', style: TextStyle(fontSize: 28)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Create YOUR Avatar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Imagine an AI-generated portrait of your child as the hero — not a pre-made character, but THEM.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✅ Unlock with Free Premium:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('• Custom AI avatar generation',
                      style: TextStyle(fontSize: 13)),
                  Text('• Story illustrations', style: TextStyle(fontSize: 13)),
                  Text('• Unlimited stories', style: TextStyle(fontSize: 13)),
                  SizedBox(height: 4),
                  Text(
                    'Use your own free Google AI key — most families spend under \$0.50/month.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => const ByokSetupWizardScreen(),
                  fullscreenDialog: true,
                ),
              );
            },
            icon: const Icon(Icons.key, size: 16),
            label: const Text('Set Up Free Premium →'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7E57C2),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

}

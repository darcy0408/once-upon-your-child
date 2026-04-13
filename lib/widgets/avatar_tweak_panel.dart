import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service_manager.dart';

/// Panel shown after a gallery avatar is selected, letting premium users
/// optionally change the hair length or eye colour before confirming.
///
/// Free users see the panel with a "Premium only" note on the Generate button.
/// All users can tap "Use this look" to skip customisation entirely.
class AvatarTweakPanel extends StatefulWidget {
  /// Flutter asset path of the selected gallery avatar, e.g.
  /// `assets/avatars/midjourney/avatar_042.webp`.
  final String assetPath;

  /// Whether the current user has premium access.
  final bool isPremium;

  /// Called when the user finalises their choice.
  ///
  /// [imageData] is either the original [assetPath] (when the user kept the
  /// gallery image as-is) or a `data:image/png;base64,...` string (tweaked).
  final void Function(String imageData) onConfirm;

  /// Called when the user taps "Pick a different one".
  final VoidCallback onBack;

  const AvatarTweakPanel({
    super.key,
    required this.assetPath,
    required this.isPremium,
    required this.onConfirm,
    required this.onBack,
  });

  @override
  State<AvatarTweakPanel> createState() => _AvatarTweakPanelState();
}

class _AvatarTweakPanelState extends State<AvatarTweakPanel> {
  static const _hairOptions = ['Short', 'Medium', 'Long', 'Curly'];
  static const _eyeOptions = ['Brown', 'Blue', 'Green', 'Hazel', 'Gray'];

  String? _selectedHair;
  String? _selectedEye;
  bool _isGenerating = false;
  bool _premiumExpanded = false;
  String? _tweakedImageData; // base64 data URI when generation succeeds

  bool get _hasChanges => _selectedHair != null || _selectedEye != null;

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _tweakedImageData = null;
    });
    final result = await ApiServiceManager.tweakGalleryAvatar(
      assetPath: widget.assetPath,
      hairLength: _selectedHair?.toLowerCase(),
      eyeColor: _selectedEye?.toLowerCase(),
    );
    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      _tweakedImageData = result;
    });
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Oops — the magic wand slipped! Please try again. ✨"),
        backgroundColor: Color(0xFFE53935),
      ));
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildOriginalAvatar({double size = 140}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.asset(
        widget.assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildTweakedAvatar({double size = 140}) {
    final data = _tweakedImageData!;
    final bytes = base64Decode(data.split(',').last);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover),
    );
  }

  // ─── Chip row ────────────────────────────────────────────────────────────────

  Widget _chipRow<T>({
    required String label,
    required List<String> options,
    required String? selected,
    required void Function(String) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD54F),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE8D5FF),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected == opt;
            return GestureDetector(
              onTap: () => setState(() => onSelect(isSelected ? '' : opt)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFFD54F)
                      : const Color(0xFF2A0D55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFFB300)
                        : const Color(0xFFFFD54F).withAlpha(60),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD54F).withAlpha(80),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFF3B2363)
                        : const Color(0xFFD4ADFF),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
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
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: _tweakedImageData != null
                  ? _buildComparisonView()
                  : _buildCustomiseView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
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
          const Text('✨', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Customise Your Look',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B2363),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, size: 16, color: Color(0xFF3B2363)),
            label: const Text(
              'Pick another',
              style: TextStyle(color: Color(0xFF3B2363), fontSize: 13),
            ),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }

  // ─── Customise view (before generation) ─────────────────────────────────────

  Widget _buildCustomiseView() {
    return Column(
      children: [
        // Avatar preview + "Use as-is" button
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildOriginalAvatar(),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Love it already?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => widget.onConfirm(widget.assetPath),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Use this look'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Customise section header
        Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              widget.isPremium ? 'Customise it' : 'Customise it',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.isPremium
                    ? const Color(0xFFFFE082)
                    : const Color(0xFFFFE082).withAlpha(130),
                letterSpacing: 0.5,
              ),
            ),
            if (!widget.isPremium) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD54F).withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFFD54F).withAlpha(80), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🔒', style: TextStyle(fontSize: 11)),
                    SizedBox(width: 4),
                    Text(
                      'Premium',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFD54F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),

        // For non-premium users, collapse into a compact teaser
        if (!widget.isPremium) ...[
          GestureDetector(
            onTap: () => setState(() => _premiumExpanded = !_premiumExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0835).withAlpha(200),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFFD54F).withAlpha(45),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  const Text('🔒', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Change hair, eyes & more with Premium',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    _premiumExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_premiumExpanded) ...[
            const SizedBox(height: 12),
            _buildAttributePickers(),
            const SizedBox(height: 12),
            _buildGenerateButton(disabled: true),
          ],
        ] else ...[
          // Premium users get the full expanded pickers
          _buildAttributePickers(),
          const SizedBox(height: 20),
          _isGenerating
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Color(0xFFFFC44D)),
                        SizedBox(height: 10),
                        Text(
                          'Creating your custom look…',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildGenerateButton(disabled: !_hasChanges),
        ],
      ],
    );
  }

  Widget _buildAttributePickers() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0835).withAlpha(200),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD54F).withAlpha(45),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          _chipRow(
            label: 'Hair length',
            options: _hairOptions,
            selected: _selectedHair,
            onSelect: (v) => _selectedHair = v.isEmpty ? null : v,
          ),
          const SizedBox(height: 18),
          Divider(color: const Color(0xFFFFD54F).withAlpha(30), height: 1),
          const SizedBox(height: 18),
          _chipRow(
            label: 'Eye colour',
            options: _eyeOptions,
            selected: _selectedEye,
            onSelect: (v) => _selectedEye = v.isEmpty ? null : v,
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton({bool disabled = false}) {
    final canAct = !disabled && widget.isPremium && _hasChanges;
    return GestureDetector(
      onTap: canAct ? _generate : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: canAct
              ? const LinearGradient(
                  colors: [Color(0xFFFFD54F), Color(0xFFFFAB40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: canAct ? null : const Color(0xFF2A0D55),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: canAct
                ? const Color(0xFFFFB300)
                : const Color(0xFFFFD54F).withAlpha(40),
            width: 1.5,
          ),
          boxShadow: canAct
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD54F).withAlpha(100),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.isPremium ? '🪄' : '🔒',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 10),
            Text(
              widget.isPremium
                  ? (_hasChanges ? 'Generate my look' : 'Pick options above')
                  : 'Premium only',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: canAct ? const Color(0xFF3B2363) : const Color(0xFFD4ADFF).withAlpha(150),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Comparison view (after generation) ─────────────────────────────────────

  Widget _buildComparisonView() {
    return Column(
      children: [
        const Text(
          'Which do you prefer?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompareCard(
              label: 'Original',
              avatar: _buildOriginalAvatar(size: 130),
              buttonLabel: 'Keep original',
              buttonColor: const Color(0xFF607D8B),
              onTap: () => widget.onConfirm(widget.assetPath),
            ),
            _buildCompareCard(
              label: 'Your look ✨',
              avatar: _buildTweakedAvatar(size: 130),
              buttonLabel: 'Use this one!',
              buttonColor: const Color(0xFF4CAF50),
              onTap: () => widget.onConfirm(_tweakedImageData!),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Allow trying again
        TextButton.icon(
          onPressed: () => setState(() {
            _tweakedImageData = null;
          }),
          icon: const Icon(Icons.refresh, size: 16, color: Colors.white70),
          label: const Text(
            'Try different options',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildCompareCard({
    required String label,
    required Widget avatar,
    required String buttonLabel,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 10),
        avatar,
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text(buttonLabel,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

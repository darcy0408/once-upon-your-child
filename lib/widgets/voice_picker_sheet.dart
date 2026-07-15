import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/elevenlabs_voice.dart';
import '../providers/age_band_provider.dart';
import '../providers/voice_preference_provider.dart';
import '../services/tts_api_service.dart';
import '../theme/app_theme.dart';

/// Bottom sheet that lets the user pick an ElevenLabs narrator voice.
/// Shows a curated list with name, accent chip, description, a "Preview"
/// button, and a gold highlight on the currently selected voice.
///
/// Usage:
/// ```dart
/// VoicePickerSheet.show(context);
/// ```
class VoicePickerSheet extends ConsumerStatefulWidget {
  const VoicePickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoicePickerSheet(),
    );
  }

  @override
  ConsumerState<VoicePickerSheet> createState() => _VoicePickerSheetState();
}

class _VoicePickerSheetState extends ConsumerState<VoicePickerSheet> {
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _previewingVoiceId;
  bool _isLoadingPreview = false;

  static const String _previewText =
      'Once upon a time, in a land full of magic and wonder, '
      'a brave young hero set off on an incredible adventure.';

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _preview(String voiceId) async {
    if (_isLoadingPreview) return;
    await _previewPlayer.stop();

    setState(() {
      _previewingVoiceId = voiceId;
      _isLoadingPreview = true;
    });

    TtsSynthesisResult? ttsResult;
    try {
      ttsResult = await TtsApiService.synthesize(
        _previewText,
        voiceId: voiceId,
      );
    } on TtsConsentGateException {
      // COPPA gate — treat like "unavailable" and fall into the snackbar path.
      ttsResult = null;
    } on TtsQuotaExceededException {
      // Daily quota spent — snackbar path, no robotic preview.
      ttsResult = null;
    } on TtsRateLimitException {
      // Transient rate limit — snackbar path.
      ttsResult = null;
    }
    final mp3 = ttsResult?.audioBytes;

    if (!mounted) return;
    setState(() => _isLoadingPreview = false);

    if (mp3 != null && mp3.isNotEmpty) {
      await _previewPlayer.play(BytesSource(mp3));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preview unavailable — check backend connection')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(voicePreferenceNotifierProvider);
    final band = ref.watch(ageBandNotifierProvider).band;
    final bandDefaultId = ElevenLabsVoice.defaultVoiceIdForBand(band);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2D1B69), Color(0xFF1A0E3A)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  children: [
                    const Icon(Icons.record_voice_over, color: AppColors.gold, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Choose a Voice',
                      style: GoogleFonts.cinzelDecorative(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white12, height: 1),

              // Voice list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: ElevenLabsVoice.curated.length,
                  itemBuilder: (_, index) {
                    final voice = ElevenLabsVoice.curated[index];
                    final isSelected = voice.id == selectedId;
                    final isPreviewing = _previewingVoiceId == voice.id;

                    return _VoiceCard(
                      voice: voice,
                      isSelected: isSelected,
                      isBandDefault: voice.id == bandDefaultId,
                      isPreviewing: isPreviewing,
                      isLoadingPreview: isPreviewing && _isLoadingPreview,
                      onSelect: () {
                        ref
                            .read(voicePreferenceNotifierProvider.notifier)
                            .setVoice(voice.id);
                        Navigator.of(context).pop();
                      },
                      onPreview: () => _preview(voice.id),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VoiceCard extends StatelessWidget {
  final ElevenLabsVoice voice;
  final bool isSelected;
  final bool isBandDefault;
  final bool isPreviewing;
  final bool isLoadingPreview;
  final VoidCallback onSelect;
  final VoidCallback onPreview;

  const _VoiceCard({
    required this.voice,
    required this.isSelected,
    required this.isBandDefault,
    required this.isPreviewing,
    required this.isLoadingPreview,
    required this.onSelect,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.gold.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.12),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Gender icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.gold.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    voice.gender == 'female'
                        ? Icons.face
                        : Icons.face_2,
                    color: isSelected ? AppColors.gold : Colors.white70,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Name + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            voice.name,
                            style: GoogleFonts.quicksand(
                              color: isSelected ? AppColors.gold : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isBandDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.gold.withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                '★ Recommended',
                                style: GoogleFonts.quicksand(
                                  color: AppColors.gold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        voice.description,
                        style: GoogleFonts.quicksand(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _Chip(voice.accent),
                          if (voice.ageHint != 'all ages') ...[
                            const SizedBox(width: 6),
                            _Chip(voice.ageHint),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Preview button
                _PreviewButton(
                  isLoading: isLoadingPreview,
                  isActive: isPreviewing && !isLoadingPreview,
                  onTap: onPreview,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.quicksand(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PreviewButton extends StatelessWidget {
  final bool isLoading;
  final bool isActive;
  final VoidCallback onTap;

  const _PreviewButton({
    required this.isLoading,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.gold.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? AppColors.gold : Colors.white24,
          ),
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              )
            : Icon(
                isActive ? Icons.volume_up : Icons.play_arrow,
                color: isActive ? AppColors.gold : Colors.white54,
                size: 20,
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/wizard_data.dart';
import '../models.dart';
import '../services/app_tts_service.dart';
import '../theme/age_band_theme.dart';
import '../theme/app_theme.dart';

/// Dispatcher — renders the age-appropriate "Imagine It" input for each band.
///
/// Sprout    (3-5):  large voice button + illustrated tile grid + caregiver fallback
/// Explorer  (6-8):  idea starter chips + text field + voice button
/// Adventurer(9-11): genre chips + text field + Surprise Me
/// Creator+ (12+):   clean text area + optional advanced controls
class BandAdaptiveImagineIt extends StatefulWidget {
  final WizardData wizardData;

  const BandAdaptiveImagineIt({super.key, required this.wizardData});

  @override
  State<BandAdaptiveImagineIt> createState() => _BandAdaptiveImagineItState();
}

class _BandAdaptiveImagineItState extends State<BandAdaptiveImagineIt> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String? _confirmedVoiceText; // shown after successful voice capture

  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController =
        TextEditingController(text: widget.wizardData.customElements);
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }

  // ── Voice helpers ─────────────────────────────────────────────────────────

  Future<void> _startListening({Duration timeout = const Duration(seconds: 15)}) async {
    final available = await _speech.initialize();
    if (!available || !mounted) return;
    setState(() => _isListening = true);
    _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        listenFor: timeout,
      ),
      onResult: (result) {
        if (result.finalResult && mounted) {
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) {
            setState(() {
              _isListening = false;
              _confirmedVoiceText = words;
              _textController.text = words;
              widget.wizardData.customElements = words;
            });
          } else {
            setState(() => _isListening = false);
          }
        }
      },
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
  }

  void _onTextChanged(String value) {
    widget.wizardData.customElements = value;
    if (_confirmedVoiceText != null && mounted) {
      setState(() => _confirmedVoiceText = null);
    }
  }

  // ── Entry point ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    return switch (band.band) {
      AgeBand.sprout     => _SproutInput(
          isListening: _isListening,
          confirmedText: _confirmedVoiceText,
          onVoiceTap: () async {
            if (_isListening) {
              await _stopListening();
            } else {
              await AppTtsService.instance.speak('Where do you want to go?');
              await _startListening(timeout: const Duration(seconds: 12));
            }
          },
          onTileSelected: (value) {
            setState(() {
              _confirmedVoiceText = null;
              _textController.text = value;
              widget.wizardData.customElements = value;
            });
          },
          selectedValue: widget.wizardData.customElements,
          onCaregiverType: (value) {
            setState(() {
              _confirmedVoiceText = null;
              _textController.text = value;
              widget.wizardData.customElements = value;
            });
          },
          band: band,
        ),
      AgeBand.explorer   => _ExplorerInput(
          controller: _textController,
          isListening: _isListening,
          onVoiceTap: () async {
            if (_isListening) {
              await _stopListening();
            } else {
              await _startListening();
            }
          },
          onChanged: _onTextChanged,
          band: band,
        ),
      AgeBand.adventurer => _AdventurerInput(
          controller: _textController,
          isListening: _isListening,
          onVoiceTap: () async {
            if (_isListening) {
              await _stopListening();
            } else {
              await _startListening();
            }
          },
          onChanged: _onTextChanged,
          band: band,
        ),
      _ => _MatureInput(
          controller: _textController,
          onChanged: _onTextChanged,
          band: band,
          wizardData: widget.wizardData,
        ),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SPROUT (3-5): Big voice button + tile grid + caregiver fallback
// ═══════════════════════════════════════════════════════════════════════════

class _SproutInput extends StatelessWidget {
  final bool isListening;
  final String? confirmedText;
  final VoidCallback onVoiceTap;
  final ValueChanged<String> onTileSelected;
  final ValueChanged<String> onCaregiverType;
  final String selectedValue;
  final AgeBandThemeData band;

  const _SproutInput({
    required this.isListening,
    required this.confirmedText,
    required this.onVoiceTap,
    required this.onTileSelected,
    required this.onCaregiverType,
    required this.selectedValue,
    required this.band,
  });

  static const _tiles = [
    _Tile('🏰', 'A magical castle', 'Castle'),
    _Tile('🌊', 'Under the ocean', 'Ocean'),
    _Tile('🚀', 'Outer space', 'Space'),
    _Tile('🌲', 'An enchanted forest', 'Forest'),
    _Tile('🍭', 'A candy land', 'Candy Land'),
    _Tile('🦕', 'Dinosaur world', 'Dinosaurs'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Big voice button ─────────────────────────────────────────────
        _SproutVoiceButton(isListening: isListening, onTap: onVoiceTap, band: band),
        const SizedBox(height: 16),

        // ── Confirmation text ────────────────────────────────────────────
        if (confirmedText != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: band.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '✨ "$confirmedText"',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: band.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── "or pick a place" divider ────────────────────────────────────
        Row(children: [
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'or pick a place',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.3))),
        ]),
        const SizedBox(height: 12),

        // ── Tile grid ────────────────────────────────────────────────────
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: _tiles.map((tile) {
            final isSelected = selectedValue == tile.value;
            return _SproutTile(
              tile: tile,
              isSelected: isSelected,
              band: band,
              onTap: () => onTileSelected(tile.value),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // ── Caregiver fallback ───────────────────────────────────────────
        TextButton(
          onPressed: () => _showCaregiverSheet(context),
          child: Text(
            'Grown-up? Type something different',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: Colors.white60,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white60,
            ),
          ),
        ),
      ],
    );
  }

  void _showCaregiverSheet(BuildContext context) {
    final controller = TextEditingController(text: selectedValue);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type your child\'s story setting',
                style: GoogleFonts.nunito(
                  fontSize: 18, fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                )),
            const SizedBox(height: 12),
            Semantics(
              label: 'Story setting',
              textField: true,
              child: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'e.g. A candy house in the clouds...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: band.primary, width: 2)),
              ),
              onChanged: onCaregiverType,
            ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: band.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  onCaregiverType(controller.text);
                  Navigator.of(context).pop();
                },
                child: Text('Done',
                    style: GoogleFonts.nunito(
                      fontSize: 16, fontWeight: FontWeight.bold,
                      color: Colors.white,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SproutVoiceButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onTap;
  final AgeBandThemeData band;

  const _SproutVoiceButton({
    required this.isListening,
    required this.onTap,
    required this.band,
  });

  @override
  State<_SproutVoiceButton> createState() => _SproutVoiceButtonState();
}

class _SproutVoiceButtonState extends State<_SproutVoiceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) {
              final scale = widget.isListening
                  ? 1.0 + _pulse.value * 0.12
                  : 1.0;
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isListening
                    ? Colors.red.shade400
                    : widget.band.primary,
                boxShadow: [
                  BoxShadow(
                    color: (widget.isListening
                            ? Colors.red
                            : widget.band.primary)
                        .withValues(alpha: 0.5),
                    blurRadius: widget.isListening ? 32 : 16,
                    spreadRadius: widget.isListening ? 8 : 2,
                  ),
                ],
              ),
              child: Icon(
                widget.isListening ? Icons.mic : Icons.mic_none_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.isListening ? 'Listening... tap to stop' : 'Tap to tell me!',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _SproutTile extends StatelessWidget {
  final _Tile tile;
  final bool isSelected;
  final AgeBandThemeData band;
  final VoidCallback onTap;

  const _SproutTile({
    required this.tile,
    required this.isSelected,
    required this.band,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        decoration: BoxDecoration(
          color: isSelected
              ? band.primary.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? band.accent : Colors.white24,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: band.accent.withValues(alpha: 0.4), blurRadius: 12)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tile.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 4),
            Text(
              tile.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EXPLORER (6-8): Idea starter chips + text field + voice button
// ═══════════════════════════════════════════════════════════════════════════

class _ExplorerInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isListening;
  final VoidCallback onVoiceTap;
  final ValueChanged<String> onChanged;
  final AgeBandThemeData band;

  const _ExplorerInput({
    required this.controller,
    required this.isListening,
    required this.onVoiceTap,
    required this.onChanged,
    required this.band,
  });

  static const _chips = [
    _Tile('🌲', 'An enchanted forest', 'Enchanted Forest'),
    _Tile('🚀', 'Outer space', 'Outer Space'),
    _Tile('🌊', 'Under the ocean', 'Under the Ocean'),
    _Tile('🍭', 'A candy kingdom', 'Candy Kingdom'),
    _Tile('🦕', 'Dinosaur island', 'Dinosaur Island'),
    _Tile('🏫', 'A magic school', 'Magic School'),
  ];

  @override
  Widget build(BuildContext context) {
    return _ImagineItContainer(
      band: band,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'What amazing place should your story happen in?',
            style: GoogleFonts.quicksand(
              fontSize: 16, fontWeight: FontWeight.bold,
              color: band.primary,
            ),
          ),
          const SizedBox(height: 12),

          // Idea starter chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _chips.map((chip) => _IdeaChip(
              tile: chip,
              band: band,
              onTap: () {
                controller.text = chip.value;
                onChanged(chip.value);
              },
            )).toList(),
          ),
          const SizedBox(height: 14),

          // Text field with voice suffix
          Semantics(
            label: 'Story idea',
            textField: true,
            child: TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 500,
            style: GoogleFonts.quicksand(fontSize: 15, color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: 'Type or say your idea...',
              hintStyle: TextStyle(
                color: AppColors.textDark.withValues(alpha: 0.4),
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: band.primary.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: band.primary, width: 2),
              ),
              filled: true,
              fillColor: band.primary.withValues(alpha: 0.05),
              suffixIcon: _VoiceSuffixButton(
                isListening: isListening,
                onTap: onVoiceTap,
                band: band,
              ),
            ),
            onChanged: onChanged,
          ),
          ),

          // Persistent examples strip
          const SizedBox(height: 10),
          Text(
            'Ideas: enchanted forest · outer space · under the ocean · candy kingdom',
            style: GoogleFonts.quicksand(
              fontSize: 12,
              color: AppColors.textDark.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ADVENTURER (9-11): Genre chips + text field + Surprise Me + word count
// ═══════════════════════════════════════════════════════════════════════════

class _AdventurerInput extends StatefulWidget {
  final TextEditingController controller;
  final bool isListening;
  final VoidCallback onVoiceTap;
  final ValueChanged<String> onChanged;
  final AgeBandThemeData band;

  const _AdventurerInput({
    required this.controller,
    required this.isListening,
    required this.onVoiceTap,
    required this.onChanged,
    required this.band,
  });

  @override
  State<_AdventurerInput> createState() => _AdventurerInputState();
}

class _AdventurerInputState extends State<_AdventurerInput> {
  String? _selectedGenre;

  static const _genres = ['Fantasy', 'Sci-Fi', 'Mystery', 'Realistic', 'Horror-Lite', 'Mashup'];

  static const _surprisePrompts = [
    'A haunted library floating in the clouds',
    'A city built inside a giant sleeping robot',
    'The last forest on a planet made of metal',
    'An underground ocean where fish carry lanterns',
    'A school where every student has one secret power',
    'A map that changes every time you look away',
    'A storm that freezes time wherever it lands',
    'A village hidden inside a volcano that never erupts',
  ];

  int _wordCount(String text) =>
      text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  String _badge(int count) {
    if (count >= 25) return 'Inferno 🔥';
    if (count >= 10) return 'Flame 🌟';
    if (count > 0) return 'Spark ✨';
    return '';
  }

  void _surprise() {
    final prompts = List<String>.from(_surprisePrompts)..shuffle();
    final picked = prompts.first;
    widget.controller.text = picked;
    widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final wc = _wordCount(widget.controller.text);
    final badge = _badge(wc);

    return _ImagineItContainer(
      band: widget.band,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Set the scene for your story.',
            style: GoogleFonts.getFont(
              widget.band.uiFontFamily,
              fontSize: 16, fontWeight: FontWeight.bold,
              color: widget.band.primary,
            ),
          ),
          const SizedBox(height: 12),

          // Genre chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _genres.map((g) {
              final selected = _selectedGenre == g;
              return FilterChip(
                label: Text(g,
                  style: GoogleFonts.getFont(
                    widget.band.uiFontFamily,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? Colors.white : widget.band.primary,
                  )),
                selected: selected,
                onSelected: (_) => setState(() {
                  _selectedGenre = selected ? null : g;
                  if (!selected) {
                    final note = widget.controller.text.isNotEmpty
                        ? widget.controller.text
                        : '';
                    // Prepend genre hint if field is empty
                    if (note.isEmpty) {
                      widget.controller.text = '[$g setting] ';
                      widget.onChanged(widget.controller.text);
                    }
                  }
                }),
                selectedColor: widget.band.primary,
                backgroundColor: widget.band.primary.withValues(alpha: 0.08),
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: selected
                      ? widget.band.primary
                      : widget.band.primary.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Text field + word count badge
          Stack(
            children: [
              Semantics(
                label: 'World description',
                textField: true,
                child: TextField(
                controller: widget.controller,
                maxLines: 4,
                maxLength: 500,
                style: GoogleFonts.getFont(
                  widget.band.uiFontFamily,
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Describe the world, the atmosphere, what makes it unique...',
                  hintStyle: TextStyle(
                    color: AppColors.textDark.withValues(alpha: 0.4),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: widget.band.primary.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: widget.band.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: widget.band.primary.withValues(alpha: 0.05),
                  contentPadding:
                      const EdgeInsets.fromLTRB(14, 12, 52, 36),
                  suffixIcon: Align(
                    alignment: Alignment.topRight,
                    widthFactor: 1.0,
                    heightFactor: 1.0,
                    child: _VoiceSuffixButton(
                      isListening: widget.isListening,
                      onTap: widget.onVoiceTap,
                      band: widget.band,
                    ),
                  ),
                ),
                onChanged: (v) {
                  widget.onChanged(v);
                  setState(() {}); // refresh word count
                },
              ),
              ),
              if (badge.isNotEmpty)
                Positioned(
                  bottom: 8,
                  right: 10,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      badge,
                      key: ValueKey(badge),
                      style: GoogleFonts.getFont(
                        widget.band.uiFontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.band.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Surprise Me button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _surprise,
              icon: const Text('🎲', style: TextStyle(fontSize: 16)),
              label: Text(
                'Surprise Me',
                style: GoogleFonts.getFont(
                  widget.band.uiFontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: widget.band.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CREATOR / ADOLESCENT / ADULT: Clean text area + optional advanced controls
// ═══════════════════════════════════════════════════════════════════════════

class _MatureInput extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final AgeBandThemeData band;
  final WizardData wizardData;

  const _MatureInput({
    required this.controller,
    required this.onChanged,
    required this.band,
    required this.wizardData,
  });

  @override
  State<_MatureInput> createState() => _MatureInputState();
}

class _MatureInputState extends State<_MatureInput> {
  bool _advancedOpen = false;
  String? _genre;
  String? _tone;
  String? _pov;

  @override
  void initState() {
    super.initState();
    _genre = widget.wizardData.selectedGenre;
  }

  void _applyAdvanced({String? genre, String? tone, String? pov}) {
    setState(() {
      if (genre != null) _genre = genre;
      if (tone != null) _tone = tone;
      if (pov != null) _pov = pov;
    });
    // Write genre to the dedicated WizardData field
    widget.wizardData.selectedGenre = _genre;
    // Append tone/POV as a natural-language suffix in customElements
    _updateCustomElements();
  }

  void _updateCustomElements() {
    final base = widget.controller.text
        .replaceAll(RegExp(r'\s*\[.*?\]\s*$'), '') // strip any prior suffix
        .trimRight();
    final parts = <String>[];
    if (_tone != null) parts.add('Tone: $_tone');
    if (_pov != null) parts.add('POV: $_pov');
    final suffix = parts.isEmpty ? '' : ' [${parts.join(', ')}]';
    final full = '$base$suffix';
    widget.controller.text = full;
    widget.onChanged(full);
  }

  static const _genres = [
    'Fantasy', 'Sci-Fi', 'Mystery', 'Thriller',
    'Romance', 'Horror', 'Realistic', 'Historical', 'Mashup',
  ];
  static const _tones = ['Light', 'Dark', 'Bittersweet', 'Hopeful', 'Balanced'];
  static const _povs = ['First person', 'Third person'];

  bool get _isDark =>
      widget.band.band == AgeBand.creator ||
      widget.band.band == AgeBand.adolescent ||
      widget.band.band == AgeBand.adult;

  Color get _surface => _isDark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.white;

  Color get _textColor => _isDark ? Colors.white : AppColors.textDark;

  Color get _hintColor => _isDark
      ? Colors.white.withValues(alpha: 0.3)
      : AppColors.textDark.withValues(alpha: 0.4);

  String get _placeholder {
    return switch (widget.band.band) {
      AgeBand.adult      => 'Set the scene. Describe the world, tone, or feeling...',
      AgeBand.adolescent => 'Describe the world you want to explore...',
      _                  => 'Describe your world. Setting, atmosphere, anything that matters...',
    };
  }

  String get _title {
    return switch (widget.band.band) {
      AgeBand.adult      => 'Set the scene.',
      AgeBand.adolescent => 'Describe your world.',
      _                  => 'Describe your world.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(widget.band.band == AgeBand.adult ? 8 : 12),
        border: Border(
          left: BorderSide(color: widget.band.primary, width: 3),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            _title,
            style: GoogleFonts.getFont(
              widget.band.uiFontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: widget.band.primary,
            ),
          ),
          const SizedBox(height: 10),

          // Text area
          Semantics(
            label: 'Story idea',
            textField: true,
            child: TextField(
            controller: widget.controller,
            maxLines: 5,
            maxLength: 500,
            style: GoogleFonts.getFont(
              widget.band.uiFontFamily,
              fontSize: 14,
              color: _textColor,
            ),
            decoration: InputDecoration(
              hintText: _placeholder,
              hintStyle: TextStyle(
                color: _hintColor,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: widget.band.primary.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: widget.band.primary, width: 1.5),
              ),
              filled: true,
              fillColor: widget.band.primary.withValues(alpha: 0.04),
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: widget.onChanged,
          ),
          ),
          const SizedBox(height: 8),

          // Privacy note
          Row(
            children: [
              Icon(Icons.lock_outline, size: 12,
                  color: _textColor.withValues(alpha: 0.4)),
              const SizedBox(width: 4),
              Text(
                'Private to you and the story engine',
                style: GoogleFonts.getFont(
                  widget.band.uiFontFamily,
                  fontSize: 11,
                  color: _textColor.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),

          // Advanced controls (Creator+)
          if (widget.band.band.isMature) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _advancedOpen = !_advancedOpen),
              child: Row(
                children: [
                  Text(
                    'Advanced',
                    style: GoogleFonts.getFont(
                      widget.band.uiFontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.band.primary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _advancedOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down,
                        size: 16,
                        color: widget.band.primary.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _advancedOpen
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _AdvancedDropdown(
                            label: 'Genre',
                            value: _genre,
                            items: _genres,
                            band: widget.band,
                            textColor: _textColor,
                            onChanged: (v) => _applyAdvanced(genre: v),
                          ),
                          _AdvancedDropdown(
                            label: 'Tone',
                            value: _tone,
                            items: _tones,
                            band: widget.band,
                            textColor: _textColor,
                            onChanged: (v) => _applyAdvanced(tone: v),
                          ),
                          _AdvancedDropdown(
                            label: 'POV',
                            value: _pov,
                            items: _povs,
                            band: widget.band,
                            textColor: _textColor,
                            onChanged: (v) => _applyAdvanced(pov: v),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

/// Shared themed container (Explorer and Adventurer bands)
class _ImagineItContainer extends StatelessWidget {
  final Widget child;
  final AgeBandThemeData band;

  const _ImagineItContainer({required this.child, required this.band});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: band.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: band.primary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Idea starter chip (Explorer)
class _IdeaChip extends StatelessWidget {
  final _Tile tile;
  final AgeBandThemeData band;
  final VoidCallback onTap;

  const _IdeaChip({required this.tile, required this.band, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: band.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: band.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tile.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              tile.label,
              style: GoogleFonts.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: band.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Voice mic button for Explorer — larger and animated than the old suffix icon
class _VoiceSuffixButton extends StatelessWidget {
  final bool isListening;
  final VoidCallback onTap;
  final AgeBandThemeData band;

  const _VoiceSuffixButton({
    required this.isListening,
    required this.onTap,
    required this.band,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(6),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isListening
              ? Colors.red.shade400
              : band.primary.withValues(alpha: 0.15),
          border: Border.all(
            color: isListening ? Colors.red : band.primary,
            width: 1.5,
          ),
        ),
        child: Icon(
          isListening ? Icons.mic : Icons.mic_none_rounded,
          size: 20,
          color: isListening ? Colors.white : band.primary,
        ),
      ),
    );
  }
}

/// Advanced genre/tone/POV dropdown for mature bands
class _AdvancedDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final AgeBandThemeData band;
  final Color textColor;
  final ValueChanged<String?> onChanged;

  const _AdvancedDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.band,
    required this.textColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: band.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: band.primary.withValues(alpha: 0.25)),
        ),
        child: DropdownButton<String>(
          value: value,
          hint: Text(label,
              style: GoogleFonts.getFont(
                band.uiFontFamily,
                fontSize: 12,
                color: textColor.withValues(alpha: 0.5),
              )),
          items: items.map((s) => DropdownMenuItem(
            value: s,
            child: Text(s,
                style: GoogleFonts.getFont(
                  band.uiFontFamily,
                  fontSize: 13,
                  color: textColor,
                )),
          )).toList(),
          onChanged: onChanged,
          dropdownColor: band.gradientStart,
          isDense: true,
          style: GoogleFonts.getFont(
            band.uiFontFamily,
            fontSize: 13,
            color: textColor,
          ),
          icon: Icon(Icons.keyboard_arrow_down,
              size: 16, color: band.primary),
        ),
      ),
    );
  }
}

// ─── Data class ──────────────────────────────────────────────────────────────

class _Tile {
  final String emoji;
  final String value; // sent to customElements
  final String label; // shown in UI

  const _Tile(this.emoji, this.value, this.label);
}

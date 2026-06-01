import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart';
import '../../services/app_tts_service.dart';
import '../../models.dart';
import '../../theme/age_band_theme.dart';

class HeroPetCard extends StatefulWidget {
  final WizardData wizardData;
  final Future<void> Function({int? petIndex}) onPickPhoto;
  final VoidCallback onChanged;
  final Future<void> Function({required int petIndex, required String name, required String species, required String description})? onSaveCompanion;
  /// When non-null, creates a new companion with this species and opens the
  /// editor. The parent should reset this to null after the card processes it.
  final String? pendingNewSpecies;
  final VoidCallback? onPendingConsumed;

  const HeroPetCard({
    super.key,
    required this.wizardData,
    required this.onPickPhoto,
    required this.onChanged,
    this.onSaveCompanion,
    this.pendingNewSpecies,
    this.onPendingConsumed,
  });

  @override
  State<HeroPetCard> createState() => _HeroPetCardState();
}

class _HeroPetCardState extends State<HeroPetCard> {
  late TextEditingController _nameCtrl;
  late TextEditingController _colorCtrl;
  String _species = 'Dog';
  int _selectedPetIndex = -1;
  bool _isEditing = false;
  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  String _listeningField = '';

  static const _speciesOptions = [
    'Human',
    'Dog',
    'Cat',
    'Bird',
    'Rabbit',
    'Hamster',
    'Fish',
    'Turtle',
    'Snake',
    'Horse',
    'Guinea Pig',
    'Other',
  ];

  Map<String, String>? get _pet {
    if (_selectedPetIndex < 0 ||
        _selectedPetIndex >= widget.wizardData.pets.length) {
      return null;
    }
    return widget.wizardData.pets[_selectedPetIndex];
  }

  String? get _photo {
    final name = _pet?['name'] ?? 'My Pet';
    return widget.wizardData.petAvatars[name]?.imageBase64 ??
        widget.wizardData.petPhotos[name];
  }

  @override
  void initState() {
    super.initState();
    if (widget.wizardData.pets.isNotEmpty) {
      _selectedPetIndex = 0;
    }
    _nameCtrl = TextEditingController();
    _colorCtrl = TextEditingController();
    _loadFromSelectedPet();
    _initVoiceHelpers();
  }

  @override
  void didUpdateWidget(covariant HeroPetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedPetIndex >= widget.wizardData.pets.length) {
      _selectedPetIndex = widget.wizardData.pets.isEmpty
          ? -1
          : widget.wizardData.pets.length - 1;
      _loadFromSelectedPet();
    }
    if (widget.pendingNewSpecies != null &&
        widget.pendingNewSpecies != oldWidget.pendingNewSpecies) {
      final species = widget.pendingNewSpecies!.split(':').first;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        _addCompanionWithType(species);
        widget.onPendingConsumed?.call();
        // The "Add from Photo" / "Add My Pet" buttons take their name
        // seriously — the user expects a photo prompt immediately, not a
        // hidden empty entry they have to find and tap into. Auto-trigger
        // the picker for the just-added pet.
        final newIndex = widget.wizardData.pets.length - 1;
        if (newIndex >= 0 && mounted) {
          await widget.onPickPhoto(petIndex: newIndex);
        }
      });
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _initVoiceHelpers() async {
    _speechReady = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _listeningField = '');
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _listeningField = '');
      },
    );
  }

  Future<void> _speakPrompt(String text) async {
    unawaited(AppTtsService.instance.speak(text));
  }

  Future<void> _toggleVoiceInput({
    required String fieldKey,
    required TextEditingController controller,
    required String prompt,
  }) async {
    if (!_speechReady) {
      unawaited(
          AppTtsService.instance.speak('Microphone is unavailable right now.'));
      return;
    }
    if (_listeningField == fieldKey) {
      await _speech.stop();
      if (mounted) setState(() => _listeningField = '');
      return;
    }

    unawaited(AppTtsService.instance.speak(prompt));
    if (mounted) setState(() => _listeningField = fieldKey);

    await _speech.listen(
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 2),
      ),
      onResult: (result) {
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;
        if (mounted) {
          setState(() {
            controller.text = words;
          });
          _updatePet();
        }
        if (result.finalResult) {
          _speech.stop();
          if (mounted) setState(() => _listeningField = '');
        }
      },
    );
  }

  Widget _buildVoiceField({
    required TextEditingController controller,
    required String hint,
    required String fieldKey,
    required String speakPrompt,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _petFieldDecoration(hint),
            onChanged: (_) => _updatePet(),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Read prompt aloud',
          icon: const Icon(Icons.volume_up_rounded,
              color: Color(0xFFFFD700), size: 20),
          onPressed: () => _speakPrompt(speakPrompt),
        ),
        IconButton(
          tooltip: _speechReady ? 'Tap and speak' : 'Mic unavailable',
          icon: Icon(
            _listeningField == fieldKey ? Icons.mic : Icons.mic_none,
            color: _speechReady
                ? (_listeningField == fieldKey
                    ? const Color(0xFFFFD700)
                    : Colors.white70)
                : Colors.white38,
            size: 20,
          ),
          onPressed: () => _toggleVoiceInput(
            fieldKey: fieldKey,
            controller: controller,
            prompt: speakPrompt,
          ),
        ),
      ],
    );
  }

  void _updatePet() {
    if (_selectedPetIndex < 0 ||
        _selectedPetIndex >= widget.wizardData.pets.length) {
      return;
    }
    final oldName = _pet?['name'] ?? 'My Pet';
    final newName = _nameCtrl.text.trim().isEmpty
        ? 'My Pet ${_selectedPetIndex + 1}'
        : _nameCtrl.text.trim();
    final photo = widget.wizardData.petPhotos[oldName];
    widget.wizardData.pets[_selectedPetIndex] = {
      'name': newName,
      'species': _species,
      'color': _colorCtrl.text.trim(),
      'personality': '',
    };
    if (photo != null && oldName != newName) {
      widget.wizardData.petPhotos.remove(oldName);
      widget.wizardData.petPhotos[newName] = photo;
    }
    final generated = widget.wizardData.petAvatars[oldName];
    if (generated != null && oldName != newName) {
      widget.wizardData.petAvatars.remove(oldName);
      widget.wizardData.petAvatars[newName] = generated;
    }
    if (widget.wizardData.companionNames.contains(oldName) &&
        oldName != newName) {
      widget.wizardData.companionNames.remove(oldName);
      widget.wizardData.companionNames.add(newName);
    }
    widget.onChanged();
  }

  void _loadFromSelectedPet() {
    final pet = _pet;
    _nameCtrl.text = pet?['name'] ?? '';
    _colorCtrl.text = pet?['color'] ?? '';
    _species = pet?['species'] ?? 'Dog';
  }

  void _selectPet(int index, {bool edit = false}) {
    if (index < 0 || index >= widget.wizardData.pets.length) return;
    setState(() {
      _selectedPetIndex = index;
      _isEditing = edit;
      _loadFromSelectedPet();
    });
  }

  void _addAnotherPet() => _addCompanionWithType('Dog');

  void _addCompanionWithType(String species) {
    final nextIndex = widget.wizardData.pets.length;
    widget.wizardData.pets.add({
      'name': '',
      'species': species,
      'color': '',
      'personality': '',
    });
    final petId = 'my_pet_$nextIndex';
    if (!widget.wizardData.selectedCompanions.contains(petId)) {
      widget.wizardData.selectedCompanions.add(petId);
    }
    widget.onChanged();
    _selectPet(nextIndex, edit: true);
  }

  @override
  Widget build(BuildContext context) {
    final hasPet = widget.wizardData.pets.isNotEmpty;
    final photo = _photo;

    if (!hasPet) {
      return GestureDetector(
        onTap: () async {
          await widget.onPickPhoto(petIndex: 0);
          if (!mounted) return;
          setState(() {
            if (widget.wizardData.pets.isNotEmpty) {
              _selectedPetIndex = 0;
              _isEditing = true;
              _loadFromSelectedPet();
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFFD700).withAlpha(160),
              width: 2,
            ),
            gradient: const LinearGradient(
              colors: [Color(0xFF2C1B47), Color(0xFF1A0E36)],
            ),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFFFD700).withAlpha(35), blurRadius: 12),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD700).withAlpha(40),
                ),
                child: const Icon(Icons.add_a_photo_rounded,
                    color: Color(0xFFFFD700), size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bring Your Companion!',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        )),
                    SizedBox(height: 3),
                    Text(
                      'Add a photo and we\'ll put them in the story',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedPetIndex == -1) {
      _selectedPetIndex = 0;
      _loadFromSelectedPet();
    }

    if (!_isEditing) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFFFFD700).withAlpha(150), width: 1.5),
          color: const Color(0xFF2C1B47),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < widget.wizardData.pets.length; i++)
                  ChoiceChip(
                    label: Text(
                        widget.wizardData.pets[i]['name'] ?? 'Pet ${i + 1}'),
                    selected: i == _selectedPetIndex,
                    selectedColor: const Color(0xFFFFD700).withAlpha(40),
                    labelStyle: TextStyle(
                      color: i == _selectedPetIndex
                          ? const Color(0xFFFFD700)
                          : Colors.white70,
                      fontSize: 12,
                    ),
                    onSelected: (_) => _selectPet(i),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF3A2363),
                  backgroundImage: photo != null && photo.isNotEmpty
                      ? MemoryImage(base64Decode(
                          photo.replaceFirst(RegExp(r'data:[^,]+,'), '')))
                      : null,
                  child: photo == null || photo.isEmpty
                      ? Icon(_species == 'Human' ? Icons.person : Icons.pets, color: Colors.white70)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Builder(builder: (context) {
                    final band = Theme.of(context).extension<AgeBandThemeData>();
                    final useCompanion = band != null &&
                        band.band != AgeBand.sprout &&
                        band.band != AgeBand.explorer;
                    return Text(
                      useCompanion
                          ? 'Your companion is ready! 🌟'
                          : 'Your buddy is ready! 🌟',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    );
                  }),
                ),
                TextButton(
                  onPressed: () => setState(() => _isEditing = true),
                  child: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _addAnotherPet,
                  icon: const Icon(Icons.add),
                  label: const Text('Add another companion'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      widget.onPickPhoto(petIndex: _selectedPetIndex),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Change photo'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Companion editor card
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFFFFD700).withAlpha(180), width: 2),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C1B47), Color(0xFF1A0E36)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withAlpha(40),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Semantics(
              button: true,
              label: 'Close pet editor',
              child: GestureDetector(
              onTap: () {
                final pet = _pet;
                final name = (pet?['name'] ?? '').trim();
                final isDefault = name.isEmpty ||
                    name == 'My Pet' ||
                    RegExp(r'^My Pet \d+$').hasMatch(name);
                final hasPhoto = _photo != null && _photo!.isNotEmpty;
                if (isDefault && !hasPhoto) {
                  if (_selectedPetIndex >= 0 &&
                      _selectedPetIndex < widget.wizardData.pets.length) {
                    final removedName =
                        widget.wizardData.pets[_selectedPetIndex]['name'] ?? '';
                    widget.wizardData.pets.removeAt(_selectedPetIndex);
                    widget.wizardData.companionNames.remove(removedName);
                    widget.wizardData.selectedCompanions
                        .remove('my_pet_$_selectedPetIndex');
                    widget.onChanged();
                  }
                  setState(() {
                    _selectedPetIndex = widget.wizardData.pets.isEmpty
                        ? -1
                        : widget.wizardData.pets.length - 1;
                    _isEditing = false;
                    _loadFromSelectedPet();
                  });
                } else {
                  setState(() {
                    _isEditing = false;
                    _loadFromSelectedPet();
                  });
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Icon(Icons.close_rounded,
                    color: Colors.white54, size: 22),
              ),
            ),
            ),
          ),
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Change pet photo',
                child: GestureDetector(
                onTap: () => widget.onPickPhoto(petIndex: _selectedPetIndex),
                child: Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFFFD700), width: 2),
                        color: const Color(0xFF3A2363),
                      ),
                      child: ClipOval(
                        child: photo != null && photo.isNotEmpty
                            ? Image.memory(
                                base64Decode(photo.replaceFirst(
                                    RegExp(r'data:[^,]+,'), '')),
                                fit: BoxFit.cover,
                              )
                            : Icon(
                                _species == 'Human' ? Icons.person : Icons.pets,
                                color: Colors.white70, size: 36,
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFD700),
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.black, size: 12),
                      ),
                    ),
                  ],
                ),
              ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    _buildVoiceField(
                      controller: _nameCtrl,
                      hint: _species == 'Human'
                          ? 'Friend\'s name (e.g. Alex)'
                          : 'Pet\'s name (e.g. Biscuit)',
                      fieldKey: 'pet_name',
                      speakPrompt: _species == 'Human'
                          ? 'Say your friend\'s name.'
                          : 'Say your pet\'s name. For example, Whiskers.',
                    ),
                    const SizedBox(height: 8),
                    _buildVoiceField(
                      controller: _colorCtrl,
                      hint: _species == 'Human'
                          ? 'Looks (e.g. brown hair, glasses, blue eyes)'
                          : 'Looks (e.g. golden fur, floppy ears)',
                      fieldKey: 'pet_looks',
                      speakPrompt: _species == 'Human'
                          ? 'Describe what your friend looks like.'
                          : 'Describe what your pet looks like.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _species,
            dropdownColor: const Color(0xFF2C1B47),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _petFieldDecoration('Companion type'),
            items: _speciesOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _species = v);
                _updatePet();
              }
            },
          ),
          const SizedBox(height: 6),
          Text(
            '✨ Bring your companion on your magical adventure!',
            style: TextStyle(
                color: const Color(0xFFFFD700).withAlpha(200),
                fontSize: 11,
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                _updatePet();
                final savedIndex = _selectedPetIndex;
                final savedName = _nameCtrl.text.trim().isEmpty
                    ? 'My Pet${savedIndex > 0 ? ' ${savedIndex + 1}' : ''}'
                    : _nameCtrl.text.trim();
                final savedSpecies = _species;
                final savedDescription = _colorCtrl.text.trim();
                setState(() => _isEditing = false);
                widget.onSaveCompanion?.call(
                  petIndex: savedIndex,
                  name: savedName,
                  species: savedSpecies,
                  description: savedDescription,
                );
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save Companion'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _petFieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFFFD700), fontSize: 13),
        filled: true,
        fillColor: Colors.white.withAlpha(18),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFFFD700).withAlpha(100)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFFFD700).withAlpha(120)),
        ),
      );
}

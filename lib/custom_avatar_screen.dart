import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'avatar_models.dart';
import 'config/environment.dart';
import 'services/api_service_manager.dart';
import 'services/app_tts_service.dart';
import 'theme/age_band_theme.dart';
import 'theme/app_theme.dart';

// ── Step definitions ─────────────────────────────────────────────────────────
enum _AvatarStep { gender, hairColor, eyeColor, favoriteColor, photo }

// ── Main screen ──────────────────────────────────────────────────────────────
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

class _CustomAvatarScreenState extends State<CustomAvatarScreen>
    with SingleTickerProviderStateMixin {
  // Step navigation
  _AvatarStep _step = _AvatarStep.gender;

  // Selections
  String _gender = 'girl';
  String _hairColor = 'Brown';
  String _eyeColor = 'Brown';
  String _favoriteColor = 'Blue';

  // Photo & generation
  Uint8List? _imageBytes;
  bool _isGenerating = false;
  String? _generatedImageBase64;

  // Step transition animation
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ── Age band helpers ────────────────────────────────────────────────────────
  int get _age => widget.initialAge ?? 7;
  AgeBand get _ageBand => ageBandFromAge(_age);
  AgeBandThemeData get _bt => themeForBand(_ageBand);
  bool get _isSprout => _ageBand == AgeBand.sprout;
  bool get _isExplorer => _ageBand == AgeBand.explorer;
  bool get _isCreator => _ageBand == AgeBand.creator;

  // ── Color data ──────────────────────────────────────────────────────────────
  static const _eyeColors = ['Brown', 'Blue', 'Green', 'Hazel', 'Grey'];
  static const _hairColors = ['Black', 'Brown', 'Blonde', 'Red', 'Grey', 'Pink'];
  static const _favoriteColors = [
    'Red', 'Blue', 'Green', 'Yellow', 'Purple', 'Pink', 'Orange', 'Teal', 'Gold'
  ];

  static const Map<String, Color> _eyeSwatches = {
    'Brown': Color(0xFF6D4C41),
    'Blue': Color(0xFF4FC3F7),
    'Green': Color(0xFF66BB6A),
    'Hazel': Color(0xFF8D6E63),
    'Grey': Color(0xFF90A4AE),
  };
  static const Map<String, Color> _hairSwatches = {
    'Black': Color(0xFF1B1B1F),
    'Brown': Color(0xFF6D4C41),
    'Blonde': Color(0xFFFFE082),
    'Red': Color(0xFFE57373),
    'Grey': Color(0xFFB0BEC5),
    'Pink': Color(0xFFF48FB1),
  };
  static const Map<String, Color> _favoriteSwatches = {
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

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();

    // Sprout: auto-speak the first question
    if (_isSprout) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _speakPrompt());
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── TTS ─────────────────────────────────────────────────────────────────────
  void _speakPrompt() {
    AppTtsService.instance.speak(_question(_step));
  }

  // Age-band-adapted question text per step
  String _question(_AvatarStep step) {
    switch (_ageBand) {
      case AgeBand.sprout:
        return const {
          _AvatarStep.gender: 'Are you a girl or a boy?',
          _AvatarStep.hairColor: 'What color is your hair?',
          _AvatarStep.eyeColor: 'What color are your eyes?',
          _AvatarStep.favoriteColor: 'What is your favorite color?',
          _AvatarStep.photo: "Let's take a photo of your face!",
        }[step]!;
      case AgeBand.explorer:
        return const {
          _AvatarStep.gender: 'Choose your hero\'s style!',
          _AvatarStep.hairColor: 'Pick your hair color!',
          _AvatarStep.eyeColor: 'Pick your eye color!',
          _AvatarStep.favoriteColor: 'Pick your hero\'s outfit color!',
          _AvatarStep.photo: 'Add a photo so we can paint your face!',
        }[step]!;
      case AgeBand.adventurer:
        return const {
          _AvatarStep.gender: 'Choose your character\'s style',
          _AvatarStep.hairColor: 'Select your hair color',
          _AvatarStep.eyeColor: 'Select your eye color',
          _AvatarStep.favoriteColor: 'Pick an outfit color',
          _AvatarStep.photo: 'Add a reference photo',
        }[step]!;
      case AgeBand.creator:
        return const {
          _AvatarStep.gender: 'Character style',
          _AvatarStep.hairColor: 'Hair color',
          _AvatarStep.eyeColor: 'Eye color',
          _AvatarStep.favoriteColor: 'Outfit color',
          _AvatarStep.photo: 'Reference photo',
        }[step]!;
    }
  }

  String _subtitle(_AvatarStep step) {
    if (_isSprout || _isCreator) return '';
    return const {
      _AvatarStep.gender: 'Your hero will look just like you!',
      _AvatarStep.hairColor: 'Tap the color that matches yours',
      _AvatarStep.eyeColor: 'Tap the color that matches yours',
      _AvatarStep.favoriteColor: 'This colour will be your hero\'s outfit',
      _AvatarStep.photo: 'We\'ll transform your face into your hero',
    }[step]!;
  }

  // ── Step navigation ─────────────────────────────────────────────────────────
  static const _stepOrder = [
    _AvatarStep.gender,
    _AvatarStep.hairColor,
    _AvatarStep.eyeColor,
    _AvatarStep.favoriteColor,
    _AvatarStep.photo,
  ];

  int get _stepIndex => _stepOrder.indexOf(_step);
  bool get _isLastStep => _step == _AvatarStep.photo;

  Future<void> _goForward() async {
    if (_isLastStep) {
      await _generateAvatar();
      return;
    }
    await _animCtrl.reverse();
    if (mounted) {
      setState(() => _step = _stepOrder[_stepIndex + 1]);
      _animCtrl.forward();
      if (_isSprout) _speakPrompt();
    }
  }

  Future<void> _goBack() async {
    if (_stepIndex == 0) {
      Navigator.pop(context);
      return;
    }
    await _animCtrl.reverse();
    if (mounted) {
      setState(() => _step = _stepOrder[_stepIndex - 1]);
      _animCtrl.forward();
    }
  }

  // Auto-advance for Sprout (short delay so selection animation plays)
  void _sproutAutoAdvance() {
    Timer(const Duration(milliseconds: 320), () {
      if (mounted) _goForward();
    });
  }

  // ── Photo helpers ───────────────────────────────────────────────────────────
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (mounted) setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (mounted) setState(() => _imageBytes = bytes);
    }
  }

  // ── Avatar generation (API call unchanged) ──────────────────────────────────
  Future<void> _generateAvatar() async {
    if (_imageBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isSprout
                  ? 'Please take a photo first!'
                  : 'Please add a photo to continue.',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final baseUrl = Environment.backendUrl;
      final url = Uri.parse('$baseUrl/avatar/generate-custom-avatar');

      Future<http.Response> sendRequest() async {
        final request = http.MultipartRequest('POST', url);
        final authHeaders = await ApiServiceManager.authHeaders();
        if (authHeaders.containsKey('Authorization')) {
          request.headers['Authorization'] = authHeaders['Authorization']!;
        }
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            _imageBytes!,
            filename: 'photo.jpg',
          ),
        );
        request.fields['character_name'] = widget.initialName ?? '';
        request.fields['age'] = _age.toString();
        request.fields['gender'] = _gender;
        request.fields['eye_color'] = _eyeColor;
        request.fields['hair_color'] = _hairColor;
        request.fields['favorite_color'] = _favoriteColor;
        debugPrint('📡 Sending custom avatar request to $url');
        final streamed =
            await request.send().timeout(const Duration(minutes: 3));
        return http.Response.fromStream(streamed);
      }

      http.Response response = await sendRequest();
      if (response.statusCode == 401) {
        debugPrint('⚠️ Custom avatar 401; refreshing auth and retrying');
        await ApiServiceManager.resetAndReauthenticate();
        response = await sendRequest();
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final raw = data['avatar']['image_base64'] as String;
          final base64Only = raw.contains(',') ? raw.split(',').last : raw;
          if (mounted) {
            setState(() {
              _generatedImageBase64 = base64Only;
              _isGenerating = false;
            });
            if (_isSprout) {
              AppTtsService.instance.speak('Your magical hero is ready!');
            }
          }
        } else {
          throw Exception(data['message'] ?? 'Generation failed');
        }
      } else {
        String msg = 'Server error: ${response.statusCode}';
        try {
          final body = json.decode(response.body) as Map<String, dynamic>;
          final m = body['message']?.toString();
          if (m != null && m.trim().isNotEmpty) msg = m;
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      debugPrint('❌ Error generating custom avatar: $e');
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(gradient: _bt.backgroundGradient),
        child: SafeArea(
          child: _isGenerating
              ? _buildGeneratingView()
              : _generatedImageBase64 != null
                  ? _buildResultView()
                  : _buildWizardView(),
        ),
      ),
    );
  }

  // ── Wizard shell ────────────────────────────────────────────────────────────
  Widget _buildWizardView() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _isSprout ? 16 : 20,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStepHeader(),
                    SizedBox(height: _isSprout ? 24 : 16),
                    Expanded(child: _buildStepContent()),
                    // Sprout auto-advances on color/gender steps;
                    // Next button only shown on the photo step for sprout,
                    // or every step for older bands.
                    if (!_isSprout || _step == _AvatarStep.photo)
                      _buildNextButton(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Top bar: back + progress dots + TTS ────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _goBack,
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: Colors.white,
              size: _isSprout ? 30 : 22,
            ),
          ),
          Expanded(child: _buildProgressDots()),
          // TTS: always visible for sprout/explorer, hidden for creator
          if (!_isCreator)
            IconButton(
              onPressed: _speakPrompt,
              tooltip: 'Read aloud',
              icon: Icon(
                Icons.volume_up_rounded,
                color: _bt.accent,
                size: _isSprout ? 32 : 24,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_stepOrder.length, (i) {
        final active = i == _stepIndex;
        final done = i < _stepIndex;
        final dotW = active ? (_isSprout ? 26.0 : 20.0) : (_isSprout ? 14.0 : 10.0);
        final dotH = _isSprout ? 14.0 : 10.0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: dotW,
          height: dotH,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: done
                ? _bt.accent.withAlpha(180)
                : active
                    ? _bt.accent
                    : Colors.white.withAlpha(55),
          ),
        );
      }),
    );
  }

  // ── Step header (question + optional subtitle) ──────────────────────────────
  Widget _buildStepHeader() {
    final q = _question(_step);
    final sub = _subtitle(_step);

    if (_isSprout) {
      return Text(
        q,
        textAlign: TextAlign.center,
        style: GoogleFonts.nunito(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.2,
        ),
      );
    }

    return Column(
      children: [
        Text(
          q,
          textAlign: TextAlign.center,
          style: _isCreator
              ? GoogleFonts.sourceSans3(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                )
              : GoogleFonts.quicksand(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
              fontSize: 15,
              color: Colors.white.withAlpha(185),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  // ── Step content router ─────────────────────────────────────────────────────
  Widget _buildStepContent() {
    switch (_step) {
      case _AvatarStep.gender:
        return _buildGenderStep();
      case _AvatarStep.hairColor:
        return _buildColorStep(
          colors: _hairColors,
          swatches: _hairSwatches,
          selected: _hairColor,
          onSelect: (v) {
            setState(() => _hairColor = v);
            if (_isSprout) {
              AppTtsService.instance.speak(v);
              _sproutAutoAdvance();
            }
          },
        );
      case _AvatarStep.eyeColor:
        return _buildColorStep(
          colors: _eyeColors,
          swatches: _eyeSwatches,
          selected: _eyeColor,
          onSelect: (v) {
            setState(() => _eyeColor = v);
            if (_isSprout) {
              AppTtsService.instance.speak(v);
              _sproutAutoAdvance();
            }
          },
        );
      case _AvatarStep.favoriteColor:
        return _buildColorStep(
          colors: _favoriteColors,
          swatches: _favoriteSwatches,
          selected: _favoriteColor,
          onSelect: (v) {
            setState(() => _favoriteColor = v);
            if (_isSprout) {
              AppTtsService.instance.speak(v);
              _sproutAutoAdvance();
            }
          },
        );
      case _AvatarStep.photo:
        return _buildPhotoStep();
    }
  }

  // ── Gender step ─────────────────────────────────────────────────────────────
  Widget _buildGenderStep() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final halfW = (constraints.maxWidth - (_isSprout ? 20.0 : 16.0)) / 2;
        final cardH = constraints.maxHeight * (_isSprout ? 0.62 : 0.52);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildGenderCard(
                value: 'girl', emoji: '👧', label: 'Girl', w: halfW, h: cardH),
            _buildGenderCard(
                value: 'boy', emoji: '👦', label: 'Boy', w: halfW, h: cardH),
          ],
        );
      },
    );
  }

  Widget _buildGenderCard({
    required String value,
    required String emoji,
    required String label,
    required double w,
    required double h,
  }) {
    final sel = _gender == value;
    return GestureDetector(
      onTap: () {
        setState(() => _gender = value);
        if (_isSprout) {
          AppTtsService.instance.speak(label);
          _sproutAutoAdvance();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_bt.cardRadiusBase),
          color: sel
              ? _bt.primary.withAlpha(160)
              : Colors.white.withAlpha(22),
          border: Border.all(
            color: sel ? _bt.accent : Colors.white.withAlpha(55),
            width: sel ? 3 : 1.5,
          ),
          boxShadow: sel
              ? [
                  BoxShadow(
                    color: _bt.accent.withAlpha(90),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji,
                style: TextStyle(fontSize: _isSprout ? 72 : 52)),
            SizedBox(height: _isSprout ? 12 : 8),
            Text(
              label,
              style: _isSprout
                  ? GoogleFonts.nunito(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    )
                  : GoogleFonts.quicksand(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
            ),
            if (sel) ...[
              SizedBox(height: _isSprout ? 10 : 6),
              Icon(
                Icons.check_circle_rounded,
                color: _bt.accent,
                size: _isSprout ? 32 : 22,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Color swatch step ───────────────────────────────────────────────────────
  Widget _buildColorStep({
    required List<String> colors,
    required Map<String, Color> swatches,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    // Swatch sizing per age band
    final swatchSize = _isSprout
        ? 88.0
        : _isExplorer
            ? 72.0
            : _isCreator
                ? 52.0
                : 62.0;
    final showLabel = !_isSprout;

    return Center(
      child: Wrap(
        spacing: _isSprout ? 16 : 12,
        runSpacing: _isSprout ? 20 : 14,
        alignment: WrapAlignment.center,
        children: colors.map((name) {
          final isSelected = name == selected;
          final color = swatches[name] ?? Colors.white;
          return GestureDetector(
            onTap: () => onSelect(name),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: swatchSize,
                  height: swatchSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(
                      color: isSelected
                          ? _bt.accent
                          : Colors.white.withAlpha(70),
                      width: isSelected ? 4.0 : 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? color.withAlpha(150)
                            : Colors.black.withAlpha(35),
                        blurRadius: isSelected ? 18 : 6,
                        spreadRadius: isSelected ? 2 : 0,
                      ),
                    ],
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: swatchSize * 0.44,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 4)
                          ],
                        )
                      : null,
                ),
                if (showLabel) ...[
                  const SizedBox(height: 5),
                  Text(
                    name,
                    style: GoogleFonts.quicksand(
                      fontSize: _isCreator ? 12 : 13,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withAlpha(170),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Photo step ──────────────────────────────────────────────────────────────
  Widget _buildPhotoStep() {
    final previewSize = _isSprout ? 180.0 : 150.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Preview circle / placeholder
        Container(
          width: previewSize,
          height: previewSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _bt.accent.withAlpha(200),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: _bt.accent.withAlpha(55),
                blurRadius: 22,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _imageBytes != null
              ? Image.memory(_imageBytes!, fit: BoxFit.cover)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isSprout
                          ? Icons.camera_alt_rounded
                          : Icons.add_photo_alternate_rounded,
                      size: _isSprout ? 60 : 48,
                      color: Colors.white.withAlpha(200),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isSprout ? 'Your photo' : 'Add photo',
                      style: _isSprout
                          ? GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withAlpha(220),
                            )
                          : GoogleFonts.quicksand(
                              fontSize: 14,
                              color: Colors.white.withAlpha(180),
                            ),
                    ),
                  ],
                ),
        ),
        SizedBox(height: _isSprout ? 28 : 20),
        // Camera / upload buttons
        if (_isSprout) ...[
          Row(
            children: [
              Expanded(
                child: _buildBigIconButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: _bt.primary,
                  onTap: _takePhoto,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBigIconButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Album',
                  color: const Color(0xFF7A3FC8),
                  onTap: _pickFromGallery,
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5F4BDB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(_bt.buttonRadiusBase),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Upload'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7A3FC8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(_bt.buttonRadiusBase),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_imageBytes != null) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => setState(() => _imageBytes = null),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white60),
            label: Text(
              _isSprout ? 'Take again' : 'Retake',
              style: GoogleFonts.quicksand(
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Sprout-style big icon button (used on photo step)
  Widget _buildBigIconButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_bt.cardRadiusBase),
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(100),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 40),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Next / Generate button ──────────────────────────────────────────────────
  Widget _buildNextButton() {
    final canProceed = _step != _AvatarStep.photo || _imageBytes != null;
    final label = _isLastStep
        ? (_isSprout ? 'Make My Hero! ✨' : 'Generate Magic Avatar ✨')
        : (_isSprout ? 'Next!' : 'Next');

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ElevatedButton(
        onPressed: canProceed ? _goForward : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _bt.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white24,
          padding: EdgeInsets.symmetric(vertical: _isSprout ? 18 : 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_bt.buttonRadiusBase),
          ),
          elevation: 3,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: _isSprout
                  ? GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    )
                  : GoogleFonts.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
            ),
            if (!_isLastStep) ...[
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded,
                  size: _isSprout ? 26 : 20),
            ],
          ],
        ),
      ),
    );
  }

  // ── Generating view ─────────────────────────────────────────────────────────
  Widget _buildGeneratingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isSprout) ...[
            const Text('🪄', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 24),
          ],
          const CircularProgressIndicator(color: AppColors.gold),
          const SizedBox(height: 20),
          Text(
            _isSprout
                ? 'Making your magic hero...'
                : 'Brewing your magical avatar...',
            style: _isSprout
                ? GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  )
                : GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSprout
                ? '(This takes about a minute!)'
                : '(Usually about a minute)',
            style: GoogleFonts.quicksand(
              color: Colors.white.withAlpha(195),
              fontSize: _isSprout ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── Result view ─────────────────────────────────────────────────────────────
  Widget _buildResultView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        children: [
          Text(
            _isSprout ? 'Your hero is ready! 🎉' : 'Your Magical Avatar ✨',
            textAlign: TextAlign.center,
            style: _isSprout
                ? GoogleFonts.nunito(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  )
                : GoogleFonts.cinzelDecorative(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
          ),
          const SizedBox(height: 20),
          Container(
            constraints: const BoxConstraints(maxHeight: 380),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_bt.cardRadiusBase),
              border: Border.all(color: _bt.accent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: _bt.accent.withAlpha(80),
                  blurRadius: 22,
                  spreadRadius: 2,
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
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              final dataUri =
                  'data:image/png;base64,$_generatedImageBase64';
              final customAvatar =
                  CharacterAvatar.defaultAvatar.copyWith(
                customImagePath: dataUri,
                isCustom: true,
              );
              Navigator.pop(context, customAvatar);
            },
            icon: const Icon(Icons.check_circle_rounded),
            label: Text(
              _isSprout ? 'Use this hero!' : 'Use This Avatar',
              style: _isSprout
                  ? GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    )
                  : null,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF208D62),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  vertical: 16, horizontal: 32),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(_bt.buttonRadiusBase),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _generatedImageBase64 = null;
              _step = _AvatarStep.gender;
            }),
            child: Text(
              _isSprout ? 'Make a new one' : 'Start over',
              style: GoogleFonts.quicksand(
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

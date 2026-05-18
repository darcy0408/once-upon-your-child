import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'avatar_models.dart';
import 'config/environment.dart';
import 'services/api_service_manager.dart';
import 'services/app_tts_service.dart';
import 'services/parental_consent_service.dart';
import 'theme/age_band_theme.dart';
import 'widgets/avatar_generating_view.dart';
import 'widgets/safe_asset_image.dart';

// ── Step definitions ─────────────────────────────────────────────────────────
// sproutWelcome is only included in the step order for Sprout (3-5) band.
enum _AvatarStep { sproutWelcome, gender, hairColor, eyeColor, favoriteColor, photo }

// ── Main screen ──────────────────────────────────────────────────────────────
class CustomAvatarScreen extends StatefulWidget {
  final String? initialName;
  final int? initialAge;
  final String? initialGender;

  /// Sprout-only: called when the child taps "Pick a ready hero" on the
  /// welcome step so the parent screen can open the avatar gallery instead.
  /// When null, the welcome step's gallery option is hidden.
  final VoidCallback? onOpenGallery;

  const CustomAvatarScreen({
    super.key,
    this.initialName,
    this.initialAge,
    this.initialGender,
    this.onOpenGallery,
  });

  @override
  State<CustomAvatarScreen> createState() => _CustomAvatarScreenState();
}

class _CustomAvatarScreenState extends State<CustomAvatarScreen>
    with SingleTickerProviderStateMixin {
  // Step navigation — order built in initState based on age band
  late final List<_AvatarStep> _stepOrder;
  late _AvatarStep _step;

  // Selections
  String _gender = 'girl';
  String? _pressedGender;
  String _hairColor = 'Brown';
  String _eyeColor = 'Brown';
  String _favoriteColor = 'Blue';

  // Photo & generation
  Uint8List? _imageBytes;
  bool _isGenerating = false;
  String? _generatedImageBase64;

  // M-11 (COPPA): photo-based avatar creation requires an explicit parental
  // opt-in. `null` = the opt-in check is still loading; `false` = blocked.
  // Enforced inside this screen, not only by hiding an entry button.
  bool? _photoAvatarAllowed;

  // One-time refinement (Adventurer+ / BYOK only)
  bool _hasUsedRefinement = false;
  bool _showRefinementInput = false;
  final TextEditingController _refinementController = TextEditingController();
  final SpeechToText _refinementSpeech = SpeechToText();
  bool _refinementSpeechEnabled = false;
  bool _isListeningForRefinement = false;

  // Step transition animation
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ── Age band helpers ────────────────────────────────────────────────────────
  int get _age => widget.initialAge ?? 7;
  String get _name =>
      (widget.initialName?.trim().isNotEmpty == true) ? widget.initialName! : '';
  AgeBand get _ageBand => ageBandFromAge(_age);
  AgeBandThemeData get _bt => themeForBand(_ageBand);
  bool get _isSprout => _ageBand == AgeBand.sprout;
  bool get _isExplorer => _ageBand == AgeBand.explorer;
  bool get _isCreator => _ageBand == AgeBand.creator;
  // Adventurer (9-11) and up can read well enough to use the refinement flow.
  bool get _canRefine => !_isSprout && !_isExplorer;

  // ── Color data ──────────────────────────────────────────────────────────────
  // Sprout: large swatches (88 px, no labels) — 9 colors renders as a 3×3 grid.
  // Omit Gold/Teal (not intuitive crayon colors). Blue/Light Blue/Dark Blue are
  // natural kid language ("sky blue", "dark blue") and visually distinct.
  static const _sproutFavoriteColors = [
    'Red', 'Orange', 'Yellow', 'Green', 'Blue', 'Light Blue', 'Dark Blue', 'Purple', 'Pink',
  ];
  static const _allFavoriteColors = [
    'Red', 'Blue', 'Green', 'Yellow', 'Purple', 'Pink', 'Orange', 'Teal', 'Gold'
  ];
  static const _eyeColors = ['Brown', 'Blue', 'Green', 'Hazel', 'Grey'];
  static const _hairColors = [
    'Black',
    'Dark Brown',
    'Brown',
    'Chestnut',
    'Light Brown',
    'Dark Blonde',
    'Blonde',
    'Platinum',
    'Auburn',
    'Red',
    'Ginger',
    'Strawberry',
    'Grey',
    'White',
    'Pink',
    'Blue',
    'Purple',
    'Teal',
    'Green',
  ];

  static const Map<String, Color> _eyeSwatches = {
    'Brown': Color(0xFF6D4C41),
    'Blue': Color(0xFF4FC3F7),
    'Green': Color(0xFF66BB6A),
    'Hazel': Color(0xFF8D6E63),
    'Grey': Color(0xFF90A4AE),
  };
  static const Map<String, Color> _hairSwatches = {
    // Natural shades
    'Black': Color(0xFF0A0A0A),
    'Dark Brown': Color(0xFF2C1A0E),
    'Brown': Color(0xFF5C3A1E),
    'Chestnut': Color(0xFF80461B),
    'Light Brown': Color(0xFF8B6914),
    'Dark Blonde': Color(0xFFB8860B),
    'Blonde': Color(0xFFD4A940),
    'Platinum': Color(0xFFE8DCC8),
    'Auburn': Color(0xFF922B05),
    'Red': Color(0xFFC62828),
    'Ginger': Color(0xFFD84315),
    'Strawberry': Color(0xFFE08060),
    'Grey': Color(0xFF9E9E9E),
    'White': Color(0xFFEEEEEE),
    // Fun / dyed colors
    'Pink': Color(0xFFE91E90),
    'Blue': Color(0xFF2196F3),
    'Purple': Color(0xFF7B1FA2),
    'Teal': Color(0xFF009688),
    'Green': Color(0xFF4CAF50),
  };
  static const Map<String, Color> _favoriteSwatches = {
    'Red': Color(0xFFE53935),
    'Orange': Color(0xFFFB8C00),
    'Yellow': Color(0xFFFDD835),
    'Green': Color(0xFF43A047),
    'Blue': Color(0xFF1E88E5),
    'Light Blue': Color(0xFF81D4FA),
    'Dark Blue': Color(0xFF1565C0),
    'Purple': Color(0xFF8E24AA),
    'Pink': Color(0xFFD81B60),
    'Teal': Color(0xFF00897B),
    'Gold': Color(0xFFFFD700),
  };

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Pre-set gender if caller already knows it.
    if (widget.initialGender != null) {
      _gender = widget.initialGender!.toLowerCase();
    }

    // Build step order — skip gender step if already provided.
    final skipGender = widget.initialGender != null;
    // Sprout (3-5): the AI infers hair and eye color from the photo — we only
    // ask gender and favorite color (outfit), then go straight to the camera.
    // Non-Sprout: AI can detect hair from the photo but eye color is hard to
    // read photographically, so we still ask for it.
    _stepOrder = _isSprout
        ? [
            _AvatarStep.sproutWelcome,
            if (!skipGender) _AvatarStep.gender,
            _AvatarStep.favoriteColor,
            _AvatarStep.photo,
          ]
        : [
            if (!skipGender) _AvatarStep.gender,
            _AvatarStep.eyeColor,
            _AvatarStep.photo,
          ];
    _step = _stepOrder.first;

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

    // Sprout: auto-speak the welcome prompt
    if (_isSprout) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _speakPrompt());
    }

    // Initialise STT for the refinement mic (non-blocking)
    if (_canRefine) {
      _refinementSpeech.initialize().then((ok) {
        if (mounted) setState(() => _refinementSpeechEnabled = ok);
      });
    }

    // M-11 (COPPA, CWE-602): enforce the parental "Allow photo-based avatar
    // creation" opt-in at the screen level. This screen is reachable from
    // several entry points (avatar builder, gallery callback, Sprout welcome
    // route) — relying on a hidden entry button is not sufficient.
    _enforcePhotoAvatarOptIn();
  }

  /// Reads the parental photo-avatar opt-in. If it is off, the photo path is
  /// blocked: the screen shows a "needs a grown-up's permission" message and
  /// pops, so neither the camera nor an upload can ever be reached.
  Future<void> _enforcePhotoAvatarOptIn() async {
    final allowed = await const ParentalConsentService().getAllowPhotoAvatar();
    if (!mounted) return;
    setState(() => _photoAvatarAllowed = allowed);
  }

  @override
  void dispose() {
    unawaited(AppTtsService.instance.stop());
    _refinementController.dispose();
    _refinementSpeech.stop();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── TTS ─────────────────────────────────────────────────────────────────────
  Future<void> _speakPrompt() async {
    AppTtsService.instance.markInteracted();
    await AppTtsService.instance.stop();
    unawaited(AppTtsService.instance.speak(_question(_step)));
  }

  String _question(_AvatarStep step) {
    switch (_ageBand) {
      case AgeBand.sprout:
        final greeting = _name.isNotEmpty ? 'Hi $_name! ' : 'Hi! ';
        return {
          _AvatarStep.sproutWelcome:
              '${greeting}Do you want to pick a ready-made hero, or make one that looks like you with a grown-up?',
          _AvatarStep.gender: 'Are you a girl or a boy?',
          _AvatarStep.hairColor: 'What color is your hair?',
          _AvatarStep.eyeColor: 'What color are your eyes?',
          _AvatarStep.favoriteColor: 'What is your favorite color?',
          _AvatarStep.photo: "Let's take a photo of your face with a grown-up!",
        }[step]!;
      case AgeBand.explorer:
        return {
          _AvatarStep.sproutWelcome: '',
          _AvatarStep.gender: 'Choose your hero\'s style!',
          _AvatarStep.hairColor: 'Pick your hair color!',
          _AvatarStep.eyeColor: 'Pick your eye color!',
          _AvatarStep.favoriteColor: 'Pick your hero\'s outfit color!',
          _AvatarStep.photo: 'Add a photo so we can paint your face!',
        }[step]!;
      case AgeBand.adventurer:
        return {
          _AvatarStep.sproutWelcome: '',
          _AvatarStep.gender: 'Choose your character\'s style',
          _AvatarStep.hairColor: 'Select your hair color',
          _AvatarStep.eyeColor: 'Select your eye color',
          _AvatarStep.favoriteColor: 'Pick an outfit color',
          _AvatarStep.photo: 'Add a reference photo',
        }[step]!;
      case AgeBand.creator:
        return {
          _AvatarStep.sproutWelcome: '',
          _AvatarStep.gender: 'Character style',
          _AvatarStep.hairColor: 'Hair color',
          _AvatarStep.eyeColor: 'Eye color',
          _AvatarStep.favoriteColor: 'Outfit color',
          _AvatarStep.photo: 'Reference photo',
        }[step]!;
      case AgeBand.adolescent:
        return {
          _AvatarStep.sproutWelcome: '',
          _AvatarStep.gender: 'Character style',
          _AvatarStep.hairColor: 'Hair color',
          _AvatarStep.eyeColor: 'Eye color',
          _AvatarStep.favoriteColor: 'Outfit color',
          _AvatarStep.photo: 'Reference photo',
        }[step]!;
      case AgeBand.adult:
        return {
          _AvatarStep.sproutWelcome: '',
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
    return {
      _AvatarStep.sproutWelcome: '',
      _AvatarStep.gender: 'Your hero will look just like you!',
      _AvatarStep.hairColor: 'Tap the color that matches yours',
      _AvatarStep.eyeColor: 'Tap the color that matches yours',
      _AvatarStep.favoriteColor: 'This colour will be your hero\'s outfit',
      _AvatarStep.photo: 'We\'ll transform your face into your hero',
    }[step]!;
  }

  // ── Step navigation ─────────────────────────────────────────────────────────
  int get _stepIndex => _stepOrder.indexOf(_step);
  bool get _isLastStep => _step == _AvatarStep.photo;
  // Progress dots only show for steps after sproutWelcome
  List<_AvatarStep> get _progressSteps =>
      _stepOrder.where((s) => s != _AvatarStep.sproutWelcome).toList();

  Future<void> _goForward() async {
    await AppTtsService.instance.stop();
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
    await AppTtsService.instance.stop();
    if (_stepIndex == 0) {
      if (mounted) Navigator.pop(context);
      return;
    }
    await _animCtrl.reverse();
    if (mounted) {
      setState(() => _step = _stepOrder[_stepIndex - 1]);
      _animCtrl.forward();
    }
  }

  // Auto-advance for Sprout (600ms so the pulse animation has time to play)
  void _sproutAutoAdvance() {
    Timer(const Duration(milliseconds: 600), () {
      if (mounted) _goForward();
    });
  }

  // ── Photo helpers ───────────────────────────────────────────────────────────
  Future<void> _takePhoto() async {
    // M-11: defence-in-depth — never invoke the camera/picker unless the
    // parental photo-avatar opt-in is on. The build gate already blocks the
    // UI, but re-check here so a future code path cannot bypass it.
    if (_photoAvatarAllowed != true) return;
    final picker = ImagePicker();
    XFile? picked;
    if (kIsWeb) {
      // Camera capture is not available on web via image_picker.
      // Fall back to gallery/file picker so the button is never a dead end.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Camera isn't available here — opening your photos instead!"),
          duration: Duration(seconds: 2),
        ));
      }
      picked = await picker.pickImage(source: ImageSource.gallery);
    } else {
      try {
        picked = await picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
        );
      } catch (_) {
        // Camera permission denied or unavailable — fall back to gallery.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Can't open camera. Let's pick a photo instead!"),
            duration: Duration(seconds: 2),
          ));
        }
        picked = await picker.pickImage(source: ImageSource.gallery);
      }
    }
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (mounted) setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _pickFromGallery() async {
    // M-11: defence-in-depth — see _takePhoto.
    if (_photoAvatarAllowed != true) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (mounted) setState(() => _imageBytes = bytes);
    }
  }

  // ── Avatar generation (API call unchanged) ──────────────────────────────────
  Future<void> _generateAvatar({String? refinementNote}) async {
    // M-11: final backstop — never upload a child photo without the parental
    // photo-avatar opt-in.
    if (_photoAvatarAllowed != true) return;
    if (_imageBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isSprout
                  ? 'Ask a grown-up to take a photo first!'
                  : 'Please add a photo to continue.',
            ),
          ),
        );
      }
      return;
    }

    // Backend requires character_name. If we land here with no name (e.g. the
    // wizard advanced past the name step without one), surface a clear UI
    // error instead of the cryptic "All fields required" 400 response.
    if (_name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Go back and give your hero a name first!',
            ),
            backgroundColor: Color(0xFFFF6B6B),
            behavior: SnackBarBehavior.floating,
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
        if (refinementNote != null && refinementNote.isNotEmpty) {
          request.fields['refinement_note'] = refinementNote;
        }
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
        String? errorCode;
        try {
          final body = json.decode(response.body) as Map<String, dynamic>;
          final m = body['message']?.toString();
          if (m != null && m.trim().isNotEmpty) msg = m;
          errorCode = body['error_code']?.toString();
        } catch (_) {}
        // The one free custom avatar has already been used — show a friendly
        // upgrade invitation rather than the generic "Generation failed".
        if (errorCode == 'UPGRADE_REQUIRED' && mounted) {
          setState(() => _isGenerating = false);
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF2D1060),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Unlock more magic ✨',
                style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              content: Text(
                msg,
                style: GoogleFonts.quicksand(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Maybe later', style: GoogleFonts.quicksand(color: Colors.white60)),
                ),
                if (widget.onOpenGallery != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5F4BDB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                      widget.onOpenGallery!();
                    },
                    child: Text(
                      _isSprout ? 'Pick a ready hero!' : 'Pick a premade hero',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          );
          return;
        }
        throw Exception(msg);
      }
    } catch (e) {
      debugPrint('❌ Error generating custom avatar: $e');
      if (mounted) {
        setState(() => _isGenerating = false);
        final msg = e.toString().replaceFirst('Exception: ', '');
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2D1060),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              _isSprout ? "Oops! Something went wrong." : 'Generation failed',
              style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            content: Text(
              msg,
              style: GoogleFonts.quicksand(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Try Again', style: GoogleFonts.quicksand(color: Colors.white60)),
              ),
              if (widget.onOpenGallery != null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5F4BDB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                    widget.onOpenGallery!();
                  },
                  child: Text(
                    _isSprout ? 'Pick a ready hero!' : 'Pick a premade hero',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
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
          // M-11: gate the entire screen on the parental photo-avatar opt-in.
          child: _photoAvatarAllowed == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : _photoAvatarAllowed == false
                  ? _buildPhotoAvatarBlockedView()
                  : _isGenerating
                      ? _buildGeneratingView()
                      : _generatedImageBase64 != null
                          ? _buildResultView()
                          : _buildWizardView(),
        ),
      ),
    );
  }

  // ── Photo-avatar blocked view (M-11) ────────────────────────────────────────
  /// Shown when the parental "Allow photo-based avatar creation" opt-in is off.
  /// The camera/upload flow is never built, so a photo cannot be captured.
  Widget _buildPhotoAvatarBlockedView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 28),
            ),
          ),
          const Spacer(),
          const Icon(Icons.lock_outline_rounded,
              color: Colors.white, size: 56),
          const SizedBox(height: 16),
          Text(
            _isSprout
                ? 'Ask a grown-up first!'
                : 'Photo avatars need a grown-up\'s permission',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: _isSprout ? 26 : 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'A parent or guardian can turn on photo-based avatars in '
            'parental controls. Until then, you can pick a ready-made hero '
            'instead.',
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
              fontSize: 15,
              color: Colors.white.withAlpha(200),
            ),
          ),
          const SizedBox(height: 24),
          if (widget.onOpenGallery != null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onOpenGallery!();
              },
              icon: const Icon(Icons.star_rounded),
              label: Text(
                _isSprout ? 'Pick a ready hero!' : 'Pick a premade hero',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5F4BDB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 28),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(_bt.buttonRadiusBase)),
              ),
            )
          else
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(
                'Go back',
                style: GoogleFonts.quicksand(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }

  // ── Wizard shell ────────────────────────────────────────────────────────────
  Widget _buildWizardView() {
    // Sprout welcome step takes over the full screen
    if (_step == _AvatarStep.sproutWelcome) {
      return _buildSproutWelcomeView();
    }

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
                    // Keep an explicit Next button visible for every step.
                    // Sprout still auto-advances on taps, but the button
                    // prevents the flow from getting stuck if auto-advance
                    // is delayed or interrupted.
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

  // ── Sprout welcome / choice screen ─────────────────────────────────────────
  Widget _buildSproutWelcomeView() {
    final greeting = _name.isNotEmpty ? 'Hi $_name! 👋' : 'Hi there! 👋';
    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Back / close
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(height: 8),
            // Greeting
            Text(
              greeting,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'How do you want your hero to look?',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white.withAlpha(210),
              ),
            ),
            const Spacer(),
            // Option A: Pick a premade hero
            if (widget.onOpenGallery != null)
              _buildWelcomeChoice(
                emoji: '⭐',
                topLine: 'Pick a ready hero!',
                bottomLine: 'Choose from lots of cool characters',
                color: const Color(0xFF5F4BDB),
                onTap: () {
                  Navigator.pop(context);
                  widget.onOpenGallery!();
                },
              ),
            const SizedBox(height: 20),
            // Option B: Make one with a grown-up
            _buildWelcomeChoice(
              emoji: '📸',
              topLine: 'Make one that looks like me!',
              bottomLine: 'Ask a grown-up to help',
              color: const Color(0xFF7A3FC8),
              onTap: _goForward,
            ),
            const Spacer(),
            // TTS replay button
            TextButton.icon(
              onPressed: _speakPrompt,
              icon: Icon(Icons.volume_up_rounded,
                  color: _bt.accent, size: 26),
              label: Text(
                'Read it to me!',
                style: GoogleFonts.nunito(
                  color: _bt.accent,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeChoice({
    required String emoji,
    required String topLine,
    required String bottomLine,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_bt.cardRadiusBase),
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(120),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topLine,
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    bottomLine,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(200),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white60, size: 20),
          ],
        ),
      ),
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
    // Dots track the main wizard steps (not the sprout welcome screen)
    final steps = _progressSteps;
    final activeIndex = steps.indexOf(_step).clamp(0, steps.length - 1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (i) {
        final active = i == activeIndex;
        final done = i < activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? (_isSprout ? 26.0 : 20.0) : (_isSprout ? 14.0 : 10.0),
          height: _isSprout ? 14.0 : 10.0,
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

  // ── Step header ─────────────────────────────────────────────────────────────
  Widget _buildStepHeader() {
    final q = _question(_step);
    final sub = _subtitle(_step);

    // Name greeting shown above the question for all bands
    final nameGreeting = _name.isNotEmpty && !_isSprout
        ? Text(
            'Hi $_name!',
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _bt.accent.withAlpha(210),
            ),
          )
        : null;

    if (_isSprout) {
      return Text(
        q,
        textAlign: TextAlign.center,
        style: GoogleFonts.nunito(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.2,
        ),
      );
    }

    return Column(
      children: [
        if (nameGreeting != null) ...[nameGreeting, const SizedBox(height: 4)],
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
      case _AvatarStep.sproutWelcome:
        return const SizedBox(); // handled above
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
          colors: _isSprout ? _sproutFavoriteColors : _allFavoriteColors,
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
        final boyAsset = _genderAsset('boy');
        final girlAsset = _genderAsset('girl');
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildGenderCard(value: 'girl', assetPath: girlAsset, label: 'Girl',
                w: halfW, h: cardH),
            _buildGenderCard(value: 'boy', assetPath: boyAsset, label: 'Boy',
                w: halfW, h: cardH),
          ],
        );
      },
    );
  }

  String _genderAsset(String gender) {
    final band = _ageBand;
    final g = gender == 'boy' ? 'boy' : 'girl';
    return switch (band) {
      AgeBand.sprout     => 'assets/images/ui/gender/gender_sprout_$g.png',
      AgeBand.explorer   => 'assets/images/ui/gender/gender_explorer_$g.png',
      AgeBand.adventurer => 'assets/images/ui/gender/gender_adventurer_$g.png',
      AgeBand.creator    => 'assets/images/ui/gender/gender_creator_$g.png',
      AgeBand.adolescent => 'assets/images/ui/gender/gender_adolescent_$g.png',
      AgeBand.adult      => 'assets/images/ui/gender/gender_adult_$g.png',
    };
  }

  Widget _buildGenderCard({
    required String value,
    required String assetPath,
    required String label,
    required double w,
    required double h,
  }) {
    final sel = _gender == value;
    final pressed = _pressedGender == value;
    final imageWidget = SafeAssetImage(
      assetPath,
      width: w,
      height: h * 0.78,
      fit: BoxFit.contain,
    );
    return GestureDetector(
      onTap: () {
        setState(() => _gender = value);
        if (_isSprout) {
          AppTtsService.instance.speak(label);
          _sproutAutoAdvance();
        }
      },
      onTapDown: (_) => setState(() => _pressedGender = value),
      onTapUp: (_) => setState(() => _pressedGender = null),
      onTapCancel: () => setState(() => _pressedGender = null),
      child: AnimatedScale(
        scale: pressed ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_bt.cardRadiusBase),
            color: sel ? _bt.primary.withAlpha(160) : Colors.white.withAlpha(22),
            border: Border.all(
              color: sel ? _bt.accent : Colors.white.withAlpha(55),
              width: sel ? 3 : 1.5,
            ),
            boxShadow: sel
                ? [BoxShadow(color: _bt.accent.withAlpha(90), blurRadius: 22, spreadRadius: 2)]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey('$value-$sel'),
                tween: Tween(begin: sel ? 0.85 : 1.0, end: 1.0),
                duration: const Duration(milliseconds: 350),
                curve: Curves.elasticOut,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: pressed
                      ? ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                              Color(0x44FFFFFF), BlendMode.screen),
                          child: imageWidget,
                        )
                      : imageWidget,
                ),
              ),
              SizedBox(height: _isSprout ? 10 : 6),
              Text(
                label,
                style: _isSprout
                    ? GoogleFonts.nunito(
                        fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)
                    : GoogleFonts.quicksand(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              if (sel) ...[
                SizedBox(height: _isSprout ? 6 : 4),
                Icon(Icons.check_circle_rounded, color: _bt.accent,
                    size: _isSprout ? 28 : 20),
              ],
            ],
          ),
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
    bool? hideLabels,
  }) {
    // Smaller swatches when there are many colors
    final manyColors = colors.length > 10;
    final swatchSize = _isSprout
        ? 88.0
        : _isExplorer
            ? 72.0
            : manyColors
                ? 44.0
                : _isCreator
                    ? 52.0
                    : 62.0;
    final showLabel = !(hideLabels ?? false) && !_isSprout && !manyColors;

    return Center(
      child: Wrap(
        spacing: _isSprout ? 16 : 12,
        runSpacing: _isSprout ? 20 : 14,
        alignment: WrapAlignment.center,
        children: colors.map((name) {
          final isSel = name == selected;
          final color = swatches[name] ?? Colors.white;
          return GestureDetector(
            onTap: () => onSelect(name),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Elastic pop-scale when selected
                TweenAnimationBuilder<double>(
                  key: ValueKey('$name-$isSel'),
                  tween: Tween(begin: isSel ? 0.7 : 1.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  builder: (_, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: swatchSize,
                    height: swatchSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(
                        color: isSel ? _bt.accent : Colors.white.withAlpha(70),
                        width: isSel ? 4.0 : 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSel
                              ? color.withAlpha(160)
                              : Colors.black.withAlpha(35),
                          blurRadius: isSel ? 20 : 6,
                          spreadRadius: isSel ? 3 : 0,
                        ),
                      ],
                    ),
                    child: isSel
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
                ),
                if (showLabel) ...[
                  const SizedBox(height: 5),
                  Text(
                    name,
                    style: GoogleFonts.quicksand(
                      fontSize: _isCreator ? 12 : 13,
                      fontWeight:
                          isSel ? FontWeight.w800 : FontWeight.w500,
                      color:
                          isSel ? Colors.white : Colors.white.withAlpha(170),
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
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // Preview circle / placeholder — tappable to open picker directly
        GestureDetector(
          onTap: _imageBytes == null ? _takePhoto : null,
          child: Container(
            width: previewSize,
            height: previewSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _bt.accent.withAlpha(200), width: 3),
              boxShadow: [
                BoxShadow(color: _bt.accent.withAlpha(55), blurRadius: 22)
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
                                color: Colors.white.withAlpha(220))
                            : GoogleFonts.quicksand(
                                fontSize: 14,
                                color: Colors.white.withAlpha(180)),
                      ),
                    ],
                  ),
          ),
        ),
        SizedBox(height: _isSprout ? 16 : 20),
        // Sprout: "ask a grown-up" note
        if (_isSprout)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withAlpha(22),
              border: Border.all(color: _bt.accent.withAlpha(100)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🧑', style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Ask a grown-up to help take your photo!',
                    style: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Camera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5F4BDB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_bt.buttonRadiusBase),
                ),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Upload'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A3FC8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_bt.buttonRadiusBase),
                ),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
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

  // Sprout-style big icon button
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
          padding:
              EdgeInsets.symmetric(vertical: _isSprout ? 18 : 14),
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
                      fontSize: 22, fontWeight: FontWeight.w900)
                  : GoogleFonts.quicksand(
                      fontSize: 18, fontWeight: FontWeight.w700),
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
    return AvatarGeneratingView(
      ageBand: _ageBand,
      status: _isSprout
          ? 'Making your magic hero...'
          : 'Brewing your magical avatar...',
      onCancel: () => setState(() => _isGenerating = false),
    );
  }

  // ── Result view ─────────────────────────────────────────────────────────────
  // ── Refinement helpers ──────────────────────────────────────────────────────

  Future<void> _listenForRefinement() async {
    if (!_refinementSpeechEnabled) return;
    if (_isListeningForRefinement) {
      await _refinementSpeech.stop();
      setState(() => _isListeningForRefinement = false);
      return;
    }
    setState(() => _isListeningForRefinement = true);
    await _refinementSpeech.listen(
      onResult: (result) {
        setState(() {
          if (result.recognizedWords.isNotEmpty) {
            _refinementController.text = result.recognizedWords;
          }
          if (result.finalResult) _isListeningForRefinement = false;
        });
      },
    );
  }

  Future<void> _submitRefinement() async {
    final note = _refinementController.text.trim();
    if (note.isEmpty) return;
    setState(() {
      _hasUsedRefinement = true;
      _showRefinementInput = false;
      _generatedImageBase64 = null;
    });
    _refinementController.clear();
    await _generateAvatar(refinementNote: note);
  }

  Widget _buildRefinementInput() {
    const accentColor = Color(0xFF80CBC4);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What would you like to change?',
            style: GoogleFonts.quicksand(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _refinementController,
                  style: GoogleFonts.quicksand(color: Colors.white, fontSize: 14),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'e.g. lighter hair, more curly',
                    hintStyle: GoogleFonts.quicksand(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withAlpha(12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: accentColor, width: 1.5),
                    ),
                  ),
                ),
              ),
              if (_refinementSpeechEnabled) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _listenForRefinement,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListeningForRefinement
                          ? const Color(0xFF9E6CFF)
                          : const Color(0xFF5F4BDB),
                      boxShadow: [
                        BoxShadow(
                          color: (_isListeningForRefinement
                                  ? const Color(0xFF9E6CFF)
                                  : const Color(0xFF5F4BDB))
                              .withAlpha(100),
                          blurRadius: _isListeningForRefinement ? 14 : 6,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListeningForRefinement
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _refinementController.text.trim().isEmpty
                      ? null
                      : _submitRefinement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black87,
                    disabledBackgroundColor: Colors.white24,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Regenerate',
                    style: GoogleFonts.quicksand(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() {
                  _showRefinementInput = false;
                  _refinementController.clear();
                }),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.quicksand(color: Colors.white38),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
                    color: Colors.white)
                : GoogleFonts.cinzelDecorative(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
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
                    spreadRadius: 2),
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
                      fontSize: 20, fontWeight: FontWeight.w900)
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
          // "Make a Change" — Adventurer+ (9+) and BYOK only, one use per session
          if (_canRefine && !_hasUsedRefinement) ...[
            const SizedBox(height: 4),
            if (_showRefinementInput)
              _buildRefinementInput()
            else
              TextButton.icon(
                onPressed: () => setState(() => _showRefinementInput = true),
                icon: const Icon(Icons.edit_rounded,
                    size: 15, color: Color(0xFF80CBC4)),
                label: Text(
                  'Make a Change',
                  style: GoogleFonts.quicksand(
                    color: const Color(0xFF80CBC4),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
          TextButton(
            onPressed: () => setState(() {
              _generatedImageBase64 = null;
              _step = _stepOrder.first;
              _hasUsedRefinement = false;
              _showRefinementInput = false;
              _refinementController.clear();
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

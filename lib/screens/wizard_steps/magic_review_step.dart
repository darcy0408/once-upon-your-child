import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:io';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/achievement_service.dart';
import 'package:story_weaver_app/story_result_screen.dart';
import 'package:story_weaver_app/story_illustration_service.dart';
import 'package:story_weaver_app/pick_a_path_adventure_screen.dart';
import 'package:story_weaver_app/pre_story_feelings_dialog.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/theme/app_theme.dart';
import 'package:story_weaver_app/widgets/magic_orb.dart';
import 'package:story_weaver_app/widgets/magical_loading_view.dart';
import 'package:story_weaver_app/widgets/image_mode_orb.dart';
import 'package:story_weaver_app/widgets/image_crystal_formation.dart';
import 'package:story_weaver_app/widgets/image_make_magic_button.dart';
import 'package:story_weaver_app/data/scenario_data.dart';
import 'package:story_weaver_app/data/companion_data.dart';
import 'package:story_weaver_app/widgets/magical_float.dart';
import 'wizard_data_mapper.dart';

/// Step 4: Magic Review & Launch
/// Updated with audio prompts and consistent magical typography.
class MagicReviewStep extends StatefulWidget {
  final WizardData wizardData;
  const MagicReviewStep({super.key, required this.wizardData});
  @override
  State<MagicReviewStep> createState() => _MagicReviewStepState();
}

class _MagicReviewStepState extends State<MagicReviewStep> {
  bool _isGenerating = false;
  late String _loadingStatus;
  final StoryIllustrationService _illustrationService = StoryIllustrationService();
  late FlutterTts _tts;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _initTts();
    if (widget.wizardData.characterAge >= 10) {
      _loadingStatus = 'Architecting your Epic Story...';
    } else if (widget.wizardData.characterAge >= 7) {
      _loadingStatus = 'Weaving a grand adventure...';
    } else {
      _loadingStatus = 'Creating your story...';
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  String get _scenarioImage {
    if (widget.wizardData.selectedScenario != null) {
      final scenario = ScenarioData.getById(widget.wizardData.selectedScenario!);
      if (scenario != null) {
        return scenario.illustration.startsWith('assets/') ? scenario.illustration : 'assets/${scenario.illustration}';
      }
    }
    return 'assets/images/scenarios/magic_door.png';
  }

  String? get _companionImage {
    if (widget.wizardData.selectedCompanions.isNotEmpty) {
      final firstComp = widget.wizardData.selectedCompanions.first;
      try {
        final magicComp = magicCompanions.firstWhere((c) => c.id == firstComp);
        return 'assets/images/companions/${magicComp.id}.jpg';
      } catch (_) { return null; }
    }
    return null;
  }

  String get _scenarioLabel => widget.wizardData.selectedScenario != null ? (ScenarioData.getById(widget.wizardData.selectedScenario!)?.title ?? 'Magical Adventure') : 'Magical Adventure';

  Widget _audioPrompt(String text) => IconButton(icon: const Icon(Icons.volume_up_rounded, color: Color(0xFFFFD700), size: 32), onPressed: () => _tts.speak(text));

  void _launchStoryCreation() async {
    if (!widget.wizardData.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all steps first!'), backgroundColor: AppColors.warning));
      return;
    }
    CurrentFeeling? currentFeeling;
    if (widget.wizardData.characterName.isNotEmpty) {
      if (!mounted) return;
      currentFeeling = await PreStoryFeelingsDialog.show(context: context, characterName: widget.wizardData.characterName, childAge: widget.wizardData.characterAge);
    }
    if (!mounted) return;
    setState(() => _isGenerating = true);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    try {
      await _saveCharacterIfNeeded();
      final requestData = WizardDataMapper.mapToStoryRequest(widget.wizardData);
      if (currentFeeling != null) requestData['currentFeeling'] = currentFeeling.toJson();
      if (widget.wizardData.interactiveMode) {
        if (mounted) {
          final character = Character(id: widget.wizardData.characterId ?? 'temp-${DateTime.now().millisecondsSinceEpoch}', name: widget.wizardData.characterName, age: widget.wizardData.characterAge, role: widget.wizardData.selectedArchetypeId ?? 'Adventurer', gender: widget.wizardData.characterGender, personalitySliders: widget.wizardData.personalitySliders);
          await Navigator.of(context).push(MaterialPageRoute(builder: (context) => PickAPathAdventureScreen(userId: 'guest', character: character, theme: requestData['theme'] ?? 'Adventure', tone: 'whimsical', length: _mapStoryLength(widget.wizardData.storyLength), interests: widget.wizardData.selectedEmotionChips.isNotEmpty ? widget.wizardData.selectedEmotionChips : null, mustInclude: widget.wizardData.customElements.isNotEmpty ? [widget.wizardData.customElements] : null, avoid: widget.wizardData.fears.isNotEmpty ? widget.wizardData.fears : null, lifeChallenge: widget.wizardData.lifeChallenge, personalitySliders: widget.wizardData.personalitySliders)));
        }
      } else {
        final result = await ApiServiceManager.generateStory(characterName: requestData['character'] ?? 'Hero', age: requestData['age'] ?? 5, theme: requestData['theme'] ?? 'Magical Adventure', companion: requestData['companion'] ?? '', characterDetails: requestData['characterDetails'], currentFeeling: requestData['currentFeeling'], additionalCharacters: requestData['additionalCharacters'], includeIllustrations: widget.wizardData.includeIllustrations, rhymeTimeMode: widget.wizardData.rhymeTimeMode, learningToReadMode: widget.wizardData.learningToReadMode, companionPets: requestData['companion_pets'], companionCharacters: requestData['companion_characters'], storyLength: requestData['storyLength'] ?? 'standard', customElements: requestData['customElements'] ?? '', onProgress: (status) { if (mounted) setState(() => _loadingStatus = status); });
        if (widget.wizardData.customAvatarPath != null) {
          try {
            final avatarFile = File(widget.wizardData.customAvatarPath!);
            if (await avatarFile.exists()) {
              final avatarBytes = await avatarFile.readAsBytes();
              final avatarBase64 = base64Encode(avatarBytes);
              final charDetails = requestData['characterDetails'];
              if (charDetails is Map<String, dynamic>) charDetails['custom_avatar_base64'] = avatarBase64;
            }
          } catch (e) { debugPrint('⚠️ Could not load custom avatar for illustration: $e'); }
        }
        List<Map<String, dynamic>> inlineIllustrations = result.illustrations;
        if (widget.wizardData.includeIllustrations && inlineIllustrations.isEmpty) {
          if (mounted) setState(() => _loadingStatus = 'Painting magical illustrations...');
          inlineIllustrations = await _generateInlineIllustrations(storyText: result.storyText, storyTitle: result.title ?? 'My Magical Story', requestData: requestData);
        }
        if (mounted) {
          await Navigator.of(context).push(MaterialPageRoute(builder: (context) => StoryResultScreen(title: result.title ?? 'My Magical Story', storyText: result.storyText, wisdomGem: result.wisdomGem ?? 'You are magic!', characterName: requestData['characterName'] ?? widget.wizardData.characterName, theme: requestData['theme'], characterAge: requestData['age'], pages: result.pages, adventureSteps: result.adventureSteps, storyLengthHint: requestData['storyLength']?.toString() ?? widget.wizardData.storyLength, trackStoryCreation: true, trackAnalytics: true, achievementsService: AchievementService(), storyCreatedAt: DateTime.now(), isRhyming: widget.wizardData.rhymeTimeMode, isLearningToReadMode: widget.wizardData.learningToReadMode, backendIllustrations: inlineIllustrations, asyncIllustrations: result.asyncIllustrations, companionAvatars: widget.wizardData.petAvatars)));
        }
      }
    } catch (e) {
      debugPrint('❌ Error generating story: $e');
      String userMessage = 'Magic needed a recharge';
      if (e.toString().contains('500')) userMessage = 'Server error. The magic faded.'; else if (e.toString().contains('timeout')) userMessage = 'Story took too long.';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$userMessage\nTry again?'), backgroundColor: AppColors.error, action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: _launchStoryCreation)));
    } finally { if (mounted) setState(() => _isGenerating = false); }
  }

  Future<List<Map<String, dynamic>>> _generateInlineIllustrations({required String storyText, required String storyTitle, required Map<String, dynamic> requestData}) async {
    try {
      final generated = await _illustrationService.generateIllustrations(storyText: storyText, storyTitle: storyTitle, characterName: requestData['character']?.toString() ?? widget.wizardData.characterName, theme: requestData['theme']?.toString(), numberOfImages: 1, age: requestData['age'] as int? ?? widget.wizardData.characterAge, characterAppearance: requestData['characterDetails'] as Map<String, dynamic>?);
      return generated.map((illustration) {
        final url = illustration.imageUrl;
        if (url.startsWith('data:image/') && url.contains(',')) {
          final commaIndex = url.indexOf(',');
          if (commaIndex < 0 || commaIndex + 1 >= url.length) return null;
          return {'id': illustration.id, 'prompt': illustration.prompt, 'image_data': url.substring(commaIndex + 1)};
        }
        return null;
      }).whereType<Map<String, dynamic>>().toList();
    } catch (e) { debugPrint('⚠️ Illustration generation failed: $e'); return const []; }
  }

  Future<void> _saveCharacterIfNeeded() async {
    try {
      final characterDetails = WizardDataMapper.mapToStoryRequest(widget.wizardData)['characterDetails'] as Map<String, dynamic>;
      final body = {'name': widget.wizardData.characterName, 'age': widget.wizardData.characterAge, 'gender': widget.wizardData.characterGender, 'role': widget.wizardData.selectedArchetypeId, 'character_type': 'Everyday Kid', 'character_style': 'Regular Kid', 'likes': characterDetails['interests'] ?? [], 'strengths': characterDetails['strengths'] ?? [], 'pets': widget.wizardData.pets, 'friends': widget.wizardData.additionalCharacters, 'avatar': {'hairColor': 'Brown', 'skinTone': 'Light'}, if (widget.wizardData.generatedAvatar != null) 'avatar_data': widget.wizardData.generatedAvatar!.toJson()};
      final api = ApiServiceManager();
      if (widget.wizardData.characterId != null) { await api.patch('/characters/${widget.wizardData.characterId}', body); } else {
        final response = await api.post('/create-character', body);
        if (response.containsKey('character_id')) { widget.wizardData.characterId = response['character_id']?.toString(); } else if (response.containsKey('id')) { widget.wizardData.characterId = response['id']?.toString(); }
      }
    } catch (e) { debugPrint('⚠️ Character save failed: $e'); }
  }

  String _mapStoryLength(String wizardLength) => wizardLength == 'quick' ? 'short' : (wizardLength == 'epic' ? 'long' : 'medium');

  @override
  Widget build(BuildContext context) {
    final data = widget.wizardData;
    final screenWidth = MediaQuery.of(context).size.width;
    final orbSize = (screenWidth - 64).clamp(180.0, 250.0);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [_audioPrompt("Gaze into the future"), const SizedBox(width: 8), Text("Gaze into the Future", style: GoogleFonts.cinzelDecorative(color: const Color(0xFFFFD700), fontSize: 24, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 24),
            SizedBox(height: 340, child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
              Container(width: orbSize + 50, height: orbSize + 50, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [const Color(0xFFFFEEA8).withValues(alpha: 0.4), const Color(0xFFE985FF).withValues(alpha: 0.3), const Color(0xFFB5F7FF).withValues(alpha: 0.2), Colors.transparent], stops: const [0.0, 0.4, 0.7, 1.0]))),
              MagicOrbWidget(imagePath: _scenarioImage, size: orbSize * 0.95, glowColor: AppColors.gold, topLabel: _scenarioLabel, label: data.characterName.isNotEmpty ? data.characterName : 'Your Hero', childScale: 0.92, child: _HeroAvatar(generatedAvatar: data.generatedAvatar, characterName: data.characterName, role: data.selectedArchetypeId)),
              Positioned(left: 5, bottom: 10, child: Column(mainAxisSize: MainAxisSize.min, children: [MagicalFloat(distance: 6.0, duration: const Duration(seconds: 4), delay: 100, child: _AuraCircle(size: 84, auraColor: const Color(0xFFFFD9A6), child: ClipOval(child: Image.asset(_scenarioImage, fit: BoxFit.cover)))), const SizedBox(height: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1)), child: Text(_scenarioLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))]))
              , if (data.selectedCompanions.isNotEmpty) Positioned(right: 5, bottom: 10, child: Column(mainAxisSize: MainAxisSize.min, children: [MagicalFloat(distance: 6.0, duration: const Duration(seconds: 4), delay: 500, child: _AuraCircle(size: 84, auraColor: const Color(0xFFF3AEFF), child: _CompanionAvatar(companionImage: _companionImage))), const SizedBox(height: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)), child: const Text('Companion', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))]))
            ])),
            const SizedBox(height: 24),
            Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 12, children: [
              ImageModeOrb(modeType: 'tales', label: 'Tales', isActive: data.includeIllustrations, onTap: () => setState(() => data.includeIllustrations = !data.includeIllustrations), primaryColor: const Color(0xFFAA88FF), secondaryColor: const Color(0xFFE28EFF)),
              ImageModeOrb(modeType: 'rhyme', label: 'Rhyme', isActive: data.rhymeTimeMode, onTap: () => setState(() { data.rhymeTimeMode = !data.rhymeTimeMode; if (data.rhymeTimeMode) { data.learningToReadMode = false; data.interactiveMode = false; } }), primaryColor: const Color(0xFF00D4DD), secondaryColor: const Color(0xFF7FDDFF)),
              ImageModeOrb(modeType: 'reading', label: 'Read-Along', isActive: data.learningToReadMode, onTap: () => setState(() { data.learningToReadMode = !data.learningToReadMode; if (data.learningToReadMode) { data.rhymeTimeMode = false; data.interactiveMode = false; } }), primaryColor: const Color(0xFFB88AFF), secondaryColor: const Color(0xFFFF9ECC)),
              ImageModeOrb(modeType: 'pickpath', label: 'Pick Your Path', isActive: data.interactiveMode, onTap: () => setState(() { data.interactiveMode = !data.interactiveMode; if (data.interactiveMode) { data.rhymeTimeMode = false; data.learningToReadMode = false; } }), primaryColor: const Color(0xFF9E6CFF), secondaryColor: const Color(0xFFFFB3E6)),
            ]),
            const SizedBox(height: AppSpacing.xl),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(child: ImageCrystalFormation(type: 'quick', label: 'Quick', isSelected: data.storyLength == 'quick', onTap: () => setState(() => data.storyLength = 'quick'))),
              const SizedBox(width: 12),
              Flexible(child: ImageCrystalFormation(type: 'classic', label: 'Classic', isSelected: data.storyLength == 'standard', onTap: () => setState(() => data.storyLength = 'standard'))),
              const SizedBox(width: 12),
              Flexible(child: ImageCrystalFormation(type: 'epic', label: 'Epic', isSelected: data.storyLength == 'epic', onTap: () => setState(() => data.storyLength = 'epic'))),
            ]),
            const SizedBox(height: AppSpacing.xl),
            Stack(children: [
              TextField(maxLines: 3, onChanged: (value) => setState(() => data.customElements = value), style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Whisper a special wish for your story...', hintStyle: TextStyle(color: Colors.white.withAlpha(80), fontStyle: FontStyle.italic), filled: true, fillColor: Colors.white.withAlpha(10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), contentPadding: const EdgeInsets.all(20))),
              const Positioned(right: 12, bottom: 12, child: Icon(Icons.auto_awesome, color: AppColors.gold, size: 20)),
            ]),
            const SizedBox(height: AppSpacing.xxl),
            Center(child: _isGenerating ? MagicalLoadingView(status: _loadingStatus, onCancel: () => setState(() => _isGenerating = false)) : _PulsingCastSpellFrame(isReady: !_isGenerating && data.isComplete, child: ImageMakeMagicButton(onTap: _launchStoryCreation, isEnabled: !_isGenerating && data.isComplete, label: 'MAKE MAGIC'))),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _AuraCircle extends StatelessWidget {
  final double size; final Color auraColor; final Widget child;
  const _AuraCircle({required this.size, required this.auraColor, required this.child});
  @override Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      Container(width: size + 50, height: size + 50, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [auraColor.withValues(alpha: 0.4), auraColor.withValues(alpha: 0.2), Colors.transparent], stops: const [0.0, 0.5, 1.0]))),
      Container(width: size + 32, height: size + 32, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [auraColor.withValues(alpha: 0.7), auraColor.withValues(alpha: 0.4), auraColor.withValues(alpha: 0.2), Colors.transparent], stops: const [0.0, 0.4, 0.7, 1.0]))),
      Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 16, spreadRadius: -2), BoxShadow(color: auraColor.withValues(alpha: 0.9), blurRadius: 50, spreadRadius: 6), BoxShadow(color: const Color(0xFFFFE4B8).withValues(alpha: 0.7), blurRadius: 30, spreadRadius: 2), BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 60, spreadRadius: 10)]), child: child),
    ]);
  }
}

class _HeroAvatar extends StatelessWidget {
  final GeneratedAvatar? generatedAvatar; final String characterName; final String? role;
  const _HeroAvatar({required this.generatedAvatar, required this.characterName, required this.role});
  @override Widget build(BuildContext context) {
    if (generatedAvatar == null) return _GradientSphereFallback(child: _HeroFallbackIdentity(name: characterName, role: role));
    final data = generatedAvatar!.imageBase64;
    if (data.startsWith('assets/')) return ClipOval(child: Image.asset(data, fit: BoxFit.cover));
    if (data.startsWith('http')) return ClipOval(child: Image.network(data, fit: BoxFit.cover));
    try { return ClipOval(child: Image.memory(base64Decode(data.split(',').last), fit: BoxFit.cover)); } catch (_) { return _GradientSphereFallback(child: _HeroFallbackIdentity(name: characterName, role: role)); }
  }
}

class _HeroFallbackIdentity extends StatelessWidget {
  final String name; final String? role;
  const _HeroFallbackIdentity({required this.name, required this.role});
  @override Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(role?.toLowerCase().contains('artist') == true ? Icons.palette : (role?.toLowerCase().contains('athlete') == true ? Icons.bolt : Icons.face), color: Colors.white, size: 42),
      const SizedBox(height: 8),
      Text(name.isNotEmpty ? name[0].toUpperCase() : 'H', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
    ]);
  }
}

class _CompanionAvatar extends StatelessWidget {
  final String? companionImage;
  const _CompanionAvatar({required this.companionImage});
  @override Widget build(BuildContext context) {
    if (companionImage == null) return const _GradientSphereFallback(child: Icon(Icons.pets, color: Colors.white, size: 48));
    return ClipOval(child: Image.asset(companionImage!, fit: BoxFit.cover));
  }
}

class _GradientSphereFallback extends StatelessWidget {
  final Widget child;
  const _GradientSphereFallback({required this.child});
  @override Widget build(BuildContext context) {
    return Container(decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0xFFFFF3D6), Color(0xFFEAA6FF), Color(0xFFAA7CEB)], stops: [0.1, 0.6, 1.0])), child: Center(child: child));
  }
}

class _PulsingCastSpellFrame extends StatefulWidget {
  final bool isReady; final Widget child;
  const _PulsingCastSpellFrame({required this.isReady, required this.child});
  @override State<_PulsingCastSpellFrame> createState() => _PulsingCastSpellFrameState();
}
class _PulsingCastSpellFrameState extends State<_PulsingCastSpellFrame> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2)); if (widget.isReady) _ctrl.repeat(reverse: true); }
  @override didUpdateWidget(old) { super.didUpdateWidget(old); if (widget.isReady != old.isReady) { if (widget.isReady) _ctrl.repeat(reverse: true); else _ctrl.stop(); } }
  @override dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _ctrl, builder: (ctx, child) => Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), boxShadow: widget.isReady ? [BoxShadow(color: const Color(0xFF9E6CFF).withAlpha((_ctrl.value * 100).toInt()), blurRadius: 28)] : null), child: child), child: widget.child);
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_tts_service.dart';
import '../services/parental_consent_service.dart';
import '../theme/app_theme.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

/// TEMP — PRE-LAUNCH TESTING ONLY. When true, the under-13 COPPA
/// email-verification round-trip is skipped in ALL builds (release included);
/// under-13 parents get the same simple checkbox consent screen as 13+, and
/// self-attested consent is recorded directly (method 'self_attested',
/// verified=false — honest, NOT mislabelled 'email_verified').
///
/// This is NOT COPPA-verifiable consent. It is acceptable only for a closed
/// tester build with no real end users. MUST be set back to `false` before
/// launch to re-enable the email round-trip — tracked in docs/MANUAL_TASKS.md.
const bool _kSkipEmailConsent = true;

/// M-15 (CWE-489) — Consent test bypass.
///
/// Compile-time flag, default OFF. The COPPA consent gate is auto-completed
/// ONLY when the app is built with `--dart-define=CONSENT_TEST_BYPASS=true`
/// (used by Playwright smoke tests, which cannot satisfy the scroll gate in
/// Flutter web canvas mode). Because this is resolved at compile time, a
/// normal release/QA build CANNOT enable it via a URL query parameter or any
/// other runtime input — the previous `?bypass_consent=1` runtime bypass is
/// removed entirely.
const bool _kConsentTestBypass =
    bool.fromEnvironment('CONSENT_TEST_BYPASS', defaultValue: false);

class ParentalConsentScreen extends StatefulWidget {
  const ParentalConsentScreen({
    super.key,
    required this.consentService,
    required this.declaredAge,
  });

  final ParentalConsentService consentService;
  final int declaredAge;

  @override
  State<ParentalConsentScreen> createState() => _ParentalConsentScreenState();
}

/// Phases of the consent flow.
///  - notice:       parent reads the notice + (under-13) enters email.
///  - awaitingCode: under-13 only — verification email sent, parent enters the
///                  code they received. Child has NOT been granted access yet.
enum _ConsentPhase { notice, awaitingCode }

class _ParentalConsentScreenState extends State<ParentalConsentScreen> {
  String? _parentEmail;
  bool _consentGiven = false;
  bool _allowPhotoAvatar = false; // COPPA: parent must explicitly opt in
  bool _submitting = false;
  bool _parentTitleActive = false;
  Timer? _titleTimer;
  final _scrollController = ScrollController();
  double _scrollProgress = 0.0;

  // ── Email round-trip verification state (under-13 only) ──────────────────
  _ConsentPhase _phase = _ConsentPhase.notice;
  final _codeController = TextEditingController();
  bool _verifying = false;
  String? _verifyError;

  bool get _isUnder13 => widget.declaredAge < 13;

  /// Whether the COPPA email round-trip applies. True for under-13 unless the
  /// pre-launch [_kSkipEmailConsent] flag is set (see its doc comment).
  bool get _requiresEmailVerification =>
      _isUnder13 && !_kSkipEmailConsent;

  /// For under-13, a properly-formatted parent email is REQUIRED — it is the
  /// destination of the COPPA verifiable-consent round trip. For 13+ the email
  /// is optional and any non-empty value must still be well-formed.
  bool get _emailValid {
    final email = _parentEmail?.trim() ?? '';
    if (_requiresEmailVerification) {
      return ParentalConsentService.isValidEmail(email);
    }
    // 13+: optional — empty is fine, but if provided it must be valid.
    return email.isEmpty || ParentalConsentService.isValidEmail(email);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Child-facing: let them know to get a grown-up, then hand off to the parent.
    AppTtsService.instance.speak(
        'Almost there! Ask a grown-up to unlock your magical adventure!');
    // Switch to parent-facing title after the TTS phrase finishes (~5 s).
    _titleTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _parentTitleActive = true);
    });
    // M-15: test-only consent bypass for Playwright smoke tests. Flutter web
    // canvas mode rejects programmatic scrolling, so the "scroll-to-bottom"
    // gate cannot be satisfied from automation. This is driven by the
    // compile-time `_kConsentTestBypass` flag (`--dart-define`), default OFF —
    // it cannot be triggered by a URL query parameter or any runtime input.
    if (_kConsentTestBypass) {
      debugPrint(
          '🔓 COPPA consent bypassed (CONSENT_TEST_BYPASS build flag)');
      // Schedule after first frame so Navigator/context are ready.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _debugBypassConsent();
      });
    }
  }

  @override
  void dispose() {
    _titleTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.maxScrollExtent > 0) {
      setState(() {
        _scrollProgress = (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const textWhite70 = TextStyle(color: Colors.white70);

    return Scaffold(
      backgroundColor: AppColors.gradientStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            _parentTitleActive
                ? 'Parental Consent Required'
                : 'Just one sec! ✨',
            key: ValueKey(_parentTitleActive),
            style: GoogleFonts.fredoka(color: Colors.white, fontSize: 20),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _scrollProgress,
            backgroundColor: Colors.white.withAlpha(30),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
            minHeight: 4,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.gradientStart, Color(0xFF1E0A3C)],
          ),
        ),
        child: SafeArea(
          child: _phase == _ConsentPhase.awaitingCode
              ? _buildVerificationStep()
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Child-facing intro — shown before the parent legal content
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              margin:
                                  const EdgeInsets.only(bottom: AppSpacing.md),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withAlpha(30),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFFD700).withAlpha(180),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Text('🌟',
                                      style: TextStyle(fontSize: 36)),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Your magical story is almost ready!',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.fredoka(
                                      color: const Color(0xFFFFD700),
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Hand this to a parent or guardian — they just need to say yes, and your adventure begins!',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.fredoka(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const _KidSummaryCard(),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Notice to Parents & Guardians 👋',
                              style: GoogleFonts.fredoka(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Your child (age ${widget.declaredAge}) would like to use Story Weaver. '
                              'As required by COPPA, we need your verifiable consent before your child can use this app.',
                              style: GoogleFonts.fredoka(
                                  color: Colors.white, fontSize: 16),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            // AI-transparency notice at consent time (STORE-6 /
                            // PP-6): parents must know content is AI-generated.
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('✨',
                                    style: TextStyle(fontSize: 16)),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    'Please note: stories, illustrations, and avatars are created by AI from your child\'s inputs. AI content can be imperfect and is not human-authored or clinician-reviewed.',
                                    style: GoogleFonts.fredoka(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            // Notice to Parents box
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color:
                                        const Color(0xFFFFD700).withAlpha(120)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'What We Collect & Why',
                                    style: GoogleFonts.fredoka(
                                      color: const Color(0xFFFFD700),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  const Text(
                                      '• Child\'s first name and age — to personalize stories',
                                      style: textWhite70),
                                  const Text(
                                      '• Character choices and avatar selections — saved locally on this device for your child\'s stories',
                                      style: textWhite70),
                                  const Text(
                                      '• Story preferences & emotions — to generate content',
                                      style: textWhite70),
                                  const Text(
                                      '• Usage data — to improve the app (no personal identifiers)',
                                      style: textWhite70),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'What We Do NOT Do',
                                    style: GoogleFonts.fredoka(
                                      color: const Color(0xFFFFD700),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  const Text(
                                      "• Never sell or share your child's personal information",
                                      style: textWhite70),
                                  const Text(
                                      '• No behavioral advertising or third-party tracking',
                                      style: textWhite70),
                                  const Text(
                                      '• Your child can choose a premade avatar instead of creating a cartoon image from a photo',
                                      style: textWhite70),
                                  const Text(
                                      "• Your child's stories and characters are saved on our secure servers — you can view or delete them any time from Parent Controls",
                                      style: textWhite70),
                                  const Text(
                                      '• Photo-based avatars are optional and off by default — if you turn them on, a photo is sent securely to create the cartoon avatar and is used for nothing else',
                                      style: textWhite70),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'Third-Party Services',
                                    style: GoogleFonts.fredoka(
                                      color: const Color(0xFFFFD700),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  const Text(
                                      '• Google Gemini — AI story-text and illustration generation. Receives a pseudonymized hero token, story details, themes, any "big feelings" text shared, and image prompts.',
                                      style: textWhite70),
                                  const Text(
                                      "• OpenRouter, Replicate, Cloudflare Workers AI — AI image and avatar generation. Receive image prompts, and on the photo-avatar path the child's photo.",
                                      style: textWhite70),
                                  const Text(
                                      '• ElevenLabs — text-to-speech narration. Receives generated story text.',
                                      style: textWhite70),
                                  const Text(
                                      '• Stripe — payment processing. Receives parent payment info; never child data.',
                                      style: textWhite70),
                                  const Text(
                                      '• Railway — secure cloud hosting. Stores profiles, stories, and preferences (United States).',
                                      style: textWhite70),
                                  const Text(
                                      '• Firebase / Google Analytics — app analytics. Anonymized usage events only; off by default and not enabled for children under 13.',
                                      style: textWhite70),
                                  const Text(
                                      '• Sentry — error monitoring. Receives crash and error diagnostics.',
                                      style: textWhite70),
                                  const Text(
                                      "• Resend — sends this consent verification email. Receives the parent/guardian email address.",
                                      style: textWhite70),
                                  const SizedBox(height: AppSpacing.xs),
                                  const Text(
                                      'Each provider receives only the minimum data needed and is governed by its own privacy policy. The full list also appears in our Privacy Policy.',
                                      style: textWhite70),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: _requiresEmailVerification
                                    ? 'Parent/Guardian Email (required)'
                                    : 'Your Email (optional)',
                                labelStyle:
                                    const TextStyle(color: Colors.white70),
                                hintText: 'parent@example.com',
                                hintStyle: TextStyle(
                                    color: Colors.white.withAlpha(120)),
                                helperText: _requiresEmailVerification
                                    ? 'Required — we email a code to confirm you are the parent (COPPA verifiable consent).'
                                    : 'Recommended — allows us to send you account confirmations.',
                                helperStyle: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                                helperMaxLines: 3,
                                errorText: (_parentEmail != null &&
                                        (_parentEmail!.trim().isNotEmpty ||
                                            _requiresEmailVerification) &&
                                        !_emailValid)
                                    ? 'Enter a valid email address'
                                    : null,
                                errorStyle: const TextStyle(
                                    color: Color(0xFFFF8A80), fontSize: 12),
                                prefixIcon: const Icon(Icons.email_outlined,
                                    color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withAlpha(25),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.white54),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.white54),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFFFD700), width: 2),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (value) =>
                                  setState(() => _parentEmail = value),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            // ── Photo avatar opt-out ───────────────────────────────────
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white38),
                              ),
                              child: SwitchListTile(
                                title: const Text(
                                  'Allow photo-based avatar creation',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: const Text(
                                  'Your child can choose a premade avatar, or use a photo to create a cartoon one. '
                                  'If turned on, the photo is sent securely to generate the avatar and is used for nothing else. Off by default.',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                                activeThumbColor: const Color(0xFFFFD700),
                                value: _allowPhotoAvatar,
                                onChanged: (value) =>
                                    setState(() => _allowPhotoAvatar = value),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const PrivacyPolicyScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text('Privacy Policy',
                                      style:
                                          TextStyle(color: Color(0xFFFFD700))),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const TermsOfServiceScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text('Terms of Service',
                                      style:
                                          TextStyle(color: Color(0xFFFFD700))),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            // ── ElevenLabs kudos ─────────────────────────────────────────
                            GestureDetector(
                              onTap: () => launchUrl(
                                Uri.parse(
                                    'https://elevenlabs.io/impact-program'),
                                mode: LaunchMode.externalApplication,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(8),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.white.withAlpha(30),
                                      width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        SvgPicture.network(
                                          'https://eleven-public-cdn.elevenlabs.io/payloadcms/csnjio02mx4-elevenlabs-logo-white.svg',
                                          height: 22,
                                          semanticsLabel: 'ElevenLabs',
                                          placeholderBuilder: (_) => Text(
                                            'ElevenLabs',
                                            style: GoogleFonts.fredoka(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFD700)
                                                .withAlpha(40),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: const Color(0xFFFFD700)
                                                    .withAlpha(120)),
                                          ),
                                          child: Text(
                                            'Proud Partner',
                                            style: GoogleFonts.fredoka(
                                              color: const Color(0xFFFFD700),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                      'Story Weaver uses ElevenLabs to bring stories to life with natural, expressive voices. '
                                      'Beyond storytelling, ElevenLabs is doing incredible work through their Impact Program — '
                                      'providing free access to their voice technology for people who have lost the ability to '
                                      'speak, and tools that help people with visual impairments experience the world through sound. '
                                      'We\'re proud to partner with a company whose technology genuinely changes lives.',
                                      style: GoogleFonts.fredoka(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Row(
                                      children: [
                                        const Icon(Icons.open_in_new,
                                            color: Color(0xFFFFD700), size: 13),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Learn about their Impact Program',
                                          style: GoogleFonts.fredoka(
                                            color: const Color(0xFFFFD700),
                                            fontSize: 12,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor:
                                                const Color(0xFFFFD700),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildStickyFooter(),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _shareToGrownUp() async {
    final message =
        "Hi! I want to try Story Weaver, an app that makes me the hero of my own stories. "
        "It needs a grown-up to say yes before I can play. "
        "Could you look at this together with me? It takes about a minute. "
        "Thanks!";
    await SharePlus.instance.share(ShareParams(text: message));
  }

  Widget _buildStickyFooter() {
    final bool readEnough = _scrollProgress >= 0.95;
    final bool canSubmit =
        _consentGiven && _emailValid && !_submitting && readEnough;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E0A3C),
        border: Border(
          top: BorderSide(color: Colors.white.withAlpha(30), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kid's escape hatch — they can message a grown-up instead of waiting.
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _shareToGrownUp,
              icon: const Icon(Icons.ios_share,
                  color: Color(0xFFFFD700), size: 16),
              label: Text(
                'Send to a grown-up',
                style: GoogleFonts.fredoka(
                  color: const Color(0xFFFFD700),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
            ),
          ),
          if (!readEnough)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_arrow_up,
                      color: Colors.white.withAlpha(140), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Please scroll through the notice above',
                    style: TextStyle(
                        color: Colors.white.withAlpha(160), fontSize: 12),
                  ),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: _consentGiven
                  ? const Color(0xFFFFD700).withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _consentGiven ? const Color(0xFFFFD700) : Colors.white70,
                width: _consentGiven ? 2 : 1.5,
              ),
            ),
            child: CheckboxListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              title: const Text(
                'I am a parent/guardian and give permission',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              checkColor: Colors.black,
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFFFFD700);
                }
                return Colors.white.withValues(alpha: 0.25);
              }),
              side: const BorderSide(color: Colors.white70, width: 2),
              value: _consentGiven,
              onChanged: readEnough
                  ? (value) => setState(() => _consentGiven = value ?? false)
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSubmit ? _submitConsent : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white.withAlpha(30),
                disabledForegroundColor: Colors.white54,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                _submitting
                    ? (_requiresEmailVerification
                        ? 'Sending email...'
                        : 'Saving...')
                    : (_requiresEmailVerification
                        ? 'Send Verification Email ✉️'
                        : 'Give Permission ✓'),
                style: GoogleFonts.fredoka(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitConsent() async {
    if (_requiresEmailVerification) {
      await _startEmailVerification();
      return;
    }
    // 13+ — COPPA verifiable consent is not required. Self-attested consent is
    // recorded truthfully (not labelled 'email_verified', not marked verified).
    setState(() => _submitting = true);
    try {
      await widget.consentService.recordConsent(
        age: widget.declaredAge,
        parentEmail: _parentEmail?.trim(),
        method: 'self_attested',
        allowPhotoAvatar: _allowPhotoAvatar,
        verified: false,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save consent. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Test-only consent bypass for Playwright smoke tests. Records an HONEST,
  /// clearly test-only consent method ('debug_bypass') — it does NOT mislabel
  /// consent as 'email_verified'. Reachable only when the build sets the
  /// compile-time `_kConsentTestBypass` flag (`--dart-define`), default OFF.
  Future<void> _debugBypassConsent() async {
    assert(_kConsentTestBypass,
        'consent bypass must only run when CONSENT_TEST_BYPASS is set');
    setState(() => _submitting = true);
    try {
      await widget.consentService.recordConsent(
        age: widget.declaredAge,
        method: 'debug_bypass',
        allowPhotoAvatar: _allowPhotoAvatar,
        verified: false,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
    }
  }

  /// Under-13: ask the backend to email a verification code to the parent, and
  /// move to the code-entry phase. Consent is recorded locally as PENDING
  /// (method 'email_pending', verified=false) — the child does NOT yet have
  /// full access. The screen pops `true` only after the code is verified.
  Future<void> _startEmailVerification() async {
    final email = _parentEmail?.trim() ?? '';
    if (!ParentalConsentService.isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid parent/guardian email.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final queued = await widget.consentService.requestEmailVerification(
        age: widget.declaredAge,
        parentEmail: email,
        allowPhotoAvatar: _allowPhotoAvatar,
      );
      if (!mounted) return;
      if (!queued) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not send the verification email. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      setState(() {
        _submitting = false;
        _phase = _ConsentPhase.awaitingCode;
        _verifyError = null;
      });
      AppTtsService.instance.stop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Could not send the verification email. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Submits the code the parent received by email. On success the local
  /// record is promoted to verified ('email_verified', verified=true) and the
  /// screen pops `true` — only now does the child get full access.
  Future<void> _submitVerificationCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _verifyError = 'Enter the code from your email.');
      return;
    }
    setState(() {
      _verifying = true;
      _verifyError = null;
    });
    try {
      final ok = await widget.consentService.verifyEmailConsent(code: code);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _verifying = false;
          _verifyError =
              'That code did not match. Check your email and try again.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verifyError = 'Could not verify right now. Please try again.';
      });
    }
  }

  /// Re-sends the verification email to the same parent address.
  Future<void> _resendVerificationEmail() async {
    final email = _parentEmail?.trim() ?? '';
    if (!ParentalConsentService.isValidEmail(email)) return;
    setState(() {
      _verifying = true;
      _verifyError = null;
    });
    try {
      await widget.consentService.requestEmailVerification(
        age: widget.declaredAge,
        parentEmail: email,
        allowPhotoAvatar: _allowPhotoAvatar,
      );
      if (!mounted) return;
      setState(() => _verifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent again.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verifyError = 'Could not resend right now. Please try again.';
      });
    }
  }

  /// Code-entry phase shown to the parent after the verification email is sent.
  Widget _buildVerificationStep() {
    final email = _parentEmail?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('✉️',
              style: TextStyle(fontSize: 44), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Check your email',
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              color: const Color(0xFFFFD700),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'We sent a verification code to:\n$email\n\n'
            'Enter the code below to confirm you are the parent or guardian. '
            'Your child cannot start playing until this step is complete.',
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _codeController,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, letterSpacing: 4),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Verification code',
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: 'e.g. 4F2A9C',
              hintStyle: TextStyle(color: Colors.white.withAlpha(120)),
              errorText: _verifyError,
              errorStyle:
                  const TextStyle(color: Color(0xFFFF8A80), fontSize: 12),
              filled: true,
              fillColor: Colors.white.withAlpha(25),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white54),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white54),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFFFD700), width: 2),
              ),
            ),
            onChanged: (_) {
              if (_verifyError != null) {
                setState(() => _verifyError = null);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _verifying ? null : _submitVerificationCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white.withAlpha(30),
                disabledForegroundColor: Colors.white54,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                _verifying ? 'Verifying...' : 'Confirm Consent ✓',
                style: GoogleFonts.fredoka(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _verifying
                    ? null
                    : () => setState(() {
                          _phase = _ConsentPhase.notice;
                          _verifyError = null;
                          _codeController.clear();
                        }),
                child: const Text('Change email',
                    style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: _verifying ? null : _resendVerificationEmail,
                child: const Text('Resend email',
                    style: TextStyle(color: Color(0xFFFFD700))),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'Consent is recorded as pending until verification completes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Collapsible "What this means for me" card written at a 4th-grade reading level.
/// Sits between the child-facing intro and the parent legal notice, so the child
/// can read it while waiting for a grown-up to handle the rest.
class _KidSummaryCard extends StatefulWidget {
  const _KidSummaryCard();

  @override
  State<_KidSummaryCard> createState() => _KidSummaryCardState();
}

class _KidSummaryCardState extends State<_KidSummaryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF7C4DFF).withAlpha(25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7C4DFF).withAlpha(120)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text('🧒', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'What this means for me',
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 10),
                  _kidPoint('📖',
                      'Stories are made just for YOU — your name is the hero!'),
                  _kidPoint('🔒',
                      'Your stories are saved safely — a grown-up can see or delete them any time.'),
                  _kidPoint('🚫', 'No ads will pop up or follow you around.'),
                  _kidPoint('📸',
                      'A grown-up decides if you can use a photo for your character.'),
                  _kidPoint('🛡️',
                      'A grown-up can change or delete everything, any time.'),
                  _kidPoint(
                      '✅', 'Once a grown-up says yes, your adventure begins!'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _kidPoint(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.fredoka(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

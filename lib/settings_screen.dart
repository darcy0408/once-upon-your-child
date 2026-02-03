// lib/settings_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/services/secure_storage_service.dart';

import 'config/environment.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/app_button.dart';
import 'widgets/app_card.dart';
import 'widgets/app_switch.dart';
import 'widgets/error_message.dart';
import 'widgets/loading_spinner.dart';
import 'screens/byok_setup_wizard.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/terms_of_service_screen.dart';

class SettingsState {
  const SettingsState({
    required this.useOwnApiKey,
    required this.isValidating,
    required this.obscureApiKey,
    required this.apiKey,
    required this.isLoading,
    this.validationMessage,
    this.isValid,
  });

  final bool useOwnApiKey;
  final bool isValidating;
  final bool obscureApiKey;
  final String apiKey;
  final bool isLoading;
  final String? validationMessage;
  final bool? isValid;

  SettingsState copyWith({
    bool? useOwnApiKey,
    bool? isValidating,
    bool? obscureApiKey,
    String? apiKey,
    bool? isLoading,
    String? validationMessage,
    bool? isValid,
  }) {
    return SettingsState(
      useOwnApiKey: useOwnApiKey ?? this.useOwnApiKey,
      isValidating: isValidating ?? this.isValidating,
      obscureApiKey: obscureApiKey ?? this.obscureApiKey,
      apiKey: apiKey ?? this.apiKey,
      isLoading: isLoading ?? this.isLoading,
      validationMessage: validationMessage,
      isValid: isValid,
    );
  }

  factory SettingsState.initial() {
    return const SettingsState(
      useOwnApiKey: false,
      isValidating: false,
      obscureApiKey: true,
      apiKey: '',
      validationMessage: null,
      isValid: null,
      isLoading: true,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState.initial()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = await SecureStorageService.getApiKey('gemini') ?? '';
    final useOwnApiKey = prefs.getBool('use_own_api_key') ?? false;

    state = state.copyWith(
      useOwnApiKey: useOwnApiKey,
      apiKey: apiKey,
      isValid: useOwnApiKey && apiKey.isNotEmpty ? true : null,
      validationMessage:
          useOwnApiKey && apiKey.isNotEmpty ? '✓ API Key configured' : null,
      isLoading: false,
    );
  }

  Future<void> reload() async {
    state = state.copyWith(isLoading: true);
    await _loadSettings();
  }

  Future<void> toggleUseOwnApiKey(bool value) async {
    state = state.copyWith(useOwnApiKey: value);
    await _persistSettings();
  }

  void toggleObscure() {
    state = state.copyWith(obscureApiKey: !state.obscureApiKey);
  }

  void updateApiKey(String value) {
    state = state.copyWith(
      apiKey: value,
      isValid: null,
      validationMessage: null,
    );
  }

  Future<void> applyWizardResult(String apiKey) async {
    state = state.copyWith(
      useOwnApiKey: true,
      apiKey: apiKey,
      isValid: true,
      validationMessage: '✓ API Key configured via wizard',
    );
    await _persistSettings(isPremium: true);
  }

  Future<bool> validateApiKey() async {
    final trimmedKey = state.apiKey.trim();
    if (trimmedKey.isEmpty) {
      state = state.copyWith(
        validationMessage: 'Please enter an API key',
        isValid: false,
      );
      return false;
    }

    state = state.copyWith(
      isValidating: true,
      validationMessage: null,
      isValid: null,
    );

    try {
      final testUrl =
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$trimmedKey');
      final response = await http.get(testUrl).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        state = state.copyWith(
          validationMessage: '✓ API Key is valid! All premium features unlocked.',
          isValid: true,
          isValidating: false,
        );
        await _persistSettings(isPremium: true);
        return true;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        state = state.copyWith(
          validationMessage:
              '✗ Invalid API key. Error: ${data['error']?['message'] ?? 'Unknown error'}',
          isValid: false,
          isValidating: false,
        );
        await _persistSettings();
        return false;
      } else {
        state = state.copyWith(
          validationMessage:
              '✗ API Key validation failed (Status ${response.statusCode})',
          isValid: false,
          isValidating: false,
        );
        await _persistSettings();
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        validationMessage: '✗ Error validating key: ${e.toString()}',
        isValid: false,
        isValidating: false,
      );
      await _persistSettings();
      return false;
    }
  }

  Future<void> clearApiKey() async {
    state = state.copyWith(
      apiKey: '',
      useOwnApiKey: false,
      validationMessage: null,
      isValid: null,
    );
    await SecureStorageService.deleteApiKey('gemini');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_own_api_key', false);
    await prefs.setBool('is_premium_byok', false);
  }

  Future<void> _persistSettings({bool? isPremium}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_own_api_key', state.useOwnApiKey);
    await SecureStorageService.saveApiKey('gemini', state.apiKey.trim());

    final premiumFlag = isPremium ?? (state.useOwnApiKey && state.isValid == true);
    await prefs.setBool('is_premium_byok', premiumFlag);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _apiKeyController.addListener(_onApiKeyChanged);
    ref.listen<SettingsState>(settingsProvider, (previous, next) {
      if (_apiKeyController.text != next.apiKey) {
        _apiKeyController.text = next.apiKey;
      }
    });
  }

  void _onApiKeyChanged() {
    final text = _apiKeyController.text;
    final current = ref.read(settingsProvider);
    if (current.apiKey == text) return;
    ref.read(settingsProvider.notifier).updateApiKey(text);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final themeMode = ref.watch(themeModeNotifierProvider);
    final notifier = ref.read(settingsProvider.notifier);

    if (settings.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: LoadingSpinner(size: 48)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(context),
            const SizedBox(height: AppSpacing.lg),
            _buildApiToggleCard(context, settings, notifier),
            if (settings.useOwnApiKey) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildBenefitsCard(),
              const SizedBox(height: AppSpacing.md),
              _buildPrivacyCard(),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Toggle between light and dark themes'),
                value: themeMode == ThemeMode.dark,
                onChanged: (_) {
                  ref.read(themeModeNotifierProvider.notifier).toggle();
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildLegalLinks(context),
            if (Environment.isDevelopment) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () {
                  // TODO: REMOVE BEFORE PRODUCTION
                  throw Exception('Test crash for Sentry verification');
                },
                child: const Text('Test Crash (Dev Only)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return AppCard(
      color: AppColors.primary.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Bring Your Own API Key',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Use your free Gemini API key to unlock all premium features!',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildApiToggleCard(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier notifier,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSwitch(
            value: settings.useOwnApiKey,
            onChanged: notifier.toggleUseOwnApiKey,
            label: 'Use my own Gemini API key',
            subtitle: 'Unlock unlimited stories and features',
            icon: Icons.api,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton.secondary(
            label: 'Open setup wizard',
            icon: Icons.auto_awesome,
            onPressed: () => _openWizard(context),
          ),
          if (settings.useOwnApiKey) ...[
            const SizedBox(height: AppSpacing.md),
            _buildApiKeyField(settings),
            const SizedBox(height: AppSpacing.sm),
            if (settings.validationMessage != null)
              settings.isValid == false
                  ? ErrorMessage(
                      title: 'Validation failed',
                      message: settings.validationMessage!,
                      onRetry: () => _onValidateApiKey(context),
                    )
                  : AppCard(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      child: Text(
                        settings.validationMessage!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.primary),
                      ),
                    ),
            const SizedBox(height: AppSpacing.md),
            AppButton.primary(
              label: settings.isValidating ? 'Validating...' : 'Validate & Save',
              onPressed: settings.isValidating ? null : () => _onValidateApiKey(context),
              icon: settings.isValidating ? null : Icons.verified_user,
            ),
            if (settings.isValidating)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: LoadingSpinner(size: 32),
              ),
            TextButton.icon(
              onPressed: _launchApiKeyHelp,
              icon: const Icon(Icons.help_outline),
              label: const Text('How do I get an API key?'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApiKeyField(SettingsState settings) {
    return TextField(
      controller: _apiKeyController,
      decoration: InputDecoration(
        labelText: 'Gemini API Key',
        hintText: 'AIza...',
        prefixIcon: const Icon(Icons.key),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                settings.obscureApiKey ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: ref.read(settingsProvider.notifier).toggleObscure,
            ),
            if (_apiKeyController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _clearApiKey(context),
              ),
          ],
        ),
      ),
      obscureText: settings.obscureApiKey,
      maxLines: 1,
    );
  }

  Widget _buildBenefitsCard() {
    const benefits = [
      'Unlimited story generation',
      'Interactive adventures',
      'Superhero mode',
      'All avatar customizations',
      'Advanced therapeutic tools',
      'No subscription needed',
    ];
    return AppCard(
      color: AppColors.secondary.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.star, color: AppColors.secondary),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Benefits',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...benefits.map((b) => _buildBenefitRow('✓ $b')),
        ],
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return AppCard(
      color: Colors.blue.shade50,
      child: Row(
        children: const [
          Icon(Icons.lock, color: Colors.blue),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Your API key is stored securely on your device and never sent to our servers.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Colors.green.shade900),
      ),
    );
  }

  Widget _buildLegalLinks(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Legal',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                );
              },
              child: const Text('Privacy Policy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TermsOfServiceScreen(),
                  ),
                );
              },
              child: const Text('Terms of Service'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onValidateApiKey(BuildContext context) async {
    final success = await ref.read(settingsProvider.notifier).validateApiKey();
    if (!context.mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Premium features unlocked!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _clearApiKey(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear API Key?'),
        content: const Text(
          'This will remove your API key and disable premium features. You can add it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(settingsProvider.notifier).clearApiKey();
      _apiKeyController.clear();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key cleared')),
      );
    }
  }

  Future<void> _openWizard(BuildContext context) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const ByokSetupWizardScreen(),
        fullscreenDialog: true,
      ),
    );
    if (result != null && result.isNotEmpty) {
      await ref.read(settingsProvider.notifier).applyWizardResult(result);
      _apiKeyController.text = result;
    } else {
      await ref.read(settingsProvider.notifier).reload();
    }
  }

  void _launchApiKeyHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to get a Gemini API Key'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1. Visit: ai.google.dev/gemini-api',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('2. Click "Get API key in Google AI Studio"'),
              const SizedBox(height: 8),
              const Text('3. Sign in with your Google account'),
              const SizedBox(height: 8),
              const Text('4. Create a new API key'),
              const SizedBox(height: 8),
              const Text('5. Copy and paste it here'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Free Tier Limits:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('• 15 requests per minute'),
                    Text('• 1 million tokens per minute'),
                    Text('• 1,500 requests per day'),
                    SizedBox(height: 8),
                    Text(
                      'Perfect for personal use!',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

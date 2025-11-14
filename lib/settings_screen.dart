// lib/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'theme/app_theme.dart';
import 'widgets/app_card.dart';
import 'widgets/app_button.dart';
import 'widgets/loading_spinner.dart';
import 'widgets/error_message.dart';
import 'widgets/app_switch.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _useOwnApiKey = false;
  bool _isValidating = false;
  bool _obscureApiKey = true;
  String? _validationMessage;
  bool? _isValid;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Widget _buildHeaderCard(BuildContext context) {
    return AppCard(
      color: AppColors.primary.withOpacity(0.05),
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

  Widget _buildApiToggleCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSwitch(
            value: _useOwnApiKey,
            onChanged: (value) {
              setState(() => _useOwnApiKey = value);
              _saveSettings();
            },
            label: 'Use my own Gemini API key',
            subtitle: 'Unlock unlimited stories and features',
            icon: Icons.api,
          ),
          if (_useOwnApiKey) ...[
            const SizedBox(height: AppSpacing.md),
            _buildApiKeyField(),
            const SizedBox(height: AppSpacing.sm),
            if (_validationMessage != null)
              _isValid == false
                  ? ErrorMessage(
                      title: 'Validation failed',
                      message: _validationMessage!,
                      onRetry: _validateApiKey,
                    )
                  : AppCard(
                      color: AppColors.accent.withOpacity(0.15),
                      child: Text(
                        _validationMessage!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.primary),
                      ),
                    ),
            const SizedBox(height: AppSpacing.md),
            AppButton.primary(
              label: _isValidating ? 'Validating...' : 'Validate & Save',
              onPressed: _isValidating ? null : _validateApiKey,
              icon: _isValidating ? null : Icons.verified_user,
            ),
            if (_isValidating)
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

  Widget _buildApiKeyField() {
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
                _obscureApiKey ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
            ),
            if (_apiKeyController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clearApiKey,
              ),
          ],
        ),
      ),
      obscureText: _obscureApiKey,
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
      color: AppColors.secondary.withOpacity(0.08),
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
  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useOwnApiKey = prefs.getBool('use_own_api_key') ?? false;
      _apiKeyController.text = prefs.getString('gemini_api_key') ?? '';
      if (_useOwnApiKey && _apiKeyController.text.isNotEmpty) {
        _isValid = true;
        _validationMessage = '✓ API Key configured';
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_own_api_key', _useOwnApiKey);
    await prefs.setString('gemini_api_key', _apiKeyController.text.trim());

    if (_useOwnApiKey && _isValid == true) {
      // When users bring their own key, they get "premium" features
      await prefs.setBool('is_premium_byok', true);
    } else {
      await prefs.setBool('is_premium_byok', false);
    }
  }

  Future<void> _validateApiKey() async {
    if (_apiKeyController.text.trim().isEmpty) {
      setState(() {
        _validationMessage = 'Please enter an API key';
        _isValid = false;
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _validationMessage = null;
      _isValid = null;
    });

    try {
      // Test the API key with a minimal request
      final apiKey = _apiKeyController.text.trim();
      final testUrl = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');

      final response = await http.get(testUrl).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        setState(() {
          _validationMessage = '✓ API Key is valid! All premium features unlocked.';
          _isValid = true;
          _isValidating = false;
        });

        await _saveSettings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Premium features unlocked!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        setState(() {
          _validationMessage =
              '✗ Invalid API key. Error: ${data['error']?['message'] ?? 'Unknown error'}';
          _isValid = false;
          _isValidating = false;
        });
      } else {
        setState(() {
          _validationMessage =
              '✗ API Key validation failed (Status ${response.statusCode})';
          _isValid = false;
          _isValidating = false;
        });
      }
    } catch (e) {
      setState(() {
        _validationMessage = '✗ Error validating key: ${e.toString()}';
        _isValid = false;
        _isValidating = false;
      });
    }
  }

  Future<void> _clearApiKey() async {
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
      setState(() {
        _apiKeyController.clear();
        _useOwnApiKey = false;
        _validationMessage = null;
        _isValid = null;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('gemini_api_key');
      await prefs.setBool('use_own_api_key', false);
      await prefs.setBool('is_premium_byok', false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key cleared')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
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
            _buildApiToggleCard(),
            if (_useOwnApiKey) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildBenefitsCard(),
              const SizedBox(height: AppSpacing.md),
              _buildPrivacyCard(),
            ],
          ],
        ),
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
}

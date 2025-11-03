// lib/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              color: Colors.deepPurple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.vpn_key, color: Colors.deepPurple.shade700),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Bring Your Own API Key',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use your free Gemini API key to unlock all premium features!',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Toggle Switch
            SwitchListTile(
              title: const Text(
                'Use my own Gemini API key',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Unlock unlimited stories and features'),
              value: _useOwnApiKey,
              activeColor: Colors.deepPurple,
              onChanged: (value) {
                setState(() => _useOwnApiKey = value);
                _saveSettings();
              },
            ),

            if (_useOwnApiKey) ...[
              const SizedBox(height: 16),

              // API Key Input
              TextField(
                controller: _apiKeyController,
                decoration: InputDecoration(
                  labelText: 'Gemini API Key',
                  hintText: 'AIza...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _obscureApiKey = !_obscureApiKey);
                        },
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
              ),

              const SizedBox(height: 12),

              // Validation Message
              if (_validationMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isValid == true
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isValid == true
                          ? Colors.green.shade200
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isValid == true ? Icons.check_circle : Icons.error,
                        color:
                            _isValid == true ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _validationMessage!,
                          style: TextStyle(
                            color: _isValid == true
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Validate Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isValidating ? null : _validateApiKey,
                  icon: _isValidating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.verified_user),
                  label: Text(_isValidating ? 'Validating...' : 'Validate & Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Help Button
              TextButton.icon(
                onPressed: _launchApiKeyHelp,
                icon: const Icon(Icons.help_outline),
                label: const Text('How do I get an API key?'),
              ),

              const SizedBox(height: 24),

              // Benefits Card
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Benefits',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildBenefitRow('✓ Unlimited story generation'),
                      _buildBenefitRow('✓ Interactive choose-your-own-adventure'),
                      _buildBenefitRow('✓ Superhero mode'),
                      _buildBenefitRow('✓ All avatar customizations'),
                      _buildBenefitRow('✓ Advanced therapeutic features'),
                      _buildBenefitRow('✓ No subscription needed'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Privacy Note
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.lock, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Your API key is stored securely on your device and never sent to our servers.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(color: Colors.green.shade900),
      ),
    );
  }
}

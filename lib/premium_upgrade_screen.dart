// lib/premium_upgrade_screen.dart

import 'package:flutter/material.dart';
import 'subscription_models.dart';
import 'settings_screen.dart' deferred as settings_screen;
import 'services/analytics_service.dart';
import 'widgets/subscribe_button.dart';

class PremiumUpgradeScreen extends StatefulWidget {
  final String? requiredFeature;
  final String? customMessage;

  const PremiumUpgradeScreen({
    super.key,
    this.requiredFeature,
    this.customMessage,
  });

  @override
  State<PremiumUpgradeScreen> createState() => _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends State<PremiumUpgradeScreen> {
  SubscriptionTier? _selectedTier;
  bool _isYearly = true;

  @override
  void initState() {
    super.initState();
    // Funnel instrumentation (MT-249): the paywall/upsell is now on screen.
    // Fire-and-forget — never blocks or breaks the screen.
    AnalyticsService.paywallViewed(requiredFeature: widget.requiredFeature);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade to Premium'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple,
              Colors.deepPurple.shade300,
              Colors.white,
            ],
            stops: const [0.0, 0.3, 0.3],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header section
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.auto_stories,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unlock Unlimited Storytelling',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (widget.customMessage != null)
                      Text(
                        widget.customMessage!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),

              // FREE PREMIUM OPTION - BYOK
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade300, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.key,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FREE Premium Option',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  'Bring Your Own API Key',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'FREE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Get FREE access to all premium features by using your own Google AI API key. Google provides monthly free credit—enough for most families.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await settings_screen.loadLibrary();
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                 MaterialPageRoute(
                                   builder: (_) => settings_screen.SettingsScreen(),
                                 ),
                              );
                            }
                          },
                          icon: const Icon(Icons.settings),
                          label: const Text(
                            'Set Up Free Premium',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // DIVIDER
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),

              // Paid Subscription Options
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text(
                  'Choose a Paid Plan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Billing toggle
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildBillingToggle('Monthly', !_isYearly),
                    ),
                    Expanded(
                      child:
                          _buildBillingToggle('Yearly (Save 33%)', _isYearly),
                    ),
                  ],
                ),
              ),

              // Pricing cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: TierPricing.allTiers
                      .where((pricing) => pricing.tier != SubscriptionTier.free)
                      .map((pricing) => _buildPricingCard(pricing))
                      .toList(),
                ),
              ),

              const SizedBox(height: 24),

              // Features comparison
              _buildFeaturesComparison(),

              const SizedBox(height: 24),

              // CTA Button
              if (_selectedTier != null)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      SubscribeButton(
                        tier: _selectedTier!,
                        onSuccess: () {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Redirecting to checkout for ${_selectedTier!.displayName}',
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Cancel anytime • Safe & Secure',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillingToggle(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isYearly = label.contains('Yearly');
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildPricingCard(TierPricing pricing) {
    final isSelected = _selectedTier == pricing.tier;
    final price = _isYearly ? pricing.yearlyPrice : pricing.monthlyPrice;
    final perMonth = _isYearly ? price / 12 : price;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTier = pricing.tier;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? pricing.tier.color : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:
                        pricing.tier.color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        pricing.tier.icon,
                        color: pricing.tier.color,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pricing.tier.displayName,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: pricing.tier.color,
                              ),
                            ),
                            if (_isYearly && pricing.yearlySavings > 0)
                              Text(
                                'Save \$${pricing.yearlySavings.toStringAsFixed(2)}/year',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${perMonth.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            '/month',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  ...pricing.features.map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: pricing.tier.color,
                              size: 20,
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            if (pricing.badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: pricing.tier.color,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    pricing.badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesComparison() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why Go Premium?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildFeatureHighlight(
            Icons.psychology_alt,
            'Therapeutic Superhero Missions',
            'Unlock playful heroes that model brave, kind responses for tough moments.',
          ),
          _buildFeatureHighlight(
            Icons.self_improvement,
            'Guided Growth Quests',
            'Access expanded therapeutic prompts and coping tools for each story session.',
          ),
          _buildFeatureHighlight(
            Icons.people,
            'Multi-Character Stories',
            'Create stories with siblings and friends together',
          ),
          _buildFeatureHighlight(
            Icons.download,
            'Export & Share',
            'Save stories as PDFs and share with family',
          ),
          _buildFeatureHighlight(
            Icons.block,
            'Ad-Free',
            'Enjoy uninterrupted storytelling without ads',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureHighlight(
      IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.deepPurple, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

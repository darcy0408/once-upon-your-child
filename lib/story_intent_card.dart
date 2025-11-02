// Story Intent Card
// Unified theme selection and therapeutic customization
// Age-inclusive: supports kids, teens, and adults

import 'package:flutter/material.dart';

class StoryIntentCard extends StatefulWidget {
  final Function(StoryIntentData)? onIntentChanged;
  final StoryIntentData? initialData;

  const StoryIntentCard({
    super.key,
    this.onIntentChanged,
    this.initialData,
  });

  @override
  State<StoryIntentCard> createState() => _StoryIntentCardState();
}

class _StoryIntentCardState extends State<StoryIntentCard> {
  // Narrative style selection
  String? _selectedStyle;

  // Support focus selection (optional, can be multiple)
  Set<String> _selectedFocuses = {};

  // Text field controllers
  final TextEditingController _situationController = TextEditingController();
  final TextEditingController _outcomeController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  // Available narrative styles
  final List<String> _narrativeStyles = [
    'Adventure',
    'Friendship',
    'Magic',
    'Dragons',
    'Castles',
    'Unicorns',
    'Space',
    'Ocean',
  ];

  // Available support focuses
  final List<String> _supportFocuses = [
    'Building Confidence',
    'Managing Anxiety',
    'Social Skills',
    'Emotional Regulation',
    'Building Resilience',
    'Dealing with Bullies',
    'Overcoming Fears',
    'Life Transitions',
    'Self-Esteem',
    'Making Friends',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _selectedStyle = widget.initialData!.narrativeStyle;
      _selectedFocuses = Set.from(widget.initialData!.supportFocuses);
      _situationController.text = widget.initialData!.situation ?? '';
      _outcomeController.text = widget.initialData!.desiredOutcome ?? '';
      _messageController.text = widget.initialData!.message ?? '';
    }
  }

  @override
  void dispose() {
    _situationController.dispose();
    _outcomeController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    if (widget.onIntentChanged != null) {
      widget.onIntentChanged!(
        StoryIntentData(
          narrativeStyle: _selectedStyle,
          supportFocuses: _selectedFocuses.toList(),
          situation: _situationController.text.trim().isEmpty
              ? null
              : _situationController.text,
          desiredOutcome: _outcomeController.text.trim().isEmpty
              ? null
              : _outcomeController.text,
          message: _messageController.text.trim().isEmpty
              ? null
              : _messageController.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFF8F0), // Cream light
              const Color(0xFFA8D5A3).withOpacity(0.1), // Jungle mint hint
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 20),

              // A. Narrative Style Section
              _buildNarrativeStyleSection(),
              const SizedBox(height: 24),

              // B. Support Focus Section (Optional)
              _buildSupportFocusSection(),
              const SizedBox(height: 24),

              // C. Free-Text Inputs
              _buildFreeTextInputs(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6B9F4A), // Jungle leaf
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_stories,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Story Intent',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D5016), // Jungle deep green
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Pick a style and (optional) support focus. This works for any age — kids, teens, and adults.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF556B2F), // Jungle olive
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildNarrativeStyleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Narrative Style',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D5016),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose the vibe and fantasy flavor for your story',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF556B2F),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _narrativeStyles.map((style) {
            final isSelected = _selectedStyle == style;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedStyle = style;
                });
                _notifyChange();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6B9F4A)
                      : Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF6B9F4A)
                        : const Color(0xFF87B668),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF6B9F4A).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  style,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF2D5016),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSupportFocusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Support Focus',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D5016),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB26B), // Sunset peach
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'optional',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose anything you\'d like this story to help with — confidence, anxiety, stress, friendship, life changes, etc.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF556B2F),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _supportFocuses.map((focus) {
            final isSelected = _selectedFocuses.contains(focus);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedFocuses.remove(focus);
                  } else {
                    _selectedFocuses.add(focus);
                  }
                });
                _notifyChange();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF9B59B6) // Purple for support
                      : Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF9B59B6)
                        : const Color(0xFFC39BD3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF9B59B6).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  focus,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF2D5016),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFreeTextInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32, thickness: 1, color: Color(0xFFA8D5A3)),

        // Input 1: What's happening
        _buildTextField(
          controller: _situationController,
          label: 'What\'s happening that you want this story to help with?',
          hint: 'e.g., "I\'m anxious before tests" or "Work stress is wearing me down" or "My daughter is scared of the dark"',
          maxLines: 3,
        ),
        const SizedBox(height: 20),

        // Input 2: Desired outcome
        _buildTextField(
          controller: _outcomeController,
          label: 'What outcome would you love to see in the story?',
          hint: 'e.g., "I feel calmer and more confident"',
          maxLines: 2,
        ),
        const SizedBox(height: 20),

        // Input 3: Message to reinforce
        _buildTextField(
          controller: _messageController,
          label: 'Is there a message you\'d like the story to reinforce?',
          hint: 'e.g., "You are capable and safe"',
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D5016),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: (_) => _notifyChange(),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: Colors.grey[400],
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF87B668), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF87B668), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6B9F4A), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF2D5016),
          ),
        ),
      ],
    );
  }
}

// Data class to hold story intent information
class StoryIntentData {
  final String? narrativeStyle;
  final List<String> supportFocuses;
  final String? situation;
  final String? desiredOutcome;
  final String? message;

  StoryIntentData({
    this.narrativeStyle,
    this.supportFocuses = const [],
    this.situation,
    this.desiredOutcome,
    this.message,
  });

  Map<String, dynamic> toJson() => {
        'narrativeStyle': narrativeStyle,
        'supportFocuses': supportFocuses,
        'situation': situation,
        'desiredOutcome': desiredOutcome,
        'message': message,
      };

  factory StoryIntentData.fromJson(Map<String, dynamic> json) {
    return StoryIntentData(
      narrativeStyle: json['narrativeStyle'],
      supportFocuses: json['supportFocuses'] != null
          ? List<String>.from(json['supportFocuses'])
          : [],
      situation: json['situation'],
      desiredOutcome: json['desiredOutcome'],
      message: json['message'],
    );
  }
}

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
  // Support focus selection (optional, can be multiple)
  Set<String> _selectedFocuses = {};

  // Story elements selection
  Set<String> _selectedElements = {};

  // Text field controllers
  final TextEditingController _situationController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

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
    'Focus & Listening',
  ];

  // Available story elements
  final List<String> _storyElements = [
    'Friends',
    'Siblings',
    'Magic',
    'Animals',
    'School',
    'Home',
    'Park',
    'Toys',
    'Nature',
    'Space',
    'Ocean',
    'Castle',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _selectedFocuses = Set.from(widget.initialData!.supportFocuses);
      _selectedElements = Set.from(widget.initialData!.storyElements);
      _situationController.text = widget.initialData!.situation ?? '';
      _messageController.text = widget.initialData!.message ?? '';
    }
  }

  @override
  void dispose() {
    _situationController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    if (widget.onIntentChanged != null) {
      widget.onIntentChanged!(
        StoryIntentData(
          supportFocuses: _selectedFocuses.toList(),
          storyElements: _selectedElements.toList(),
          situation: _situationController.text.trim().isEmpty
              ? null
              : _situationController.text,
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
              const Color(0xFFA8D5A3).withValues(alpha: 0.1), // Jungle mint hint
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

              // 1. Situation & Focus
              _buildSituationSection(),
              const SizedBox(height: 24),

              // 2. Story Elements
              _buildStoryElementsSection(),
              const SizedBox(height: 24),

              // 3. Message
              _buildMessageSection(),
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
          'Customize what happens in the story.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF556B2F), // Jungle olive
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSituationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _situationController,
          label: 'What\'s happening?',
          hint: 'e.g., "Nervous about school" or "Want to learn about sharing"',
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        const Text(
          'Or choose a focus:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF556B2F),
          ),
        ),
        const SizedBox(height: 8),
        _buildChipGroup(
          items: _supportFocuses,
          selectedItems: _selectedFocuses,
          onSelectionChanged: (item, isSelected) {
            setState(() {
              if (isSelected) {
                _selectedFocuses.add(item);
              } else {
                _selectedFocuses.remove(item);
              }
            });
            _notifyChange();
          },
          color: const Color(0xFF9B59B6), // Purple
        ),
      ],
    );
  }

  Widget _buildStoryElementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Include in story:',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D5016),
          ),
        ),
        const SizedBox(height: 8),
        _buildChipGroup(
          items: _storyElements,
          selectedItems: _selectedElements,
          onSelectionChanged: (item, isSelected) {
            setState(() {
              if (isSelected) {
                _selectedElements.add(item);
              } else {
                _selectedElements.remove(item);
              }
            });
            _notifyChange();
          },
          color: const Color(0xFF2980B9), // Blue
        ),
      ],
    );
  }

  Widget _buildMessageSection() {
    return _buildTextField(
      controller: _messageController,
      label: 'Message to reinforce (Optional)',
      hint: 'e.g., "You are brave" or "It\'s okay to ask for help"',
      maxLines: 1,
    );
  }

  Widget _buildChipGroup({
    required List<String> items,
    required Set<String> selectedItems,
    required Function(String, bool) onSelectionChanged,
    required Color color,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final isSelected = selectedItems.contains(item);
        return GestureDetector(
          onTap: () => onSelectionChanged(item, !isSelected),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white,
              border: Border.all(
                color: isSelected ? color : color.withValues(alpha: 0.5),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Text(
              item,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : color.withValues(alpha: 0.8),
              ),
            ),
          ),
        );
      }).toList(),
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
        Semantics(
          label: label,
          textField: true,
          child: TextField(
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
        ),
      ],
    );
  }
}

// Data class to hold story intent information
class StoryIntentData {
  final List<String> supportFocuses;
  final List<String> storyElements;
  final String? situation;
  final String? message;

  StoryIntentData({
    this.supportFocuses = const [],
    this.storyElements = const [],
    this.situation,
    this.message,
  });

  Map<String, dynamic> toJson() => {
        'supportFocuses': supportFocuses,
        'storyElements': storyElements,
        'situation': situation,
        'message': message,
      };

  factory StoryIntentData.fromJson(Map<String, dynamic> json) {
    return StoryIntentData(
      supportFocuses: json['supportFocuses'] != null
          ? List<String>.from(json['supportFocuses'])
          : [],
      storyElements: json['storyElements'] != null
          ? List<String>.from(json['storyElements'])
          : [],
      situation: json['situation'],
      message: json['message'],
    );
  }
}

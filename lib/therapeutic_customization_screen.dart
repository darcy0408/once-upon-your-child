// lib/therapeutic_customization_screen.dart

import 'package:flutter/material.dart';
import 'therapeutic_models.dart';

class TherapeuticCustomizationScreen extends StatefulWidget {
  const TherapeuticCustomizationScreen({super.key});

  @override
  State<TherapeuticCustomizationScreen> createState() =>
      _TherapeuticCustomizationScreenState();
}

class _TherapeuticCustomizationScreenState
    extends State<TherapeuticCustomizationScreen> {
  TherapeuticGoal? _selectedGoal;
  TherapeuticScenario? _selectedScenario;
  final List<StoryWish> _wishes = [];
  final TextEditingController _situationController = TextEditingController();
  final TextEditingController _lessonController = TextEditingController();
  final Set<String> _selectedStrategies = {};

  @override
  void dispose() {
    _situationController.dispose();
    _lessonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Therapeutic Story Customization'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade100, Colors.blue.shade100],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.psychology, size: 48, color: Colors.deepPurple),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a Healing Story',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stories can help children process feelings and build coping skills',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Therapeutic Goal
            _buildSectionCard(
              'What do you want to work on?',
              Icons.track_changes,
              _buildGoalSelector(),
            ),

            const SizedBox(height: 16),

            // Pre-made scenarios
            if (_selectedGoal != null) ...[
              _buildSectionCard(
                'Or choose a scenario template',
                Icons.auto_stories,
                _buildScenarioSelector(),
              ),
              const SizedBox(height: 16),
            ],

            // Specific situation
            _buildSectionCard(
              'Describe the specific situation (optional)',
              Icons.edit_note,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'e.g., "A classmate keeps taking my pencils" or "Moving to a new house"',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _situationController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'What\'s happening that you want to address?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Story wishes
            _buildSectionCard(
              'What would you like to see happen?',
              Icons.auto_awesome,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add specific outcomes you\'d like in the story',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ..._wishes.map((wish) => _buildWishCard(wish)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addWish,
                    icon: const Icon(Icons.add),
                    label: const Text('Add a wish'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Coping strategies
            if (_selectedScenario != null) ...[
              _buildSectionCard(
                'Coping strategies to highlight',
                Icons.psychology_alt,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedScenario!.copingStrategies.map((strategy) {
                    final isSelected = _selectedStrategies.contains(strategy);
                    return FilterChip(
                      label: Text(strategy),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedStrategies.add(strategy);
                          } else {
                            _selectedStrategies.remove(strategy);
                          }
                        });
                      },
                      selectedColor: Colors.deepPurple.shade100,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Desired lesson
            _buildSectionCard(
              'Lesson or message (optional)',
              Icons.school,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What message or lesson would you like the story to reinforce?',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _lessonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g., "You are brave and can handle challenges"',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Create story button
            ElevatedButton.icon(
              onPressed: _createTherapeuticStory,
              icon: const Icon(Icons.auto_stories, size: 28),
              label: const Text(
                'Create Therapeutic Story',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, Widget content) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TherapeuticGoal.values.map((goal) {
        final isSelected = _selectedGoal == goal;
        return FilterChip(
          label: Text(goal.displayName),
          selected: isSelected,
          avatar: Icon(goal.icon, size: 18, color: isSelected ? Colors.white : goal.color),
          onSelected: (selected) {
            setState(() {
              _selectedGoal = selected ? goal : null;
              if (selected) {
                // Auto-select matching scenario
                _selectedScenario = TherapeuticScenario.getAllScenarios()
                    .where((s) => s.goal == goal)
                    .firstOrNull;
                if (_selectedScenario != null) {
                  _selectedStrategies.clear();
                }
              }
            });
          },
          selectedColor: goal.color,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScenarioSelector() {
    final scenarios = TherapeuticScenario.getAllScenarios()
        .where((s) => s.goal == _selectedGoal)
        .toList();

    if (scenarios.isEmpty) return const SizedBox();

    return Column(
      children: scenarios.map((scenario) {
        final isSelected = _selectedScenario?.id == scenario.id;
        return Card(
          color: isSelected ? Colors.deepPurple.shade50 : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: scenario.goal.color,
              child: Icon(scenario.goal.icon, color: Colors.white, size: 20),
            ),
            title: Text(
              scenario.title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(scenario.description),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: Colors.deepPurple)
                : null,
            onTap: () {
              setState(() {
                _selectedScenario = scenario;
                _selectedStrategies.clear();
              });
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWishCard(StoryWish wish) {
    return Card(
      color: Colors.amber.shade50,
      child: ListTile(
        leading: const Icon(Icons.star, color: Colors.amber),
        title: Text(wish.description),
        subtitle: Text(wish.type.displayName),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            setState(() {
              _wishes.remove(wish);
            });
          },
        ),
      ),
    );
  }

  void _addWish() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        WishType selectedType = WishType.other;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add a Story Wish'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'e.g., "The bully apologizes and learns to be kind"',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<WishType>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type of wish',
                      border: OutlineInputBorder(),
                    ),
                    items: WishType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      setState(() {
                        _wishes.add(StoryWish(
                          description: controller.text,
                          type: selectedType,
                        ));
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _createTherapeuticStory() {
    final customization = TherapeuticStoryCustomization(
      primaryGoal: _selectedGoal,
      wishes: _wishes,
      specificSituation: _situationController.text.isEmpty
          ? null
          : _situationController.text,
      copingStrategiesToHighlight: _selectedStrategies.toList(),
      desiredLesson: _lessonController.text.isEmpty
          ? null
          : _lessonController.text,
    );

    // Return to main story screen with customization
    Navigator.pop(context, customization);
  }
}

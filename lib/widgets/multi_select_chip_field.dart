import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A reusable chip selector that allows choosing multiple options with optional
/// custom inputs. Selections are capped by [maxSelection] and reported through
/// [onChanged].
class MultiSelectChipField extends StatefulWidget {
  const MultiSelectChipField({
    super.key,
    required this.title,
    required this.helperText,
    required this.suggestions,
    required this.initialSelection,
    required this.onChanged,
    this.maxSelection = 5,
    this.fieldLabel = 'items',
    this.addCustomLabel = 'Add Custom',
  });

  /// Header text displayed above the chips.
  final String title;

  /// Helper description displayed under the title.
  final String helperText;

  /// Suggested chip values shown to the user.
  final List<String> suggestions;

  /// Initial selections supplied by the parent.
  final Set<String> initialSelection;

  /// Callback invoked whenever the selection changes.
  final ValueChanged<Set<String>> onChanged;

  /// Maximum number of selectable chips.
  final int maxSelection;

  /// Label used in limit/validation messages.
  final String fieldLabel;

  /// Label used for the "add custom" chip.
  final String addCustomLabel;

  @override
  State<MultiSelectChipField> createState() => _MultiSelectChipFieldState();
}

class _MultiSelectChipFieldState extends State<MultiSelectChipField> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelection};
  }

  @override
  void didUpdateWidget(covariant MultiSelectChipField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!setEquals(oldWidget.initialSelection, widget.initialSelection)) {
      setState(() {
        _selected = {...widget.initialSelection};
      });
    }
  }

  void _notifyParent() {
    widget.onChanged({..._selected});
  }

  bool _containsIgnoreCase(Set<String> target, String value) {
    final lower = value.toLowerCase();
    return target.any((item) => item.toLowerCase() == lower);
  }

  void _showSnack(String message, {Color background = Colors.orange}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
      ),
    );
  }

  String _formatCustomValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    final words = trimmed.split(RegExp(r'\\s+'));
    return words
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  Future<void> _addCustomValue() async {
    if (_selected.length >= widget.maxSelection) {
      _showSnack(
          'You can choose up to ${widget.maxSelection} ${widget.fieldLabel}.');
      return;
    }

    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(widget.addCustomLabel),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Type a custom value',
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (label == null) return;
    final formatted = _formatCustomValue(label);
    if (formatted.isEmpty) return;

    if (_containsIgnoreCase(_selected, formatted)) {
      _showSnack('That option is already selected.');
      return;
    }

    setState(() {
      _selected.add(formatted);
    });
    _notifyParent();
  }

  void _toggleValue(String value) {
    final alreadySelected = _containsIgnoreCase(_selected, value);
    if (alreadySelected) {
      setState(() {
        _selected
            .removeWhere((item) => item.toLowerCase() == value.toLowerCase());
      });
      _notifyParent();
      return;
    }

    if (_selected.length >= widget.maxSelection) {
      _showSnack(
          'You can choose up to ${widget.maxSelection} ${widget.fieldLabel}.');
      return;
    }

    setState(() {
      _selected.add(value);
    });
    _notifyParent();
  }

  @override
  Widget build(BuildContext context) {
    final displayOptions = <String>[
      ...widget.suggestions,
      ..._selected.where(
        (item) => !widget.suggestions
            .any((option) => option.toLowerCase() == item.toLowerCase()),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.helperText,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in displayOptions)
              FilterChip(
                label: Text(option),
                selected: _containsIgnoreCase(_selected, option),
                onSelected: (_) => _toggleValue(option),
                selectedColor: Colors.deepPurple.shade100,
                checkmarkColor: Colors.deepPurple,
              ),
            ActionChip(
              label: Text(widget.addCustomLabel),
              avatar: const Icon(Icons.add, size: 18),
              onPressed: _addCustomValue,
              backgroundColor: Colors.deepPurple.shade50,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${_selected.length}/${widget.maxSelection} selected',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

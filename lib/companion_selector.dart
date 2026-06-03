import 'package:flutter/material.dart';
import 'widgets/safe_asset_image.dart';


/// Backend-aligned companion names.
const kCompanionOptions = <CompanionOption>[
  CompanionOption(
    label: 'None',
    keyName: 'None',
    asset: null,
    description: 'Go on a solo adventure!',
  ),
  CompanionOption(
    label: 'Star Dog',
    keyName: 'Star Dog',
    asset: 'assets/images/companions/dog.jpg',
    description: 'A loyal pup with a coat like the night sky and a super-powered sniff.',
  ),
  CompanionOption(
    label: 'Shadow Cat',
    keyName: 'Shadow Cat',
    asset: 'assets/images/companions/cat.jpg',
    description: 'A sleek, mysterious friend who can vanish into the shadows.',
  ),
  CompanionOption(
    label: 'Tiny Dragon',
    keyName: 'Tiny Dragon',
    asset: 'assets/images/companions/dragon.jpg',
    description: 'A pocket-sized powerhouse who can light the way with a tiny spark.',
  ),
  CompanionOption(
    label: 'Wise Owl',
    keyName: 'Wise Owl',
    asset: 'assets/images/companions/owl.jpg',
    description: 'A clever feathered friend who knows ancient secrets and sees in the dark.',
  ),
  CompanionOption(
    label: 'Magic Unicorn',
    keyName: 'Magic Unicorn',
    asset: 'assets/images/companions/unicorn.jpg',
    description: 'A shimmering guide who can heal spirits and find hidden paths.',
  ),
  CompanionOption(
    label: 'Clever Fox',
    keyName: 'Clever Fox',
    asset: 'assets/images/companions/fox.jpg',
    description: 'A quick-witted trickster who can solve any puzzle or outsmart any trap.',
  ),
  CompanionOption(
    label: 'Robin',
    keyName: 'Robin',
    asset: 'assets/images/companions/robin.jpg',
    description: 'Flies ahead to scout every path and signals the all-clear — three chirps means danger, one long note means you\'re safe to come.',
  ),
];

class CompanionOption {
  final String label;   // Shown in UI
  final String keyName; // Sent to backend
  final String? asset;  // Optional image path
  final String description; // NEW: Detailed description
  const CompanionOption({
    required this.label,
    required this.keyName,
    required this.description,
    this.asset,
  });
}

/// A nice, self-contained selector with:
/// - Search bar
/// - Chips/Grid toggle
/// - “None” option
/// - Optional images (falls back to icon)
class CompanionSelector extends StatefulWidget {
  final String value;                   // current selected keyName (e.g., "Tiny Dragon" or "None")
  final ValueChanged<String> onChanged; // returns keyName
  final List<CompanionOption> options;

  const CompanionSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.options = kCompanionOptions,
  });

  @override
  State<CompanionSelector> createState() => _CompanionSelectorState();
}

class _CompanionSelectorState extends State<CompanionSelector> {
  String _query = '';
  bool _gridMode = false;

  List<CompanionOption> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options.where((o) =>
        o.label.toLowerCase().contains(q) || o.keyName.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Choose a Companion (Optional)', style: theme.textTheme.titleMedium),
            Row(
              children: [
                IconButton(
                  tooltip: _gridMode ? 'Use chips' : 'Use grid',
                  icon: Icon(_gridMode ? Icons.view_agenda : Icons.grid_view),
                  onPressed: () => setState(() => _gridMode = !_gridMode),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Search
        Semantics(
          label: 'Search companions',
          textField: true,
          child: TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search companions…',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        ),
        const SizedBox(height: 12),

        // Content
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _gridMode
              ? _GridViewCompanions(
                  key: const ValueKey('grid'),
                  options: _filtered,
                  selected: selected,
                  onSelect: widget.onChanged,
                )
              : _ChipsCompanions(
                  key: const ValueKey('chips'),
                  options: _filtered,
                  selected: selected,
                  onSelect: widget.onChanged,
                ),
        ),
      ],
    );
  }
}

class _ChipsCompanions extends StatelessWidget {
  final List<CompanionOption> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _ChipsCompanions({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final isSel = o.keyName == selected;
        return Tooltip(
          message: o.description,
          child: ChoiceChip(
            label: Text(o.label),
            selected: isSel,
            avatar: _ChipAvatar(option: o, selected: isSel),
            onSelected: (_) => onSelect(o.keyName),
          ),
        );
      }).toList(),
    );
  }
}

class _GridViewCompanions extends StatelessWidget {
  final List<CompanionOption> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _GridViewCompanions({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 520;
    final cross = isWide ? 4 : 2;
    return GridView.builder(
      itemCount: options.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        childAspectRatio: 0.85, // Adjusted for description
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (_, i) {
        final o = options[i];
        final isSel = o.keyName == selected;
        return InkWell(
          onTap: () => onSelect(o.keyName),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSel ? Colors.blueAccent : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ImageOrIcon(option: o, size: 40),
                const SizedBox(height: 8),
                Text(
                  o.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSel ? Colors.blueAccent : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    o.description,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSel ? Colors.blueGrey : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChipAvatar extends StatelessWidget {
  final CompanionOption option;
  final bool selected;
  const _ChipAvatar({required this.option, required this.selected});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: selected ? Colors.blue.withValues(alpha: .12) : Colors.grey.withValues(alpha: .12),
      child: _ImageOrIcon(option: option, size: 18),
    );
  }
}

class _ImageOrIcon extends StatelessWidget {
  final CompanionOption option;
  final double size;
  const _ImageOrIcon({required this.option, required this.size});

  @override
  Widget build(BuildContext context) {
    final asset = option.asset;
    if (asset == null) {
      // Fallback icons mapped by name
      final name = option.keyName.toLowerCase();
      IconData icon = Icons.pets;
      if (name.contains('cat')) icon = Icons.pets;
      if (name.contains('dog')) icon = Icons.pets;
      if (name.contains('dragon')) icon = Icons.local_fire_department;
      if (name.contains('owl')) icon = Icons.visibility;
      if (name.contains('horse')) icon = Icons.directions_run;
      if (name.contains('robot')) icon = Icons.smart_toy;
      if (name.contains('fairy')) icon = Icons.auto_awesome;
      if (name == 'none') icon = Icons.block;
      return Icon(icon, size: size);
    }
    return SafeAssetImage(
      asset,
      width: size,
      height: size,
      placeholder: const Icon(Icons.image_not_supported),
    );
  }
}

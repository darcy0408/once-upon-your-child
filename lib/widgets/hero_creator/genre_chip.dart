import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GenreChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  /// UI font family for the chip label. Pass `'Bitter'` so the Adventurer band
  /// reads with its slab-serif "book feel" (MT-277); when null the chip keeps
  /// the rounded Fredoka used by the younger bands.
  final String? fontFamily;

  const GenreChip({
    super.key,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        // Floor the height at 44px so chips meet the minimum tap target — the
        // 10px vertical padding alone leaves them ~36-40px, below the norm and
        // well under the Adventurer band's 64px standard.
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF9E6CFF).withAlpha(230)
              : Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? const Color(0xFFE28EFF) : Colors.white24,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: const Color(0xFF9E6CFF).withAlpha(100),
                      blurRadius: 8,
                      spreadRadius: 1)
                ]
              : [],
        ),
        child: Text(
          label,
          style: (fontFamily == 'Bitter' ? GoogleFonts.bitter : GoogleFonts.fredoka)(
            color: Colors.white,
            fontSize: 15,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/age_band_theme.dart';
import '../safe_asset_image.dart';

class GenderImageButton extends StatefulWidget {
  const GenderImageButton({
    super.key,
    required this.gender,
    this.label,
    required this.assetPath,
    required this.isSelected,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final String gender;
  /// Display label shown below the image. Defaults to [gender] if not provided.
  final String? label;
  final String assetPath;
  final bool isSelected;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  State<GenderImageButton> createState() => _GenderImageButtonState();
}

class _GenderImageButtonState extends State<GenderImageButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final bool useDecorative = band.band == AgeBand.explorer;
    final imageWidget = SafeAssetImage(
      widget.assetPath,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
    );

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: widget.label ?? widget.gender,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: _pressed ? 1.08 : (_hovered ? 1.04 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1828),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withAlpha(160),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withAlpha(80),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                  border: Border.all(
                    color: widget.isSelected
                        ? const Color(0xFFFFD700)
                        : _hovered
                            ? const Color(0xFFFFD700).withAlpha(100)
                            : Colors.white30,
                    width: widget.isSelected ? 3.5 : 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: ColoredBox(
                    color: const Color(0xFF1E1828),
                    child: _pressed
                        ? ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                                Color(0x44FFFFFF), BlendMode.screen),
                            child: imageWidget,
                          )
                        : imageWidget,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: useDecorative
                    ? GoogleFonts.cinzelDecorative(
                        color: widget.isSelected
                            ? const Color(0xFFFFD700)
                            : Colors.white70,
                        fontSize: 15,
                        fontWeight: widget.isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        shadows: [
                          Shadow(
                            color: widget.isSelected
                                ? const Color(0xFFFFD700)
                                : const Color(0x00FFD700),
                            blurRadius: widget.isSelected ? 10.0 : 0.0,
                          ),
                        ],
                      )
                    : GoogleFonts.sourceSans3(
                        color: widget.isSelected
                            ? const Color(0xFFFFD700)
                            : Colors.white70,
                        fontSize: 15,
                        fontWeight: widget.isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                child: Text(widget.label ?? widget.gender),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class ThemedNameInput extends StatefulWidget {
  const ThemedNameInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.fontSize,
    required this.height,
    required this.onChanged,
    this.onMicTap,
    this.isListening = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final double fontSize;
  final double height;
  final ValueChanged<String> onChanged;
  final VoidCallback? onMicTap;
  final bool isListening;

  @override
  State<ThemedNameInput> createState() => _ThemedNameInputState();
}

class _ThemedNameInputState extends State<ThemedNameInput>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _focused = widget.focusNode.hasFocus);
    if (_focused) {
      _glowCtrl.repeat(reverse: true);
    } else {
      _glowCtrl.stop();
      _glowCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final bool useDecorative = band.band == AgeBand.explorer;
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) {
        final g = _focused ? _glowAnim.value : 0.0;
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFF5C1A8C).withAlpha(200),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _focused
                  ? Color.fromARGB(
                      (180 + (g * 75).round()).clamp(0, 255), 0xFF, 0xD5, 0x4F)
                  : const Color(0xFFFFD54F).withAlpha(130),
              width: _focused ? 2.0 : 1.5,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color:
                          const Color(0xFFFFD54F).withAlpha((80 * g).round()),
                      blurRadius: 18 * g,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(60),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: widget.onMicTap != null ? 8 : 24,
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                textAlign: TextAlign.center,
                style: useDecorative
                    ? GoogleFonts.cinzelDecorative(
                        fontSize: widget.fontSize,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(color: Color(0xFFFFD54F), blurRadius: 6)
                        ],
                      )
                    : GoogleFonts.sourceSans3(
                        fontSize: widget.fontSize,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                decoration: InputDecoration(
                  hintText: "Type your hero's name...",
                  hintStyle: useDecorative
                      ? GoogleFonts.cinzelDecorative(
                          color: const Color(0xFFFFE082).withAlpha(180),
                          fontSize: widget.fontSize * 0.85,
                          fontWeight: FontWeight.w400,
                        )
                      : TextStyle(
                          color: Colors.white30,
                          fontSize: widget.fontSize * 0.85,
                        ),
                  border: InputBorder.none,
                  filled: false,
                  suffixIcon: widget.onMicTap != null
                      ? GestureDetector(
                          onTap: widget.onMicTap,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.all(8),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.isListening
                                  ? Colors.red.shade400
                                  : const Color(0xFFFFD54F).withAlpha(50),
                              border: Border.all(
                                color: widget.isListening
                                    ? Colors.red
                                    : const Color(0xFFFFD54F).withAlpha(180),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              widget.isListening
                                  ? Icons.mic
                                  : Icons.mic_none_rounded,
                              size: 18,
                              color: widget.isListening
                                  ? Colors.white
                                  : const Color(0xFFFFD54F),
                            ),
                          ),
                        )
                      : null,
                ),
                onChanged: widget.onChanged,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A stateful arrow button with clear press feedback:
/// shrinks to 86% + brightens gradient + amplifies glow on tap-down.
class PressableArrowButton extends StatefulWidget {
  const PressableArrowButton({
    super.key,
    required this.enabled,
    required this.onTap,
    this.hint,
  });
  final bool enabled;
  final VoidCallback onTap;
  final String? hint;

  @override
  State<PressableArrowButton> createState() => _PressableArrowButtonState();
}

class _PressableArrowButtonState extends State<PressableArrowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final btnSize = (band.touchTargetMin / 64.0 * 80).roundToDouble();
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTapDown:
                widget.enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp:
                widget.enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.enabled ? widget.onTap : null,
            child: AnimatedScale(
              scale: _pressed ? 0.86 : 1.0,
              duration: const Duration(milliseconds: 80),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: btnSize,
                height: btnSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _pressed
                        ? [const Color(0xFFD070FF), const Color(0xFF8B4FD8)]
                        : [const Color(0xFF9B3FD8), const Color(0xFF5B1BAA)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700)
                          .withAlpha(_pressed ? 200 : 100),
                      blurRadius: _pressed ? 32 : 20,
                      spreadRadius: _pressed ? 4 : 0,
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: btnSize * 0.5),
              ),
            ),
          ),
          if (widget.hint != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.hint!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

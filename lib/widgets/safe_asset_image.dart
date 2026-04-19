import 'package:flutter/material.dart';

/// Drop-in replacement for [Image.asset] that never overflows or crashes
/// when the asset is missing. Returns an empty [SizedBox] of the declared
/// dimensions if the asset fails to load, preserving the intended layout.
///
/// Use this anywhere a missing asset would disrupt layout or user experience.
class SafeAssetImage extends StatelessWidget {
  const SafeAssetImage(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.color,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.frameBuilder,
    this.placeholder,
    this.semanticLabel,
    this.fallbackPath,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Color? color;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final ImageFrameBuilder? frameBuilder;

  /// Optional custom placeholder. Defaults to a sized [SizedBox].
  final Widget? placeholder;

  final String? semanticLabel;

  /// If [path] fails to load, try this path before showing [placeholder].
  final String? fallbackPath;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      color: color,
      alignment: alignment,
      filterQuality: filterQuality,
      frameBuilder: frameBuilder,
      semanticLabel: semanticLabel,
      errorBuilder: (_, __, ___) {
        if (fallbackPath != null) {
          return Image.asset(
            fallbackPath!,
            width: width,
            height: height,
            fit: fit,
            color: color,
            alignment: alignment,
            filterQuality: filterQuality,
            semanticLabel: semanticLabel,
            errorBuilder: (_, __, ___) =>
                placeholder ?? SizedBox(width: width, height: height),
          );
        }
        return placeholder ?? SizedBox(width: width, height: height);
      },
    );
  }
}

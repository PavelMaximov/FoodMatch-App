import 'package:flutter/material.dart';

class FoodMatchEmptyStateImage extends StatelessWidget {
  const FoodMatchEmptyStateImage({
    required this.assetPath,
    this.size,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.fallback,
    super.key,
  });

  final String assetPath;
  final double? size;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size ?? width,
      height: size ?? height,
      fit: fit,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => fallback ?? const SizedBox.shrink(),
    );
  }
}

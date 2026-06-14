import 'package:flutter/material.dart';

import '../../../core/utils/image_utils.dart';
import 'safe_network_image.dart';

class SafeDishImage extends StatelessWidget {
  const SafeDishImage({
    required this.imageUrl,
    this.usage = ImageUsage.dishCard,
    required this.fit,
    this.width,
    this.height,
    this.borderRadius,
    super.key,
  });

  final String? imageUrl;
  final ImageUsage usage;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return SafeNetworkImage(
      imageUrl: imageUrl,
      usage: usage,
      fit: fit,
      width: width,
      height: height,
      borderRadius: borderRadius,
      backgroundColor: const Color(0xFFF5EDE8),
      placeholderIcon: Icons.restaurant_menu,
      errorIcon: Icons.restaurant_menu,
    );
  }
}

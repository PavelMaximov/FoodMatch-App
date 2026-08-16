import 'package:flutter/material.dart';

import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/food_match_empty_state_image.dart';
import 'safe_network_image.dart';

class SafeDishImage extends StatelessWidget {
  const SafeDishImage({
    required this.imageUrl,
    this.usage = ImageUsage.dishCard,
    required this.fit,
    this.width,
    this.height,
    this.borderRadius,
    this.emptyImageAsset,
    super.key,
  });

  final String? imageUrl;
  final ImageUsage usage;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final String? emptyImageAsset;

  @override
  Widget build(BuildContext context) {
    final Widget assetFallback = FoodMatchEmptyStateImage(
      assetPath: emptyImageAsset ?? '',
      width: width,
      height: height,
      fit: fit,
      fallback: SafeNetworkImage(
        imageUrl: null,
        usage: usage,
        fit: fit,
        width: width,
        height: height,
        backgroundColor: context.fmColors.imageFallbackBackground,
        placeholderIcon: Icons.restaurant_menu,
        errorIcon: Icons.restaurant_menu,
      ),
    );
    final Widget networkImage = SafeNetworkImage(
      imageUrl: imageUrl,
      usage: usage,
      fit: fit,
      width: width,
      height: height,
      borderRadius: borderRadius,
      backgroundColor: context.fmColors.imageFallbackBackground,
      placeholderIcon: Icons.restaurant_menu,
      errorIcon: Icons.restaurant_menu,
      errorFallback: emptyImageAsset == null ? null : assetFallback,
    );
    if ((imageUrl?.trim().isNotEmpty ?? false) || emptyImageAsset == null) {
      return networkImage;
    }
    return assetFallback;
  }
}

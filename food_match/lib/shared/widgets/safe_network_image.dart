import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class SafeNetworkImage extends StatelessWidget {
  const SafeNetworkImage({
    required this.imageUrl,
    required this.fit,
    this.width,
    this.height,
    this.placeholderIcon = Icons.image_outlined,
    this.errorIcon = Icons.image_not_supported_outlined,
    this.backgroundColor,
    super.key,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final IconData placeholderIcon;
  final IconData errorIcon;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final String trimmed = imageUrl.trim();
    final Uri? uri = Uri.tryParse(trimmed);
    final bool canLoadNetworkImage = uri != null && uri.hasScheme && uri.host.isNotEmpty;
    if (trimmed.isEmpty || !canLoadNetworkImage) {
      return _FallbackImage(
        width: width,
        height: height,
        icon: placeholderIcon,
        backgroundColor: backgroundColor,
      );
    }

    return CachedNetworkImage(
      imageUrl: trimmed,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) => _FallbackImage(
        width: width,
        height: height,
        icon: placeholderIcon,
        backgroundColor: backgroundColor,
        showLoader: true,
      ),
      errorWidget: (_, __, ___) => _FallbackImage(
        width: width,
        height: height,
        icon: errorIcon,
        backgroundColor: backgroundColor,
      ),
    );
  }
}

class _FallbackImage extends StatelessWidget {
  const _FallbackImage({
    required this.icon,
    this.width,
    this.height,
    this.backgroundColor,
    this.showLoader = false,
  });

  final double? width;
  final double? height;
  final IconData icon;
  final Color? backgroundColor;
  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? const Color(0xFFEFE8E4),
      child: Center(
        child: showLoader
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              )
            : Icon(icon, color: AppColors.textHint, size: 40),
      ),
    );
  }
}

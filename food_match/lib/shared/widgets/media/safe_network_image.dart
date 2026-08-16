import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/image_utils.dart';

class SafeNetworkImage extends StatelessWidget {
  const SafeNetworkImage({
    required this.imageUrl,
    required this.fit,
    this.usage = ImageUsage.original,
    this.width,
    this.height,
    this.placeholderIcon = Icons.image_outlined,
    this.errorIcon = Icons.image_not_supported_outlined,
    this.backgroundColor,
    this.borderRadius,
    this.errorFallback,
    super.key,
  });

  final String? imageUrl;
  final ImageUsage usage;
  final BoxFit fit;
  final double? width;
  final double? height;
  final IconData placeholderIcon;
  final IconData errorIcon;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final Widget? errorFallback;

  @override
  Widget build(BuildContext context) {
    final String optimizedUrl = ImageUtils.getImageUrl(imageUrl, usage: usage);
    final Uri? uri = Uri.tryParse(optimizedUrl);
    final bool canLoadNetworkImage =
        uri != null && uri.hasScheme && uri.host.isNotEmpty;

    final Widget image = optimizedUrl.isEmpty || !canLoadNetworkImage
        ? errorFallback ??
            _FallbackImage(
              width: width,
              height: height,
              icon: placeholderIcon,
              backgroundColor: backgroundColor,
            )
        : CachedNetworkImage(
            imageUrl: optimizedUrl,
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
            errorWidget: (_, __, ___) =>
                errorFallback ??
                _FallbackImage(
                  width: width,
                  height: height,
                  icon: errorIcon,
                  backgroundColor: backgroundColor,
                ),
          );

    final BorderRadius? radius = borderRadius;
    if (radius == null) return image;
    return ClipRRect(borderRadius: radius, child: image);
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
      color: backgroundColor ?? context.fmColors.imageFallbackBackground,
      child: Center(
        child: showLoader
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.fmColors.primary,
                ),
              )
            : Icon(icon, color: context.fmColors.textMuted, size: 40),
      ),
    );
  }
}

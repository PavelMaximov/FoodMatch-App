import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/utils/image_utils.dart';
import 'safe_network_image.dart';

class SafeAvatarImage extends StatelessWidget {
  const SafeAvatarImage({
    required this.imageUrl,
    required this.size,
    this.localPreview,
    this.isUploading = false,
    super.key,
  });

  final String? imageUrl;
  final double size;
  final File? localPreview;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    final File? preview = localPreview;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ClipOval(
            child: preview != null
                ? Image.file(preview, width: size, height: size, fit: BoxFit.cover)
                : SafeNetworkImage(
                    imageUrl: imageUrl,
                    usage: ImageUsage.avatarLarge,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    placeholderIcon: Icons.person,
                    errorIcon: Icons.person,
                  ),
          ),
          if (isUploading)
            DecoratedBox(
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), shape: BoxShape.circle),
              child: const Center(
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}

import '../constants/api_constants.dart';
import 'cloudinary_image_url.dart';

enum ImageUsage {
  avatarSmall,
  avatarLarge,
  dishCard,
  dishHero,
  swipeCard,
  matchOverlay,
  original,
}

class ImageUtils {
  static String getImageUrl(String? imageUrl, {ImageUsage usage = ImageUsage.original}) {
    final String trimmed = (imageUrl ?? '').trim();
    if (trimmed.isEmpty) return '';

    final String resolved = trimmed.startsWith('http') || trimmed.startsWith('assets/')
        ? trimmed
        : '${ApiConstants.baseUrl}/$trimmed';
    switch (usage) {
      case ImageUsage.avatarSmall:
        return CloudinaryImageUrl.getAvatarSmallImageUrl(resolved);
      case ImageUsage.avatarLarge:
        return CloudinaryImageUrl.getAvatarImageUrl(resolved);
      case ImageUsage.dishCard:
        return CloudinaryImageUrl.getDishCardImageUrl(resolved);
      case ImageUsage.dishHero:
        return CloudinaryImageUrl.getDishHeroImageUrl(resolved);
      case ImageUsage.swipeCard:
        return CloudinaryImageUrl.getSwipeCardImageUrl(resolved);
      case ImageUsage.matchOverlay:
        return CloudinaryImageUrl.getMatchOverlayImageUrl(resolved);
      case ImageUsage.original:
        return resolved;
    }
  }
}

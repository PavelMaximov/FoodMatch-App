import '../constants/api_constants.dart';
import 'cloudinary_image_url.dart';

enum ImageUsage { dishCard, dishHero, avatar, original }

class ImageUtils {
  static String getImageUrl(String? imageUrl, {ImageUsage usage = ImageUsage.original}) {
    final String trimmed = (imageUrl ?? '').trim();
    if (trimmed.isEmpty) return '';

    final String resolved = trimmed.startsWith('http') ? trimmed : '${ApiConstants.baseUrl}/$trimmed';
    switch (usage) {
      case ImageUsage.dishCard:
        return CloudinaryImageUrl.getDishCardImageUrl(resolved);
      case ImageUsage.dishHero:
        return CloudinaryImageUrl.getDishHeroImageUrl(resolved);
      case ImageUsage.avatar:
        return CloudinaryImageUrl.getAvatarImageUrl(resolved);
      case ImageUsage.original:
        return resolved;
    }
  }
}

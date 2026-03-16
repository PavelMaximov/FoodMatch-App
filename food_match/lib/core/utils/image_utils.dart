import '../constants/api_constants.dart';

class ImageUtils {
  static const String placeholder =
      'https://via.placeholder.com/400x300?text=No+Image';

  static String getImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return placeholder;
    if (imageUrl.startsWith('http')) return imageUrl;
    return '${ApiConstants.baseUrl}/$imageUrl';
  }
}

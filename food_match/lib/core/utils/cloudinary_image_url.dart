class CloudinaryImageUrl {
  static const String avatarSmallTransform = 'f_auto,q_auto,w_128,h_128,c_fill,g_auto';
  static const String avatarLargeTransform = 'f_auto,q_auto,w_512,h_512,c_fill,g_auto';
  static const String dishCardTransform = 'f_auto,q_auto,w_500,c_fill';
  static const String dishHeroTransform = 'f_auto,q_auto,w_1200,c_fill';
  static const String swipeCardTransform = 'f_auto,q_auto,w_900,c_fill';
  static const String matchOverlayTransform = 'f_auto,q_auto,w_900,c_fill';

  static String getAvatarSmallImageUrl(String? url) => _transform(url, avatarSmallTransform);
  static String getAvatarImageUrl(String? url) => _transform(url, avatarLargeTransform);
  static String getDishCardImageUrl(String? url) => _transform(url, dishCardTransform);
  static String getDishHeroImageUrl(String? url) => _transform(url, dishHeroTransform);
  static String getSwipeCardImageUrl(String? url) => _transform(url, swipeCardTransform);
  static String getMatchOverlayImageUrl(String? url) => _transform(url, matchOverlayTransform);

  static String _transform(String? url, String transformation) {
    final String trimmed = (url ?? '').trim();
    if (trimmed.isEmpty || _isLocalOrSvgAsset(trimmed) || !_isCloudinaryUrl(trimmed) || _hasTransformation(trimmed)) {
      return trimmed;
    }

    const String uploadSegment = '/upload/';
    final int uploadIndex = trimmed.indexOf(uploadSegment);
    if (uploadIndex == -1) return trimmed;

    final int insertAt = uploadIndex + uploadSegment.length;
    return '${trimmed.substring(0, insertAt)}$transformation/${trimmed.substring(insertAt)}';
  }

  static bool isNetworkUrl(String? url) {
    final Uri? uri = Uri.tryParse((url ?? '').trim());
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  static bool _isCloudinaryUrl(String url) {
    final Uri? uri = Uri.tryParse(url);
    return uri != null && uri.host.toLowerCase().contains('res.cloudinary.com');
  }

  static bool _isLocalOrSvgAsset(String url) {
    final String lower = url.toLowerCase();
    return lower.startsWith('assets/') || lower.endsWith('.svg');
  }

  static bool _hasTransformation(String url) {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return false;
    final List<String> segments = uri.pathSegments;
    final int uploadIndex = segments.indexOf('upload');
    if (uploadIndex == -1 || uploadIndex + 1 >= segments.length) return false;
    final String nextSegment = segments[uploadIndex + 1];
    return nextSegment.contains(',') || nextSegment.startsWith('w_') || nextSegment.startsWith('f_') || nextSegment.startsWith('q_');
  }
}

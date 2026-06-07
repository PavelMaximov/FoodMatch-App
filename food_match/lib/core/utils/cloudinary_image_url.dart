class CloudinaryImageUrl {
  static String getDishCardImageUrl(String? url) => _transform(url, 'f_auto,q_auto,w_600');

  static String getDishHeroImageUrl(String? url) => _transform(url, 'f_auto,q_auto,w_1200');

  static String getAvatarImageUrl(String? url) => _transform(url, 'f_auto,q_auto,w_512,c_fill,g_auto');

  static String _transform(String? url, String transformation) {
    final String trimmed = (url ?? '').trim();
    if (trimmed.isEmpty || !_isCloudinaryUrl(trimmed) || _hasTransformation(trimmed)) {
      return trimmed;
    }

    const String uploadSegment = '/upload/';
    final int uploadIndex = trimmed.indexOf(uploadSegment);
    if (uploadIndex == -1) {
      return trimmed;
    }

    final int insertAt = uploadIndex + uploadSegment.length;
    return '${trimmed.substring(0, insertAt)}$transformation/${trimmed.substring(insertAt)}';
  }

  static bool _isCloudinaryUrl(String url) {
    final Uri? uri = Uri.tryParse(url);
    return uri != null && uri.host.toLowerCase().contains('res.cloudinary.com');
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

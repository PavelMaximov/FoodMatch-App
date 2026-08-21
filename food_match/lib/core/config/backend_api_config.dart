class BackendApiConfig {
  BackendApiConfig._();

  static String normalizeBaseUrl(String value) {
    final String trimmed = value.trim();
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw StateError(
        'Invalid API_BASE_URL. Use the FoodMatch backend root URL, for '
        'example http://192.168.0.39:4000.',
      );
    }
    if (looksLikeSupabase(uri)) {
      throw StateError(
        'Invalid API_BASE_URL. API_BASE_URL must point to the FoodMatch '
        'backend, not Supabase.',
      );
    }
    if ((uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw StateError(
        'Invalid API_BASE_URL. Use the FoodMatch backend root URL and do not '
        'include /api or any path.',
      );
    }
    return uri.replace(path: '').toString().replaceFirst(RegExp(r'/$'), '');
  }

  static bool looksLikeSupabase(Uri uri) =>
      uri.host.toLowerCase() == 'supabase.co' ||
      uri.host.toLowerCase().endsWith('.supabase.co');

  static bool hasApiPath(Uri uri) =>
      uri.path == '/api' || uri.path.startsWith('/api/');
}

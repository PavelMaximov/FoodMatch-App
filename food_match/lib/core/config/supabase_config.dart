class SupabaseConfig {
  SupabaseConfig._();

  static const String _rawUrl = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get url => normalizeUrl(_rawUrl);

  static String normalizeUrl(String value) {
    final String trimmed = value.trim();
    final Uri? uri = Uri.tryParse(trimmed);
    if (trimmed.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw StateError(
        'Invalid SUPABASE_URL. Use the project root URL, for example '
        'https://<project-ref>.supabase.co. Do not include /rest/v1, '
        '/auth/v1, /api, or any path.',
      );
    }
    if ((uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw StateError(
        'Invalid SUPABASE_URL. Use the project root URL, for example '
        'https://<project-ref>.supabase.co. Do not include /rest/v1, '
        '/auth/v1, /api, or any path.',
      );
    }
    return uri.replace(path: '').toString().replaceFirst(RegExp(r'/$'), '');
  }

  static void validate() {
    final List<String> missing = <String>[
      if (_rawUrl.trim().isEmpty) 'SUPABASE_URL',
      if (anonKey.trim().isEmpty) 'SUPABASE_ANON_KEY',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Missing required Supabase Flutter configuration: ${missing.join(', ')}. '
        'Run with --dart-define=SUPABASE_URL=<url> '
        '--dart-define=SUPABASE_ANON_KEY=<anon-key>.',
      );
    }
    normalizeUrl(_rawUrl);
  }
}

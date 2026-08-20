class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void validate() {
    final List<String> missing = <String>[
      if (url.trim().isEmpty) 'SUPABASE_URL',
      if (anonKey.trim().isEmpty) 'SUPABASE_ANON_KEY',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Missing required Supabase Flutter configuration: ${missing.join(', ')}. '
        'Run with --dart-define=SUPABASE_URL=<url> '
        '--dart-define=SUPABASE_ANON_KEY=<anon-key>.',
      );
    }
  }
}

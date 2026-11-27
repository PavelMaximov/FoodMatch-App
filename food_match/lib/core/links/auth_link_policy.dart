import 'session_invitation.dart';

/// Preserve Supabase's callback detection, excluding our invitation namespace.
/// Called during Supabase.initialize, before either initial-link listener runs.
bool shouldHandleAuthLink(Uri uri) {
  if (isSessionInvitationRoute(uri)) return false;
  try {
    final query = uri.queryParameters;
    final fragment = Uri.splitQueryString(uri.fragment);
    return const {
      'access_token',
      'code',
      'error',
      'error_code',
      'error_description',
    }.any((key) => query.containsKey(key) || fragment.containsKey(key));
  } on FormatException {
    return false;
  }
}

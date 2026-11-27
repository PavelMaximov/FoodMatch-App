/// Route recognition is separate from code validation: even a malformed
/// invitation must never be interpreted as a Supabase authorization code.
bool isSessionInvitationRoute(Uri uri) =>
    uri.scheme == 'foodmatch' &&
    (const {'join', 'connect-couple'}.contains(uri.host) ||
        (uri.host.isEmpty &&
            const {'/join', '/connect-couple'}.contains(uri.path)));

/// Only the invitation route is accepted; arbitrary deep-link navigation is not.
String? invitationCode(Uri uri) {
  if (uri.scheme != 'foodmatch' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.fragment.isNotEmpty) {
    return null;
  }
  if (!isSessionInvitationRoute(uri) ||
      (uri.host.isNotEmpty && uri.path.isNotEmpty)) {
    return null;
  }
  final values = uri.queryParametersAll['code'];
  if (values == null || values.length != 1) return null;
  final code = values.single.trim().toUpperCase();
  return RegExp(r'^[A-Z0-9]{6}$').hasMatch(code) ? code : null;
}

Uri sessionInvitationLink(String code) => Uri(
  scheme: 'foodmatch',
  host: 'connect-couple',
  queryParameters: {'code': code.trim().toUpperCase()},
);

/// Serializes storage and delivery so initial-link/stream duplicates cannot race.
class SessionInvitationInbox {
  SessionInvitationInbox({required this.read, required this.write});
  final Future<String?> Function() read;
  final Future<void> Function(String?) write;
  final Set<String> _seen = {};
  Future<void> _tail = Future.value();
  String? _pending;
  bool _restored = false;
  bool _disposed = false;

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _tail.then((_) async {
      if (!_disposed) await action();
    });
    _tail = result.catchError((Object _) {});
    return result;
  }

  Future<void> restore() => _enqueue(() async {
    if (_restored) return;
    final stored = await read();
    if (stored != null && RegExp(r'^[A-Z0-9]{6}$').hasMatch(stored)) {
      _pending = stored;
      _seen.add(stored);
    }
    _restored = true;
  });

  Future<void> receive(Uri uri) => _enqueue(() async {
    final code = invitationCode(uri);
    if (code == null || _seen.contains(code)) return;
    await write(code);
    _seen.add(code);
    _pending = code;
  });

  Future<void> deliver({
    required bool Function() isReady,
    required void Function(String) navigate,
  }) => _enqueue(() async {
    if (_pending == null || !isReady()) return;
    final code = _pending!;
    // Clear durable state before delivery, but keep it pending if auth changed.
    await write(null);
    if (_disposed || !isReady()) {
      await write(code);
      return;
    }
    try {
      navigate(code);
      _pending = null;
    } catch (_) {
      await write(code);
      rethrow;
    }
  });

  void dispose() => _disposed = true;
}

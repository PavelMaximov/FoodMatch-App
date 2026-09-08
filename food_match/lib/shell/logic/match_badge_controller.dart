import 'package:flutter/foundation.dart';

class MatchBadgeController extends ChangeNotifier {
  final Map<String, _MatchBadgeScope> _scopes = <String, _MatchBadgeScope>{};
  String? _userId;
  String _mode = 'solo';
  String? _sessionId;
  int _bumpToken = 0;
  String? _lastAnimationEventId;

  int get badgeCount => _activeScope?.unseenMatchIds.length ?? 0;
  int get bumpToken => _bumpToken;
  String get mode => _mode;
  String? get sessionId => _sessionId;
  String? get lastAnimationEventId => _lastAnimationEventId;
  Set<String> get unseenMatchIds =>
      Set<String>.unmodifiable(_activeScope?.unseenMatchIds ?? <String>{});
  Set<String> get knownMatchIds =>
      Set<String>.unmodifiable(_activeScope?.knownMatchIds ?? <String>{});

  void setActiveUser(String? userId, {String reason = 'auth_update'}) {
    final String? normalized = _normalize(userId);
    if (_userId == normalized) return;
    if (_userId == null && normalized != null && _scopes.isNotEmpty) {
      final Map<String, _MatchBadgeScope> provisional =
          Map<String, _MatchBadgeScope>.from(_scopes);
      _scopes.clear();
      for (final MapEntry<String, _MatchBadgeScope> entry
          in provisional.entries) {
        _scopes[entry.key.replaceFirst('none:', '$normalized:')] = entry.value;
      }
      _userId = normalized;
      if (kDebugMode) {
        debugPrint('[MatchBadge] provisional state claimed user=$normalized');
      }
      notifyListeners();
      return;
    }
    _userId = normalized;
    _scopes.clear();
    _sessionId = null;
    _lastAnimationEventId = null;
    if (kDebugMode) {
      debugPrint('[MatchBadge] reset reason=$reason user=${normalized ?? 'none'}');
    }
    notifyListeners();
  }

  void setScope({required String mode, String? sessionId}) {
    final String normalizedMode = mode == 'paired' ? 'paired' : 'solo';
    final String? normalizedSession = _normalize(sessionId);
    if (_mode == normalizedMode && _sessionId == normalizedSession) return;
    _mode = normalizedMode;
    _sessionId = normalizedSession;
    if (kDebugMode) {
      debugPrint(
        '[MatchBadge] scope mode=$_mode sessionId=${_sessionId ?? 'none'} '
        'badgeCount=$badgeCount',
      );
    }
    notifyListeners();
  }

  void initializeBaseline({
    required String userId,
    required String mode,
    required String? sessionId,
    required Iterable<String> matchIds,
  }) {
    _activate(userId: userId, mode: mode, sessionId: sessionId);
    final _MatchBadgeScope scope = _scopeForActive();
    final Set<String> ids = _normalizeIds(matchIds);
    scope.knownMatchIds
      ..clear()
      ..addAll(ids);
    scope.unseenMatchIds
      ..clear()
      ..addAll(ids.difference(scope.seenMatchIds));
    scope.initialized = true;
    if (kDebugMode) {
      debugPrint(
        '[MatchBadge] baseline count=$badgeCount bumpToken=$_bumpToken '
        'sessionId=${_sessionId ?? 'none'}',
      );
    }
    notifyListeners();
  }

  bool registerNewMatch({
    required String matchId,
    required String source,
    String? mode,
    String? sessionId,
  }) {
    final String normalizedId = matchId.trim();
    if (normalizedId.isEmpty) return false;
    if (mode != null || sessionId != null) {
      setScope(mode: mode ?? _mode, sessionId: sessionId ?? _sessionId);
    }
    final _MatchBadgeScope scope = _scopeForActive();
    if (!scope.knownMatchIds.add(normalizedId)) return false;
    scope.unseenMatchIds.add(normalizedId);
    scope.pendingImmediateIds.add(normalizedId);
    scope.initialized = true;
    _bumpToken++;
    _lastAnimationEventId = '${_scopeKey()}:$normalizedId';
    if (kDebugMode) {
      debugPrint(
        '[MatchBadge] new source=$source matchId=$normalizedId '
        'badgeCount=$badgeCount bumpToken=$_bumpToken',
      );
    }
    notifyListeners();
    return true;
  }

  void applyFetchedMatches({
    required String userId,
    required String mode,
    required String? sessionId,
    required Iterable<String> matchIds,
    required String reason,
    bool animateNew = true,
  }) {
    _activate(userId: userId, mode: mode, sessionId: sessionId);
    final _MatchBadgeScope scope = _scopeForActive();
    final Set<String> fetchedIds = _normalizeIds(matchIds);
    if (!scope.initialized) {
      initializeBaseline(
        userId: userId,
        mode: mode,
        sessionId: sessionId,
        matchIds: fetchedIds,
      );
      return;
    }
    final Set<String> newIds = fetchedIds.difference(scope.knownMatchIds);
    final Set<String> genuinelyNew = newIds.difference(scope.pendingImmediateIds);
    final Set<String> authoritativeIds = <String>{
      ...fetchedIds,
      ...scope.pendingImmediateIds,
    };
    scope.knownMatchIds
      ..clear()
      ..addAll(authoritativeIds);
    scope.unseenMatchIds.retainAll(authoritativeIds);
    scope.unseenMatchIds.addAll(newIds.difference(scope.seenMatchIds));
    scope.pendingImmediateIds.clear();
    if (animateNew && genuinelyNew.isNotEmpty) {
      _bumpToken++;
      _lastAnimationEventId =
          '${_scopeKey()}:fetch:${genuinelyNew.toList()..sort()}';
    }
    if (kDebugMode) {
      debugPrint(
        '[MatchBadge] fetched reason=$reason newIds=$newIds '
        'badgeCount=$badgeCount bumpToken=$_bumpToken',
      );
    }
    notifyListeners();
  }

  void markAllSeen({required String reason}) {
    final _MatchBadgeScope? scope = _activeScope;
    if (scope == null || scope.unseenMatchIds.isEmpty) return;
    scope.seenMatchIds.addAll(scope.unseenMatchIds);
    scope.unseenMatchIds.clear();
    if (kDebugMode) {
      debugPrint('[MatchBadge] markAllSeen reason=$reason');
    }
    notifyListeners();
  }

  void resetForUserChange({required String reason}) {
    _userId = null;
    _scopes.clear();
    _sessionId = null;
    _lastAnimationEventId = null;
    if (kDebugMode) debugPrint('[MatchBadge] reset reason=$reason');
    notifyListeners();
  }

  _MatchBadgeScope? get _activeScope {
    if (_sessionId == null) return null;
    return _scopes[_scopeKey()];
  }

  _MatchBadgeScope _scopeForActive() =>
      _scopes.putIfAbsent(_scopeKey(), _MatchBadgeScope.new);

  void _activate({
    required String userId,
    required String mode,
    required String? sessionId,
  }) {
    setActiveUser(userId);
    setScope(mode: mode, sessionId: sessionId);
  }

  String _scopeKey() =>
      '${_userId ?? 'none'}:${_mode}:${_sessionId ?? 'none'}';

  Set<String> _normalizeIds(Iterable<String> ids) => ids
      .map((String id) => id.trim())
      .where((String id) => id.isNotEmpty)
      .toSet();

  String? _normalize(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class _MatchBadgeScope {
  final Set<String> knownMatchIds = <String>{};
  final Set<String> unseenMatchIds = <String>{};
  final Set<String> seenMatchIds = <String>{};
  final Set<String> pendingImmediateIds = <String>{};
  bool initialized = false;
}

import 'package:flutter/foundation.dart';

typedef MatchBadgeRefresh = Future<void> Function({
  required String mode,
  required String? sessionId,
  required String reason,
});

class MatchBadgeController extends ChangeNotifier {
  final Map<String, _MatchBadgeScope> _scopes = <String, _MatchBadgeScope>{};
  String? _userId;
  String _mode = 'solo';
  String? _sessionId;
  int _bumpToken = 0;
  String? _lastAnimationEventId;
  MatchBadgeRefresh? _refresh;

  int get badgeCount => _activeScope?.currentMatchIds.length ?? 0;
  String? get activeUserId => _userId;
  int get bumpToken => _bumpToken;
  String get mode => _mode;
  String? get sessionId => _sessionId;
  String? get lastAnimationEventId => _lastAnimationEventId;
  bool get hasValidScope => _userId != null && _sessionId != null;
  Set<String> get authoritativeMatchIds => Set<String>.unmodifiable(
        _activeScope?.authoritativeMatchIds ?? <String>{},
      );
  Set<String> get knownMatchIds =>
      Set<String>.unmodifiable(_activeScope?.knownMatchIds ?? <String>{});

  void attachRefreshHandler(MatchBadgeRefresh refresh) => _refresh = refresh;

  Future<void> requestAuthoritativeRefresh({
    required String mode,
    required String? sessionId,
    required String reason,
  }) async {
    final MatchBadgeRefresh? refresh = _refresh;
    if (refresh == null) {
      if (kDebugMode) {
        debugPrint('[SwipeBadge] action=force_refresh skipped=no_handler');
      }
      return;
    }
    await refresh(mode: mode, sessionId: sessionId, reason: reason);
  }

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
        '[MatchBadge] scope user=${_userId ?? 'none'} mode=$_mode '
        'session=${_sessionId ?? 'none'} '
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
    scope.authoritativeMatchIds
      ..clear()
      ..addAll(ids);
    scope.knownMatchIds.addAll(ids);
    scope.pendingImmediateIds.clear();
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
    bool? animateNew,
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
      if (_isSwipeMatchReason(reason) && fetchedIds.isNotEmpty) {
        _bumpToken++;
        _lastAnimationEventId =
            '${_scopeKey()}:fetch:${fetchedIds.toList()..sort()}';
        if (kDebugMode) {
          debugPrint(
            '[MatchBadge] reconcile reason=$reason previousKnown={} '
            'fetched=$fetchedIds newIds=$fetchedIds badge=$badgeCount '
            'bumpToken=$_bumpToken',
          );
        }
        notifyListeners();
      }
      return;
    }
    final Set<String> previousKnown = Set<String>.from(scope.knownMatchIds);
    final Set<String> newIds = fetchedIds.difference(previousKnown);
    scope.authoritativeMatchIds
      ..clear()
      ..addAll(fetchedIds);
    scope.knownMatchIds.addAll(fetchedIds);
    scope.pendingImmediateIds.clear();
    final bool shouldAnimate =
        animateNew ?? _reasonAllowsAnimation(reason);
    if (shouldAnimate && newIds.isNotEmpty) {
      _bumpToken++;
      _lastAnimationEventId =
          '${_scopeKey()}:fetch:${newIds.toList()..sort()}';
    }
    if (kDebugMode) {
      debugPrint(
        '[MatchBadge] reconcile reason=$reason previousKnown=$previousKnown '
        'fetched=$fetchedIds newIds=$newIds badge=$badgeCount '
        'bumpToken=$_bumpToken',
      );
    }
    notifyListeners();
  }

  void markAllSeen({required String reason}) {
    if (kDebugMode) {
      debugPrint('[MatchBadge] markAllSeen ignored total-count reason=$reason');
    }
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

  bool _reasonAllowsAnimation(String reason) => <String>{
        'swipe_match_created',
        'swipe_match_created_scope_unresolved',
        'swipe_match_created_no_match_id',
        'shell_poll',
        'app_resume',
      }.contains(reason);

  bool _isSwipeMatchReason(String reason) => <String>{
        'swipe_match_created',
        'swipe_match_created_scope_unresolved',
        'swipe_match_created_no_match_id',
      }.contains(reason);

  String? _normalize(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class _MatchBadgeScope {
  final Set<String> authoritativeMatchIds = <String>{};
  final Set<String> knownMatchIds = <String>{};
  final Set<String> pendingImmediateIds = <String>{};
  bool initialized = false;

  Set<String> get currentMatchIds => <String>{
        ...authoritativeMatchIds,
        ...pendingImmediateIds,
      };
}

import 'package:flutter/foundation.dart';

/// Owns the authenticated session's badge count and one-shot animation events.
class NavBadgeAnimationController extends ChangeNotifier {
  int _soloMatchesPlusOneEvent = 0;
  int _badgeCount = 0;
  String? _lastSoloMatchesPlusOneEventKey;
  final Set<String> _animatedMatchEvents = <String>{};
  final Set<String> _knownMatchIds = <String>{};
  String? _userId;
  String _mode = 'solo';
  String? _sessionId;
  bool _baselineInitialized = false;
  int _pendingRefreshCredits = 0;

  int get soloMatchesPlusOneEvent => _soloMatchesPlusOneEvent;
  int get badgeCount => _badgeCount;
  int get bumpToken => _soloMatchesPlusOneEvent;
  String get mode => _mode;
  String? get sessionId => _sessionId;
  String? get lastSoloMatchesPlusOneEventKey =>
      _lastSoloMatchesPlusOneEventKey;

  void setActiveUser(String? userId) {
    final String? normalized = _normalize(userId);
    if (_userId == normalized) return;
    _userId = normalized;
    _resetScope(notify: true);
  }

  void setScope({required String mode, String? sessionId}) {
    final String normalizedMode = mode == 'paired' ? 'paired' : 'solo';
    final String? normalizedSession = _normalize(sessionId);
    if (_mode == normalizedMode && _sessionId == normalizedSession) return;
    _mode = normalizedMode;
    _sessionId = normalizedSession;
    _resetScope(notify: true);
  }

  void applyFetchedMatches({
    required Iterable<String> matchIds,
    required String reason,
  }) {
    final int oldCount = _badgeCount;
    final Set<String> fetchedIds = matchIds.toSet();
    final Set<String> newMatchIds = fetchedIds.difference(_knownMatchIds);
    final int fetchedCount = fetchedIds.length;
    final int delta = fetchedCount - oldCount;
    final bool shouldBump = _baselineInitialized &&
        newMatchIds.isNotEmpty &&
        _pendingRefreshCredits == 0;
    if (shouldBump) {
      _lastSoloMatchesPlusOneEventKey =
          'fetch:${_mode}:${_sessionId ?? 'none'}:$reason:$_soloMatchesPlusOneEvent';
      _soloMatchesPlusOneEvent++;
      if (kDebugMode) {
        debugPrint(
          '[NavBadgeAnim] trigger plusOne '
          'eventKey=$_lastSoloMatchesPlusOneEventKey',
        );
      }
    }
    _badgeCount = fetchedCount;
    _knownMatchIds
      ..clear()
      ..addAll(fetchedIds);
    _pendingRefreshCredits = 0;
    _baselineInitialized = true;
    if (kDebugMode) {
      debugPrint(
        '[MatchBadge] refresh reason=$reason oldBadgeCount=$oldCount '
        'newMatchIds=$newMatchIds newBadgeCount=$_badgeCount '
        'delta=$delta bumpToken=$bumpToken',
      );
    }
    if (delta != 0 || shouldBump) notifyListeners();
  }

  bool registerImmediateMatch({
    required String matchId,
    required String mode,
    String? sessionId,
  }) {
    final String normalizedMode = mode == 'paired' ? 'paired' : 'solo';
    final String? normalizedSession = _normalize(sessionId) ?? _sessionId;
    setScope(mode: normalizedMode, sessionId: normalizedSession);
    final String eventKey =
        '$normalizedMode:${normalizedSession ?? 'active'}:$matchId';
    if (!_animatedMatchEvents.add(eventKey)) return false;
    final int oldCount = _badgeCount;
    _badgeCount++;
    _knownMatchIds.add(matchId);
    _pendingRefreshCredits++;
    _baselineInitialized = true;
    _lastSoloMatchesPlusOneEventKey = eventKey;
    _soloMatchesPlusOneEvent++;
    if (kDebugMode) {
      debugPrint(
        '[MatchBadge] notifyListeners badgeCount=$_badgeCount '
        'oldBadgeCount=$oldCount bumpToken=$bumpToken eventKey=$eventKey',
      );
      debugPrint('[NavBadgeAnim] trigger plusOne eventKey=$eventKey');
    }
    notifyListeners();
    return true;
  }

  void _resetScope({required bool notify}) {
    final bool changed = _badgeCount != 0 || _baselineInitialized;
    _badgeCount = 0;
    _baselineInitialized = false;
    _animatedMatchEvents.clear();
    _knownMatchIds.clear();
    _pendingRefreshCredits = 0;
    _lastSoloMatchesPlusOneEventKey = null;
    if (changed && notify) notifyListeners();
  }

  String? _normalize(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

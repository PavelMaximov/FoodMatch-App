import 'package:flutter/foundation.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/cache_policy.dart';
import '../../../data/local/cache_service.dart';
import '../../../data/models/dish.dart';
import '../../../data/models/match_item.dart';
import '../../../data/repositories/swipe_repository.dart';
import '../../../data/services/api_service.dart';
import '../../../shell/logic/match_badge_controller.dart';

class MatchProvider extends ChangeNotifier {
  MatchProvider({
    required SwipeRepository swipeRepository,
    CacheService? cacheService,
    MatchBadgeController? badgeController,
  })  : _swipeRepository = swipeRepository,
        _cacheService = cacheService ?? CacheService(),
        _badgeController = badgeController {
    badgeController?.attachRefreshHandler(_refreshForBadgeEvent);
  }

  final SwipeRepository _swipeRepository;
  final CacheService _cacheService;
  final MatchBadgeController? _badgeController;
  String? _activeCoupleId;
  String? _activeSoloSessionId;
  String? _activeUserId;
  String _mode = 'solo';
  int _sessionStateVersion = 0;
  DateTime? _matchesLoadedAt;
  Future<void>? _matchesLoadFuture;
  final Set<String> _knownPairedMatchIds = <String>{};
  final Set<String> _optimisticSoloMatchKeys = <String>{};
  final Map<String, MatchItem> _optimisticSoloMatches = <String, MatchItem>{};
  bool _hasSeededPairedMatchNotifications = false;
  int _authBoundaryVersion = -1;

  List<MatchItem> matches = <MatchItem>[];
  bool isLoading = false;
  String? error;

  int get matchCount => matches.length;
  String get mode => _mode;
  bool get isSoloMode => _mode == 'solo';
  String? get activeSoloSessionId => _activeSoloSessionId;

  bool recordSoloMatchFromSwipe({
    required Dish dish,
    required String sessionId,
    required String eventId,
  }) {
    final String eventKey = 'solo:$sessionId:$eventId';
    final int oldCount = matchCount;
    if (_mode != 'solo' || _activeSoloSessionId != sessionId) {
      if (kDebugMode) {
        debugPrint(
          '[MatchProvider] optimistic solo match rejected '
          'provider=${identityHashCode(this)} eventKey=$eventKey '
          'oldCount=$oldCount '
          'newCount=$matchCount sessionId=$sessionId '
          'activeSessionId=${_activeSoloSessionId ?? 'none'} mode=$_mode',
        );
      }
      return false;
    }
    final String key = '$sessionId:$eventId';
    if (!_optimisticSoloMatchKeys.add(key)) return false;
    final bool alreadyPresent = matches.any(
      (MatchItem item) => item.sessionId == sessionId && item.dish.id == dish.id,
    );
    if (!alreadyPresent) {
      final MatchItem optimisticMatch = MatchItem(
        id: eventId,
        dish: dish,
        mode: 'solo',
        matchType: 'solo_pick',
        sessionId: sessionId,
        createdAt: DateTime.now(),
      );
      _optimisticSoloMatches[key] = optimisticMatch;
      matches = <MatchItem>[optimisticMatch, ...matches];
      notifyListeners();
    }
    if (kDebugMode) {
      debugPrint(
        '[MatchProvider] optimistic solo match register '
        'provider=${identityHashCode(this)} eventKey=$eventKey '
        'oldCount=$oldCount '
        'newCount=$matchCount sessionId=$sessionId',
      );
    }
    return true;
  }

  void setActiveUser(String? userId) {
    final String? normalized = userId?.trim().isEmpty == true
        ? null
        : userId?.trim();
    if (_activeUserId == normalized) return;
    _activeUserId = normalized;
    _badgeController?.setActiveUser(normalized);
    _optimisticSoloMatchKeys.clear();
    _optimisticSoloMatches.clear();
    matches = <MatchItem>[];
    error = null;
    _matchesLoadedAt = null;
    _matchesLoadFuture = null;
    _cacheService.clearCachedMatches();
    AppLogger.info('[Cache] matches invalidated reason=account-change');
  }
  bool get _hasFreshMatchesCache {
    final DateTime? loadedAt = _matchesLoadedAt;
    return loadedAt != null &&
        DateTime.now().difference(loadedAt) < CachePolicy.matchesTtl;
  }

  Future<void> loadMatches({
    bool force = false,
    String? mode,
    String? soloSessionId,
    String? reason,
  }) {
    if (_activeUserId == null || _activeUserId!.isEmpty) {
      AppLogger.info(
        '[MatchProvider] loadMatches skipped reason=user_unresolved',
      );
      return Future<void>.value();
    }
    if (soloSessionId != null && soloSessionId != _activeSoloSessionId) {
      _activeSoloSessionId = soloSessionId;
      _optimisticSoloMatchKeys.clear();
      _optimisticSoloMatches.clear();
      matches = <MatchItem>[];
      error = null;
      _matchesLoadedAt = null;
      _matchesLoadFuture = null;
      _cacheService.clearCachedMatches();
    }
    if (mode != null && mode != _mode) {
      _mode = mode;
      matches = <MatchItem>[];
      error = null;
      _matchesLoadedAt = null;
      _matchesLoadFuture = null;
      _cacheService.clearCachedMatches();
    }
    if (!force && _hasFreshMatchesCache) {
      final int age = DateTime.now().difference(_matchesLoadedAt!).inSeconds;
      AppLogger.info('[MatchProvider] cache hit=true count=${matches.length} age=${age}s key=$_cacheKey');
      return Future<void>.value();
    }
    final Future<void>? inFlight = _matchesLoadFuture;
    if (inFlight != null) {
      if (force) {
        AppLogger.info(
          '[RequestDedup] matches force refresh queued reason=${reason ?? 'refresh'}',
        );
        return inFlight.then(
          (_) => loadMatches(
            force: true,
            mode: mode,
            soloSessionId: soloSessionId,
            reason: reason,
          ),
        );
      }
      AppLogger.info('[RequestDedup] matches load skipped: already in flight');
      return inFlight;
    }

    final String requestKey = _cacheKey;
    AppLogger.info('[MatchProvider] loadMatches user=${_activeUserId ?? 'none'} mode=$_mode scope=${_mode == 'solo' ? 'current' : 'all'} sessionId=${_activeSoloSessionId ?? _activeCoupleId ?? 'none'} force=$force');
    AppLogger.info('[MatchProvider] cache hit=false count=0 key=$requestKey');
    _matchesLoadFuture = _loadMatchesFromApi(
      force: force,
      requestKey: requestKey,
      reason: reason ?? (force ? 'refresh' : 'initial_load'),
    );
    return _matchesLoadFuture!;
  }

  Future<void> _loadMatchesFromApi({
    required bool force,
    required String requestKey,
    required String reason,
  }) async {
    AppLogger.info(
      '[PageLoad] start page=Matches reason=$reason',
    );
    AppLogger.info(force ? '[Cache] matches force refresh' : '[Cache] matches miss');
    isLoading = true;
    error = null;
    notifyListeners();
    final Set<String> previousMatchIds = matches
        .map((MatchItem item) => item.id?.trim())
        .whereType<String>()
        .where((String id) => id.isNotEmpty)
        .toSet();
    if (kDebugMode) {
      debugPrint(
        '[MatchBadge] refresh start reason=$reason '
        'previousMatchIds=$previousMatchIds',
      );
    }

    try {
      final List<MatchItem> result = _filterForMode(
        await _swipeRepository.getMatches(
          mode: _mode,
          scope: _mode == 'solo' ? 'current' : null,
          soloSessionId: _mode == 'solo' ? _activeSoloSessionId : null,
        ),
      );
      AppLogger.info('[MatchProvider] API result count=${result.length}');
      final Set<String> fetchedMatchIds = result
          .map((MatchItem item) => item.id?.trim())
          .whereType<String>()
          .where((String id) => id.isNotEmpty)
          .toSet();
      if (kDebugMode) {
        debugPrint(
          '[MatchProvider] fetched user=${_activeUserId ?? 'none'} '
          'mode=$_mode session=${_activeSoloSessionId ?? _activeCoupleId ?? 'none'} '
          'total=${fetchedMatchIds.length} ids=$fetchedMatchIds',
        );
      }
      if (requestKey != _cacheKey) {
        AppLogger.info('[MatchProvider] stale response ignored requestKey=$requestKey currentKey=$_cacheKey');
        return;
      }
      if (_mode == 'solo') {
        final Set<String> serverDishIds = result
            .map((MatchItem item) => item.dish.id)
            .toSet();
        _optimisticSoloMatches.removeWhere(
          (_, MatchItem item) => serverDishIds.contains(item.dish.id),
        );
        matches = <MatchItem>[
          ..._optimisticSoloMatches.values.where(
            (MatchItem item) => item.sessionId == _activeSoloSessionId,
          ),
          ...result,
        ];
      } else {
        matches = result;
      }
      _matchesLoadedAt = DateTime.now();
      await _cacheService.cacheMatches(matches.map((MatchItem item) => item.dish).toList(), coupleId: requestKey);
      AppLogger.info('[MatchProvider] cache key=$requestKey');
      AppLogger.info('MatchProvider: loaded ${matches.length} matches');
      final String? badgeUserId = _activeUserId;
      if (badgeUserId != null) {
        _badgeController?.applyFetchedMatches(
          userId: badgeUserId,
          mode: _mode,
          sessionId: _mode == 'solo'
              ? _activeSoloSessionId
              : _activeCoupleId,
          matchIds: fetchedMatchIds,
          reason: reason,
        );
      }
      AppLogger.info(
        matches.isEmpty
            ? '[PageLoad] empty page=Matches'
            : '[PageLoad] success page=Matches items=${matches.length}',
      );
    } catch (e) {
      if (requestKey != _cacheKey) return;
      final List<MatchItem> cached =
          (await _cacheService.getCachedMatches(coupleId: requestKey))
          .map((Dish dish) => MatchItem.fromCachedDish(dish, _mode))
          .toList();
      if (_mode == 'solo') {
        final Set<String> cachedDishIds = cached
            .map((MatchItem item) => item.dish.id)
            .toSet();
        matches = <MatchItem>[
          ..._optimisticSoloMatches.values.where(
            (MatchItem item) =>
                item.sessionId == _activeSoloSessionId &&
                !cachedDishIds.contains(item.dish.id),
          ),
          ...cached,
        ];
      } else {
        matches = cached;
      }
      if (matches.isEmpty) {
        error = _mapError(e);
        AppLogger.info('[PageLoad] error page=Matches error=$error');
      } else {
        _matchesLoadedAt ??= DateTime.now();
        AppLogger.info('MatchProvider: loaded ${matches.length} from cache');
      }
    } finally {
      if (requestKey == _cacheKey) {
        isLoading = false;
        _matchesLoadFuture = null;
        notifyListeners();
      }
    }
  }

  Future<void> _refreshForBadgeEvent({
    required String mode,
    required String? sessionId,
    required String reason,
    String? removedMatchId,
  }) async {
    if (_activeUserId == null) {
      if (kDebugMode) {
        debugPrint('[SwipeBadge] action=force_refresh skipped=user_unresolved');
      }
      return;
    }
    if (removedMatchId != null && removedMatchId.isNotEmpty) {
      matches = matches
          .where((MatchItem item) => item.id != removedMatchId)
          .toList();
      _optimisticSoloMatches.removeWhere(
        (_, MatchItem item) => item.id == removedMatchId,
      );
      notifyListeners();
    }
    if (kDebugMode) {
      debugPrint('[MatchProvider] background refresh reason=$reason started');
    }
    await loadMatches(
      force: true,
      mode: mode,
      soloSessionId: mode == 'solo' ? sessionId : null,
      reason: reason,
    );
    if (kDebugMode) {
      debugPrint(
        '[MatchProvider] background refresh reason=$reason '
        'completed total=${matches.length}',
      );
    }
  }

  String get _cacheKey {
    final String user = _activeUserId ?? 'anonymous';
    if (_mode == 'paired') {
      return 'matches:user=$user:mode=paired:scope=current:session=${_activeCoupleId ?? 'none'}';
    }
    return 'matches:user=$user:mode=solo:scope=current:session=${_activeSoloSessionId ?? 'none'}';
  }

  List<MatchItem> _filterForMode(List<MatchItem> items) {
    if (_mode == 'solo') {
      return items.where((MatchItem item) => item.mode == 'solo').toList();
    }
    if (_mode == 'paired') {
      return items
          .where((MatchItem item) => item.mode == 'paired' && item.matchType == 'pair_match')
          .toList();
    }
    return items;
  }

  void setActiveCouple(String? coupleId, {int? sessionStateVersion}) {
    final String? normalized = coupleId?.trim().isEmpty == true
        ? null
        : coupleId?.trim();
    final int nextVersion = sessionStateVersion ?? _sessionStateVersion;
    if (normalized == null) {
      if (_activeCoupleId == null && _mode == 'solo') {
        _badgeController?.setScope(
          mode: 'solo',
          sessionId: _activeSoloSessionId,
        );
        return;
      }
      _activeCoupleId = null;
      _mode = 'solo';
      _badgeController?.setScope(mode: 'solo');
      _sessionStateVersion = nextVersion;
      matches = <MatchItem>[];
      error = null;
      isLoading = false;
      _matchesLoadedAt = null;
      _matchesLoadFuture = null;
      notifyListeners();
      _cacheService.clearCachedMatches();
      _clearPairNotificationState();
      return;
    }
    if (normalized == _activeCoupleId &&
        nextVersion == _sessionStateVersion &&
        _mode == 'paired') {
      _badgeController?.setScope(mode: 'paired', sessionId: normalized);
      return;
    }

    _activeCoupleId = normalized;
    _activeSoloSessionId = null;
    _optimisticSoloMatchKeys.clear();
    _optimisticSoloMatches.clear();
    _mode = 'paired';
    _badgeController?.setScope(mode: 'paired', sessionId: normalized);
    _sessionStateVersion = nextVersion;
    matches = <MatchItem>[];
    error = null;
    isLoading = false;
    _matchesLoadedAt = null;
    _matchesLoadFuture = null;
    notifyListeners();
    _cacheService.clearCachedMatches();
    _clearPairNotificationState();

    loadMatches();
  }

  void setSoloSession(String? sessionId) {
    final String? normalized = sessionId?.trim().isEmpty == true
        ? null
        : sessionId?.trim();
    if (_mode == 'solo' && _activeSoloSessionId == normalized) {
      _badgeController?.setScope(mode: 'solo', sessionId: normalized);
      return;
    }
    _activeCoupleId = null;
    _activeSoloSessionId = normalized;
    _optimisticSoloMatchKeys.clear();
    _optimisticSoloMatches.clear();
    _mode = 'solo';
    _badgeController?.setScope(mode: 'solo', sessionId: normalized);
    matches = <MatchItem>[];
    error = null;
    isLoading = false;
    _matchesLoadedAt = null;
    _matchesLoadFuture = null;
    _cacheService.clearCachedMatches();
    _clearPairNotificationState();
    notifyListeners();
  }

  void setMode(String mode) {
    final String normalized = mode == 'paired' ? 'paired' : 'solo';
    if (_mode == normalized) {
      return;
    }
    _mode = normalized;
    _badgeController?.setScope(
      mode: normalized,
      sessionId: normalized == 'solo' ? _activeSoloSessionId : _activeCoupleId,
    );
    if (normalized == 'paired') {
      _activeSoloSessionId = null;
      _optimisticSoloMatchKeys.clear();
      _optimisticSoloMatches.clear();
    }
    matches = <MatchItem>[];
    error = null;
    isLoading = false;
    _matchesLoadedAt = null;
    _matchesLoadFuture = null;
    _cacheService.clearCachedMatches();
    notifyListeners();
  }

  void clearMatches() {
    matches = <MatchItem>[];
    error = null;
    _matchesLoadedAt = null;
    _matchesLoadFuture = null;
    _cacheService.clearCachedMatches();
    _clearPairNotificationState();
    AppLogger.info('[Cache] matches invalidated reason=clear');
    notifyListeners();
  }

  void resetForAuthBoundary({bool notify = true}) {
    clearForLogout(notify: notify);
  }

  void handleAuthBoundary(int version) {
    if (_authBoundaryVersion == version) {
      return;
    }
    _authBoundaryVersion = version;
    resetForAuthBoundary(notify: false);
  }

  void clearForLogout({bool notify = true}) {
    final bool changed = _activeCoupleId != null ||
        _activeSoloSessionId != null ||
        _sessionStateVersion != 0 ||
        matches.isNotEmpty ||
        error != null ||
        isLoading;
    _activeCoupleId = null;
    _activeSoloSessionId = null;
    _activeUserId = null;
    _optimisticSoloMatchKeys.clear();
    _optimisticSoloMatches.clear();
    _mode = 'solo';
    _sessionStateVersion = 0;
    matches = <MatchItem>[];
    error = null;
    isLoading = false;
    _matchesLoadedAt = null;
    _matchesLoadFuture = null;
    _cacheService.clearCachedMatches();
    _clearPairNotificationState();
    AppLogger.info('[Cache] matches invalidated reason=logout');
    if (changed && notify) {
      notifyListeners();
    }
  }


  void markMatchSeen(String matchId) {
    final String normalized = matchId.trim();
    if (normalized.isNotEmpty) {
      _knownPairedMatchIds.add(normalized);
    }
  }

  Future<List<MatchItem>> syncPairedMatchesForNotifications({bool seedOnly = false}) async {
    if (_mode != 'paired' || _activeCoupleId == null) {
      return <MatchItem>[];
    }

    try {
      final List<MatchItem> latest = _filterForMode(await _swipeRepository.getMatches(mode: 'paired'));
      final Set<String> latestIds = latest
          .map((MatchItem item) => item.id)
          .whereType<String>()
          .where((String id) => id.isNotEmpty)
          .toSet();
      final bool shouldSeed = seedOnly || !_hasSeededPairedMatchNotifications;
      final List<MatchItem> newMatches = shouldSeed
          ? <MatchItem>[]
          : latest
              .where((MatchItem item) => item.id != null && !_knownPairedMatchIds.contains(item.id))
              .toList();

      _knownPairedMatchIds.addAll(latestIds);
      _hasSeededPairedMatchNotifications = true;
      matches = latest;
      _matchesLoadedAt = DateTime.now();
      await _cacheService.cacheMatches(matches.map((MatchItem item) => item.dish).toList(), coupleId: _cacheKey);
      notifyListeners();
      return newMatches;
    } catch (e) {
      AppLogger.error('MatchProvider: paired notification sync failed', e);
      return <MatchItem>[];
    }
  }

  void _clearPairNotificationState() {
    _knownPairedMatchIds.clear();
    _hasSeededPairedMatchNotifications = false;
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return ErrorMessages.fromApiException(e);
    }
    return ErrorMessages.unexpected;
  }
}

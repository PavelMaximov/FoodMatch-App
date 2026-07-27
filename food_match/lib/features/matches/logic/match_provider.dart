import 'package:flutter/foundation.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/cache_policy.dart';
import '../../../data/local/cache_service.dart';
import '../../../data/models/dish.dart';
import '../../../data/models/match_item.dart';
import '../../../data/repositories/swipe_repository.dart';
import '../../../data/services/api_service.dart';

class MatchProvider extends ChangeNotifier {
  MatchProvider({
    required SwipeRepository swipeRepository,
    CacheService? cacheService,
  })  : _swipeRepository = swipeRepository,
        _cacheService = cacheService ?? CacheService();

  final SwipeRepository _swipeRepository;
  final CacheService _cacheService;
  String? _activeCoupleId;
  String? _activeSoloSessionId;
  String _mode = 'solo';
  int _sessionStateVersion = 0;
  DateTime? _matchesLoadedAt;
  Future<void>? _matchesLoadFuture;
  final Set<String> _knownPairedMatchIds = <String>{};
  bool _hasSeededPairedMatchNotifications = false;
  int _authBoundaryVersion = -1;

  List<MatchItem> matches = <MatchItem>[];
  bool isLoading = false;
  String? error;

  int get matchCount => matches.length;
  String get mode => _mode;
  bool get isSoloMode => _mode == 'solo';


  bool get _hasFreshMatchesCache {
    final DateTime? loadedAt = _matchesLoadedAt;
    return loadedAt != null &&
        DateTime.now().difference(loadedAt) < CachePolicy.matchesTtl;
  }

  Future<void> loadMatches({bool force = false, String? mode, String? soloSessionId}) {
    if (soloSessionId != null && soloSessionId != _activeSoloSessionId) {
      _activeSoloSessionId = soloSessionId;
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
      AppLogger.info('[Cache] matches hit count=${matches.length} age=${age}s');
      return Future<void>.value();
    }
    final Future<void>? inFlight = _matchesLoadFuture;
    if (inFlight != null) {
      AppLogger.info('[RequestDedup] matches load skipped: already in flight');
      return inFlight;
    }

    _matchesLoadFuture = _loadMatchesFromApi(force: force);
    return _matchesLoadFuture!;
  }

  Future<void> _loadMatchesFromApi({required bool force}) async {
    AppLogger.info(
      '[PageLoad] start page=Matches reason=${force ? 'refresh' : 'route'}',
    );
    AppLogger.info(force ? '[Cache] matches force refresh' : '[Cache] matches miss');
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      matches = _filterForMode(
        await _swipeRepository.getMatches(
          mode: _mode,
          scope: _mode == 'solo' ? 'current' : null,
          soloSessionId: _mode == 'solo' ? _activeSoloSessionId : null,
        ),
      );
      _matchesLoadedAt = DateTime.now();
      await _cacheService.cacheMatches(matches.map((MatchItem item) => item.dish).toList(), coupleId: _cacheKey);
      AppLogger.info('MatchProvider: loaded ${matches.length} matches');
      AppLogger.info(
        matches.isEmpty
            ? '[PageLoad] empty page=Matches'
            : '[PageLoad] success page=Matches items=${matches.length}',
      );
    } catch (e) {
      matches = (await _cacheService.getCachedMatches(coupleId: _cacheKey))
          .map((Dish dish) => MatchItem.fromCachedDish(dish, _mode))
          .toList();
      if (matches.isEmpty) {
        error = _mapError(e);
        AppLogger.info('[PageLoad] error page=Matches error=$error');
      } else {
        _matchesLoadedAt ??= DateTime.now();
        AppLogger.info('MatchProvider: loaded ${matches.length} from cache');
      }
    } finally {
      isLoading = false;
      _matchesLoadFuture = null;
      notifyListeners();
    }
  }

  String get _cacheKey {
    if (_mode == 'paired') {
      return _activeCoupleId ?? 'paired';
    }
    return _activeSoloSessionId == null ? 'solo-current' : 'solo_$_activeSoloSessionId';
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
    final String? normalized = coupleId?.trim().isEmpty == true ? null : coupleId?.trim();
    final int nextVersion = sessionStateVersion ?? _sessionStateVersion;
    if (normalized == null) {
      if (_activeCoupleId == null && _mode == 'solo') {
        return;
      }
      _activeCoupleId = null;
      _mode = 'solo';
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
    if (normalized == _activeCoupleId && nextVersion == _sessionStateVersion && _mode == 'paired') {
      return;
    }

    _activeCoupleId = normalized;
    _activeSoloSessionId = null;
    _mode = 'paired';
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
    final String? normalized = sessionId?.trim().isEmpty == true ? null : sessionId?.trim();
    if (_mode == 'solo' && _activeSoloSessionId == normalized) {
      return;
    }
    _activeCoupleId = null;
    _activeSoloSessionId = normalized;
    _mode = 'solo';
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
    if (normalized == 'paired') {
      _activeSoloSessionId = null;
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

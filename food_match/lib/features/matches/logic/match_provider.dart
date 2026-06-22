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
  String _mode = 'solo';
  int _sessionStateVersion = 0;
  DateTime? _matchesLoadedAt;
  Future<void>? _matchesLoadFuture;

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

  Future<void> loadMatches({bool force = false, String? mode}) {
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
    AppLogger.info(force ? '[Cache] matches force refresh' : '[Cache] matches miss');
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      matches = _filterForMode(await _swipeRepository.getMatches(mode: _mode));
      _matchesLoadedAt = DateTime.now();
      await _cacheService.cacheMatches(matches.map((MatchItem item) => item.dish).toList(), coupleId: _cacheKey);
      AppLogger.info('MatchProvider: loaded ${matches.length} matches');
    } catch (e) {
      matches = (await _cacheService.getCachedMatches(coupleId: _cacheKey))
          .map((Dish dish) => MatchItem.fromCachedDish(dish, _mode))
          .toList();
      if (matches.isEmpty) {
        error = _mapError(e);
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

  String get _cacheKey => _mode == 'paired' ? (_activeCoupleId ?? 'paired') : 'solo';

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
    final String nextMode = normalized == null ? 'solo' : 'paired';
    if (normalized == _activeCoupleId && nextVersion == _sessionStateVersion && nextMode == _mode) {
      return;
    }

    _activeCoupleId = normalized;
    _mode = nextMode;
    _sessionStateVersion = nextVersion;
    matches = <MatchItem>[];
    error = null;
    isLoading = false;
    _matchesLoadedAt = null;
    _matchesLoadFuture = null;
    notifyListeners();
    _cacheService.clearCachedMatches();

    loadMatches();
  }

  void setMode(String mode) {
    final String normalized = mode == 'paired' ? 'paired' : 'solo';
    if (_mode == normalized) {
      return;
    }
    _mode = normalized;
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
    AppLogger.info('[Cache] matches invalidated reason=clear');
    notifyListeners();
  }

  void clearForLogout({bool notify = true}) {
    final bool changed = _activeCoupleId != null ||
        _sessionStateVersion != 0 ||
        matches.isNotEmpty ||
        error != null ||
        isLoading;
    _activeCoupleId = null;
    _mode = 'solo';
    _sessionStateVersion = 0;
    matches = <MatchItem>[];
    error = null;
    isLoading = false;
    _matchesLoadedAt = null;
    _matchesLoadFuture = null;
    _cacheService.clearCachedMatches();
    AppLogger.info('[Cache] matches invalidated reason=logout');
    if (changed && notify) {
      notifyListeners();
    }
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return ErrorMessages.fromApiException(e);
    }
    return ErrorMessages.unexpected;
  }
}

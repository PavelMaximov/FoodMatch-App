import 'package:flutter/foundation.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/cache_policy.dart';
import '../../../data/local/cache_service.dart';
import '../../../data/models/dish.dart';
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
  int _sessionStateVersion = 0;
  DateTime? _matchesLoadedAt;
  Future<void>? _matchesLoadFuture;

  List<Dish> matches = <Dish>[];
  bool isLoading = false;
  String? error;

  int get matchCount => matches.length;

  bool get _hasFreshMatchesCache {
    final DateTime? loadedAt = _matchesLoadedAt;
    return loadedAt != null &&
        DateTime.now().difference(loadedAt) < CachePolicy.matchesTtl;
  }

  Future<void> loadMatches({bool force = false}) {
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
      matches = await _swipeRepository.getMatches();
      _matchesLoadedAt = DateTime.now();
      await _cacheService.cacheMatches(matches, coupleId: _activeCoupleId ?? 'solo');
      AppLogger.info('MatchProvider: loaded ${matches.length} matches');
    } catch (e) {
      matches = await _cacheService.getCachedMatches(coupleId: _activeCoupleId ?? 'solo');
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

  void setActiveCouple(String? coupleId, {int? sessionStateVersion}) {
    final String? normalized = coupleId?.trim().isEmpty == true ? null : coupleId?.trim();
    final int nextVersion = sessionStateVersion ?? _sessionStateVersion;
    if (normalized == _activeCoupleId && nextVersion == _sessionStateVersion) {
      return;
    }

    _activeCoupleId = normalized;
    _sessionStateVersion = nextVersion;
    matches = <Dish>[];
    error = null;
    isLoading = false;
    _matchesLoadedAt = null;
    _matchesLoadFuture = null;
    notifyListeners();
    _cacheService.clearCachedMatches();

    loadMatches();
  }

  void clearMatches() {
    matches = <Dish>[];
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
    _sessionStateVersion = 0;
    matches = <Dish>[];
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

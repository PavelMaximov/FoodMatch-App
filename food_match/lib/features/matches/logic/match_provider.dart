import 'package:flutter/foundation.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/logger.dart';
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

  List<Dish> matches = <Dish>[];
  bool isLoading = false;
  String? error;

  int get matchCount => matches.length;

  Future<void> loadMatches({bool force = false}) async {
    if (isLoading && !force) {
      return;
    }

    if (_activeCoupleId == null || _activeCoupleId!.isEmpty) {
      matches = <Dish>[];
      error = null;
      isLoading = false;
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      matches = await _swipeRepository.getMatches();
      await _cacheService.cacheMatches(matches, coupleId: _activeCoupleId);
      AppLogger.info('MatchProvider: loaded ${matches.length} matches');
    } catch (e) {
      matches = await _cacheService.getCachedMatches(coupleId: _activeCoupleId);
      if (matches.isEmpty) {
        error = _mapError(e);
      } else {
        AppLogger.info('MatchProvider: loaded ${matches.length} from cache');
      }
    } finally {
      isLoading = false;
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
    notifyListeners();
    _cacheService.clearCachedMatches();

    if (_activeCoupleId != null) {
      loadMatches();
    }
  }

  void clearMatches() {
    matches = <Dish>[];
    error = null;
    _cacheService.clearCachedMatches();
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
    _cacheService.clearCachedMatches();
    if (changed && notify) {
      notifyListeners();
    }
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return e.message;
    }
    return AppStrings.unexpectedError;
  }
}

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/cache_service.dart';
import '../../../data/models/dish.dart';
import '../../../data/repositories/dish_repository.dart';
import '../../../data/repositories/swipe_repository.dart';
import '../../../data/services/api_service.dart';

class MatchProvider extends ChangeNotifier {
  MatchProvider({
    required SwipeRepository swipeRepository,
    required DishRepository dishRepository,
    CacheService? cacheService,
  })  : _swipeRepository = swipeRepository,
        _dishRepository = dishRepository,
        _cacheService = cacheService ?? CacheService();

  final SwipeRepository _swipeRepository;
  final DishRepository _dishRepository;
  final CacheService _cacheService;
  String? _activeCoupleId;
  int _sessionStateVersion = 0;

  List<Dish> matches = <Dish>[];
  Set<String> savedDishIds = <String>{};
  bool isLoading = false;
  String? error;

  int get matchCount => matches.length;

  Future<void> loadMatches() async {
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
      await _refreshSavedDishIds();
      AppLogger.info('MatchProvider: loaded ${matches.length} matches');
    } catch (e) {
      matches = await _cacheService.getCachedMatches(coupleId: _activeCoupleId);
      await _refreshSavedDishIds();
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
    savedDishIds = <String>{};
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
    savedDishIds = <String>{};
    error = null;
    _cacheService.clearCachedMatches();
    notifyListeners();
  }

  bool isDishSaved(String dishId) => savedDishIds.contains(dishId);

  Future<void> toggleDishSaved(String dishId) async {
    if (dishId.isEmpty) {
      return;
    }

    try {
      final bool currentlySaved = savedDishIds.contains(dishId);
      if (currentlySaved) {
        await _dishRepository.unsaveDish(dishId);
        savedDishIds.remove(dishId);
      } else {
        await _dishRepository.saveDish(dishId);
        savedDishIds.add(dishId);
      }
      error = null;
    } catch (e) {
      error = _mapError(e);
    }
    notifyListeners();
  }

  Future<void> _refreshSavedDishIds() async {
    try {
      final List<Dish> savedDishes = await _dishRepository.getSavedDishes();
      savedDishIds = savedDishes
          .map((Dish dish) => dish.id)
          .where((String id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      // Keep previous state on temporary backend/network failures.
    }
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return e.message;
    }
    return AppStrings.unexpectedError;
  }
}

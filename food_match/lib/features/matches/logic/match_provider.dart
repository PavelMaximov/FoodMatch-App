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

  List<Dish> matches = <Dish>[];
  bool isLoading = false;
  String? error;

  int get matchCount => matches.length;

  Future<void> loadMatches() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      matches = await _swipeRepository.getMatches();
      await _cacheService.cacheMatches(matches);
      AppLogger.info('MatchProvider: loaded ${matches.length} matches');
    } catch (e) {
      matches = await _cacheService.getCachedMatches();
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

  void clearMatches() {
    matches = <Dish>[];
    notifyListeners();
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return e.message;
    }
    return AppStrings.unexpectedError;
  }
}

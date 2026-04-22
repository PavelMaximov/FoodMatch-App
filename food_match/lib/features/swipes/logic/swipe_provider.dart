import 'package:flutter/foundation.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/cache_service.dart';
import '../../../data/local/user_profile_hive_service.dart';
import '../../../data/models/dish.dart';
import '../../../data/repositories/dish_repository.dart';
import '../../../data/repositories/swipe_repository.dart';
import '../../../data/services/api_service.dart';

class SwipeProvider extends ChangeNotifier {
  SwipeProvider({
    required DishRepository dishRepository,
    required SwipeRepository swipeRepository,
    required UserProfileHiveService userProfileService,
    CacheService? cacheService,
  })  : _dishRepository = dishRepository,
        _swipeRepository = swipeRepository,
        _cacheService = cacheService ?? CacheService(),
        _userProfileService = userProfileService;

  final DishRepository _dishRepository;
  final SwipeRepository _swipeRepository;
  final CacheService _cacheService;
  final UserProfileHiveService _userProfileService;

  final Set<String> _sentSwipeDishIds = <String>{};
  bool _isSendingSwipe = false;
  String? _activeUserId;
  bool _hasPreparedDeck = false;

  List<Dish> deck = <Dish>[];
  int currentIndex = 0;
  bool isLoading = false;
  String? error;
  Dish? _lastSwipedDish;
  int? _lastSwipedIndex;
  Set<String> _seenDishIds = <String>{};

  Dish? get currentDish =>
      deck.isNotEmpty && currentIndex < deck.length ? deck[currentIndex] : null;
  bool get isDeckEmpty => currentIndex >= deck.length;
  Dish? get lastSwipedDish => _lastSwipedDish;
  bool get canUndo => _lastSwipedDish != null && _lastSwipedIndex != null;
  bool get hasPreparedDeck => _hasPreparedDeck;

  bool isSeenDish(String dishId) => _seenDishIds.contains(dishId);

  void setActiveUser(String? userId) {
    _activeUserId = userId;
  }

  void applyPreparedDeck(List<Dish> prepared, {Set<String> seenDishIds = const <String>{}}) {
    deck = prepared;
    _seenDishIds = seenDishIds;
    _hasPreparedDeck = true;
    currentIndex = 0;
    _lastSwipedDish = null;
    _lastSwipedIndex = null;
    _sentSwipeDishIds.clear();
    _isSendingSwipe = false;
    error = deck.isEmpty ? AppStrings.noDishesAvailable : null;
    notifyListeners();
  }

  void clearPreparedDeckFlag() {
    _hasPreparedDeck = false;
  }

  void clearPreparedDeck() {
    deck = <Dish>[];
    _seenDishIds = <String>{};
    _hasPreparedDeck = false;
    currentIndex = 0;
    _lastSwipedDish = null;
    _lastSwipedIndex = null;
    _sentSwipeDishIds.clear();
    error = null;
    notifyListeners();
  }

  Future<void> loadDeck({String? cuisine}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      deck = await _dishRepository.getDishes(cuisine: cuisine);
      AppLogger.info('SwipeProvider: loaded ${deck.length} from backend');
      await _cacheService.cacheDishes(deck);
    } catch (e) {
      AppLogger.error('SwipeProvider: backend failed', e);
      deck = await _cacheService.getCachedDishes();
      if (deck.isNotEmpty) {
        AppLogger.info('SwipeProvider: loaded ${deck.length} from cache');
      } else {
        error = AppStrings.failedToLoadDishes;
      }
    }

    if (deck.isEmpty && error == null) {
      error = AppStrings.noDishesAvailable;
    }

    _seenDishIds = <String>{};
    _hasPreparedDeck = false;
    currentIndex = 0;
    _lastSwipedDish = null;
    _lastSwipedIndex = null;
    _sentSwipeDishIds.clear();
    _isSendingSwipe = false;
    isLoading = false;
    notifyListeners();
  }

  Future<dynamic> swipe(String direction) async {
    final Dish? dish = currentDish;
    if (dish == null || _isSendingSwipe || _sentSwipeDishIds.contains(dish.id)) {
      return null;
    }

    _isSendingSwipe = true;
    _lastSwipedDish = dish;
    _lastSwipedIndex = currentIndex;

    try {
      final dynamic result = await _swipeRepository.sendSwipe(
        dishId: dish.id,
        direction: direction,
      );
      _sentSwipeDishIds.add(dish.id);
      currentIndex++;
      await _persistLearning(dish, direction, result);
      _cleanupSessionChoicesIfDone();
      notifyListeners();
      return result;
    } catch (e) {
      if (_shouldQueueOffline(e)) {
        AppLogger.info('SwipeProvider: queueing swipe offline');
        await _cacheService.queueSwipe(dish.id, direction);
        _sentSwipeDishIds.add(dish.id);
        currentIndex++;
        await _persistLearning(dish, direction, null);
        _cleanupSessionChoicesIfDone();
        notifyListeners();
        return null;
      }

      AppLogger.error('SwipeProvider: swipe rejected', e);
      error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isSendingSwipe = false;
    }
  }

  void undo() {
    if (!canUndo) {
      return;
    }

    currentIndex = _lastSwipedIndex!;
    if (_lastSwipedDish != null) {
      _sentSwipeDishIds.remove(_lastSwipedDish!.id);
    }
    _lastSwipedDish = null;
    _lastSwipedIndex = null;
    AppLogger.info('SwipeProvider: undo swipe, back to index $currentIndex');
    notifyListeners();
  }

  Future<void> syncPendingSwipes() async {
    final List<Map<String, dynamic>> pending = await _cacheService.getPendingSwipes();
    if (pending.isEmpty) {
      return;
    }

    AppLogger.info('SwipeProvider: syncing ${pending.length} pending swipes');
    int synced = 0;

    for (int i = 0; i < pending.length; i++) {
      try {
        await _swipeRepository.sendSwipe(
          dishId: pending[i]['dishId'] as String,
          direction: pending[i]['action'] as String,
        );
        synced++;
      } catch (e) {
        AppLogger.error('SwipeProvider: sync failed for swipe $i', e);
        break;
      }
    }

    if (synced > 0) {
      await _cacheService.clearPendingSwipes();
      AppLogger.info('SwipeProvider: synced $synced swipes');
    }
  }

  Future<dynamic> like() => swipe('like');

  Future<dynamic> dislike() => swipe('dislike');

  bool _shouldQueueOffline(Object error) {
    if (error is! ApiException) {
      return false;
    }

    final int? statusCode = error.statusCode;
    return statusCode == null || statusCode >= 500;
  }

  Future<void> _persistLearning(Dish dish, String direction, dynamic result) async {
    final String? userId = _activeUserId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    await _userProfileService.recordSwipe(
      userId: userId,
      dishId: dish.id,
      direction: direction,
      cuisine: dish.cuisine,
    );

    final bool matched = result is Map<String, dynamic> && result['swipe']?['matchCreated'] == true;
    if (matched) {
      await _userProfileService.recordMatch(userId: userId, dishId: dish.id);
      _seenDishIds.add(dish.id);
    }
  }

  Future<void> _cleanupSessionChoicesIfDone() async {
    if (!isDeckEmpty || !_hasPreparedDeck) {
      return;
    }
    final String? userId = _activeUserId;
    if (userId != null && userId.isNotEmpty) {
      await _userProfileService.clearSessionChoices(userId);
    }
    _hasPreparedDeck = false;
  }
}

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/cache_service.dart';
import '../../../data/models/dish.dart';
import '../../../data/repositories/dish_repository.dart';
import '../../../data/repositories/swipe_repository.dart';
import '../../../data/services/mealdb_service.dart';

class SwipeProvider extends ChangeNotifier {
  SwipeProvider({
    required DishRepository dishRepository,
    required SwipeRepository swipeRepository,
    MealDbService? mealDbService,
    CacheService? cacheService,
  })  : _dishRepository = dishRepository,
        _swipeRepository = swipeRepository,
        _mealDbService = mealDbService ?? MealDbService(),
        _cacheService = cacheService ?? CacheService();

  final DishRepository _dishRepository;
  final SwipeRepository _swipeRepository;
  final MealDbService _mealDbService;
  final CacheService _cacheService;

  List<Dish> deck = <Dish>[];
  int currentIndex = 0;
  bool isLoading = false;
  String? error;
  Dish? _lastSwipedDish;
  int? _lastSwipedIndex;

  Dish? get currentDish =>
      deck.isNotEmpty && currentIndex < deck.length ? deck[currentIndex] : null;
  bool get isDeckEmpty => currentIndex >= deck.length;
  Dish? get lastSwipedDish => _lastSwipedDish;
  bool get canUndo => _lastSwipedDish != null && _lastSwipedIndex != null;

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

      try {
        final List<Dish> mealDbDeck;
        if (cuisine != null && cuisine.isNotEmpty) {
          final mealDbDishes = await _mealDbService.getMealsByArea(cuisine);
          mealDbDeck = mealDbDishes.map((meal) => meal.toDish()).toList();
        } else {
          final mealDbDishes = await _mealDbService.getRandomMeals(count: 20);
          mealDbDeck = mealDbDishes.map((meal) => meal.toDish()).toList();
        }
        deck = mealDbDeck;
        AppLogger.info('SwipeProvider: loaded ${deck.length} from MealDB');
        await _cacheService.cacheDishes(deck);
      } catch (e2) {
        AppLogger.error('SwipeProvider: MealDB failed', e2);

        deck = await _cacheService.getCachedDishes();
        if (deck.isNotEmpty) {
          AppLogger.info('SwipeProvider: loaded ${deck.length} from cache');
        } else {
          error = AppStrings.failedToLoadDishes;
        }
      }
    }

    if (deck.isEmpty && error == null) {
      try {
        final List<Dish> mealDbDeck;
        if (cuisine != null && cuisine.isNotEmpty) {
          final mealDbDishes = await _mealDbService.getMealsByArea(cuisine);
          mealDbDeck = mealDbDishes.map((meal) => meal.toDish()).toList();
        } else {
          final mealDbDishes = await _mealDbService.getRandomMeals(count: 20);
          mealDbDeck = mealDbDishes.map((meal) => meal.toDish()).toList();
        }
        deck = mealDbDeck;
        await _cacheService.cacheDishes(deck);
      } catch (_) {
        deck = await _cacheService.getCachedDishes();
        if (deck.isEmpty) {
          error = AppStrings.noDishesAvailable;
        }
      }
    }

    currentIndex = 0;
    _lastSwipedDish = null;
    _lastSwipedIndex = null;
    isLoading = false;
    notifyListeners();
  }

  Future<dynamic> swipe(String action) async {
    final Dish? dish = currentDish;
    if (dish == null) {
      return null;
    }

    _lastSwipedDish = dish;
    _lastSwipedIndex = currentIndex;

    if (dish.source == 'mealdb') {
      currentIndex++;
      notifyListeners();
      AppLogger.info('SwipeProvider: local swipe for MealDB dish ${dish.id} ($action)');
      return <String, dynamic>{'matched': false, 'source': 'mealdb-local'};
    }

    try {
      final dynamic result = await _swipeRepository.sendSwipe(
        dishId: dish.id,
        action: action,
      );
      currentIndex++;
      notifyListeners();
      return result;
    } catch (e) {
      AppLogger.info('SwipeProvider: queueing swipe offline');
      await _cacheService.queueSwipe(dish.id, action);
      currentIndex++;
      notifyListeners();
      return null;
    }
  }

  void undo() {
    if (!canUndo) {
      return;
    }

    currentIndex = _lastSwipedIndex!;
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
          action: pending[i]['action'] as String,
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
}

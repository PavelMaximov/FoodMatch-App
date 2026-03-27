import 'package:flutter/foundation.dart';

import '../../../core/utils/logger.dart';
import '../../../data/models/dish.dart';
import '../../../data/repositories/dish_repository.dart';
import '../../../data/repositories/swipe_repository.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/mealdb_service.dart';

class SwipeProvider extends ChangeNotifier {
  SwipeProvider({
    required DishRepository dishRepository,
    required SwipeRepository swipeRepository,
    MealDbService? mealDbService,
  })  : _dishRepository = dishRepository,
        _swipeRepository = swipeRepository,
        _mealDbService = mealDbService ?? MealDbService();

  final DishRepository _dishRepository;
  final SwipeRepository _swipeRepository;
  final MealDbService _mealDbService;

  List<Dish> deck = <Dish>[];
  int currentIndex = 0;
  bool isLoading = false;
  String? error;

  Dish? get currentDish =>
      deck.isNotEmpty && currentIndex < deck.length ? deck[currentIndex] : null;
  bool get isDeckEmpty => currentIndex >= deck.length;

  Future<void> loadDeck({String? cuisine}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      deck = await _dishRepository.getDishes(cuisine: cuisine);
      AppLogger.info('SwipeProvider: loaded ${deck.length} dishes from backend');
    } catch (e) {
      AppLogger.error('SwipeProvider: backend failed, falling back to MealDB', e);
      try {
        final mealDbDishes = await _mealDbService.getRandomMeals(count: 20);
        deck = mealDbDishes.map((meal) => meal.toDish()).toList();
        AppLogger.info('SwipeProvider: loaded ${deck.length} dishes from MealDB');
      } catch (mealDbError) {
        error = 'Failed to load dishes';
        AppLogger.error('SwipeProvider: MealDB also failed', mealDbError);
      }
    }

    if (deck.isEmpty && error == null) {
      AppLogger.info('SwipeProvider: backend returned 0 dishes, trying MealDB');
      try {
        final mealDbDishes = await _mealDbService.getRandomMeals(count: 20);
        deck = mealDbDishes.map((meal) => meal.toDish()).toList();
        AppLogger.info('SwipeProvider: loaded ${deck.length} dishes from MealDB');
      } catch (e) {
        error = 'No dishes available';
      }
    }

    currentIndex = 0;
    isLoading = false;
    notifyListeners();
  }

  Future<dynamic> swipe(String action) async {
    final dish = currentDish;
    if (dish == null) {
      return null;
    }

    if (dish.source == 'mealdb') {
      currentIndex++;
      notifyListeners();
      AppLogger.info('SwipeProvider: local swipe for MealDB dish ${dish.id} ($action)');
      return <String, dynamic>{'matched': false, 'source': 'mealdb-local'};
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final result = await _swipeRepository.sendSwipe(
        dishId: dish.id,
        action: action,
      );
      currentIndex++;
      notifyListeners();
      return result;
    } catch (e) {
      error = _mapError(e);
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<dynamic> like() => swipe('like');

  Future<dynamic> dislike() => swipe('dislike');

  String _mapError(Object e) {
    if (e is ApiException) {
      return e.message;
    }
    return 'Unexpected error occurred';
  }
}

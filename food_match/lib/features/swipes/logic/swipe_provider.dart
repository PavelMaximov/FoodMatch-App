import 'package:flutter/foundation.dart';

import '../../../data/models/dish.dart';
import '../../../data/repositories/dish_repository.dart';
import '../../../data/repositories/swipe_repository.dart';
import '../../../data/services/api_service.dart';

class SwipeProvider extends ChangeNotifier {
  SwipeProvider({
    required DishRepository dishRepository,
    required SwipeRepository swipeRepository,
  })  : _dishRepository = dishRepository,
        _swipeRepository = swipeRepository;

  final DishRepository _dishRepository;
  final SwipeRepository _swipeRepository;

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
      currentIndex = 0;
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<dynamic> swipe(String action) async {
    final dish = currentDish;
    if (dish == null) {
      return null;
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

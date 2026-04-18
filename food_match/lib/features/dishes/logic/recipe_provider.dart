import 'package:flutter/foundation.dart';

import '../../../core/constants/app_strings.dart';
import '../../../data/models/dish.dart';
import '../../../data/repositories/dish_repository.dart';
import '../../../data/services/api_service.dart';

class RecipeProvider extends ChangeNotifier {
  RecipeProvider({required DishRepository repository}) : _repository = repository;

  final DishRepository _repository;

  Dish? currentDish;
  bool isLoading = false;
  bool isFavorite = false;
  bool isFavoriteUpdating = false;
  String? error;

  Future<void> loadRecipeForDish({required String dishId, Dish? dish}) async {
    if (dish != null) {
      currentDish = dish;
      error = null;
      isLoading = false;
      notifyListeners();
      await _loadFavoriteState(dish.id);
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      currentDish = await _repository.getDishById(dishId);
      await _loadFavoriteState(currentDish?.id ?? dishId);
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavoriteForCurrentDish() async {
    final String dishId = currentDish?.id ?? '';
    if (dishId.isEmpty || isFavoriteUpdating) {
      return;
    }

    final bool previous = isFavorite;
    final bool next = !previous;
    isFavorite = next;
    isFavoriteUpdating = true;
    notifyListeners();

    try {
      if (next) {
        await _repository.saveDish(dishId);
      } else {
        await _repository.unsaveDish(dishId);
      }
      error = null;
    } catch (e) {
      isFavorite = previous;
      error = _mapError(e);
    } finally {
      isFavoriteUpdating = false;
      notifyListeners();
    }
  }

  Future<void> _loadFavoriteState(String dishId) async {
    if (dishId.isEmpty) {
      isFavorite = false;
      return;
    }

    try {
      final List<Dish> savedDishes = await _repository.getSavedDishes();
      isFavorite = savedDishes.any((Dish savedDish) => savedDish.id == dishId);
    } catch (_) {
      // Keep default false if saved dishes can't be loaded.
      isFavorite = false;
    }
  }

  void clearRecipe() {
    currentDish = null;
    isFavorite = false;
    isFavoriteUpdating = false;
    notifyListeners();
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return e.message;
    }
    return AppStrings.unexpectedError;
  }
}

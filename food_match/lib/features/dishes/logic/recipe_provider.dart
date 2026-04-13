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
  String? error;

  Future<void> loadRecipeForDish({required String dishId, Dish? dish}) async {
    if (dish != null) {
      currentDish = dish;
      error = null;
      isLoading = false;
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      currentDish = await _repository.getDishById(dishId);
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearRecipe() {
    currentDish = null;
    notifyListeners();
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return e.message;
    }
    return AppStrings.unexpectedError;
  }
}

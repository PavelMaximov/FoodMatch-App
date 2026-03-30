import 'package:flutter/foundation.dart';

import '../../../core/constants/app_strings.dart';
import '../../../data/models/dish.dart';
import '../../../data/models/recipe.dart';
import '../../../data/repositories/recipe_repository.dart';
import '../../../data/services/api_service.dart';

class RecipeProvider extends ChangeNotifier {
  RecipeProvider({required RecipeRepository repository}) : _repository = repository;

  final RecipeRepository _repository;

  Recipe? currentRecipe;
  bool isLoading = false;
  String? error;

  Future<void> loadRecipe(String dishId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      currentRecipe = await _repository.getRecipe(dishId);
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRecipeForDish({required String dishId, Dish? dish}) async {
    if (dish?.recipe != null) {
      currentRecipe = dish!.recipe;
      error = null;
      isLoading = false;
      notifyListeners();
      return;
    }

    await loadRecipe(dishId);
  }

  void clearRecipe() {
    currentRecipe = null;
    notifyListeners();
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return e.message;
    }
    return AppStrings.unexpectedError;
  }
}

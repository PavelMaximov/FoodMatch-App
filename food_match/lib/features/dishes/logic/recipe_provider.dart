import 'package:flutter/foundation.dart';

import '../../../core/errors/error_messages.dart';
import '../../../data/models/dish.dart';
import '../../../data/repositories/dish_repository.dart';
import '../../../data/services/api_service.dart';
import '../../../core/utils/logger.dart';

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
      if (!_needsHydration(dish)) return;
    } else { currentDish = null;
    }

    final hasInitialDish = currentDish != null;
    isLoading = !hasInitialDish;
    error = null;
    notifyListeners();

    try {
      AppLogger.info('[RecipeDetail] hydrate full dish id=$dishId');
      currentDish = await _repository.getDishById(dishId);
      AppLogger.info('[RecipeDetail] hydrated hasTime=${currentDish!.hasTime} totalTime=${currentDish!.resolvedTotalTimeMinutes}');
    } catch (e) {
      if (!hasInitialDish) error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
  bool _needsHydration(Dish dish) => !dish.hasTime || dish.sections.isEmpty || dish.steps.isEmpty || !dish.sections.expand((s) => s.components).any((c) => c.measurements.isNotEmpty);

  void clearRecipe() {
    currentDish = null;
    notifyListeners();
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return ErrorMessages.fromApiException(e);
    }
    return ErrorMessages.unexpected;
  }
}

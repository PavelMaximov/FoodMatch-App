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
  int _requestGeneration = 0;
  String? _activeDishId;
  bool _disposed = false;

  Future<void> loadRecipeForDish({required String dishId, Dish? dish}) async {
    final int generation = ++_requestGeneration;
    _activeDishId = dishId;
    if (dish != null) {
      currentDish = dish;
      error = null;
      isLoading = false;
      notifyListeners();
      if (!_needsHydration(dish)) return;
    } else {
      currentDish = null;
    }

    final hasInitialDish = currentDish != null;
    isLoading = !hasInitialDish;
    error = null;
    notifyListeners();

    try {
      AppLogger.info('[RecipeDetail] hydrate full dish id=$dishId');
      final Dish loadedDish = await _repository.getDishById(dishId);
      if (!_isCurrentRequest(dishId, generation)) return;
      currentDish = loadedDish;
      AppLogger.info(
        '[RecipeDetail] hydrated hasTime=${currentDish!.hasTime} '
        'totalTime=${currentDish!.resolvedTotalTimeMinutes}',
      );
    } catch (e) {
      if (!_isCurrentRequest(dishId, generation)) return;
      if (!hasInitialDish) error = _mapError(e);
    } finally {
      if (_isCurrentRequest(dishId, generation)) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  bool _needsHydration(Dish dish) =>
      !dish.hasTime ||
      dish.sections.isEmpty ||
      dish.steps.isEmpty ||
      !dish.sections
          .expand((DishSection section) => section.components)
          .any(
            (DishComponent component) => component.measurements.isNotEmpty,
          );

  void clearRecipe() {
    _requestGeneration++;
    _activeDishId = null;
    currentDish = null;
    notifyListeners();
  }

  bool _isCurrentRequest(String dishId, int generation) =>
      !_disposed && generation == _requestGeneration && dishId == _activeDishId;

  @override
  void dispose() {
    _disposed = true;
    _requestGeneration++;
    super.dispose();
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return ErrorMessages.fromApiException(e);
    }
    return ErrorMessages.unexpected;
  }
}

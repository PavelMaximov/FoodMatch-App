import 'package:flutter/foundation.dart';

import '../../../core/errors/error_messages.dart';
import '../../../data/models/dish.dart';
import '../../../data/repositories/dish_repository.dart';
import '../../../data/services/api_service.dart';

class FavoritesProvider extends ChangeNotifier {
  FavoritesProvider({required DishRepository repository}) : _repository = repository;

  final DishRepository _repository;

  List<Dish> _savedDishes = <Dish>[];
  Set<String> _savedDishIds = <String>{};
  final Set<String> _updatingDishIds = <String>{};
  String? _activeUserId;

  bool isLoading = false;
  String? error;

  List<Dish> get savedDishes => List<Dish>.unmodifiable(_savedDishes);
  Set<String> get savedDishIds => Set<String>.unmodifiable(_savedDishIds);
  Set<String> get updatingDishIds => Set<String>.unmodifiable(_updatingDishIds);

  void setActiveUser(String? userId) {
    final String? normalized = userId?.trim().isEmpty == true ? null : userId?.trim();
    if (normalized == _activeUserId) {
      return;
    }

    _activeUserId = normalized;
    _savedDishes = <Dish>[];
    _savedDishIds = <String>{};
    _updatingDishIds.clear();
    error = null;
    isLoading = false;
    notifyListeners();

    if (_activeUserId != null) {
      loadFavorites();
    }
  }

  bool isFavorite(String dishId) => _savedDishIds.contains(dishId);
  bool isUpdating(String dishId) => _updatingDishIds.contains(dishId);

  Future<void> loadFavorites({bool force = false}) async {
    if (_activeUserId == null || (isLoading && !force)) {
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final List<Dish> dishes = await _repository.getSavedDishes();
      dishes.sort((Dish a, Dish b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _savedDishes = dishes;
      _savedDishIds = dishes.map((Dish dish) => dish.id).where((String id) => id.isNotEmpty).toSet();
      error = null;
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(Dish dish) async {
    final String dishId = dish.id;
    if (dishId.isEmpty || _updatingDishIds.contains(dishId)) {
      return;
    }

    final bool wasSaved = _savedDishIds.contains(dishId);
    final List<Dish> previousDishes = List<Dish>.from(_savedDishes);
    final Set<String> previousIds = Set<String>.from(_savedDishIds);

    _updatingDishIds.add(dishId);
    if (wasSaved) {
      _savedDishIds.remove(dishId);
      _savedDishes.removeWhere((Dish savedDish) => savedDish.id == dishId);
    } else {
      _savedDishIds.add(dishId);
      if (!_savedDishes.any((Dish savedDish) => savedDish.id == dishId)) {
        _savedDishes = <Dish>[..._savedDishes, dish]
          ..sort((Dish a, Dish b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }
    }
    error = null;
    notifyListeners();

    try {
      if (wasSaved) {
        await _repository.unsaveDish(dishId);
      } else {
        await _repository.saveDish(dishId);
      }
    } catch (e) {
      _savedDishes = previousDishes;
      _savedDishIds = previousIds;
      error = _mapError(e);
    } finally {
      _updatingDishIds.remove(dishId);
      notifyListeners();
    }
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return ErrorMessages.fromApiException(e);
    }
    return ErrorMessages.unexpected;
  }
}

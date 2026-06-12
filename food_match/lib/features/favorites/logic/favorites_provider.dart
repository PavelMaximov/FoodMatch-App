import 'package:flutter/foundation.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/cache_policy.dart';
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
  DateTime? _favoritesLoadedAt;
  Future<void>? _favoritesLoadFuture;

  bool isLoading = false;
  String? error;

  List<Dish> get savedDishes => List<Dish>.unmodifiable(_savedDishes);
  Set<String> get savedDishIds => Set<String>.unmodifiable(_savedDishIds);
  Set<String> get updatingDishIds => Set<String>.unmodifiable(_updatingDishIds);

  bool get _hasFreshFavoritesCache {
    final DateTime? loadedAt = _favoritesLoadedAt;
    return loadedAt != null &&
        DateTime.now().difference(loadedAt) < CachePolicy.favoritesTtl;
  }

  void setActiveUser(String? userId) {
    final String? normalized = userId?.trim().isEmpty == true ? null : userId?.trim();
    if (normalized == _activeUserId) {
      return;
    }

    _activeUserId = normalized;
    _savedDishes = <Dish>[];
    _savedDishIds = <String>{};
    _updatingDishIds.clear();
    _favoritesLoadedAt = null;
    _favoritesLoadFuture = null;
    error = null;
    isLoading = false;
    notifyListeners();

    if (_activeUserId != null) {
      loadFavorites();
    }
  }

  bool isFavorite(String dishId) => _savedDishIds.contains(dishId);
  bool isUpdating(String dishId) => _updatingDishIds.contains(dishId);

  Future<void> loadFavorites({bool force = false}) {
    if (_activeUserId == null) {
      return Future<void>.value();
    }
    if (!force && _hasFreshFavoritesCache) {
      final int age = DateTime.now().difference(_favoritesLoadedAt!).inSeconds;
      AppLogger.info('[Cache] favorites hit count=${_savedDishes.length} age=${age}s');
      return Future<void>.value();
    }
    final Future<void>? inFlight = _favoritesLoadFuture;
    if (inFlight != null) {
      AppLogger.info('[RequestDedup] favorites load skipped: already in flight');
      return inFlight;
    }

    _favoritesLoadFuture = _loadFavoritesFromApi(force: force);
    return _favoritesLoadFuture!;
  }

  Future<void> _loadFavoritesFromApi({required bool force}) async {
    AppLogger.info(force ? '[Cache] favorites force refresh' : '[Cache] favorites miss');
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final List<Dish> dishes = await _repository.getSavedDishes();
      dishes.sort((Dish a, Dish b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _savedDishes = List<Dish>.from(dishes);
      _savedDishIds = dishes.map((Dish dish) => dish.id).where((String id) => id.isNotEmpty).toSet();
      _favoritesLoadedAt = DateTime.now();
      error = null;
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      _favoritesLoadFuture = null;
      notifyListeners();
    }
  }

  void clearForLogout({bool notify = true}) {
    _activeUserId = null;
    _savedDishes = <Dish>[];
    _savedDishIds = <String>{};
    _updatingDishIds.clear();
    _favoritesLoadedAt = null;
    _favoritesLoadFuture = null;
    error = null;
    isLoading = false;
    AppLogger.info('[Cache] favorites invalidated reason=logout');
    if (notify) {
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
        AppLogger.info('[Cache] favorites invalidated reason=unsave');
      } else {
        await _repository.saveDish(dishId);
        AppLogger.info('[Cache] favorites invalidated reason=save');
      }
      _favoritesLoadedAt = DateTime.now();
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

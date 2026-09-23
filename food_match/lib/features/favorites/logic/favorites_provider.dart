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
  int _requestGeneration = 0;
  int _userGeneration = 0;
  int _favoritesMutationGeneration = 0;
  final Map<String, _LocalFavoriteMutation> _localMutations =
      <String, _LocalFavoriteMutation>{};
  bool _disposed = false;

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
    _requestGeneration++;
    _userGeneration++;
    _savedDishes = <Dish>[];
    _savedDishIds = <String>{};
    _updatingDishIds.clear();
    _favoritesMutationGeneration = 0;
    _localMutations.clear();
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
    final String userId = _activeUserId!;
    final int generation = ++_requestGeneration;
    final int mutationGeneration = _favoritesMutationGeneration;
    AppLogger.info(force ? '[Cache] favorites force refresh' : '[Cache] favorites miss');
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final List<Dish> dishes = await _repository.getSavedDishes();
      if (!_isCurrentRequest(userId, generation)) return;
      dishes.sort((Dish a, Dish b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final Map<String, Dish> reconciled = <String, Dish>{
        for (final Dish dish in dishes)
          if (dish.id.isNotEmpty) dish.id: dish,
      };
      for (final MapEntry<String, _LocalFavoriteMutation> entry
          in _localMutations.entries) {
        final _LocalFavoriteMutation mutation = entry.value;
        if (mutation.generation <= mutationGeneration) continue;
        if (mutation.shouldBeSaved) {
          reconciled[entry.key] = mutation.dish;
        } else {
          reconciled.remove(entry.key);
        }
      }
      _localMutations.removeWhere(
        (String _, _LocalFavoriteMutation mutation) =>
            mutation.generation <= mutationGeneration,
      );
      _savedDishes = reconciled.values.toList()
        ..sort((Dish a, Dish b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _savedDishIds = reconciled.keys.toSet();
      _favoritesLoadedAt = DateTime.now();
      error = null;
    } catch (e) {
      if (!_isCurrentRequest(userId, generation)) return;
      error = _mapError(e);
    } finally {
      if (_isCurrentRequest(userId, generation)) {
        isLoading = false;
        _favoritesLoadFuture = null;
        notifyListeners();
      }
    }
  }

  void clearForLogout({bool notify = true}) {
    _requestGeneration++;
    _userGeneration++;
    _activeUserId = null;
    _savedDishes = <Dish>[];
    _savedDishIds = <String>{};
    _updatingDishIds.clear();
    _favoritesMutationGeneration = 0;
    _localMutations.clear();
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
    final String? userId = _activeUserId;
    final int userGeneration = _userGeneration;
    final int mutationGeneration = ++_favoritesMutationGeneration;
    _localMutations[dishId] = _LocalFavoriteMutation(
      generation: mutationGeneration,
      dish: dish,
      shouldBeSaved: !wasSaved,
    );

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
      if (!_isCurrentUser(userId, userGeneration)) return;
      _favoritesLoadedAt = DateTime.now();
    } catch (e) {
      if (!_isCurrentUser(userId, userGeneration)) return;
      if (_localMutations[dishId]?.generation == mutationGeneration) {
        _localMutations.remove(dishId);
      }
      if (wasSaved) {
        _savedDishIds.add(dishId);
        if (!_savedDishes.any((Dish savedDish) => savedDish.id == dishId)) {
          _savedDishes = <Dish>[..._savedDishes, dish]
            ..sort((Dish a, Dish b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        }
      } else {
        _savedDishIds.remove(dishId);
        _savedDishes.removeWhere((Dish savedDish) => savedDish.id == dishId);
      }
      error = _mapError(e);
    } finally {
      if (_isCurrentUser(userId, userGeneration)) {
        _updatingDishIds.remove(dishId);
        notifyListeners();
      }
    }
  }

  bool _isCurrentRequest(String? userId, int generation) =>
      !_disposed &&
      generation == _requestGeneration &&
      userId == _activeUserId;

  bool _isCurrentUser(String? userId, int generation) =>
      !_disposed && generation == _userGeneration && userId == _activeUserId;

  @override
  void dispose() {
    _disposed = true;
    _requestGeneration++;
    _userGeneration++;
    super.dispose();
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return ErrorMessages.fromApiException(e);
    }
    return ErrorMessages.unexpected;
  }
}

class _LocalFavoriteMutation {
  const _LocalFavoriteMutation({
    required this.generation,
    required this.dish,
    required this.shouldBeSaved,
  });

  final int generation;
  final Dish dish;
  final bool shouldBeSaved;
}

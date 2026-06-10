import 'package:flutter/foundation.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../local/cache_policy.dart';
import '../models/dish.dart';
import '../services/api_service.dart';

class DishRepository {
  DishRepository(this._apiService);

  final ApiService _apiService;

  List<Dish> _catalogCache = <Dish>[];
  DateTime? _catalogLoadedAt;
  Future<List<Dish>>? _catalogLoadFuture;

  bool get _hasCatalogCache => _catalogCache.isNotEmpty && _catalogLoadedAt != null;
  bool get _hasFreshCatalogCache {
    final DateTime? loadedAt = _catalogLoadedAt;
    return loadedAt != null &&
        DateTime.now().difference(loadedAt) < CachePolicy.catalogDishesTtl &&
        _catalogCache.isNotEmpty;
  }

  Future<List<Dish>> getDishes({String? cuisine}) async {
    final endpoint = cuisine == null
        ? ApiConstants.dishes
        : '${ApiConstants.dishes}?q=${Uri.encodeQueryComponent(cuisine)}';
    final data = await _apiService.get(endpoint);
    final List<dynamic> list = data is Map<String, dynamic>
        ? (data['dishes'] as List<dynamic>? ?? <dynamic>[])
        : <dynamic>[];

    return list
        .map((item) => Dish.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<Dish>> getCatalogDishes({bool force = false}) async {
    if (!force && _hasFreshCatalogCache) {
      final int age = DateTime.now().difference(_catalogLoadedAt!).inSeconds;
      AppLogger.info('[Cache] catalog hit count=${_catalogCache.length} age=${age}s');
      return List<Dish>.unmodifiable(_catalogCache);
    }

    final Future<List<Dish>>? inFlight = _catalogLoadFuture;
    if (inFlight != null) {
      AppLogger.info('[RequestDedup] catalog load skipped: already in flight');
      return inFlight;
    }

    AppLogger.info(force ? '[Cache] catalog force refresh' : '[Cache] catalog miss');
    _catalogLoadFuture = _loadCatalogFromApi();
    try {
      return await _catalogLoadFuture!;
    } catch (e) {
      if (_hasCatalogCache) {
        AppLogger.error('[Cache] catalog refresh failed; returning stale cache', e);
        return List<Dish>.unmodifiable(_catalogCache);
      }
      rethrow;
    } finally {
      _catalogLoadFuture = null;
    }
  }

  Future<List<Dish>> _loadCatalogFromApi() async {
    final data = await _apiService.get(ApiConstants.dishesCatalog);
    final List<dynamic> list = data is Map<String, dynamic>
        ? (data['dishes'] as List<dynamic>? ?? <dynamic>[])
        : <dynamic>[];

    final List<Dish> dishes = list
        .map((item) => Dish.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    _catalogCache = List<Dish>.from(dishes);
    _catalogLoadedAt = DateTime.now();
    debugPrint('[DishRepository] getCatalogDishes loaded ${dishes.length} dishes');
    return List<Dish>.unmodifiable(_catalogCache);
  }

  void invalidateCatalogCache({String reason = 'manual'}) {
    _catalogCache = <Dish>[];
    _catalogLoadedAt = null;
    _catalogLoadFuture = null;
    AppLogger.info('[Cache] catalog invalidated reason=$reason');
  }

  Future<List<Dish>> getMyCustomDishes() async {
    final data = await _apiService.get(ApiConstants.dishesMy);
    final List<dynamic> list = data is Map<String, dynamic>
        ? (data['dishes'] as List<dynamic>? ?? <dynamic>[])
        : <dynamic>[];

    return list
        .map((item) => Dish.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<String>> searchIngredients(String query) async {
    final String endpoint =
        '${ApiConstants.ingredientsSearch}?q=${Uri.encodeQueryComponent(query)}';
    final data = await _apiService.get(endpoint);
    final List<dynamic> list = data is Map<String, dynamic>
        ? (data['ingredients'] as List<dynamic>? ?? <dynamic>[])
        : <dynamic>[];

    return list.map((item) => item.toString()).toList();
  }

  Future<Dish> getDishById(String dishId) async {
    final data = await _apiService.get('${ApiConstants.dishes}/$dishId');
    if (data is Map<String, dynamic>) {
      final dynamic raw = data['dish'] ?? data;
      if (raw is Map<String, dynamic>) {
        return Dish.fromJson(raw);
      }
    }
    throw const FormatException('Unexpected dish response format.');
  }

  Future<Dish> createCustomDish({
    required String title,
    required String cuisine,
    required String mood,
    required List<Map<String, String>> ingredients,
    required int cookTime,
    required int servings,
    required List<String> instructions,
    required String imageUrl,
    String? imagePublicId,
  }) async {
    final data = await _apiService.post(ApiConstants.dishesCustom, {
      'name': title,
      'cuisine': cuisine,
      'mood': mood,
      'ingredients': ingredients,
      'cookTime': cookTime,
      'servings': servings.toString(),
      'steps': instructions
          .asMap()
          .entries
          .where((entry) => entry.value.trim().isNotEmpty)
          .map((entry) => <String, dynamic>{
                'step': entry.key + 1,
                'text': entry.value.trim(),
              })
          .toList(),
      if (imageUrl.trim().isNotEmpty) 'imageUrl': imageUrl,
      if (imagePublicId?.trim().isNotEmpty == true) 'imagePublicId': imagePublicId,
    });
    invalidateCatalogCache(reason: 'custom-dish-create');

    if (data is Map<String, dynamic>) {
      final dynamic raw = data['dish'] ?? data;
      if (raw is Map<String, dynamic>) {
        return Dish.fromJson(raw);
      }
    }

    throw const FormatException('Unexpected create dish response format.');
  }

  Future<void> deleteMyDish(String dishId) async {
    await _apiService.delete('${ApiConstants.dishes}/$dishId');
    invalidateCatalogCache(reason: 'custom-dish-delete');
  }

  Future<List<Dish>> getSavedDishes() async {
    final data = await _apiService.get(ApiConstants.usersSavedDishes);
    final List<dynamic> list = data is Map<String, dynamic>
        ? (data['dishes'] as List<dynamic>? ?? <dynamic>[])
        : <dynamic>[];

    return list
        .map((item) => Dish.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> saveDish(String dishId) async {
    await _apiService.post('${ApiConstants.usersSavedDishes}/$dishId', {});
  }

  Future<void> unsaveDish(String dishId) async {
    await _apiService.delete('${ApiConstants.usersSavedDishes}/$dishId');
  }
}

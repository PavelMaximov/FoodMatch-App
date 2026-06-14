import 'package:flutter/foundation.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../local/cache_policy.dart';
import '../models/dish.dart';
import '../services/api_service.dart';

class PaginatedDishesResult {
  const PaginatedDishesResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  final List<Dish> items;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;
}

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

  Future<PaginatedDishesResult> getDishesPage({
    int limit = 20,
    int offset = 0,
    String? search,
    String? cuisine,
    String? type,
    String? mealType,
    List<String>? mood,
    List<String>? diet,
    String? effort,
    bool? popular,
    String? source,
    List<String>? season,
    int? maxCookTime,
    int? maxTotalTime,
    String? timeTier,
    int? maxIngredients,
    int? minCalories,
    int? maxCalories,
    String? sort,
    bool force = false,
  }) async {
    final Map<String, String> query = <String, String>{
      'limit': limit.clamp(1, 50).toString(),
      'offset': offset.clamp(0, 1 << 31).toString(),
      if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
      if (cuisine?.trim().isNotEmpty == true) 'cuisine': cuisine!.trim(),
      if (type?.trim().isNotEmpty == true) 'type': type!.trim(),
      if (mealType?.trim().isNotEmpty == true) 'mealType': mealType!.trim(),
      if (mood != null && mood.where((String v) => v.trim().isNotEmpty).isNotEmpty)
        'mood': mood.where((String v) => v.trim().isNotEmpty).join(','),
      if (diet != null && diet.where((String v) => v.trim().isNotEmpty).isNotEmpty)
        'diet': diet.where((String v) => v.trim().isNotEmpty).join(','),
      if (effort?.trim().isNotEmpty == true) 'effort': effort!.trim(),
      if (popular != null) 'popular': popular.toString(),
      if (source?.trim().isNotEmpty == true) 'source': source!.trim(),
      if (season != null && season.where((String v) => v.trim().isNotEmpty).isNotEmpty)
        'season': season.where((String v) => v.trim().isNotEmpty).join(','),
      if (maxCookTime != null) 'maxCookTime': maxCookTime.toString(),
      if (maxTotalTime != null) 'maxTotalTime': maxTotalTime.toString(),
      if (timeTier?.trim().isNotEmpty == true) 'timeTier': timeTier!.trim(),
      if (maxIngredients != null) 'maxIngredients': maxIngredients.toString(),
      if (minCalories != null) 'minCalories': minCalories.toString(),
      if (maxCalories != null) 'maxCalories': maxCalories.toString(),
      if (sort?.trim().isNotEmpty == true) 'sort': sort!.trim(),
      if (force) '_refresh': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    final String endpoint = Uri(path: ApiConstants.dishes, queryParameters: query).toString();
    final data = await _apiService.get(endpoint);
    return _parsePaginatedDishes(data, fallbackLimit: limit, fallbackOffset: offset);
  }

  PaginatedDishesResult _parsePaginatedDishes(
    dynamic data, {
    required int fallbackLimit,
    required int fallbackOffset,
  }) {
    if (data is Map<String, dynamic>) {
      final dynamic rawItems = data['items'] ?? data['dishes'];
      final dynamic rawMeta = data['meta'];
      final Map<String, dynamic> meta = rawMeta is Map<String, dynamic> ? rawMeta : data;
      final List<dynamic> list = rawItems is List<dynamic> ? rawItems : <dynamic>[];
      final List<Dish> items = list
          .map((item) => Dish.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      final int limit = _readInt(meta['limit'], fallbackLimit);
      final int offset = _readInt(meta['offset'], fallbackOffset);
      final int total = _readInt(meta['total'], items.length);
      final bool hasMore = meta['hasMore'] is bool
          ? meta['hasMore'] as bool
          : offset + items.length < total;
      return PaginatedDishesResult(
        items: items,
        total: total,
        limit: limit,
        offset: offset,
        hasMore: hasMore,
      );
    }

    if (data is List<dynamic>) {
      final List<Dish> items = data
          .map((item) => Dish.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      return PaginatedDishesResult(
        items: items,
        total: items.length,
        limit: fallbackLimit,
        offset: fallbackOffset,
        hasMore: false,
      );
    }

    throw const FormatException('Unexpected paginated dishes response format.');
  }

  int _readInt(dynamic value, int fallback) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
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

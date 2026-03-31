import 'dart:convert';

import 'package:hive/hive.dart';

import '../../core/utils/logger.dart';
import '../models/dish.dart';
import '../models/recipe.dart';
import '../models/recipe_step.dart';
import 'cached_dish.dart';
import 'pending_swipe.dart';

class CacheService {
  static const Duration _cacheExpiry = Duration(hours: 24);

  Box<CachedDish> get _dishBox => Hive.box<CachedDish>('dishes');
  Box<PendingSwipe> get _swipeBox => Hive.box<PendingSwipe>('pending_swipes');
  Box<dynamic> get _appCache => Hive.box<dynamic>('app_cache');

  Future<void> cacheDishes(List<Dish> dishes) async {
    await _dishBox.clear();
    for (final Dish dish in dishes) {
      await _dishBox.put(dish.id, _dishToCache(dish));
    }
    AppLogger.info('CacheService: cached ${dishes.length} dishes');
  }

  List<Dish> getCachedDishes() {
    final List<CachedDish> cached = _dishBox.values.toList();

    if (cached.isNotEmpty) {
      final DateTime oldestAllowed = DateTime.now().subtract(_cacheExpiry);
      if (cached.first.cachedAt.isBefore(oldestAllowed)) {
        AppLogger.info('CacheService: dish cache expired');
        return <Dish>[];
      }
    }

    AppLogger.info('CacheService: returning ${cached.length} cached dishes');
    return cached.map(_cacheToDish).toList();
  }

  bool get hasCachedDishes => _dishBox.isNotEmpty;

  Future<void> queueSwipe(String dishId, String action) async {
    await _swipeBox.add(
      PendingSwipe(
        dishId: dishId,
        action: action,
        createdAt: DateTime.now(),
      ),
    );
    AppLogger.info('CacheService: queued swipe $action on $dishId');
  }

  List<PendingSwipe> getPendingSwipes() => _swipeBox.values.toList();

  Future<void> clearPendingSwipes() async {
    await _swipeBox.clear();
    AppLogger.info('CacheService: cleared pending swipes');
  }

  Future<void> removePendingSwipe(int index) => _swipeBox.deleteAt(index);

  int get pendingSwipeCount => _swipeBox.length;

  Future<void> cacheMatches(List<Dish> matches) async {
    final List<Map<String, dynamic>> json =
        matches.map((Dish dish) => dish.toJson()).toList();
    await _appCache.put('matches', jsonEncode(json));
    await _appCache.put('matches_cached_at', DateTime.now().toIso8601String());
    AppLogger.info('CacheService: cached ${matches.length} matches');
  }

  List<Dish> getCachedMatches() {
    final String? jsonStr = _appCache.get('matches') as String?;
    final String? cachedAt = _appCache.get('matches_cached_at') as String?;

    if (jsonStr == null || cachedAt == null) {
      return <Dish>[];
    }

    final Duration age = DateTime.now().difference(DateTime.parse(cachedAt));
    if (age > _cacheExpiry) {
      return <Dish>[];
    }

    try {
      final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((dynamic j) => Dish.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('CacheService: failed to parse cached matches', e);
      return <Dish>[];
    }
  }

  Future<void> cacheUserData({
    required String displayName,
    required String email,
    String? coupleId,
  }) async {
    await _appCache.put('user_displayName', displayName);
    await _appCache.put('user_email', email);
    await _appCache.put('user_coupleId', coupleId);
  }

  String? get cachedDisplayName => _appCache.get('user_displayName') as String?;

  String? get cachedEmail => _appCache.get('user_email') as String?;

  Future<void> clearAll() async {
    await _dishBox.clear();
    await _swipeBox.clear();
    await _appCache.clear();
    AppLogger.info('CacheService: cleared all cache');
  }

  CachedDish _dishToCache(Dish dish) {
    String? ingredientsJson;
    String? stepsJson;

    if (dish.recipe != null) {
      ingredientsJson = jsonEncode(dish.recipe!.ingredients);
      stepsJson = jsonEncode(
        dish.recipe!.steps
            .map(
              (RecipeStep step) => <String, String>{
                'title': step.title,
                'text': step.text,
              },
            )
            .toList(),
      );
    }

    return CachedDish(
      id: dish.id,
      title: dish.title,
      description: dish.description,
      imageUrl: dish.imageUrl,
      cuisine: dish.cuisine,
      tags: dish.tags,
      source: dish.source,
      externalId: dish.externalId,
      createdBy: dish.createdBy,
      recipeIngredientsJson: ingredientsJson,
      recipeStepsJson: stepsJson,
      cachedAt: DateTime.now(),
    );
  }

  Dish _cacheToDish(CachedDish cached) {
    Recipe? recipe;
    if (cached.recipeIngredientsJson != null) {
      final List<String> ingredients =
          (jsonDecode(cached.recipeIngredientsJson!) as List<dynamic>)
              .cast<String>();

      List<RecipeStep> steps = <RecipeStep>[];
      if (cached.recipeStepsJson != null) {
        steps = (jsonDecode(cached.recipeStepsJson!) as List<dynamic>)
            .map(
              (dynamic s) => RecipeStep(
                title: (s as Map<String, dynamic>)['title'] as String? ?? '',
                text: s['text'] as String? ?? '',
              ),
            )
            .toList();
      }

      recipe = Recipe(ingredients: ingredients, steps: steps);
    }

    return Dish(
      id: cached.id,
      title: cached.title,
      description: cached.description,
      imageUrl: cached.imageUrl,
      cuisine: cached.cuisine,
      tags: cached.tags,
      source: cached.source,
      externalId: cached.externalId,
      createdBy: cached.createdBy ?? '',
      recipe: recipe,
    );
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/logger.dart';
import '../models/dish.dart';

class CacheService {
  static const Duration _cacheExpiry = Duration(hours: 24);

  static const String _dishesKey = 'cached_dishes';
  static const String _dishesCachedAtKey = 'dishes_cached_at';
  static const String _matchesKey = 'cached_matches';
  static const String _matchesCachedAtKey = 'matches_cached_at';
  static const String _pendingSwipesKey = 'pending_swipes';
  static const String _userDisplayNameKey = 'user_displayName';
  static const String _userEmailKey = 'user_email';
  static const String _userCoupleIdKey = 'user_coupleId';

  Future<void> cacheDishes(List<Dish> dishes) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList =
        dishes.map((Dish d) => d.toJson()).toList();
    await prefs.setString(_dishesKey, jsonEncode(jsonList));
    await prefs.setString(_dishesCachedAtKey, DateTime.now().toIso8601String());
    AppLogger.info('CacheService: cached ${dishes.length} dishes');
  }

  Future<List<Dish>> getCachedDishes() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_dishesKey);
    final String? cachedAt = prefs.getString(_dishesCachedAtKey);

    if (jsonStr == null || cachedAt == null) {
      return <Dish>[];
    }

    final Duration age = DateTime.now().difference(DateTime.parse(cachedAt));
    if (age > _cacheExpiry) {
      AppLogger.info('CacheService: dish cache expired');
      return <Dish>[];
    }

    try {
      final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
      final List<Dish> dishes = list
          .map((dynamic j) => Dish.fromJson(j as Map<String, dynamic>))
          .toList();
      AppLogger.info('CacheService: returning ${dishes.length} cached dishes');
      return dishes;
    } catch (e) {
      AppLogger.error('CacheService: failed to parse cached dishes', e);
      return <Dish>[];
    }
  }

  Future<bool> hasCachedDishes() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_dishesKey);
  }

  Future<void> queueSwipe(String dishId, String action) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? existing = prefs.getString(_pendingSwipesKey);
    final List<Map<String, dynamic>> swipes = <Map<String, dynamic>>[];

    if (existing != null) {
      final List<dynamic> decoded = jsonDecode(existing) as List<dynamic>;
      swipes.addAll(
        decoded.map(
          (dynamic e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
        ),
      );
    }

    swipes.add(<String, dynamic>{
      'dishId': dishId,
      'action': action,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await prefs.setString(_pendingSwipesKey, jsonEncode(swipes));
    AppLogger.info('CacheService: queued swipe $action on $dishId');
  }

  Future<List<Map<String, dynamic>>> getPendingSwipes() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_pendingSwipesKey);
    if (jsonStr == null) {
      return <Map<String, dynamic>>[];
    }

    final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
    return decoded
        .map(
          (dynamic e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
        )
        .toList();
  }

  Future<void> clearPendingSwipes() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingSwipesKey);
    AppLogger.info('CacheService: cleared pending swipes');
  }

  Future<int> get pendingSwipeCount async {
    final List<Map<String, dynamic>> swipes = await getPendingSwipes();
    return swipes.length;
  }

  Future<void> cacheMatches(List<Dish> matches) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList =
        matches.map((Dish d) => d.toJson()).toList();
    await prefs.setString(_matchesKey, jsonEncode(jsonList));
    await prefs.setString(_matchesCachedAtKey, DateTime.now().toIso8601String());
    AppLogger.info('CacheService: cached ${matches.length} matches');
  }

  Future<List<Dish>> getCachedMatches() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_matchesKey);
    final String? cachedAt = prefs.getString(_matchesCachedAtKey);

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
      AppLogger.error('CacheService: failed to parse matches', e);
      return <Dish>[];
    }
  }

  Future<void> cacheUserData({
    required String displayName,
    required String email,
    String? coupleId,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userDisplayNameKey, displayName);
    await prefs.setString(_userEmailKey, email);
    if (coupleId != null) {
      await prefs.setString(_userCoupleIdKey, coupleId);
    } else {
      await prefs.remove(_userCoupleIdKey);
    }
  }

  Future<String?> get cachedDisplayName async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userDisplayNameKey);
  }

  Future<String?> get cachedEmail async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  Future<void> clearAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dishesKey);
    await prefs.remove(_dishesCachedAtKey);
    await prefs.remove(_matchesKey);
    await prefs.remove(_matchesCachedAtKey);
    await prefs.remove(_pendingSwipesKey);
    await prefs.remove(_userDisplayNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userCoupleIdKey);
    AppLogger.info('CacheService: cleared all cache');
  }
}

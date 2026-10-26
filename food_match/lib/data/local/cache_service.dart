import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/logger.dart';
import '../models/dish.dart';
import '../models/match_item.dart';

class CacheService {
  static const Duration _cacheExpiry = Duration(hours: 24);

  static const String _dishesKey = 'cached_dishes';
  static const String _dishesCachedAtKey = 'dishes_cached_at';
  static const String _matchSnapshotKey = 'cached_match_snapshot_v2';
  static const String _matchesKey = 'cached_matches';
  static const String _matchesCachedAtKey = 'matches_cached_at';
  static const String _matchesCoupleIdKey = 'matches_couple_id';
  static const String _pendingSwipesKey = 'pending_swipes';
  static const String _userDisplayNameKey = 'user_displayName';
  static const String _userEmailKey = 'user_email';
  static const String _userCoupleIdKey = 'user_coupleId';
  static const List<String> _authBoundaryRouteKeys = <String>[
    'lastRoute',
    'lastScreen',
    'lastSwipeMode',
    'activeSessionId',
    'currentDeckId',
    'preFilterDraft',
    'sessionResumeChoice',
    'currentTab',
    'swipesState',
    'pairWaitingState',
    'previous_filter_choice',
    'PreviousFilterChoiceScreen',
    'currentPreFilterStep',
    'activeFlow',
    'pendingPreviousChoice',
    'pendingPreSwipeFlow',
    'pendingHeaderFilterAction',
    'pendingPairConnectionReadyAction',
    'startupIntent',
  ];

  Future<void> cacheDishes(List<Dish> dishes) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = dishes
        .map((Dish d) => d.toJson())
        .toList();
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

    final timestamp = DateTime.tryParse(cachedAt);
    if (timestamp == null) return <Dish>[];
    final Duration age = DateTime.now().difference(timestamp);
    if (age.isNegative || age > _cacheExpiry) {
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

  static Future<void> _queueTail = Future<void>.value();

  Future<void> _mutateQueue(Future<void> Function() task) {
    final next = _queueTail.then((_) => task());
    _queueTail = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<void> queueSwipe(
    String dishId,
    String action, {
    required String userId,
    required String mode,
    required String sessionId,
  }) => _mutateQueue(() async {
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
      'id':
          '${DateTime.now().microsecondsSinceEpoch}:$userId:$sessionId:$dishId',
      'userId': userId,
      'mode': mode,
      'sessionId': sessionId,
      'dishId': dishId,
      'action': action,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await prefs.setString(_pendingSwipesKey, jsonEncode(swipes));
    AppLogger.info('CacheService: queued swipe $action on $dishId');
  });

  Future<void> acknowledgeSwipe(String id) => _mutateQueue(() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = await getPendingSwipes();
    pending.removeWhere((entry) => entry['id'] == id);
    await prefs.setString(_pendingSwipesKey, jsonEncode(pending));
  });

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

  Future<void> clearPendingSwipes() => _mutateQueue(() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingSwipesKey);
    AppLogger.info('CacheService: cleared pending swipes');
  });

  Future<int> get pendingSwipeCount async {
    final List<Map<String, dynamic>> swipes = await getPendingSwipes();
    return swipes.length;
  }

  static Future<void> _matchCacheTail = Future<void>.value();

  Future<T> _withMatchCache<T>(Future<T> Function() task) {
    final next = _matchCacheTail.then((_) => task());
    _matchCacheTail = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return next;
  }

  Future<void> cacheMatchItems(
    List<MatchItem> matches, {
    required String scopeKey,
  }) {
    // One envelope prevents a payload from being paired with another user's key.
    final snapshot = jsonEncode(<String, dynamic>{
      'scope': scopeKey,
      'cachedAt': DateTime.now().toIso8601String(),
      'items': matches.map((item) => item.toJson()).toList(),
    });
    return _withMatchCache(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_matchSnapshotKey, snapshot);
    });
  }

  Future<List<MatchItem>> getCachedMatchItems({required String scopeKey}) =>
      _withMatchCache(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final raw = prefs.getString(_matchSnapshotKey);
          if (raw == null) return <MatchItem>[];
          final snapshot = jsonDecode(raw) as Map<String, dynamic>;
          if (snapshot['scope'] != scopeKey) return <MatchItem>[];
          final cachedAt = DateTime.tryParse(
            snapshot['cachedAt'] as String? ?? '',
          );
          if (cachedAt == null) return <MatchItem>[];
          final age = DateTime.now().difference(cachedAt);
          if (age.isNegative || age > _cacheExpiry) return <MatchItem>[];
          return (snapshot['items'] as List<dynamic>)
              .map(
                (item) =>
                    MatchItem.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList();
        } catch (e) {
          AppLogger.error('CacheService: failed to read match snapshot', e);
          return <MatchItem>[];
        }
      });

  Future<void> clearCachedMatches() => _withMatchCache(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_matchSnapshotKey);
    // Remove the old dish-only cache; it cannot preserve match identity.
    await prefs.remove(_matchesKey);
    await prefs.remove(_matchesCachedAtKey);
    await prefs.remove(_matchesCoupleIdKey);
  });

  Future<void> cacheUserData({
    required String displayName,
    required String email,
    String? coupleId,
  }) => _withMatchCache(() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userDisplayNameKey, displayName);
    await prefs.setString(_userEmailKey, email);
    if (coupleId != null) {
      await prefs.setString(_userCoupleIdKey, coupleId);
    } else {
      await prefs.remove(_userCoupleIdKey);
    }
  });

  Future<void> _clearCachedUser() => _withMatchCache(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userDisplayNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userCoupleIdKey);
  });

  Future<String?> get cachedDisplayName async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userDisplayNameKey);
  }

  Future<String?> get cachedEmail async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  Future<void> clearAuthBoundaryTransient() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await clearCachedMatches();
    await clearPendingSwipes();
    await _clearCachedUser();
    for (final String key in _authBoundaryRouteKeys) {
      await prefs.remove(key);
    }
    AppLogger.info('CacheService: cleared auth-boundary transient cache');
  }

  Future<void> clearAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dishesKey);
    await prefs.remove(_dishesCachedAtKey);
    await clearCachedMatches();
    await clearPendingSwipes();
    await _clearCachedUser();
    AppLogger.info('CacheService: cleared all cache');
  }
}

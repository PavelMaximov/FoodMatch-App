import 'package:flutter/foundation.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/cache_service.dart';
import '../../../data/local/user_profile_hive_service.dart';
import '../../../data/models/dish.dart';
import '../../../data/models/prepared_deck.dart';
import '../../../data/repositories/dish_repository.dart';
import '../../../data/repositories/couple_repository.dart';
import '../../../data/repositories/swipe_repository.dart';
import '../../../data/services/api_service.dart';

class SwipeProvider extends ChangeNotifier {
  SwipeProvider({
    required DishRepository dishRepository,
    required SwipeRepository swipeRepository,
    required CoupleRepository coupleRepository,
    required UserProfileHiveService userProfileService,
    CacheService? cacheService,
  })  : _dishRepository = dishRepository,
        _swipeRepository = swipeRepository,
        _coupleRepository = coupleRepository,
        _cacheService = cacheService ?? CacheService(),
        _userProfileService = userProfileService;

  final DishRepository _dishRepository;
  final SwipeRepository _swipeRepository;
  final CoupleRepository _coupleRepository;
  final CacheService _cacheService;
  final UserProfileHiveService _userProfileService;

  final Set<String> _sentSwipeDishIds = <String>{};
  bool _isSendingSwipe = false;
  String? _activeUserId;
  bool _hasPreparedDeck = false;
  int _deckVersion = 0;
  PreparedDeckMeta? _preparedDeckMeta;

  List<Dish> deck = <Dish>[];
  int currentIndex = 0;
  bool isLoading = false;
  String? error;
  Dish? _lastSwipedDish;
  int? _lastSwipedIndex;
  Set<String> _seenDishIds = <String>{};

  Dish? get currentDish =>
      deck.isNotEmpty && currentIndex < deck.length ? deck[currentIndex] : null;
  bool get isDeckEmpty => currentIndex >= deck.length;
  Dish? get lastSwipedDish => _lastSwipedDish;
  bool get canUndo => _lastSwipedDish != null && _lastSwipedIndex != null;
  bool get hasPreparedDeck => _hasPreparedDeck;
  int get deckVersion => _deckVersion;
  PreparedDeckMeta? get preparedDeckMeta => _preparedDeckMeta;

  bool isSeenDish(String dishId) => _seenDishIds.contains(dishId);

  void setActiveUser(String? userId) {
    final String? normalized = userId?.trim().isEmpty == true ? null : userId?.trim();
    if (normalized == _activeUserId) {
      return;
    }
    _activeUserId = normalized;
    clearForLogout(notify: false);
  }

  void clearForLogout({bool notify = true}) {
    deck = <Dish>[];
    currentIndex = 0;
    isLoading = false;
    error = null;
    _lastSwipedDish = null;
    _lastSwipedIndex = null;
    _seenDishIds = <String>{};
    _sentSwipeDishIds.clear();
    _isSendingSwipe = false;
    _hasPreparedDeck = false;
    _preparedDeckMeta = null;
    _deckVersion++;
    if (notify) {
      notifyListeners();
    }
  }

  void applyPreparedDeck(
    List<Dish> prepared, {
    Set<String> seenDishIds = const <String>{},
    PreparedDeckMeta? preparedDeckMeta,
  }) {
    deck = prepared;
    _deckVersion++;
    _seenDishIds = Set<String>.from(seenDishIds);
    _hasPreparedDeck = true;
    _preparedDeckMeta = preparedDeckMeta;
    currentIndex = 0;
    _lastSwipedDish = null;
    _lastSwipedIndex = null;
    _sentSwipeDishIds.clear();
    _isSendingSwipe = false;
    error = deck.isEmpty ? AppStrings.noDishesAvailable : null;
    notifyListeners();
  }

  void applyBackendPreparedDeck(PreparedDeck preparedDeck) {
    debugPrint('[PreparedDeck] loaded existing deck final=${preparedDeck.meta.finalCount}');
    applyPreparedDeck(preparedDeck.dishes, preparedDeckMeta: preparedDeck.meta);
  }

  Future<bool> loadExistingPreparedDeck() async {
    try {
      final PreparedDeck preparedDeck = await _coupleRepository.getPreparedDeck();
      if (preparedDeck.isReady && preparedDeck.dishes.isNotEmpty) {
        applyBackendPreparedDeck(preparedDeck);
        return true;
      }
    } catch (e) {
      debugPrint('[PreparedDeck] load existing failed $e');
    }
    return false;
  }

  void clearPreparedDeck() {
    deck = <Dish>[];
    currentIndex = 0;
    _seenDishIds = <String>{};
    _sentSwipeDishIds.clear();
    _hasPreparedDeck = false;
    _preparedDeckMeta = null;
    _lastSwipedDish = null;
    _lastSwipedIndex = null;
    error = null;
    _deckVersion++;
    notifyListeners();
  }

  void clearPreparedDeckFlag() {
    _hasPreparedDeck = false;
    _preparedDeckMeta = null;
  }

  Future<void> loadDeck({String? cuisine}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      deck = await _dishRepository.getDishes(cuisine: cuisine);
      AppLogger.info('SwipeProvider: loaded ${deck.length} from backend');
      await _cacheService.cacheDishes(deck);
    } catch (e) {
      AppLogger.error('SwipeProvider: backend failed', e);
      deck = await _cacheService.getCachedDishes();
      if (deck.isNotEmpty) {
        AppLogger.info('SwipeProvider: loaded ${deck.length} from cache');
      } else {
        error = AppStrings.failedToLoadDishes;
      }
    }

    if (deck.isEmpty && error == null) {
      error = AppStrings.noDishesAvailable;
    }

    _seenDishIds = <String>{};
    _deckVersion++;
    _hasPreparedDeck = false;
    _preparedDeckMeta = null;
    currentIndex = 0;
    _lastSwipedDish = null;
    _lastSwipedIndex = null;
    _sentSwipeDishIds.clear();
    _isSendingSwipe = false;
    isLoading = false;
    notifyListeners();
  }

  Future<dynamic> swipe(String direction) async {
    final Dish? dish = currentDish;
    if (dish == null || _isSendingSwipe || _sentSwipeDishIds.contains(dish.id)) {
      return null;
    }

    _isSendingSwipe = true;
    _lastSwipedDish = dish;
    _lastSwipedIndex = currentIndex;

    dynamic result;
    try {
      result = await _swipeRepository.sendSwipe(
        dishId: dish.id,
        direction: direction,
      );
    } catch (e) {
      if (_shouldQueueOffline(e)) {
        AppLogger.info('SwipeProvider: queueing swipe offline');
        try {
          await _cacheService.queueSwipe(dish.id, direction);
          await _applyLocalPostSwipe(dish, direction, null);
        } finally {
          _isSendingSwipe = false;
        }
        return null;
      }

      AppLogger.error('SwipeProvider: swipe rejected', e);
      error = _mapSwipeError(e);
      notifyListeners();
      _isSendingSwipe = false;
      return null;
    }

    try {
      await _applyLocalPostSwipe(dish, direction, result);
    } catch (e) {
      AppLogger.error('SwipeProvider: local post-swipe update failed after backend success', e);
      notifyListeners();
    } finally {
      _isSendingSwipe = false;
    }
    return result;
  }

  Future<void> _applyLocalPostSwipe(Dish dish, String direction, dynamic result) async {
    _sentSwipeDishIds.add(dish.id);
    currentIndex++;
    await _persistLearning(dish, direction, result);
    await _cleanupSessionChoicesIfDone();
    notifyListeners();
  }

  void undo() {
    if (!canUndo) {
      return;
    }

    currentIndex = _lastSwipedIndex!;
    if (_lastSwipedDish != null) {
      _sentSwipeDishIds.remove(_lastSwipedDish!.id);
    }
    _lastSwipedDish = null;
    _lastSwipedIndex = null;
    AppLogger.info('SwipeProvider: undo swipe, back to index $currentIndex');
    notifyListeners();
  }

  Future<void> syncPendingSwipes() async {
    final List<Map<String, dynamic>> pending = await _cacheService.getPendingSwipes();
    if (pending.isEmpty) {
      return;
    }

    AppLogger.info('SwipeProvider: syncing ${pending.length} pending swipes');
    int synced = 0;

    for (int i = 0; i < pending.length; i++) {
      try {
        await _swipeRepository.sendSwipe(
          dishId: pending[i]['dishId'] as String,
          direction: pending[i]['action'] as String,
        );
        synced++;
      } catch (e) {
        AppLogger.error('SwipeProvider: sync failed for swipe $i', e);
        break;
      }
    }

    if (synced > 0) {
      await _cacheService.clearPendingSwipes();
      AppLogger.info('SwipeProvider: synced $synced swipes');
    }
  }

  Future<dynamic> like() => swipe('like');

  Future<dynamic> dislike() => swipe('dislike');

  String _mapSwipeError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return AppStrings.unexpectedError;
  }

  bool _shouldQueueOffline(Object error) {
    if (error is! ApiException) {
      return false;
    }

    final int? statusCode = error.statusCode;
    return statusCode == null || statusCode >= 500;
  }

  Future<void> _persistLearning(Dish dish, String direction, dynamic result) async {
    final String? userId = _activeUserId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    await _userProfileService.recordSwipe(
      userId: userId,
      dishId: dish.id,
      direction: direction,
      cuisine: dish.cuisine,
    );

    final bool matched = result is Map<String, dynamic> && result['swipe']?['matchCreated'] == true;
    if (matched) {
      await _userProfileService.recordMatch(userId: userId, dishId: dish.id);
      _seenDishIds.add(dish.id);
    }
  }

  Future<void> _cleanupSessionChoicesIfDone() async {
    if (!isDeckEmpty || !_hasPreparedDeck) {
      return;
    }
    final String? userId = _activeUserId;
    if (userId != null && userId.isNotEmpty) {
      await _userProfileService.clearSessionChoices(userId);
    }
    _hasPreparedDeck = false;
  }
}

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/errors/error_messages.dart';
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
  String currentSwipeMode = 'paired';
  String? activeSoloSessionId;
  int _soloLikedCount = 0;
  int _soloRemainingCount = 0;
  bool _soloSessionCompleted = false;
  int _deckVersion = 0;
  PreparedDeckMeta? _preparedDeckMeta;
  Future<bool>? _existingPreparedDeckLoadFuture;
  bool _isApplyingSoloFilterRequest = false;
  int _authBoundaryVersion = -1;

  List<Dish> deck = <Dish>[];
  int currentIndex = 0;
  bool isLoading = false;
  String? error;
  Dish? _lastSwipedDish;
  int? _lastSwipedIndex;
  String? _lastSwipedDirection;
  Set<String> _seenDishIds = <String>{};

  Dish? get currentDish =>
      deck.isNotEmpty && currentIndex < deck.length ? deck[currentIndex] : null;
  bool get isDeckEmpty => currentIndex >= deck.length;
  Dish? get lastSwipedDish => _lastSwipedDish;
  String? get lastSwipedDirection => _lastSwipedDirection;
  bool get canUndo => _lastSwipedDish != null && _lastSwipedIndex != null && !_isSendingSwipe;
  bool get hasPreparedDeck => _hasPreparedDeck;
  int get deckVersion => _deckVersion;
  PreparedDeckMeta? get preparedDeckMeta => _preparedDeckMeta;
  bool get isSendingSwipe => _isSendingSwipe;
  bool get isSoloMode => currentSwipeMode == 'solo';
  bool get hasActiveSoloSession => activeSoloSessionId != null && !_soloSessionCompleted;
  bool get isSoloSessionCompleted => isSoloMode && _soloSessionCompleted;
  int get soloLikedCount => _soloLikedCount;
  int get remainingDishCount => isSoloMode
      ? _soloRemainingCount
      : (deck.length > currentIndex ? deck.length - currentIndex : 0);

  bool isSeenDish(String dishId) => _seenDishIds.contains(dishId);

  void setDeckError(String message) {
    error = message;
    isLoading = false;
    notifyListeners();
  }

  void clearDeckError({bool notify = true}) {
    error = null;
    if (notify) notifyListeners();
  }


  void setActiveUser(String? userId) {
    final String? normalized = userId?.trim().isEmpty == true ? null : userId?.trim();
    if (normalized == _activeUserId) {
      return;
    }
    _activeUserId = normalized;
    clearForLogout(notify: false);
  }

  void resetForAuthBoundary({bool notify = true}) {
    clearForLogout(notify: notify);
  }

  void handleAuthBoundary(int version) {
    if (_authBoundaryVersion == version) {
      return;
    }
    _authBoundaryVersion = version;
    resetForAuthBoundary(notify: false);
  }

  void clearForLogout({bool notify = true}) {
    deck = <Dish>[];
    currentIndex = 0;
    isLoading = false;
    error = null;
    _lastSwipedDish = null;
    _lastSwipedIndex = null;
    _lastSwipedDirection = null;
    _seenDishIds = <String>{};
    if (isSoloMode) {
      _soloRemainingCount = 0;
    }
    _sentSwipeDishIds.clear();
    _isSendingSwipe = false;
    _hasPreparedDeck = false;
    currentSwipeMode = 'paired';
    activeSoloSessionId = null;
    _soloLikedCount = 0;
    _soloRemainingCount = 0;
    _soloSessionCompleted = false;
    _preparedDeckMeta = null;
    _existingPreparedDeckLoadFuture = null;
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
    deck = List<Dish>.from(prepared);
    _deckVersion++;
    _seenDishIds = Set<String>.from(seenDishIds);
    _hasPreparedDeck = true;
    _preparedDeckMeta = preparedDeckMeta;
    currentIndex = 0;
    _lastSwipedDish = null;
    _lastSwipedIndex = null;
    _lastSwipedDirection = null;
    _sentSwipeDishIds.clear();
    _isSendingSwipe = false;
    error = deck.isEmpty ? AppStrings.noDishesAvailable : null;
    if (isSoloMode) {
      _soloSessionCompleted = false;
      _soloRemainingCount = deck.length > currentIndex ? deck.length - currentIndex : 0;
    }
    notifyListeners();
  }

  void applyBackendPreparedDeck(PreparedDeck preparedDeck) {
    debugPrint('[PreparedDeck] loaded existing deck final=${preparedDeck.meta.finalCount}');
    currentSwipeMode = 'paired';
    activeSoloSessionId = null;
    _soloLikedCount = 0;
    _soloRemainingCount = 0;
    _soloSessionCompleted = false;
    applyPreparedDeck(preparedDeck.dishes, preparedDeckMeta: preparedDeck.meta);
  }

  void setPairedMode() {
    currentSwipeMode = 'paired';
    activeSoloSessionId = null;
    _soloLikedCount = 0;
    _soloRemainingCount = 0;
    _soloSessionCompleted = false;
    notifyListeners();
  }

  void resetToModeSelection({bool notify = true}) {
    deck = <Dish>[];
    currentIndex = 0;
    isLoading = false;
    error = null;
    _lastSwipedDish = null;
    _lastSwipedIndex = null;
    _lastSwipedDirection = null;
    _seenDishIds = <String>{};
    _sentSwipeDishIds.clear();
    _isSendingSwipe = false;
    _hasPreparedDeck = false;
    currentSwipeMode = 'paired';
    activeSoloSessionId = null;
    _soloLikedCount = 0;
    _soloRemainingCount = 0;
    _soloSessionCompleted = false;
    _preparedDeckMeta = null;
    _existingPreparedDeckLoadFuture = null;
    _deckVersion++;
    if (notify) {
      notifyListeners();
    }
  }

  Future<bool> loadActiveSoloSession() async {
    try {
      final dynamic data = await _swipeRepository.getActiveSoloSession();
      final dynamic session = data is Map<String, dynamic> ? data['session'] : null;
      if (session is Map<String, dynamic>) {
        _applySoloSession(session);
        return true;
      }
    } catch (e) {
      debugPrint('[SoloSwipe] active load failed $e');
    }
    return false;
  }

  Future<bool> createSoloSession({required List<String> dishRegisters, required List<String> cuisines, required List<String> moods, required List<String> blocked, required List<String> diet}) async {
    if (_isApplyingSoloFilterRequest) {
      return false;
    }
    if (activeSoloSessionId != null && !_soloSessionCompleted) {
      return rebuildActiveSoloSessionFilters(dishRegisters: dishRegisters, cuisines: cuisines, moods: moods, blocked: blocked, diet: diet);
    }
    _isApplyingSoloFilterRequest = true;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      return await _createSoloSessionRequest(dishRegisters: dishRegisters, cuisines: cuisines, moods: moods, blocked: blocked, diet: diet);
    } on ApiException catch (e) {
      final bool activeSessionConflict = e.statusCode == 409 && e.message.toLowerCase().contains('active');
      if (activeSessionConflict) {
        final bool loadedActiveSolo = await _loadActiveSoloSessionRequest();
        if (loadedActiveSolo && activeSoloSessionId != null) {
          return await _rebuildActiveSoloSessionRequest(dishRegisters: dishRegisters, cuisines: cuisines, moods: moods, blocked: blocked, diet: diet);
        }
      }
      error = _mapSwipeError(e);
    } catch (e) {
      error = _mapSwipeError(e);
    } finally {
      _isApplyingSoloFilterRequest = false;
      isLoading = false;
      notifyListeners();
    }
    return false;
  }


  Future<bool> rebuildActiveSoloSessionFilters({required List<String> dishRegisters, required List<String> cuisines, required List<String> moods, required List<String> blocked, required List<String> diet}) async {
    if (_isApplyingSoloFilterRequest) {
      return false;
    }
    _isApplyingSoloFilterRequest = true;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      return await _rebuildActiveSoloSessionRequest(dishRegisters: dishRegisters, cuisines: cuisines, moods: moods, blocked: blocked, diet: diet);
    } catch (e) {
      error = _mapSwipeError(e);
    } finally {
      _isApplyingSoloFilterRequest = false;
      isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> _createSoloSessionRequest({required List<String> dishRegisters, required List<String> cuisines, required List<String> moods, required List<String> blocked, required List<String> diet}) async {
    final dynamic data = await _swipeRepository.createSoloSession(filter: _soloFilterPayload(dishRegisters: dishRegisters, cuisines: cuisines, moods: moods, blocked: blocked, diet: diet));
    return _applySoloSessionFromResponse(data);
  }

  Future<bool> _rebuildActiveSoloSessionRequest({required List<String> dishRegisters, required List<String> cuisines, required List<String> moods, required List<String> blocked, required List<String> diet}) async {
    final dynamic data = await _swipeRepository.updateActiveSoloFilter(filter: _soloFilterPayload(dishRegisters: dishRegisters, cuisines: cuisines, moods: moods, blocked: blocked, diet: diet));
    return _applySoloSessionFromResponse(data);
  }

  Future<bool> _loadActiveSoloSessionRequest() async {
    final dynamic data = await _swipeRepository.getActiveSoloSession();
    return _applySoloSessionFromResponse(data);
  }

  Map<String, dynamic> _soloFilterPayload({required List<String> dishRegisters, required List<String> cuisines, required List<String> moods, required List<String> blocked, required List<String> diet}) =>
      <String, dynamic>{'dishRegisters': dishRegisters, 'cuisines': cuisines, 'moods': moods, 'exclusions': blocked, 'diet': diet};

  bool _applySoloSessionFromResponse(dynamic data) {
    final dynamic session = data is Map<String, dynamic> ? data['session'] : null;
    if (session is Map<String, dynamic>) {
      _applySoloSession(session);
      return true;
    }
    return false;
  }

  Future<bool> updateActiveSoloFilter({required List<String> dishRegisters, required List<String> cuisines, required List<String> moods, required List<String> blocked, required List<String> diet}) async {
    if (activeSoloSessionId == null || _soloSessionCompleted) {
      return createSoloSession(dishRegisters: dishRegisters, cuisines: cuisines, moods: moods, blocked: blocked, diet: diet);
    }
    return rebuildActiveSoloSessionFilters(dishRegisters: dishRegisters, cuisines: cuisines, moods: moods, blocked: blocked, diet: diet);
  }

  Future<void> abandonActiveSoloSession() async {
    if (activeSoloSessionId == null) {
      clearPreparedDeck();
      currentSwipeMode = 'paired';
      _soloLikedCount = 0;
      _soloRemainingCount = 0;
      _soloSessionCompleted = false;
      notifyListeners();
      return;
    }
    await _swipeRepository.abandonActiveSoloSession();
    clearPreparedDeck();
    currentSwipeMode = 'paired';
    activeSoloSessionId = null;
    _soloLikedCount = 0;
    _soloRemainingCount = 0;
    _soloSessionCompleted = false;
    notifyListeners();
  }


  void _applySoloSession(Map<String, dynamic> session) {
    activeSoloSessionId = session['sessionId']?.toString();
    currentSwipeMode = 'solo';
    _soloSessionCompleted = false;
    _seenDishIds = <String>{};
    _soloLikedCount = _readInt(session['matchedCount']);
    final List<dynamic> rawDishes = session['dishes'] as List<dynamic>? ?? <dynamic>[];
    final List<Dish> sessionDeck = rawDishes
        .whereType<Map>()
        .map((Map item) => Dish.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    _soloRemainingCount = sessionDeck.length;
    applyPreparedDeck(
      sessionDeck,
      preparedDeckMeta: PreparedDeckMeta.fromJson(
        Map<String, dynamic>.from(session['meta'] as Map? ?? <String, dynamic>{}),
      ),
    );
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<bool> loadExistingPreparedDeck({bool force = false}) {
    if (!force && _hasPreparedDeck && deck.isNotEmpty) {
      debugPrint('[Cache] prepared deck hit count=${deck.length}');
      return Future<bool>.value(true);
    }
    final Future<bool>? inFlight = _existingPreparedDeckLoadFuture;
    if (inFlight != null) {
      debugPrint('[RequestDedup] prepared deck load skipped: already in flight');
      return inFlight;
    }

    _existingPreparedDeckLoadFuture = _loadExistingPreparedDeckFromApi();
    return _existingPreparedDeckLoadFuture!;
  }

  Future<bool> _loadExistingPreparedDeckFromApi() async {
    try {
      debugPrint('[Cache] prepared deck miss');
      final PreparedDeck preparedDeck = await _coupleRepository.getPreparedDeck();
      if (preparedDeck.isReady && preparedDeck.dishes.isNotEmpty) {
        applyBackendPreparedDeck(preparedDeck);
        return true;
      }
      debugPrint('[Cache] prepared deck not ready; cache not used');
    } catch (e) {
      debugPrint('[PreparedDeck] load existing failed $e');
    } finally {
      _existingPreparedDeckLoadFuture = null;
    }
    return false;
  }

  void clearPreparedDeck() {
    debugPrint('[Deck] local deck cleared');
    deck = <Dish>[];
    currentIndex = 0;
    _seenDishIds = <String>{};
    if (isSoloMode) {
      _soloRemainingCount = 0;
    }
    _sentSwipeDishIds.clear();
    _hasPreparedDeck = false;
    _preparedDeckMeta = null;
    _existingPreparedDeckLoadFuture = null;
    _lastSwipedDish = null;
    _lastSwipedIndex = null;
    _lastSwipedDirection = null;
    error = null;
    _deckVersion++;
    notifyListeners();
  }

  void clearPreparedDeckFlag() {
    _hasPreparedDeck = false;
    _preparedDeckMeta = null;
    _existingPreparedDeckLoadFuture = null;
  }

  Future<void> loadDeck({String? cuisine}) async {
    if (!isSoloMode) {
      AppLogger.info('[PairDeck] blocked generic loadDeck in Pair mode');
      setDeckError('Could not load the shared deck. Please try again.');
      return;
    }
    if (isLoading) {
      AppLogger.info('[RequestDedup] swipe deck load skipped: already in flight');
      return;
    }
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
    _existingPreparedDeckLoadFuture = null;
    currentIndex = 0;
    _lastSwipedDish = null;
    _lastSwipedIndex = null;
    _lastSwipedDirection = null;
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
    error = null;
    notifyListeners();
    _lastSwipedDish = dish;
    _lastSwipedIndex = currentIndex;
    _lastSwipedDirection = null;

    dynamic result;
    try {
      result = await _swipeRepository.sendSwipe(
        dishId: dish.id,
        direction: direction,
        soloSessionId: activeSoloSessionId,
      );
    } catch (e) {
      if (_shouldQueueOffline(e)) {
        AppLogger.info('SwipeProvider: queueing swipe offline');
        try {
          await _cacheService.queueSwipe(dish.id, direction);
          await _applyLocalPostSwipe(dish, direction, null);
        } finally {
          _isSendingSwipe = false;
          notifyListeners();
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
      notifyListeners();
    }
    return result;
  }

  Future<void> _applyLocalPostSwipe(Dish dish, String direction, dynamic result) async {
    final bool wasSoloSwipe = isSoloMode && activeSoloSessionId != null;
    _lastSwipedDirection = direction;
    _sentSwipeDishIds.add(dish.id);
    currentIndex++;
    if (wasSoloSwipe) {
      _soloRemainingCount = deck.length > currentIndex ? deck.length - currentIndex : 0;
    }
    await _persistLearning(dish, direction, result);
    if (wasSoloSwipe && direction == 'like' && result is Map<String, dynamic> && result['swipe']?['matchCreated'] == true) {
      _soloLikedCount++;
    }
    await _cleanupSessionChoicesIfDone();
    notifyListeners();
  }

  Future<void> undo() async {
    if (!canUndo) {
      return;
    }
    debugPrint('[Undo] requested mode=$currentSwipeMode hasSession=${activeSoloSessionId != null} currentIndex=$currentIndex');
    if (isSoloMode && activeSoloSessionId != null) {
      _isSendingSwipe = true;
      notifyListeners();
      try {
        final dynamic data = await _swipeRepository.undoSoloSwipe(activeSoloSessionId!);
        final dynamic session = data is Map<String, dynamic> ? data['session'] : null;
        if (session is! Map<String, dynamic>) {
          throw const FormatException('Unexpected solo undo response.');
        }
        _applySoloSession(session);
        final String currentDishId = currentDish?.id ?? 'none';
        debugPrint('[Undo] backend undo success currentIndex=$currentIndex currentDish=$currentDishId');
      } on ApiException catch (e) {
        debugPrint('[Undo] backend undo failed code=${e.code ?? e.statusCode}');
        error = _mapSwipeError(e);
      } catch (e) {
        debugPrint('[Undo] backend undo failed code=unknown');
        error = _mapSwipeError(e);
      } finally {
        _isSendingSwipe = false;
        notifyListeners();
      }
      return;
    }
    currentIndex = _lastSwipedIndex!;
    if (_lastSwipedDish != null) {
      _sentSwipeDishIds.remove(_lastSwipedDish!.id);
    }
    _lastSwipedDish = null;
    _lastSwipedIndex = null;
    _lastSwipedDirection = null;
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
      return ErrorMessages.fromApiException(error, fallback: ErrorMessages.swipeFailed);
    }
    return ErrorMessages.swipeFailed;
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
    if (currentSwipeMode == 'solo') {
      _soloSessionCompleted = true;
      _soloRemainingCount = 0;
    }
  }
}

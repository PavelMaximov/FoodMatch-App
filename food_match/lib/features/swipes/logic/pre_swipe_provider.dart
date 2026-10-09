import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/error_messages.dart';

import '../../../data/local/user_profile_hive_service.dart';
import '../../../data/models/couple_filter_state.dart';
import '../../../data/models/dish.dart';
import '../../../data/models/filter_config.dart';
import '../../../data/models/prepared_deck.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/dish_repository.dart';
import '../../../data/repositories/couple_repository.dart';
import '../../../data/services/api_service.dart';
import '../../couple/logic/couple_provider.dart';
import 'filter_scoring_service.dart';

enum PreparedDeckStatus { success, cancelled, failed }

class PreparedPoolResult {
  const PreparedPoolResult({
    required this.dishes,
    required this.seenDishIds,
    required this.usedFallback,
    required this.relaxed,
    required this.messages,
    this.config,
    this.preparedDeckMeta,
    this.status = PreparedDeckStatus.success,
    this.operationGeneration = -1,
  });

  const PreparedPoolResult.cancelled({required this.operationGeneration})
    : status = PreparedDeckStatus.cancelled,
      dishes = const <Dish>[],
      seenDishIds = const <String>{},
      usedFallback = false,
      relaxed = false,
      messages = const <String>[],
      config = null,
      preparedDeckMeta = null;

  final List<Dish> dishes;
  final Set<String> seenDishIds;
  final bool usedFallback;
  final bool relaxed;
  final List<String> messages;
  final FilterConfig? config;
  final PreparedDeckMeta? preparedDeckMeta;
  final PreparedDeckStatus status;
  final int operationGeneration;

  bool get isSuccess => status == PreparedDeckStatus.success;
}

class FilterAvailabilitySummary {
  const FilterAvailabilitySummary({
    required this.totalCount,
    required this.availableCount,
    required this.usesPartnerChoices,
    required this.usedCuisineUnionFallback,
    required this.wouldWidenSearch,
  });

  final int totalCount;
  final int availableCount;
  final bool usesPartnerChoices;
  final bool usedCuisineUnionFallback;
  final bool wouldWidenSearch;

  double get progress {
    if (totalCount <= 0) {
      return 0;
    }
    return (availableCount / totalCount).clamp(0, 1).toDouble();
  }

  String get helperText {
    if (totalCount <= 0) {
      return 'Loading dish catalog...';
    }
    if (usedCuisineUnionFallback) {
      return 'No common cuisine — showing both preferences.';
    }
    if (wouldWidenSearch && availableCount > 0) {
      return 'We widened the search a bit so you still have dishes to swipe.';
    }
    if (availableCount == 0) {
      return 'No dishes found yet. Try removing one filter.';
    }
    if (availableCount <= 10) {
      return 'Very narrow choice. We may widen the search.';
    }
    if (availableCount <= 40) {
      return 'Good match range.';
    }
    return 'Many options available.';
  }
}

class PreSwipeProvider extends ChangeNotifier {
  PreSwipeProvider({
    required DishRepository dishRepository,
    required CoupleRepository coupleRepository,
    required UserProfileHiveService profileService,
    required FilterScoringService scoringService,
  }) : _dishRepository = dishRepository,
       _coupleRepository = coupleRepository,
       _profileService = profileService,
       _scoringService = scoringService;

  final DishRepository _dishRepository;
  final CoupleRepository _coupleRepository;
  final UserProfileHiveService _profileService;
  final FilterScoringService _scoringService;

  bool isPreparingBackendDeck = false;
  int _authBoundaryVersion = -1;
  PreparedDeckMeta? preparedDeckMeta;
  String? backendDeckError;
  Future<PreparedPoolResult>? _canonicalPrepareFuture;
  PreparedPoolResult? _canonicalPreparedResult;
  int _prepareGeneration = 0;
  bool _disposed = false;

  int get operationGeneration => _prepareGeneration;

  Future<UserProfile> loadProfile(String userId) =>
      _profileService.getProfile(userId);

  Future<void> markIntroSeen(String userId) =>
      _profileService.markPreSwipeFilterIntroSeen(userId);

  Future<void> saveLastFilterPreset({
    required String userId,
    required List<String> dishRegisters,
    required bool includeCustomDishesFirst,
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
    required List<String> diet,
    required int matchedLastTime,
  }) => _profileService.saveLastFilterPreset(
    userId,
    dishRegisters: dishRegisters,
    includeCustomDishesFirst: includeCustomDishesFirst,
    cuisines: cuisines,
    moods: moods,
    diet: diet,
    exclusions: blocked,
    matchedLastTime: matchedLastTime,
  );

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
    _clearLocalDraftState(notify: notify, forceNotify: false);
  }

  void clearDraft({bool notify = true}) {
    _clearLocalDraftState(notify: notify, forceNotify: true);
  }

  void _clearLocalDraftState({
    required bool notify,
    required bool forceNotify,
  }) {
    final bool changed =
        isPreparingBackendDeck ||
        preparedDeckMeta != null ||
        backendDeckError != null ||
        _canonicalPreparedResult != null ||
        _canonicalPrepareFuture != null;
    _prepareGeneration++;
    isPreparingBackendDeck = false;
    preparedDeckMeta = null;
    backendDeckError = null;
    _canonicalPreparedResult = null;
    _canonicalPrepareFuture = null;
    if (notify && (changed || forceNotify)) {
      notifyListeners();
    }
  }

  Future<List<Dish>> loadDishes() async {
    final List<Dish> catalog = await _dishRepository.getCatalogDishes();
    try {
      final List<Dish> custom = await _dishRepository.getMyCustomDishes();
      final Map<String, Dish> available = <String, Dish>{
        for (final Dish dish in catalog) dish.id: dish,
        for (final Dish dish in custom) dish.id: dish,
      };
      return available.values.toList(growable: false);
    } catch (error) {
      debugPrint('[PreSwipeProvider] custom dish availability failed: $error');
      return catalog;
    }
  }

  Future<List<String>> loadCuisineOptions() async {
    final List<Dish> dishes = await _dishRepository.getCatalogDishes();
    final Set<String> normalized = dishes
        .map((Dish dish) => _normalizeCuisine(dish.cuisine))
        .where((String cuisine) => cuisine.isNotEmpty)
        .toSet();
    final int cuisineCountTotal = _scoringService
        .getCuisineChipCounts(dishes)
        .values
        .fold<int>(0, (int sum, int count) => sum + count);
    debugPrint(
      '[PreSwipeProvider] full catalog dishes=${dishes.length}, '
      'cuisine chip count total=$cuisineCountTotal',
    );
    final List<String> options = normalized.toList()..sort();
    return <String>['Any', ...options];
  }

  Future<void> saveAndConfirmChoices({
    required String userId,
    required CoupleProvider coupleProvider,
    required List<String> dishRegisters,
    required bool includeCustomDishesFirst,
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
    required List<String> diet,
    int? maxCookTime,
    List<String> calories = const <String>[],
    List<String> effort = const <String>[],
    List<String> ingredients = const <String>[],
    List<String> season = const <String>[],
    bool Function()? isCurrent,
  }) async {
    _invalidateCanonicalPreparation();
    final generation = _prepareGeneration;
    await _profileService.saveSessionChoices(
      userId,
      cuisines: cuisines,
      moods: moods,
      blocked: blocked,
    );
    if (!_isCurrentPreparation(generation) || isCurrent?.call() == false) {
      return;
    }
    await coupleProvider.saveAndConfirmMyChoices(
      dishRegisters: dishRegisters,
      includeCustomDishesFirst: includeCustomDishesFirst,
      cuisines: cuisines,
      moods: moods,
      diet: diet,
      exclusions: blocked,
      maxCookTime: maxCookTime,
      calories: calories,
      effort: effort,
      ingredients: ingredients,
      season: season,
    );
  }

  Future<PreparedPoolResult> preparePairDeckWithRetry({
    required bool Function() isCurrent,
    List<Duration> delays = const <Duration>[
      Duration.zero,
      Duration(milliseconds: 700),
      Duration(milliseconds: 1200),
      Duration(seconds: 2),
      Duration(seconds: 3),
      Duration(seconds: 4),
      Duration(seconds: 5),
    ],
  }) async {
    int generation = _prepareGeneration;
    Object? lastError;
    bool current() => isCurrent() && _isCurrentPreparation(generation);
    for (final delay in delays) {
      if (!current()) return _cancelledPreparation(generation);
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (!current()) return _cancelledPreparation(generation);
      try {
        final request = prepareCanonicalPairDeck();
        generation = _prepareGeneration;
        final result = await request;
        if (!current() ||
            result.status == PreparedDeckStatus.cancelled ||
            result.operationGeneration != generation) {
          return _cancelledPreparation(generation);
        }
        if (result.dishes.isNotEmpty) return result;
        lastError = StateError('Prepared deck is not ready');
      } catch (error) {
        if (!current()) return _cancelledPreparation(generation);
        if (error is ApiException &&
            const <String>{
              'PAIR_WAITING_FOR_PARTNER_FILTERS',
              'PAIR_SESSION_NEEDS_RESYNC',
              'PAIR_SESSION_INACTIVE',
            }.contains(error.code)) {
          rethrow;
        }
        lastError = error;
      }
    }
    throw lastError ?? StateError('Shared deck preparation timed out');
  }

  Future<PreparedPoolResult> prepareCanonicalPairDeck() {
    if (_disposed) {
      return Future<PreparedPoolResult>.value(
        _cancelledPreparation(_prepareGeneration),
      );
    }
    final PreparedPoolResult? ready = _canonicalPreparedResult;
    if (ready != null && ready.dishes.isNotEmpty) {
      return Future<PreparedPoolResult>.value(ready);
    }
    final Future<PreparedPoolResult>? inFlight = _canonicalPrepareFuture;
    if (inFlight != null) {
      debugPrint(
        '[RequestDedup] canonical pair deck prepare joined existing future',
      );
      return inFlight;
    }
    final int generation = ++_prepareGeneration;
    // Publish the future before notifying listeners, which may join this request.
    final completer = Completer<PreparedPoolResult>();
    _canonicalPrepareFuture = completer.future;
    completer.complete(_prepareCanonicalPairDeck(generation));
    return completer.future;
  }

  Future<PreparedPoolResult> _prepareCanonicalPairDeck(int generation) async {
    isPreparingBackendDeck = true;
    backendDeckError = null;
    notifyListeners();
    if (!_isCurrentPreparation(generation)) {
      return _cancelledPreparation(generation);
    }
    debugPrint('[PairDeck] canonical prepare started');

    try {
      final PreparedDeck backendDeck = await _coupleRepository.prepareDeck();
      if (!_isCurrentPreparation(generation)) {
        return _cancelledPreparation(generation);
      }
      preparedDeckMeta = backendDeck.meta;
      debugPrint(
        '[PairDeck] canonical prepare success final=${backendDeck.meta.finalCount}',
      );
      final List<String> messages = <String>[];
      final String? fallbackReason = backendDeck.meta.fallbackReason;
      if (fallbackReason != null && fallbackReason.isNotEmpty) {
        messages.add(fallbackReason);
      }
      final PreparedPoolResult result = PreparedPoolResult(
        dishes: backendDeck.dishes,
        seenDishIds: const <String>{},
        usedFallback: false,
        relaxed: fallbackReason != null,
        messages: messages,
        preparedDeckMeta: backendDeck.meta,
        operationGeneration: generation,
      );
      _canonicalPreparedResult = result;
      return result;
    } on ApiException catch (e) {
      if (!_isCurrentPreparation(generation)) {
        return _cancelledPreparation(generation);
      }
      backendDeckError = e.code == 'PAIR_WAITING_FOR_PARTNER_FILTERS'
          ? 'Waiting for partner choices'
          : ErrorMessages.fromApiException(e);
      debugPrint(
        '[PairDeck] canonical prepare failed code=${e.code ?? e.statusCode} message=${e.message}',
      );
      rethrow;
    } catch (e) {
      if (!_isCurrentPreparation(generation)) {
        return _cancelledPreparation(generation);
      }
      backendDeckError = 'Could not load the shared deck. Please try again.';
      debugPrint('[PairDeck] canonical prepare failed $e');
      rethrow;
    } finally {
      if (_isCurrentPreparation(generation)) {
        _canonicalPrepareFuture = null;
        isPreparingBackendDeck = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentPreparation(int generation) =>
      !_disposed && generation == _prepareGeneration;

  PreparedPoolResult _cancelledPreparation(int generation) {
    debugPrint(
      '[PreSwipe] prepare cancelled reason=stale_generation/session_changed/user_changed',
    );
    return PreparedPoolResult.cancelled(operationGeneration: generation);
  }

  void _invalidateCanonicalPreparation() {
    _prepareGeneration++;
    _canonicalPreparedResult = null;
    _canonicalPrepareFuture = null;
    preparedDeckMeta = null;
    backendDeckError = null;
    isPreparingBackendDeck = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _prepareGeneration++;
    super.dispose();
  }

  FilterAvailabilitySummary buildAvailabilitySummary({
    required List<Dish> allDishes,
    required List<String> dishRegisters,
    required bool includeCustomDishesFirst,
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
    required List<String> diet,
    CoupleFilterChoices? partnerChoices,
  }) {
    final bool hasUserSelections =
        includeCustomDishesFirst ||
        dishRegisters.isNotEmpty ||
        cuisines.isNotEmpty ||
        blocked.isNotEmpty ||
        diet.isNotEmpty;
    final bool partnerHasChoices = partnerChoices != null;
    final List<String> partnerCuisines = partnerHasChoices
        ? partnerChoices.cuisines
        : const <String>[];
    final bool usedCuisineUnionFallback = _scoringService
        .shouldShowPairCuisineFallback(cuisines, partnerCuisines);
    final FilterConfig config = _scoringService.buildConfig(
      myDishRegisters: dishRegisters,
      myCuisines: cuisines,
      myMoods: moods,
      myBlocked: blocked,
      myDiet: diet,
      partnerCuisines: partnerCuisines,
      partnerMoods: partnerHasChoices ? partnerChoices.moods : const <String>[],
      partnerBlocked: partnerHasChoices
          ? partnerChoices.exclusions
          : const <String>[],
      partnerDiet: partnerHasChoices ? partnerChoices.diet : const <String>[],
      partnerDishRegisters: partnerHasChoices
          ? partnerChoices.dishRegisters
          : const <String>[],
    );
    List<Dish> preferred = allDishes;
    if (includeCustomDishesFirst) {
      preferred = preferred.where((Dish dish) => dish.isCustom).toList();
    } else if (dishRegisters.isNotEmpty) {
      final Set<String> registers = dishRegisters
          .map((String value) => value.trim().toLowerCase())
          .toSet();
      preferred = preferred
          .where(
            (Dish dish) =>
                registers.contains(dish.dishRegister.trim().toLowerCase()),
          )
          .toList();
    }
    final int availableCount = hasUserSelections
        ? _scoringService.applyHardFilters(preferred, config).length
        : 0;

    return FilterAvailabilitySummary(
      totalCount: allDishes.length,
      availableCount: availableCount,
      usesPartnerChoices: partnerHasChoices,
      usedCuisineUnionFallback: usedCuisineUnionFallback,
      wouldWidenSearch: availableCount > 0 && availableCount < 5,
    );
  }

  int countMatchingDishes({
    required List<Dish> allDishes,
    required List<String> dishRegisters,
    required bool includeCustomDishesFirst,
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
    required List<String> diet,
    CoupleFilterChoices? partnerChoices,
  }) {
    final bool partnerHasChoices = partnerChoices != null;
    final FilterConfig config = _scoringService.buildConfig(
      myDishRegisters: dishRegisters,
      myCuisines: cuisines,
      myMoods: moods,
      myBlocked: blocked,
      myDiet: diet,
      partnerCuisines: partnerHasChoices
          ? partnerChoices.cuisines
          : const <String>[],
      partnerMoods: partnerHasChoices ? partnerChoices.moods : const <String>[],
      partnerBlocked: partnerHasChoices
          ? partnerChoices.exclusions
          : const <String>[],
      partnerDiet: partnerHasChoices ? partnerChoices.diet : const <String>[],
      partnerDishRegisters: partnerHasChoices
          ? partnerChoices.dishRegisters
          : const <String>[],
    );
    return _scoringService.applyHardFilters(allDishes, config).length;
  }

  List<FilterChipState> buildCuisineChipStates(
    List<String> options,
    List<Dish> allDishes,
  ) {
    return _scoringService.buildCuisineChipStates(options, allDishes);
  }

  List<FilterChipState> buildMoodChipStates({
    required List<String> options,
    required List<Dish> allDishes,
    required List<String> selectedCuisines,
  }) {
    final List<Dish> cuisineBase = _scoringService.applyCuisineStep(
      allDishes,
      selectedCuisines: selectedCuisines,
    );
    return _scoringService.buildMoodChipStates(options, cuisineBase);
  }

  List<FilterChipState> buildExceptionChipStates({
    required List<String> options,
    required List<Dish> allDishes,
    required List<String> selectedCuisines,
  }) {
    final List<Dish> cuisineBase = _scoringService.applyCuisineStep(
      allDishes,
      selectedCuisines: selectedCuisines,
    );
    return _scoringService.buildExceptionChipStates(options, cuisineBase);
  }

  String _normalizeCuisine(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final String lower = trimmed.toLowerCase().replaceAll('_', ' ');
    return lower
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .map((String token) => token[0].toUpperCase() + token.substring(1))
        .join(' ');
  }
}

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

class PreparedPoolResult {
  const PreparedPoolResult({
    required this.dishes,
    required this.seenDishIds,
    required this.usedFallback,
    required this.relaxed,
    required this.messages,
    this.config,
    this.preparedDeckMeta,
  });

  final List<Dish> dishes;
  final Set<String> seenDishIds;
  final bool usedFallback;
  final bool relaxed;
  final List<String> messages;
  final FilterConfig? config;
  final PreparedDeckMeta? preparedDeckMeta;
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
  })  : _dishRepository = dishRepository,
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

  Future<UserProfile> loadProfile(String userId) => _profileService.getProfile(userId);

  Future<void> markIntroSeen(String userId) => _profileService.markPreSwipeFilterIntroSeen(userId);

  Future<void> saveLastFilterPreset({
    required String userId,
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
    required List<String> diet,
    required int matchedLastTime,
  }) =>
      _profileService.saveLastFilterPreset(
        userId,
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

  void _clearLocalDraftState({required bool notify, required bool forceNotify}) {
    final bool changed = isPreparingBackendDeck || preparedDeckMeta != null || backendDeckError != null;
    isPreparingBackendDeck = false;
    preparedDeckMeta = null;
    backendDeckError = null;
    if (notify && (changed || forceNotify)) {
      notifyListeners();
    }
  }

  Future<List<Dish>> loadDishes() => _dishRepository.getCatalogDishes();

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

  Future<PreparedPoolResult> skip(String userId) async {
    final List<Dish> all = await _dishRepository.getCatalogDishes();
    return PreparedPoolResult(
      dishes: _scoringService.fallbackPopular(all),
      seenDishIds: <String>{},
      usedFallback: true,
      relaxed: false,
      messages: const <String>[],
      config: null,
    );
  }

  Future<void> saveChoices({
    required String userId,
    required CoupleProvider coupleProvider,
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
    required List<String> diet,
  }) async {
    await _profileService.saveSessionChoices(
      userId,
      cuisines: cuisines,
      moods: moods,
      blocked: blocked,
    );
    await coupleProvider.saveMyChoices(cuisines: cuisines, moods: moods, diet: diet, exclusions: blocked);
  }


  Future<void> saveAndConfirmChoices({
    required String userId,
    required CoupleProvider coupleProvider,
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
    required List<String> diet,
  }) async {
    await _profileService.saveSessionChoices(
      userId,
      cuisines: cuisines,
      moods: moods,
      blocked: blocked,
    );
    await coupleProvider.saveAndConfirmMyChoices(
      cuisines: cuisines,
      moods: moods,
      diet: diet,
      exclusions: blocked,
    );
  }

  Future<PreparedPoolResult> prepare({
    required String userId,
    required CoupleProvider coupleProvider,
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
    required List<String> diet,
    bool saveChoicesFirst = true,
  }) async {
    final UserProfile profile = await _profileService.getProfile(userId);
    if (saveChoicesFirst) {
      await saveChoices(
        userId: userId,
        coupleProvider: coupleProvider,
        cuisines: cuisines,
        moods: moods,
        blocked: blocked,
        diet: diet,
      );
    }

    final partner = coupleProvider.partnerChoices;
    final bool usePairCuisineLogic = (partner?.cuisines ?? const <String>[]).isNotEmpty;
    final List<String> effectivePartnerCuisines =
        usePairCuisineLogic ? partner!.cuisines : const <String>[];
    final List<String> messages = <String>[];

    if (_scoringService.shouldShowPairCuisineFallback(cuisines, effectivePartnerCuisines)) {
      messages.add('No common cuisine — showing both preferences');
    }

    final FilterConfig config = _scoringService.buildConfig(
      myCuisines: cuisines,
      myMoods: moods,
      myBlocked: blocked,
      myDiet: diet,
      partnerCuisines: effectivePartnerCuisines,
      partnerMoods: partner?.moods ?? const <String>[],
      partnerBlocked: partner?.exclusions ?? const <String>[],
      partnerDiet: partner?.diet ?? const <String>[],
    );

    final List<Dish> all = await _dishRepository.getCatalogDishes();
    debugPrint('[PreSwipeProvider] prepare using full catalog dishes=${all.length}');
    final _DeckAttempt attempt = _buildFallbackDeck(
      all: all,
      config: config,
      profile: profile,
      now: DateTime.now(),
      seed: _fallbackSeed(coupleProvider, config),
    );
    messages.addAll(attempt.messages);

    return PreparedPoolResult(
      dishes: attempt.picked.map((ScoredDish e) => e.dish).toList(),
      seenDishIds: attempt.picked.where((ScoredDish e) => e.seenBefore).map((ScoredDish e) => e.dish.id).toSet(),
      usedFallback: attempt.usedPopularFallback,
      relaxed: messages.isNotEmpty,
      messages: messages,
      config: config,
    );
  }

  Future<PreparedPoolResult> prepareBackendDeckWithFallback(PreparedPoolResult fallback) async {
    if (isPreparingBackendDeck) {
      debugPrint('[RequestDedup] prepared deck prepare skipped: already in flight');
      return fallback;
    }
    isPreparingBackendDeck = true;
    backendDeckError = null;
    notifyListeners();
    debugPrint('[PreparedDeck] prepare started');

    try {
      final PreparedDeck preparedDeck = await _coupleRepository.prepareDeck();
      final PreparedDeck backendDeck = await _loadCanonicalBackendDeck(preparedDeck);
      preparedDeckMeta = backendDeck.meta;
      debugPrint('[PreparedDeck] prepare success final=${backendDeck.meta.finalCount}');
      final List<String> messages = <String>[...fallback.messages];
      final String? fallbackReason = backendDeck.meta.fallbackReason;
      if (fallbackReason != null && fallbackReason.isNotEmpty) {
        messages.add(fallbackReason);
      }
      return PreparedPoolResult(
        dishes: backendDeck.dishes,
        seenDishIds: const <String>{},
        usedFallback: false,
        relaxed: fallback.relaxed || fallbackReason != null,
        messages: messages,
        config: fallback.config,
        preparedDeckMeta: backendDeck.meta,
      );
    } on ApiException catch (e) {
      final bool filtersNotReady = e.statusCode == 409 && e.message.toLowerCase().contains('filter');
      final bool deckPreparing = e.statusCode == 409 && e.message.toLowerCase().contains('preparing');
      if (deckPreparing) {
        try {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          final PreparedDeck backendDeck = await _coupleRepository.getPreparedDeck();
          preparedDeckMeta = backendDeck.meta;
          return PreparedPoolResult(
            dishes: backendDeck.dishes,
            seenDishIds: const <String>{},
            usedFallback: false,
            relaxed: fallback.relaxed,
            messages: fallback.messages,
            config: fallback.config,
            preparedDeckMeta: backendDeck.meta,
          );
        } catch (_) {
          // Fall through to normal safe fallback handling below.
        }
      }
      backendDeckError = filtersNotReady ? 'Waiting for partner choices' : ErrorMessages.fromApiException(e);
      debugPrint('[PreparedDeck] prepare failed $e');
      if (filtersNotReady) {
        debugPrint('[Deck] prepare skipped: filters not ready');
        rethrow;
      }
      final bool requiresSafeBackendDeck = fallback.config?.blocked.isNotEmpty ?? false;
      if (requiresSafeBackendDeck) {
        debugPrint('[PreparedDeck] Backend prepare failed with exclusions selected; local fallback suppressed');
        return PreparedPoolResult(
          dishes: const <Dish>[],
          seenDishIds: const <String>{},
          usedFallback: false,
          relaxed: true,
          messages: <String>[
            ...fallback.messages,
            'Could not prepare a safe deck. Please try again.',
          ],
          config: fallback.config,
          preparedDeckMeta: fallback.preparedDeckMeta,
        );
      }
      debugPrint('[PreparedDeck] Backend prepare failed, using local fallback');
      return PreparedPoolResult(
        dishes: fallback.dishes,
        seenDishIds: fallback.seenDishIds,
        usedFallback: true,
        relaxed: true,
        messages: <String>[
          ...fallback.messages,
          'Could not prepare shared deck. Using local fallback for now.',
        ],
        config: fallback.config,
        preparedDeckMeta: fallback.preparedDeckMeta,
      );
    } finally {
      isPreparingBackendDeck = false;
      notifyListeners();
    }
  }

  Future<PreparedDeck> _loadCanonicalBackendDeck(PreparedDeck preparedDeck) async {
    if (preparedDeck.dishes.isEmpty) return preparedDeck;
    try {
      final PreparedDeck canonical = await _coupleRepository.getPreparedDeck();
      if (canonical.meta.filtersHash == preparedDeck.meta.filtersHash && canonical.dishes.isNotEmpty) {
        return canonical;
      }
    } catch (e) {
      debugPrint('[PreparedDeck] canonical deck reload skipped $e');
    }
    return preparedDeck;
  }

  FilterAvailabilitySummary buildAvailabilitySummary({
    required List<Dish> allDishes,
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
    required List<String> diet,
    CoupleFilterChoices? partnerChoices,
  }) {
    final bool hasUserSelections = cuisines.isNotEmpty || moods.isNotEmpty || blocked.isNotEmpty || diet.isNotEmpty;
    final bool partnerHasChoices = partnerChoices != null;
    final List<String> partnerCuisines = partnerHasChoices ? partnerChoices.cuisines : const <String>[];
    final bool usedCuisineUnionFallback = _scoringService.shouldShowPairCuisineFallback(cuisines, partnerCuisines);
    final FilterConfig config = _scoringService.buildConfig(
      myCuisines: cuisines,
      myMoods: moods,
      myBlocked: blocked,
      myDiet: diet,
      partnerCuisines: partnerCuisines,
      partnerMoods: partnerHasChoices ? partnerChoices.moods : const <String>[],
      partnerBlocked: partnerHasChoices ? partnerChoices.exclusions : const <String>[],
      partnerDiet: partnerHasChoices ? partnerChoices.diet : const <String>[],
    );
    final int availableCount = hasUserSelections ? _scoringService.applyHardFilters(allDishes, config).length : 0;

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
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
    required List<String> diet,
    CoupleFilterChoices? partnerChoices,
  }) {
    final bool partnerHasChoices = partnerChoices != null;
    final FilterConfig config = _scoringService.buildConfig(
      myCuisines: cuisines,
      myMoods: moods,
      myBlocked: blocked,
      myDiet: diet,
      partnerCuisines: partnerHasChoices ? partnerChoices.cuisines : const <String>[],
      partnerMoods: partnerHasChoices ? partnerChoices.moods : const <String>[],
      partnerBlocked: partnerHasChoices ? partnerChoices.exclusions : const <String>[],
      partnerDiet: partnerHasChoices ? partnerChoices.diet : const <String>[],
    );
    return _scoringService.applyHardFilters(allDishes, config).length;
  }

  List<FilterChipState> buildCuisineChipStates(List<String> options, List<Dish> allDishes) {
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

  _DeckAttempt _buildFallbackDeck({
    required List<Dish> all,
    required FilterConfig config,
    required UserProfile profile,
    required DateTime now,
    required String seed,
  }) {
    final List<String> messages = <String>[];

    List<Dish> pool = _scoringService.applyHardFilters(all, config);
    List<ScoredDish> picked = _pickDeck(pool, config: config, profile: profile, now: now, seed: '$seed:strict');
    if (pool.length >= 5) {
      return _DeckAttempt(picked: picked, messages: messages, usedPopularFallback: false);
    }

    final FilterConfig neutralMoodConfig = FilterConfig(
      cuisines: config.cuisines,
      moods: const <String>[],
      blocked: config.blocked,
      diet: config.diet,
      maxCookTime: config.maxCookTime,
    );
    picked = _pickDeck(pool, config: neutralMoodConfig, profile: profile, now: now, seed: '$seed:neutralMood');
    messages.add('Widened mood filter to find more options');
    if (pool.length >= 5) {
      return _DeckAttempt(picked: picked, messages: messages, usedPopularFallback: false);
    }

    final FilterConfig noCuisineConfig = FilterConfig(
      cuisines: const <String>[],
      moods: const <String>[],
      blocked: config.blocked,
      diet: config.diet,
      maxCookTime: config.maxCookTime,
    );
    pool = _scoringService.applyHardFilters(all, noCuisineConfig);
    picked = _pickDeck(pool, config: noCuisineConfig, profile: profile, now: now, seed: '$seed:noCuisine');
    messages.add('Added dishes from other cuisines');
    if (pool.length >= 5) {
      return _DeckAttempt(picked: picked, messages: messages, usedPopularFallback: false);
    }

    final FilterConfig dietOnlyConfig = FilterConfig(
      cuisines: const <String>[],
      moods: const <String>[],
      blocked: const <String>[],
      diet: config.diet,
      maxCookTime: config.maxCookTime,
    );
    pool = _scoringService.applyHardFilters(all, dietOnlyConfig);
    picked = _pickDeck(pool, config: dietOnlyConfig, profile: profile, now: now, seed: '$seed:dietOnly');
    messages.add('Removed some restrictions to fill your deck');
    if (pool.length >= 5) {
      return _DeckAttempt(picked: picked, messages: messages, usedPopularFallback: false);
    }

    final List<Dish> popular = _scoringService.fallbackPopular(all);
    final List<ScoredDish> popularPicked = _shuffleScoredByScoreBucket(
      popular
          .map((Dish dish) => ScoredDish(
                dish: dish,
                score: _scoringService.scoreDish(dish, dietOnlyConfig, profile, now),
                seenBefore: profile.matchHistory.contains(dish.id),
              ))
          .toList(),
      '$seed:popular',
    );
    messages.add('Showing popular dishes — filters were too narrow');
    return _DeckAttempt(picked: popularPicked, messages: messages, usedPopularFallback: true);
  }

  List<ScoredDish> _pickDeck(
    List<Dish> pool, {
    required FilterConfig config,
    required UserProfile profile,
    required DateTime now,
    required String seed,
  }) {
    final List<ScoredDish> scored = _scoringService.scoreDishes(
      dishes: pool,
      config: config,
      profile: profile,
      now: now,
    );
    return _shuffleScoredByScoreBucket(scored, seed).take(30).toList();
  }

  String _fallbackSeed(CoupleProvider coupleProvider, FilterConfig config) {
    final String coupleSeed = coupleProvider.currentCouple?.id.trim().isNotEmpty == true
        ? coupleProvider.currentCouple!.id.trim()
        : 'solo';
    return <String>[
      coupleSeed,
      _stableList(config.cuisines),
      _stableList(config.moods),
      _stableList(config.blocked),
      _stableList(config.diet),
    ].join('|');
  }

  String _stableList(List<String> values) {
    final List<String> sorted = values.map((String value) => value.trim().toLowerCase()).toList()..sort();
    return sorted.join(',');
  }

  List<ScoredDish> _shuffleScoredByScoreBucket(List<ScoredDish> scored, String seed) {
    final Map<int, List<ScoredDish>> buckets = <int, List<ScoredDish>>{};
    for (final ScoredDish item in scored) {
      final int bucket = item.score.round();
      buckets.putIfAbsent(bucket, () => <ScoredDish>[]).add(item);
    }

    final List<int> sortedBuckets = buckets.keys.toList()..sort((int a, int b) => b.compareTo(a));
    return sortedBuckets.expand((int score) {
      final List<ScoredDish> stableBucket = List<ScoredDish>.from(buckets[score]!)
        ..sort((ScoredDish a, ScoredDish b) => a.dish.id.compareTo(b.dish.id));
      return _seededShuffle(stableBucket, '$seed:$score');
    }).toList();
  }

  List<T> _seededShuffle<T>(List<T> items, String seedInput) {
    final List<T> result = List<T>.from(items);
    final _SeededRandom random = _SeededRandom(_hashStringToSeed(seedInput));
    for (int i = result.length - 1; i > 0; i -= 1) {
      final int j = (random.nextDouble() * (i + 1)).floor();
      final T temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }
    return result;
  }

  int _hashStringToSeed(String input) {
    int hash = 2166136261;
    for (int i = 0; i < input.length; i += 1) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return hash;
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

class _DeckAttempt {
  const _DeckAttempt({
    required this.picked,
    required this.messages,
    required this.usedPopularFallback,
  });

  final List<ScoredDish> picked;
  final List<String> messages;
  final bool usedPopularFallback;
}

class _SeededRandom {
  _SeededRandom(this._seed);

  int _seed;

  double nextDouble() {
    _seed = (_seed + 0x6D2B79F5) & 0xFFFFFFFF;
    int t = _seed;
    t = _imul(t ^ (t >> 15), t | 1);
    t ^= t + _imul(t ^ (t >> 7), t | 61);
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296;
  }

  int _imul(int a, int b) {
    return (a * b) & 0xFFFFFFFF;
  }
}

import 'package:flutter/foundation.dart';

import '../../../data/local/user_profile_hive_service.dart';
import '../../../data/models/dish.dart';
import '../../../data/models/filter_config.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/dish_repository.dart';
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
  });

  final List<Dish> dishes;
  final Set<String> seenDishIds;
  final bool usedFallback;
  final bool relaxed;
  final List<String> messages;
  final FilterConfig? config;
}

class PreSwipeProvider extends ChangeNotifier {
  PreSwipeProvider({
    required DishRepository dishRepository,
    required UserProfileHiveService profileService,
    required FilterScoringService scoringService,
  })  : _dishRepository = dishRepository,
        _profileService = profileService,
        _scoringService = scoringService;

  final DishRepository _dishRepository;
  final UserProfileHiveService _profileService;
  final FilterScoringService _scoringService;

  Future<UserProfile> loadProfile(String userId) => _profileService.getProfile(userId);

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

  Future<PreparedPoolResult> prepare({
    required String userId,
    required CoupleProvider coupleProvider,
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
    required List<String> diet,
  }) async {
    final UserProfile profile = await _profileService.getProfile(userId);
    await _profileService.saveSessionChoices(
      userId,
      cuisines: cuisines,
      moods: moods,
      blocked: blocked,
    );

    await coupleProvider.saveMyChoices(cuisines: cuisines, moods: moods, diet: diet, exclusions: blocked);

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
  }) {
    final List<String> messages = <String>[];

    List<Dish> pool = _scoringService.applyHardFilters(all, config);
    List<ScoredDish> picked = _pickDeck(pool, config: config, profile: profile, now: now);
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
    picked = _pickDeck(pool, config: neutralMoodConfig, profile: profile, now: now);
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
    picked = _pickDeck(pool, config: noCuisineConfig, profile: profile, now: now);
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
    picked = _pickDeck(pool, config: dietOnlyConfig, profile: profile, now: now);
    messages.add('Removed some restrictions to fill your deck');
    if (pool.length >= 5) {
      return _DeckAttempt(picked: picked, messages: messages, usedPopularFallback: false);
    }

    final List<Dish> popular = _scoringService.fallbackPopular(all);
    final List<ScoredDish> popularPicked = popular
        .map((Dish dish) => ScoredDish(
              dish: dish,
              score: _scoringService.scoreDish(dish, dietOnlyConfig, profile, now),
              seenBefore: profile.matchHistory.contains(dish.id),
            ))
        .toList();
    messages.add('Showing popular dishes — filters were too narrow');
    return _DeckAttempt(picked: popularPicked, messages: messages, usedPopularFallback: true);
  }

  List<ScoredDish> _pickDeck(
    List<Dish> pool, {
    required FilterConfig config,
    required UserProfile profile,
    required DateTime now,
  }) {
    final List<ScoredDish> scored = _scoringService.scoreDishes(
      dishes: pool,
      config: config,
      profile: profile,
      now: now,
    );
    return scored.take(30).toList();
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

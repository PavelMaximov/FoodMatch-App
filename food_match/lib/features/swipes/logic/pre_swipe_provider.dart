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

class PreSwipeChipState {
  const PreSwipeChipState({required this.count, required this.enabled});

  final int count;
  final bool enabled;
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
  List<Dish> _cachedDishes = <Dish>[];

  Future<UserProfile> loadProfile(String userId) => _profileService.getProfile(userId);

  Future<List<String>> loadCuisineOptions() async {
    _cachedDishes = await _dishRepository.getDishes();
    final List<Dish> dishes = _cachedDishes;
    final Set<String> normalized = dishes
        .map((Dish dish) => _normalizeCuisine(dish.cuisine))
        .where((String cuisine) => cuisine.isNotEmpty)
        .toSet();
    final List<String> options = normalized.toList()..sort();
    return <String>['Any', ...options];
  }

  Future<PreparedPoolResult> skip(String userId) async {
    final List<Dish> all = await _dishRepository.getDishes();
    return PreparedPoolResult(
      dishes: _scoringService.fallbackPopular(all),
      seenDishIds: <String>{},
      usedFallback: true,
      relaxed: false,
      messages: const <String>[],
      config: null,
    );
  }

  List<Dish> get cachedDishes => _cachedDishes;

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

    coupleProvider.setMySessionChoices(
      userId,
      cuisines: cuisines,
      moods: moods,
      blocked: blocked,
      diet: diet,
    );

    final PartnerSessionChoices partner = coupleProvider.partnerChoicesFor(userId);

    final FilterConfig config = _scoringService.buildConfig(
      myCuisines: cuisines,
      myMoods: moods,
      myBlocked: blocked,
      myDiet: diet,
      partnerCuisines: partner.cuisines,
      partnerMoods: partner.moods,
      partnerBlocked: partner.blocked,
      partnerDiet: partner.diet,
    );

    final List<Dish> all = await _dishRepository.getDishes();
    final Set<String> myCuisineSet = cuisines.toSet();
    final Set<String> partnerCuisineSet = partner.cuisines.toSet();
    final bool usedCuisineUnionFallback = myCuisineSet.isNotEmpty &&
        partnerCuisineSet.isNotEmpty &&
        myCuisineSet.intersection(partnerCuisineSet).isEmpty;
    final FilterFallbackResult fallbackResult = _scoringService.applyFallbackCascade(all: all, config: config);
    List<Dish> filtered = fallbackResult.dishes;
    final bool relaxed = fallbackResult.messages.isNotEmpty;

    if (filtered.isEmpty) {
      return PreparedPoolResult(
        dishes: <Dish>[],
        seenDishIds: <String>{},
        usedFallback: false,
        relaxed: relaxed,
        messages: fallbackResult.messages,
        config: config,
      );
    }

    final List<ScoredDish> scored = _scoringService.scoreDishes(
      dishes: filtered,
      config: config,
      profile: profile,
      now: DateTime.now(),
    );

    final int cap = scored.length >= 30 ? 30 : (scored.length >= 15 ? scored.length : 15);
    final List<ScoredDish> picked = scored.take(cap.clamp(0, scored.length)).toList();

    return PreparedPoolResult(
      dishes: picked.map((ScoredDish e) => e.dish).toList(),
      seenDishIds: picked.where((ScoredDish e) => e.seenBefore).map((ScoredDish e) => e.dish.id).toSet(),
      usedFallback: false,
      relaxed: relaxed,
      messages: <String>[
        if (usedCuisineUnionFallback) 'No common cuisine found — showing both preferences.',
        ...fallbackResult.messages,
      ],
      config: config,
    );
  }

  Map<String, PreSwipeChipState> cuisineCounts({required List<String> options, required Set<String> selected}) {
    final Map<String, PreSwipeChipState> result = <String, PreSwipeChipState>{};
    for (final String option in options) {
      if (option == 'Any') {
        result[option] = PreSwipeChipState(count: _cachedDishes.length, enabled: _cachedDishes.length >= 3);
        continue;
      }
      final Set<String> next = Set<String>.from(selected);
      if (next.contains(option)) {
        next.remove(option);
      } else {
        next.remove('Any');
        next.add(option);
      }
      final int count = _cachedDishes.where((d) => next.isEmpty || next.contains(d.cuisine)).length;
      result[option] = PreSwipeChipState(count: count, enabled: count >= 3);
    }
    return result;
  }

  Map<String, PreSwipeChipState> moodCounts({
    required List<String> moods,
    required Set<String> selectedCuisines,
  }) {
    final List<Dish> pool = _cachedDishes
        .where((d) => selectedCuisines.isEmpty || selectedCuisines.contains('Any') || selectedCuisines.contains(d.cuisine))
        .toList();
    return <String, PreSwipeChipState>{
      for (final String mood in moods)
        mood: PreSwipeChipState(
          count: pool.where((d) => d.mood.contains(mood)).length,
          enabled: pool.where((d) => d.mood.contains(mood)).length >= 3,
        ),
    };
  }

  Map<String, PreSwipeChipState> exclusionCounts({
    required List<String> exclusions,
    required Set<String> selectedCuisines,
    required Set<String> selectedBlocked,
    required Set<String> selectedDiet,
  }) {
    final List<Dish> pool = _cachedDishes.where((Dish dish) {
      if (selectedDiet.where((e) => e != 'Any').isNotEmpty &&
          !selectedDiet.where((e) => e != 'Any').every(dish.diet.contains)) {
        return false;
      }
      if (selectedCuisines.isNotEmpty && !selectedCuisines.contains('Any') && !selectedCuisines.contains(dish.cuisine)) {
        return false;
      }
      return true;
    }).toList();

    final Map<String, PreSwipeChipState> result = <String, PreSwipeChipState>{};
    for (final String ex in exclusions) {
      final Set<String> next = Set<String>.from(selectedBlocked);
      next.contains(ex) ? next.remove(ex) : next.add(ex);
      final int count = pool.where((Dish dish) {
        final Set<String> ingredients = dish.ingredients.map((e) => e.toLowerCase()).toSet();
        return !next.any((b) => ingredients.contains(b.toLowerCase()));
      }).length;
      result[ex] = PreSwipeChipState(count: count, enabled: count >= 3);
    }
    return result;
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

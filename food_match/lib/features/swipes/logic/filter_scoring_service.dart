import '../../../data/models/dish.dart';
import '../../../data/models/filter_config.dart';
import '../../../data/models/user_profile.dart';

class ScoredDish {
  const ScoredDish({
    required this.dish,
    required this.score,
    required this.seenBefore,
  });

  final Dish dish;
  final double score;
  final bool seenBefore;
}

class FilterChipState {
  const FilterChipState({
    required this.value,
    required this.count,
    required this.enabled,
  });

  final String value;
  final int count;
  final bool enabled;
}

class CuisineBaseResult {
  const CuisineBaseResult({
    required this.dishes,
    required this.cuisines,
    required this.usedUnionFallback,
  });

  final List<Dish> dishes;
  final List<String> cuisines;
  final bool usedUnionFallback;
}

class FilterScoringService {
  const FilterScoringService();

  static const Map<String, List<String>> blockedGroups = <String, List<String>>{
    'no_meat': <String>['meat', 'chicken', 'beef', 'pork', 'lamb'],
    'no_dairy': <String>['milk', 'cheese', 'cream', 'butter', 'yogurt', 'mozzarella', 'parmesan', 'feta'],
    'no_gluten': <String>['flour', 'bread', 'pasta', 'wheat', 'spaghetti', 'lasagna sheets', 'pita', 'ciabatta'],
    'no_nuts': <String>['peanut', 'peanuts', 'almond', 'almonds', 'walnut', 'walnuts', 'cashew', 'cashews'],
    'no_seafood': <String>['fish', 'salmon', 'shrimp', 'prawn', 'prawns', 'tuna', 'mussels', 'seafood'],
  };

  UserProfile? getPartnerProfile() {
    // MVP stub: partner profile sync will be provided by backend/API in a later sprint.
    return null;
  }

  FilterConfig buildConfig({
    List<String> myDishRegisters = const <String>[],
    required List<String> myCuisines,
    required List<String> myMoods,
    required List<String> myBlocked,
    required List<String> myDiet,
    required List<String> partnerCuisines,
    required List<String> partnerMoods,
    required List<String> partnerBlocked,
    required List<String> partnerDiet,
    List<String> partnerDishRegisters = const <String>[],
  }) {
    return FilterConfig(
      dishRegisters: resolvePairCuisines(myDishRegisters, partnerDishRegisters),
      cuisines: resolvePairCuisines(myCuisines, partnerCuisines),
      moods: _normalizedUnique(<String>[...myMoods, ...partnerMoods]),
      blocked: _normalizedExclusions(<String>[...myBlocked, ...partnerBlocked]),
      diet: _resolveDiet(myDiet, partnerDiet),
      maxCookTime: null,
    );
  }

  List<String> resolvePairCuisines(List<String> myCuisines, List<String> partnerCuisines) {
    final Set<String> mine = _normalizedSet(myCuisines);
    final Set<String> partner = _normalizedSet(partnerCuisines);
    if (mine.isEmpty && partner.isEmpty) {
      return <String>[];
    }
    if (mine.isEmpty) {
      return partner.toList()..sort();
    }
    if (partner.isEmpty) {
      return mine.toList()..sort();
    }

    final Set<String> common = mine.intersection(partner);
    if (common.isNotEmpty) {
      return common.toList()..sort();
    }

    return mine.union(partner).toList()..sort();
  }

  bool shouldShowPairCuisineFallback(List<String> myCuisines, List<String> partnerCuisines) {
    final Set<String> mine = _normalizedSet(myCuisines);
    final Set<String> partner = _normalizedSet(partnerCuisines);
    return mine.isNotEmpty && partner.isNotEmpty && mine.intersection(partner).isEmpty;
  }

  CuisineBaseResult buildCuisineBase(
    List<Dish> allDishes, {
    required List<String> userACuisines,
    List<String> userBCuisines = const <String>[],
  }) {
    final bool usedUnionFallback = shouldShowPairCuisineFallback(userACuisines, userBCuisines);
    final List<String> cuisines = resolvePairCuisines(userACuisines, userBCuisines);
    return CuisineBaseResult(
      dishes: applyCuisineStep(allDishes, selectedCuisines: cuisines),
      cuisines: cuisines,
      usedUnionFallback: usedUnionFallback,
    );
  }

  List<Dish> applyCuisineStep(List<Dish> allDishes, {required List<String> selectedCuisines}) {
    final Set<String> selected = _normalizedSet(selectedCuisines);
    if (selected.isEmpty) {
      return List<Dish>.from(allDishes);
    }
    return allDishes.where((Dish dish) => selected.contains(_normalize(dish.cuisine))).toList();
  }

  List<Dish> applyMoodStep(List<Dish> cuisineBase, {required List<String> selectedMoods}) {
    return List<Dish>.from(cuisineBase);
  }

  List<Dish> applyExceptions(
    List<Dish> source, {
    required List<String> selectedDiet,
    required List<String> selectedExclusions,
  }) {
    Iterable<Dish> pool = source;
    final Set<String> diets = _normalizedSet(selectedDiet);

    if (diets.contains('vegan')) {
      pool = pool.where((Dish dish) => _normalizedSet(dish.diet).contains('vegan'));
    } else if (diets.contains('vegetarian')) {
      pool = pool.where((Dish dish) {
        final Set<String> dishDiet = _normalizedSet(dish.diet);
        return dishDiet.contains('vegetarian') || dishDiet.contains('vegan');
      });
    } else if (diets.isNotEmpty) {
      pool = pool.where((Dish dish) {
        final Set<String> dishDiet = _normalizedSet(dish.diet);
        return diets.every(dishDiet.contains);
      });
    }

    for (final String exclusion in _normalizedExclusions(selectedExclusions)) {
      if (exclusion == 'no_spicy') {
        pool = pool.where((Dish dish) {
          final String level = _normalize(dish.spiceLevel);
          return level.isEmpty || level == 'none';
        });
        continue;
      }
      final List<String> blockedWords = blockedGroups[exclusion] ?? const <String>[];
      if (blockedWords.isEmpty) {
        continue;
      }
      pool = pool.where((Dish dish) => !containsBlockedIngredient(dish, blockedWords));
    }

    return pool.toList();
  }

  bool containsBlockedIngredient(Dish dish, List<String> blockedWords) {
    final List<String> structuredIngredients = dish.sections
        .expand((DishSection section) => section.components)
        .map((DishComponent component) => component.ingredient.name.toLowerCase())
        .where((String name) => name.isNotEmpty)
        .toList();
    final Iterable<String> ingredients = structuredIngredients.isNotEmpty
        ? structuredIngredients
        : dish.ingredients.map((String ingredient) => ingredient.toLowerCase());

    return ingredients.any(
      (String name) => blockedWords.any((String blocked) => name.contains(blocked.toLowerCase())),
    );
  }

  List<Dish> applyHardFilters(List<Dish> source, FilterConfig config) {
    final List<Dish> cuisineBase = applyCuisineStep(source, selectedCuisines: config.cuisines);
    final List<Dish> moodPool = applyMoodStep(cuisineBase, selectedMoods: config.moods);
    return applyExceptions(
      moodPool,
      selectedDiet: config.diet,
      selectedExclusions: config.blocked,
    );
  }

  double scoreDish(Dish dish, FilterConfig config, UserProfile profile, DateTime now) {
    double score = 0;

    if (config.dishRegisters.isNotEmpty) {
      score += _normalizedSet(config.dishRegisters).contains(_normalize(dish.dishRegister)) ? 30 : 6;
    }

    final Set<String> selectedMoods = _normalizedSet(config.moods);
    final int moodMatches = dish.mood.where((String mood) => selectedMoods.contains(_normalize(mood))).length;
    score += moodMatches * 20;

    if (dish.popular) {
      score += 15;
    }

    score += dish.qualityScore * 2;

    final Set<String> likedDishIds = profile.swipeHistory
        .where((record) => record.direction == 'like')
        .map((record) => record.dishId)
        .toSet();
    final Set<String> dislikedDishIds = profile.swipeHistory
        .where((record) => record.direction != 'like')
        .map((record) => record.dishId)
        .toSet();
    final Set<String> matchedDishIds = profile.matchHistory.toSet();

    if (likedDishIds.contains(dish.id)) {
      score += 10;
    }
    if (dislikedDishIds.contains(dish.id)) {
      score -= 20;
    }
    if (matchedDishIds.contains(dish.id)) {
      score -= 50;
    }

    if (_normalizedSet(profile.favoriteCuisines).contains(_normalize(dish.cuisine))) {
      score += 12;
    }

    final String season = getCurrentSeason(now);
    final Set<String> dishSeasons = _normalizedSet(dish.season);
    if (dishSeasons.contains(season) || dishSeasons.contains('all')) {
      score += 8;
    }

    if (profile.preferredEffort.isNotEmpty && _normalize(profile.preferredEffort) == _normalize(dish.effort)) {
      score += 8;
    }

    return score;
  }

  List<ScoredDish> scoreDishes({
    required List<Dish> dishes,
    required FilterConfig config,
    required UserProfile profile,
    required DateTime now,
  }) {
    final List<ScoredDish> scored = dishes.map((Dish dish) {
      final bool matchedBefore = profile.matchHistory.contains(dish.id);
      return ScoredDish(
        dish: dish,
        score: scoreDish(dish, config, profile, now),
        seenBefore: matchedBefore,
      );
    }).toList();

    scored.sort((ScoredDish a, ScoredDish b) {
      final int scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return a.dish.name.toLowerCase().compareTo(b.dish.name.toLowerCase());
    });

    return scored;
  }

  List<Dish> rankDishes({
    required List<Dish> dishes,
    required FilterConfig config,
    required UserProfile profile,
    required DateTime now,
  }) {
    return scoreDishes(dishes: dishes, config: config, profile: profile, now: now)
        .map((ScoredDish scoredDish) => scoredDish.dish)
        .toList();
  }

  List<Dish> fallbackPopular(List<Dish> dishes) {
    final List<Dish> fallback = dishes.where((Dish dish) => dish.popular).toList()
      ..sort((Dish a, Dish b) {
        final int qualityCompare = b.qualityScore.compareTo(a.qualityScore);
        if (qualityCompare != 0) {
          return qualityCompare;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return fallback.take(20).toList();
  }

  Map<String, int> getCuisineChipCounts(List<Dish> allDishes) {
    final Map<String, int> counts = <String, int>{};
    for (final Dish dish in allDishes) {
      final String cuisine = _normalize(dish.cuisine);
      if (cuisine.isEmpty) {
        continue;
      }
      counts[cuisine] = (counts[cuisine] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> getMoodChipCounts(List<Dish> cuisineBase) {
    final Map<String, int> counts = <String, int>{};
    for (final Dish dish in cuisineBase) {
      for (final String mood in dish.mood) {
        final String normalized = _normalize(mood);
        if (normalized.isEmpty) {
          continue;
        }
        counts[normalized] = (counts[normalized] ?? 0) + 1;
      }
    }
    return counts;
  }

  Map<String, int> getExceptionChipCounts(List<Dish> cuisineBase) {
    final Map<String, int> counts = <String, int>{};
    for (final String exclusion in blockedGroups.keys) {
      final List<String> blockedWords = blockedGroups[exclusion] ?? const <String>[];
      counts[exclusion] = cuisineBase.where((Dish dish) => !containsBlockedIngredient(dish, blockedWords)).length;
    }
    return counts;
  }

  List<FilterChipState> buildCuisineChipStates(List<String> options, List<Dish> allDishes) {
    final Map<String, int> counts = getCuisineChipCounts(allDishes);
    return options.map((String option) {
      final String normalized = _normalize(option);
      final int count = normalized == 'any' ? allDishes.length : counts[normalized] ?? 0;
      return FilterChipState(value: option, count: count, enabled: normalized == 'any' || count > 0);
    }).toList();
  }

  List<FilterChipState> buildMoodChipStates(List<String> options, List<Dish> cuisineBase) {
    final Map<String, int> counts = getMoodChipCounts(cuisineBase);
    return options.map((String option) {
      final String normalized = _normalize(option);
      return FilterChipState(value: option, count: counts[normalized] ?? 0, enabled: true);
    }).toList();
  }

  List<FilterChipState> buildExceptionChipStates(List<String> options, List<Dish> cuisineBase) {
    final Map<String, int> counts = getExceptionChipCounts(cuisineBase);
    return options.map((String option) {
      final String normalized = _normalizeExclusion(option);
      final int count = counts[normalized] ?? cuisineBase.length;
      return FilterChipState(value: option, count: count, enabled: count > 0);
    }).toList();
  }

  String getCurrentSeason(DateTime now) {
    final int month = now.month;
    if (month >= 3 && month <= 5) {
      return 'spring';
    }
    if (month >= 6 && month <= 8) {
      return 'summer';
    }
    if (month >= 9 && month <= 11) {
      return 'autumn';
    }
    return 'winter';
  }

  List<String> _resolveDiet(List<String> myDiet, List<String> partnerDiet) {
    final Set<String> both = <String>{..._normalizedSet(myDiet), ..._normalizedSet(partnerDiet)};
    if (both.isEmpty) {
      return <String>[];
    }
    return both.toList()..sort();
  }

  List<String> _normalizedUnique(List<String> values) {
    return _normalizedSet(values).toList()..sort();
  }

  Set<String> _normalizedSet(List<String> values) {
    return values.map(_normalize).where((String value) => value.isNotEmpty && value != 'any').toSet();
  }

  List<String> _normalizedExclusions(List<String> values) {
    return values.map(_normalizeExclusion).where((String value) => value.isNotEmpty).toSet().toList()..sort();
  }

  String _normalizeExclusion(String value) {
    final String normalized = _normalize(value);
    switch (normalized) {
      case 'meat':
      case 'no meat':
        return 'no_meat';
      case 'dairy':
      case 'no dairy':
        return 'no_dairy';
      case 'gluten':
      case 'no gluten':
        return 'no_gluten';
      case 'nuts':
      case 'no nuts':
        return 'no_nuts';
      case 'fish':
      case 'seafood':
      case 'no seafood':
        return 'no_seafood';
      default:
        return normalized.replaceAll(' ', '_');
    }
  }

  String _normalize(String value) => value.trim().toLowerCase().replaceAll('_', ' ');
}

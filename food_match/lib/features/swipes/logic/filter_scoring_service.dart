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
  final int score;
  final bool seenBefore;
}

class FilterScoringService {
  const FilterScoringService();

  UserProfile? getPartnerProfile() {
    // MVP stub: partner profile sync will be provided by backend/API in a later sprint.
    return null;
  }

  FilterConfig buildConfig({
    required List<String> myCuisines,
    required List<String> myMoods,
    required List<String> myBlocked,
    required List<String> myDiet,
    required List<String> partnerCuisines,
    required List<String> partnerMoods,
    required List<String> partnerBlocked,
    required List<String> partnerDiet,
  }) {
    final Set<String> myCuisineSet = myCuisines.toSet();
    final Set<String> partnerCuisineSet = partnerCuisines.toSet();

    List<String> cuisines;
    if (myCuisineSet.isNotEmpty && partnerCuisineSet.isNotEmpty) {
      cuisines = myCuisineSet.intersection(partnerCuisineSet).toList();
    } else if (myCuisineSet.isNotEmpty) {
      cuisines = myCuisineSet.toList();
    } else {
      cuisines = partnerCuisineSet.toList();
    }

    final List<String> moods = <String>{...myMoods, ...partnerMoods}.toList();
    final List<String> blocked = <String>{...myBlocked, ...partnerBlocked}.toList();
    final List<String> diet = _resolveDiet(myDiet, partnerDiet);

    return FilterConfig(
      cuisines: cuisines,
      moods: moods,
      blocked: blocked,
      diet: diet,
      maxCookTime: null,
    );
  }

  List<Dish> applyHardFilters(List<Dish> source, FilterConfig config) {
    return source.where((Dish dish) {
      if (config.diet.isNotEmpty && !config.diet.every(dish.diet.contains)) {
        return false;
      }
      final Set<String> ingredients = dish.ingredients.map((String e) => e.toLowerCase()).toSet();
      final bool blockedHit = config.blocked.any((String b) => ingredients.contains(b.toLowerCase()));
      if (blockedHit) {
        return false;
      }
      if (config.cuisines.isNotEmpty && !config.cuisines.contains(dish.cuisine)) {
        return false;
      }
      return true;
    }).toList();
  }

  List<ScoredDish> scoreDishes({
    required List<Dish> dishes,
    required FilterConfig config,
    required UserProfile profile,
    required DateTime now,
  }) {
    final String season = _seasonOf(now);

    final List<ScoredDish> scored = dishes.map((Dish dish) {
      int score = 0;
      for (final String mood in config.moods) {
        if (dish.mood.contains(mood)) {
          score += 20;
        }
      }
      if (dish.popular) {
        score += 15;
      }
      if (profile.favoriteCuisines.contains(dish.cuisine)) {
        score += 12;
      }
      final bool likedBefore = profile.swipeHistory.any(
        (record) => record.dishId == dish.id && record.direction == 'like',
      );
      if (likedBefore) {
        score += 10;
      }
      final bool matchedBefore = profile.matchHistory.contains(dish.id);
      if (matchedBefore) {
        score -= 50;
      }
      if (dish.season.contains('all') || dish.season.contains(season)) {
        score += 8;
      }

      return ScoredDish(dish: dish, score: score, seenBefore: matchedBefore);
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

  List<Dish> fallbackPopular(List<Dish> dishes) {
    final List<Dish> fallback = dishes.where((Dish dish) => dish.popular).toList()
      ..sort((Dish a, Dish b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return fallback.take(20).toList();
  }

  List<String> _resolveDiet(List<String> myDiet, List<String> partnerDiet) {
    final Set<String> both = <String>{...myDiet, ...partnerDiet};
    if (both.isEmpty) {
      return <String>[];
    }
    // MVP safest rule: require all diet tags selected by either side.
    return both.toList();
  }

  String _seasonOf(DateTime now) {
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
}

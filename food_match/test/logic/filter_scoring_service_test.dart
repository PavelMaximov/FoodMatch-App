import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/models/filter_config.dart';
import 'package:food_match/data/models/recipe_step.dart';
import 'package:food_match/data/models/swipe_record.dart';
import 'package:food_match/data/models/user_profile.dart';
import 'package:food_match/features/swipes/logic/filter_scoring_service.dart';

Dish d(String id, {required String cuisine, List<String> mood = const <String>[], List<String> ingredients = const <String>[], bool popular = false, List<String> diet = const <String>[]}) => Dish(
  id: id,
  name: id,
  description: '',
  imageUrl: '',
  cuisine: cuisine,
  type: '',
  mood: mood,
  diet: diet,
  ingredients: ingredients,
  cookTime: 10,
  calories: '',
  effort: '',
  source: const <String>[],
  servings: '2',
  season: const <String>['all'],
  popular: popular,
  steps: const <RecipeStep>[],
);

void main() {
  const FilterScoringService service = FilterScoringService();
  final UserProfile profile = UserProfile(
    userId: 'u1',
    favoriteCuisines: const <String>[],
    favoriteDishIds: const <String>[],
    preferredMoods: const <String>[],
    blockedIngredients: const <String>[],
    swipeHistory: const <SwipeRecord>[],
    matchHistory: const <String>[],
    scoreByCuisine: const <String, int>{},
    scoreByMood: const <String, int>{},
    scoreByIngredients: const <String, int>{},
    lastUpdated: DateTime(2026, 1, 1),
    sessionCuisines: const <String>[],
    sessionMoods: const <String>[],
    sessionBlocked: const <String>[],
  );

  test('mood does not remove dishes from pool', () {
    final List<Dish> all = <Dish>[
      d('a', cuisine: 'Italian', mood: const <String>['Festive']),
      d('b', cuisine: 'Italian', mood: const <String>['Comfort']),
    ];
    const FilterConfig config = FilterConfig(cuisines: <String>['Italian'], moods: <String>['Festive'], blocked: <String>[], diet: <String>[]);

    final filtered = service.applyHardFilters(all, config);
    expect(filtered.length, 2);

    final scored = service.scoreDishes(dishes: filtered, config: config, profile: profile, now: DateTime(2026, 1, 1));
    expect(scored.first.dish.id, 'a');
  });

  test('cuisine intersection falls back to union', () {
    final config = service.buildConfig(
      myCuisines: const <String>['Italian'],
      myMoods: const <String>[],
      myBlocked: const <String>[],
      myDiet: const <String>[],
      partnerCuisines: const <String>['Japanese'],
      partnerMoods: const <String>[],
      partnerBlocked: const <String>[],
      partnerDiet: const <String>[],
    );

    expect(config.cuisines.toSet(), <String>{'Italian', 'Japanese'});
  });

  test('fallback cascade guarantees at least 5 dishes when available', () {
    final List<Dish> all = List<Dish>.generate(6, (i) => d('p$i', cuisine: 'Any', popular: true, ingredients: const <String>['x']));
    const FilterConfig config = FilterConfig(cuisines: <String>['Italian'], moods: <String>['Festive'], blocked: <String>['x'], diet: <String>[]);
    final result = service.applyFallbackCascade(all: all, config: config);
    expect(result.dishes.length, greaterThanOrEqualTo(5));
  });
}

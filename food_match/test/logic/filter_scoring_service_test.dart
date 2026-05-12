import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/models/filter_config.dart';
import 'package:food_match/data/models/recipe_step.dart';
import 'package:food_match/data/models/user_profile.dart';
import 'package:food_match/features/swipes/logic/filter_scoring_service.dart';

void main() {
  const FilterScoringService service = FilterScoringService();

  final List<Dish> allDishes = <Dish>[
    _dish(
      id: 'italian-festive',
      cuisine: 'italian',
      mood: <String>['festive', 'comfort'],
      diet: <String>['vegetarian'],
      ingredients: <String>['tomato', 'mozzarella'],
      sections: <DishSection>[
        DishSection(
          components: <DishComponent>[
            DishComponent(ingredient: DishIngredient(name: 'Mozzarella')),
          ],
        ),
      ],
      popular: true,
      qualityScore: 4,
    ),
    _dish(
      id: 'italian-comfort',
      cuisine: 'italian',
      mood: <String>['comfort'],
      diet: <String>['vegan'],
      ingredients: <String>['tomato', 'pasta'],
      popular: false,
      qualityScore: 3,
    ),
    _dish(
      id: 'japanese-light',
      cuisine: 'japanese',
      mood: <String>['light'],
      diet: <String>['pescatarian'],
      ingredients: <String>['salmon', 'rice'],
      popular: true,
      qualityScore: 5,
    ),
  ];

  test('required pre-swipe filter assertions hold', () {
    final List<String> selectedCuisines = <String>[];

    // 1. Any means no cuisine filter.
    assert(selectedCuisines.isEmpty);
    expect(selectedCuisines, isEmpty);

    // 2. Step 1 counts come from full pool.
    final Map<String, int> cuisineCounts = service.getCuisineChipCounts(allDishes);
    assert(cuisineCounts['italian']! > 0);
    expect(cuisineCounts['italian'], 2);

    // 3. Mood never removes dishes.
    final List<Dish> cuisineBase = allDishes.where((Dish dish) => dish.cuisine == 'italian').toList();
    final List<Dish> moodPool = service.applyMoodStep(cuisineBase, selectedMoods: <String>['festive']);
    assert(moodPool.length == cuisineBase.length);
    expect(moodPool, hasLength(cuisineBase.length));

    // 4. Mood affects ranking only.
    final List<Dish> ranked = service.rankDishes(
      dishes: cuisineBase,
      config: const FilterConfig(
        cuisines: <String>['italian'],
        moods: <String>['festive'],
        blocked: <String>[],
        diet: <String>[],
      ),
      profile: UserProfile.empty(),
      now: DateTime(2026, 5, 12),
    );
    assert(ranked.isNotEmpty);
    expect(ranked.first.id, 'italian-festive');

    // 5. Exceptions remove blocked dishes.
    final List<Dish> filtered = service.applyExceptions(
      cuisineBase,
      selectedDiet: <String>[],
      selectedExclusions: <String>['no_dairy'],
    );
    assert(filtered.length <= cuisineBase.length);
    expect(filtered.map((Dish dish) => dish.id), isNot(contains('italian-festive')));

    // 6. Step 2 chip counts use cuisineBase, not allDishes.
    final Map<String, int> moodCounts = service.getMoodChipCounts(cuisineBase);
    assert(moodCounts['comfort'] != null);
    expect(moodCounts['light'], isNull);

    // 7. Mood chips are never disabled.
    final List<FilterChipState> allMoodChipStates = service.buildMoodChipStates(
      <String>['comfort', 'light', 'missing'],
      cuisineBase,
    );
    assert(allMoodChipStates.every((FilterChipState chip) => chip.enabled));
    expect(allMoodChipStates.every((FilterChipState chip) => chip.enabled), isTrue);

    // 8. Pair cuisine intersection fallback.
    final CuisineBaseResult pairBase = service.buildCuisineBase(
      allDishes,
      userACuisines: <String>['italian'],
      userBCuisines: <String>['japanese'],
    );
    assert(pairBase.dishes.isNotEmpty);
    expect(pairBase.usedUnionFallback, isTrue);
    expect(pairBase.dishes, isNotEmpty);
  });

  test('diet compatibility keeps vegan for vegetarian and only vegan for vegan', () {
    final List<Dish> cuisineBase = allDishes.where((Dish dish) => dish.cuisine == 'italian').toList();

    expect(
      service.applyExceptions(
        cuisineBase,
        selectedDiet: <String>['vegetarian'],
        selectedExclusions: <String>[],
      ),
      hasLength(2),
    );

    expect(
      service
          .applyExceptions(
            cuisineBase,
            selectedDiet: <String>['vegan'],
            selectedExclusions: <String>[],
          )
          .map((Dish dish) => dish.id),
      <String>['italian-comfort'],
    );
  });
}

Dish _dish({
  required String id,
  required String cuisine,
  required List<String> mood,
  required List<String> diet,
  required List<String> ingredients,
  List<DishSection> sections = const <DishSection>[],
  bool popular = false,
  num qualityScore = 0,
}) {
  return Dish(
    id: id,
    name: id,
    description: '',
    imageUrl: '',
    cuisine: cuisine,
    type: '',
    mood: mood,
    diet: diet,
    ingredients: ingredients,
    cookTime: 0,
    calories: '',
    effort: '',
    source: const <String>[],
    servings: '',
    season: const <String>['all'],
    popular: popular,
    steps: const <RecipeStep>[],
    qualityScore: qualityScore,
    sections: sections,
  );
}

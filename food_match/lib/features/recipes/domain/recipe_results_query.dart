import '../../../data/models/dish.dart';

enum MealTabType { breakfast, lunch, dinner, snack }

class RecipeResultsQuery {
  const RecipeResultsQuery({
    this.cuisine,
    this.type,
    this.mealType,
    this.mood = const <String>[],
    this.diet = const <String>[],
    this.effort,
    this.popular,
    this.maxCookTime,
    this.maxTotalTime,
    this.timeTier,
    this.maxIngredients,
    this.sort = 'default',
  });

  final String? cuisine;
  final String? type;
  final String? mealType;
  final List<String> mood;
  final List<String> diet;
  final String? effort;
  final bool? popular;
  final int? maxCookTime;
  final int? maxTotalTime;
  final String? timeTier;
  final int? maxIngredients;
  final String sort;

  RecipeResultsQuery copyWith({
    String? cuisine,
    String? type,
    String? mealType,
    List<String>? mood,
    List<String>? diet,
    String? effort,
    bool? popular,
    int? maxCookTime,
    int? maxTotalTime,
    String? timeTier,
    int? maxIngredients,
    String? sort,
  }) {
    return RecipeResultsQuery(
      cuisine: cuisine ?? this.cuisine,
      type: type ?? this.type,
      mealType: mealType ?? this.mealType,
      mood: mood ?? this.mood,
      diet: diet ?? this.diet,
      effort: effort ?? this.effort,
      popular: popular ?? this.popular,
      maxCookTime: maxCookTime ?? this.maxCookTime,
      maxTotalTime: maxTotalTime ?? this.maxTotalTime,
      timeTier: timeTier ?? this.timeTier,
      maxIngredients: maxIngredients ?? this.maxIngredients,
      sort: sort ?? this.sort,
    );
  }
}

bool _matchesToken(String rawValue, String target) {
  final String v = rawValue.trim().toLowerCase();
  if (v.isEmpty) {
    return false;
  }
  if (v == target) {
    return true;
  }
  // split on common separators and whitespace
  final List<String> tokens = v
      .split(RegExp(r'[\s\/,&|]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (tokens.contains(target)) {
    return true;
  }
  // word-boundary match as a fallback
  return RegExp(r'\b' + RegExp.escape(target) + r'\b').hasMatch(v);
}

bool matchesMealTab(Dish dish, MealTabType tab) {
  final Set<String> tags = dish.tags
      .map((e) => e.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  final Set<String> mood = dish.mood
      .map((e) => e.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  final String type = dish.type.trim();
  final String target = tab.name.toLowerCase();

  for (final t in tags) {
    if (_matchesToken(t, target)) {
      return true;
    }
  }
  for (final m in mood) {
    if (_matchesToken(m, target)) {
      return true;
    }
  }
  if (_matchesToken(type, target)) {
    return true;
  }
  return false;
}

class RecipeCategoryConfig {
  const RecipeCategoryConfig({
    required this.id,
    required this.title,
    required this.filter,
    this.query = const RecipeResultsQuery(sort: 'default'),
    this.postFilter,
  });

  final String id;
  final String title;
  final bool Function(Dish dish) filter;
  final RecipeResultsQuery query;
  final bool Function(Dish dish)? postFilter;
}

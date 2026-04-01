import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/utils/logger.dart';
import '../models/dish.dart';
import '../models/recipe.dart';
import '../models/recipe_step.dart';

class MealDbService {
  static const String _baseUrl = 'https://www.themealdb.com/api/json/v1/1';

  MealDbService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Fetch multiple random meals (call random.php N times)
  Future<List<MealDbDish>> getRandomMeals({int count = 20}) async {
    final List<MealDbDish> meals = <MealDbDish>[];
    final Set<String> seenIds = <String>{};

    for (var i = 0; i < count; i++) {
      try {
        final uri = Uri.parse('$_baseUrl/random.php');
        final response = await _client.get(uri).timeout(
          const Duration(seconds: 10),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final mealsList = data['meals'] as List<dynamic>?;
          if (mealsList != null && mealsList.isNotEmpty) {
            final meal = MealDbDish.fromMealDbJson(
              mealsList[0] as Map<String, dynamic>,
            );
            if (!seenIds.contains(meal.id)) {
              seenIds.add(meal.id);
              meals.add(meal);
            }
          }
        }
      } catch (e) {
        AppLogger.error('MealDB random fetch failed', e);
      }
    }

    AppLogger.info('MealDB: fetched ${meals.length} unique meals');
    return meals;
  }

  /// Search meals by name
  Future<List<MealDbDish>> searchMeals(String query) async {
    try {
      final uri = Uri.parse('$_baseUrl/search.php?s=$query');
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final mealsList = data['meals'] as List<dynamic>?;
        if (mealsList != null) {
          return mealsList
              .map(
                (meal) => MealDbDish.fromMealDbJson(
                  meal as Map<String, dynamic>,
                ),
              )
              .toList();
        }
      }
    } catch (e) {
      AppLogger.error('MealDB search failed', e);
    }

    return <MealDbDish>[];
  }

  /// Get meal details by ID
  Future<MealDbDish?> getMealById(String id) async {
    try {
      final uri = Uri.parse('$_baseUrl/lookup.php?i=$id');
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final mealsList = data['meals'] as List<dynamic>?;
        if (mealsList != null && mealsList.isNotEmpty) {
          return MealDbDish.fromMealDbJson(
            mealsList[0] as Map<String, dynamic>,
          );
        }
      }
    } catch (e) {
      AppLogger.error('MealDB lookup failed', e);
    }

    return null;
  }

  /// Fetch meals by cuisine/area
  Future<List<MealDbDish>> getMealsByArea(String area) async {
    try {
      final uri = Uri.parse('$_baseUrl/filter.php?a=$area');
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final mealsList = data['meals'] as List<dynamic>?;
        if (mealsList != null) {
          final List<MealDbDish> fullMeals = <MealDbDish>[];

          for (final dynamic meal in mealsList.take(20)) {
            final id = (meal as Map<String, dynamic>)['idMeal'] as String?;
            if (id != null) {
              final MealDbDish? fullMeal = await getMealById(id);
              if (fullMeal != null) {
                fullMeals.add(fullMeal);
              }
            }
            await Future.delayed(const Duration(milliseconds: 100));
          }

          AppLogger.info('MealDB: fetched ${fullMeals.length} $area meals with details');
          return fullMeals;
        }
      }
    } catch (e) {
      AppLogger.error('MealDB area filter failed', e);
    }

    return <MealDbDish>[];
  }
}

/// Temporary model that bridges MealDB JSON to our Dish model
class MealDbDish {
  const MealDbDish({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.cuisine,
    required this.tags,
    required this.ingredients,
    required this.instructions,
  });

  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String cuisine;
  final List<String> tags;
  final List<String> ingredients;
  final String instructions;

  /// Parse from full MealDB response (random.php, lookup.php, search.php)
  factory MealDbDish.fromMealDbJson(Map<String, dynamic> json) {
    final ingredients = <String>[];
    for (var i = 1; i <= 20; i++) {
      final ingredient = json['strIngredient$i'] as String?;
      final measure = json['strMeasure$i'] as String?;
      if (ingredient != null && ingredient.trim().isNotEmpty) {
        final amount =
            measure != null && measure.trim().isNotEmpty ? '${measure.trim()} ' : '';
        ingredients.add('$amount${ingredient.trim()}');
      }
    }

    final tagsRaw = json['strTags'] as String?;
    final tags = tagsRaw != null && tagsRaw.isNotEmpty
        ? tagsRaw.split(',').map((tag) => tag.trim()).toList()
        : <String>[];

    return MealDbDish(
      id: json['idMeal'] as String? ?? '',
      title: json['strMeal'] as String? ?? 'Unknown',
      description: json['strInstructions'] as String? ?? '',
      imageUrl: json['strMealThumb'] as String? ?? '',
      cuisine: json['strArea'] as String? ?? 'International',
      tags: tags,
      ingredients: ingredients,
      instructions: json['strInstructions'] as String? ?? '',
    );
  }

  /// Parse from filter.php response (limited data)
  factory MealDbDish.fromFilterJson(Map<String, dynamic> json, String area) {
    return MealDbDish(
      id: json['idMeal'] as String? ?? '',
      title: json['strMeal'] as String? ?? 'Unknown',
      description: '',
      imageUrl: json['strMealThumb'] as String? ?? '',
      cuisine: area,
      tags: <String>[],
      ingredients: <String>[],
      instructions: '',
    );
  }

  /// Convert to our app's Dish model
  Dish toDish() {
    return Dish(
      id: id,
      title: title,
      description:
          description.length > 200 ? '${description.substring(0, 200)}...' : description,
      imageUrl: imageUrl,
      cuisine: cuisine,
      tags: tags,
      source: 'mealdb',
      externalId: id,
      createdBy: '',
      recipe: Recipe(
        ingredients: ingredients,
        steps: _parseSteps(instructions),
      ),
    );
  }

  List<RecipeStep> _parseSteps(String instructions) {
    if (instructions.isEmpty) {
      return <RecipeStep>[];
    }

    final lines = instructions
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    return lines
        .asMap()
        .entries
        .map(
          (entry) => RecipeStep(
            title: 'Step ${entry.key + 1}',
            text: entry.value.trim(),
          ),
        )
        .toList();
  }
}

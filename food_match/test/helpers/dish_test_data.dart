import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/models/recipe_step.dart';

Dish buildTestDish({
  String id = '1',
  String name = 'Test dish',
  String description = 'Description',
  String imageUrl = 'https://via.placeholder.com/300',
  String cuisine = 'Russian',
  List<String> mood = const <String>[],
  List<String> diet = const <String>[],
  List<String> ingredients = const <String>[],
  List<String> tags = const <String>[],
  List<DishSection> sections = const <DishSection>[],
  bool popular = false,
  num qualityScore = 0,
}) {
  return Dish(
    id: id,
    name: name,
    description: description,
    imageUrl: imageUrl,
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
    tags: tags,
    sections: sections,
  );
}

import 'package:json_annotation/json_annotation.dart';

import 'recipe_step.dart';

part 'dish.g.dart';

@JsonSerializable()
class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.cuisine,
    required this.type,
    required this.mood,
    required this.diet,
    required this.ingredients,
    required this.cookTime,
    required this.calories,
    required this.effort,
    required this.source,
    required this.servings,
    required this.season,
    required this.popular,
    required this.steps,
  });

  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: '')
  final String name;
  @JsonKey(defaultValue: '')
  final String description;
  @JsonKey(defaultValue: '')
  final String imageUrl;
  @JsonKey(defaultValue: '')
  final String cuisine;
  @JsonKey(defaultValue: '')
  final String type;
  @JsonKey(defaultValue: <String>[])
  final List<String> mood;
  @JsonKey(defaultValue: <String>[])
  final List<String> diet;
  @JsonKey(defaultValue: <String>[])
  final List<String> ingredients;
  @JsonKey(defaultValue: 0)
  final int cookTime;
  @JsonKey(defaultValue: '')
  final String calories;
  @JsonKey(defaultValue: '')
  final String effort;
  @JsonKey(defaultValue: <String>[])
  final List<String> source;
  @JsonKey(defaultValue: '')
  final String servings;
  @JsonKey(defaultValue: <String>[])
  final List<String> season;
  @JsonKey(defaultValue: false)
  final bool popular;
  @JsonKey(defaultValue: <RecipeStep>[])
  final List<RecipeStep> steps;

  factory Dish.fromJson(Map<String, dynamic> json) => _$DishFromJson(json);

  Map<String, dynamic> toJson() => _$DishToJson(this);
}

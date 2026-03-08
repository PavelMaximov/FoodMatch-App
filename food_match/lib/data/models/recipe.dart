import 'package:json_annotation/json_annotation.dart';

import 'recipe_step.dart';

part 'recipe.g.dart';

@JsonSerializable()
class Recipe {
  const Recipe({required this.ingredients, required this.steps});

  final List<String> ingredients;
  final List<RecipeStep> steps;

  factory Recipe.fromJson(Map<String, dynamic> json) => _$RecipeFromJson(json);

  Map<String, dynamic> toJson() => _$RecipeToJson(this);
}

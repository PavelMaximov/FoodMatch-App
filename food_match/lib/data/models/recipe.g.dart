// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe.dart';

Recipe _$RecipeFromJson(Map<String, dynamic> json) => Recipe(
      ingredients: (json['ingredients'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      steps: (json['steps'] as List<dynamic>)
          .map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RecipeToJson(Recipe instance) => <String, dynamic>{
      'ingredients': instance.ingredients,
      'steps': instance.steps,
    };

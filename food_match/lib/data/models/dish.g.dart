// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dish.dart';

Dish _$DishFromJson(Map<String, dynamic> json) => Dish(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      cuisine: json['cuisine'] as String? ?? '',
      type: json['type'] as String? ?? '',
      mood: (json['mood'] as List<dynamic>?)?.map((e) => e as String).toList() ?? <String>[],
      diet: (json['diet'] as List<dynamic>?)?.map((e) => e as String).toList() ?? <String>[],
      ingredients:
          (json['ingredients'] as List<dynamic>?)?.map((e) => e as String).toList() ?? <String>[],
      cookTime: (json['cookTime'] as num?)?.toInt() ?? 0,
      calories: json['calories'] as String? ?? '',
      effort: json['effort'] as String? ?? '',
      source: (json['source'] as List<dynamic>?)?.map((e) => e as String).toList() ?? <String>[],
      servings: json['servings'] as String? ?? '',
      season: (json['season'] as List<dynamic>?)?.map((e) => e as String).toList() ?? <String>[],
      popular: json['popular'] as bool? ?? false,
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <RecipeStep>[],
    );

Map<String, dynamic> _$DishToJson(Dish instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'imageUrl': instance.imageUrl,
      'cuisine': instance.cuisine,
      'type': instance.type,
      'mood': instance.mood,
      'diet': instance.diet,
      'ingredients': instance.ingredients,
      'cookTime': instance.cookTime,
      'calories': instance.calories,
      'effort': instance.effort,
      'source': instance.source,
      'servings': instance.servings,
      'season': instance.season,
      'popular': instance.popular,
      'steps': instance.steps,
    };

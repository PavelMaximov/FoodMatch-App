// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dish.dart';

DishIngredient _$DishIngredientFromJson(Map<String, dynamic> json) =>
    DishIngredient(name: json['name'] as String? ?? '');

Map<String, dynamic> _$DishIngredientToJson(DishIngredient instance) =>
    <String, dynamic>{'name': instance.name};

DishComponent _$DishComponentFromJson(Map<String, dynamic> json) => DishComponent(
      ingredient: json['ingredient'] == null
          ? const DishIngredient(name: '')
          : DishIngredient.fromJson(json['ingredient'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DishComponentToJson(DishComponent instance) =>
    <String, dynamic>{'ingredient': instance.ingredient};

DishSection _$DishSectionFromJson(Map<String, dynamic> json) => DishSection(
      components: (json['components'] as List<dynamic>?)
              ?.map((e) => DishComponent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <DishComponent>[],
    );

Map<String, dynamic> _$DishSectionToJson(DishSection instance) =>
    <String, dynamic>{'components': instance.components};

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
      qualityScore: json['qualityScore'] as num? ?? 0,
      tags: _readDishTags(json),
      sections: _readDishSections(json),
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
      'qualityScore': instance.qualityScore,
      'tags': instance.tags,
      'sections': instance.sections,
    };


List<DishSection> _readDishSections(Map<String, dynamic> json) {
  final dynamic rawSections = json['sections'];
  if (rawSections is List) {
    return rawSections
        .whereType<Map>()
        .map((Map section) => DishSection.fromJson(Map<String, dynamic>.from(section)))
        .toList();
  }

  final dynamic structuredIngredients = json['structuredIngredients'];
  if (structuredIngredients is List && structuredIngredients.isNotEmpty) {
    final List<DishComponent> components = structuredIngredients.whereType<Map>().map((Map ingredient) {
      final String name = ingredient['name']?.toString() ?? '';
      return DishComponent(ingredient: DishIngredient(name: name));
    }).where((DishComponent component) => component.ingredient.name.isNotEmpty).toList();

    if (components.isNotEmpty) {
      return <DishSection>[DishSection(components: components)];
    }
  }

  return <DishSection>[];
}

List<String> _readDishTags(Map<String, dynamic> json) {
  final dynamic rawTags = json['tags'];
  if (rawTags is! List) {
    return <String>[];
  }

  return rawTags
      .map((dynamic tag) {
        if (tag is String) {
          return tag;
        }
        if (tag is Map) {
          return tag['name']?.toString() ?? '';
        }
        return '';
      })
      .map((String name) => name.trim())
      .where((String name) => name.isNotEmpty)
      .toList();
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dish.dart';

DishIngredient _$DishIngredientFromJson(Map<String, dynamic> json) =>
    DishIngredient(
      name: json['name'] as String? ?? '',
      displaySingular: json['display_singular'] as String? ?? '',
      displayPlural: json['display_plural'] as String? ?? '',
    );

Map<String, dynamic> _$DishIngredientToJson(DishIngredient instance) =>
    <String, dynamic>{
      'name': instance.name,
      'display_singular': instance.displaySingular,
      'display_plural': instance.displayPlural,
    };

DishComponent _$DishComponentFromJson(Map<String, dynamic> json) =>
    DishComponent(
      ingredient: json['ingredient'] == null
          ? const DishIngredient(name: '')
          : DishIngredient.fromJson(json['ingredient'] as Map<String, dynamic>),
      position: (json['position'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      rawText: (json['rawText'] ?? json['raw_text']) as String?,
      extraComment: (json['extraComment'] ?? json['extra_comment']) as String?,
      measurements:
          (json['measurements'] as List<dynamic>?)
              ?.whereType<Map>()
              .map(
                (Map<dynamic, dynamic> value) =>
                    DishIngredientMeasurement.fromJson(
                      Map<String, dynamic>.from(value),
                    ),
              )
              .toList() ??
          <DishIngredientMeasurement>[],
    );

Map<String, dynamic> _$DishComponentToJson(DishComponent instance) =>
    <String, dynamic>{
      'ingredient': instance.ingredient,
      'position': instance.position,
      'name': instance.name,
      'displayName': instance.displayName,
      'rawText': instance.rawText,
      'extraComment': instance.extraComment,
      'measurements': instance.measurements,
    };

DishSection _$DishSectionFromJson(Map<String, dynamic> json) => DishSection(
  components:
      (json['components'] as List<dynamic>?)
          ?.map((e) => DishComponent.fromJson(e as Map<String, dynamic>))
          .toList() ??
      <DishComponent>[],
  name: json['name'] as String? ?? '',
  position: (json['position'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$DishSectionToJson(DishSection instance) =>
    <String, dynamic>{
      'components': instance.components,
      'name': instance.name,
      'position': instance.position,
    };

DishIngredientMeasurement _$DishIngredientMeasurementFromJson(
  Map<String, dynamic> json,
) => DishIngredientMeasurement(
  quantity: _readMeasurementValue(json['quantity']),
  unit: _readMeasurementUnit(json['unit']),
  system: json['system'] as String?,
);

Map<String, dynamic> _$DishIngredientMeasurementToJson(
  DishIngredientMeasurement instance,
) => <String, dynamic>{
  'quantity': instance.quantity,
  'unit': instance.unit,
  'system': instance.system,
};

DishNutrition _$DishNutritionFromJson(Map<String, dynamic> json) =>
    DishNutrition(calories: _readOptionalInt(json['calories']));

Map<String, dynamic> _$DishNutritionToJson(DishNutrition instance) =>
    <String, dynamic>{'calories': instance.calories};

Dish _$DishFromJson(Map<String, dynamic> json) => Dish(
  id: json['id'] as String? ?? '',
  name: json['name'] as String? ?? '',
  description: json['description'] as String? ?? '',
  imageUrl: json['imageUrl'] as String? ?? '',
  imagePublicId: json['imagePublicId'] as String?,
  cuisine: json['cuisine'] as String? ?? '',
  type: json['type'] as String? ?? '',
  mood:
      (json['mood'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      <String>[],
  dishRegister:
      json['dishRegister'] as String? ?? json['dish_register'] as String? ?? '',
  spiceLevel:
      json['spiceLevel'] as String? ?? json['spice_level'] as String? ?? '',
  isCustom: json['isCustom'] as bool? ?? false,
  diet:
      (json['diet'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      <String>[],
  ingredients:
      (json['ingredients'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      <String>[],
  cookTime: (json['cookTime'] as num?)?.toInt() ?? 0,
  calories: json['calories'] as String? ?? '',
  effort: json['effort'] as String? ?? '',
  source:
      (json['source'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      <String>[],
  servings: json['servings'] as String? ?? '',
  season:
      (json['season'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      <String>[],
  popular: json['popular'] as bool? ?? false,
  steps:
      (json['steps'] as List<dynamic>?)
          ?.map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
          .toList() ??
      <RecipeStep>[],
  qualityScore: json['qualityScore'] as num? ?? 0,
  tags: _readDishTags(json),
  sections: _readDishSections(json),
  nutrition: json['nutrition'] == null
      ? null
      : DishNutrition.fromJson(json['nutrition'] as Map<String, dynamic>),
);

Map<String, dynamic> _$DishToJson(Dish instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'imageUrl': instance.imageUrl,
  'imagePublicId': instance.imagePublicId,
  'cuisine': instance.cuisine,
  'type': instance.type,
  'mood': instance.mood,
  'dishRegister': instance.dishRegister,
  'spiceLevel': instance.spiceLevel,
  'isCustom': instance.isCustom,
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
  'nutrition': instance.nutrition?.toJson(),
};

List<DishSection> _readDishSections(Map<String, dynamic> json) {
  final dynamic rawSections = json['ingredientSections'] ?? json['sections'];
  if (rawSections is List) {
    return rawSections
        .whereType<Map>()
        .map(
          (Map section) =>
              DishSection.fromJson(Map<String, dynamic>.from(section)),
        )
        .toList();
  }

  final dynamic structuredIngredients = json['structuredIngredients'];
  if (structuredIngredients is List && structuredIngredients.isNotEmpty) {
    final List<DishComponent> components = structuredIngredients
        .whereType<Map>()
        .map((Map ingredient) {
          final String name = ingredient['name']?.toString() ?? '';
          final String? quantity = _readMeasurementValue(
            ingredient['quantity'],
          );
          final String? unit = _readMeasurementUnit(ingredient['unit']);
          return DishComponent(
            ingredient: DishIngredient(name: name),
            measurements: quantity == null && unit == null
                ? const <DishIngredientMeasurement>[]
                : <DishIngredientMeasurement>[
                    DishIngredientMeasurement(quantity: quantity, unit: unit),
                  ],
          );
        })
        .where(
          (DishComponent component) => component.ingredient.name.isNotEmpty,
        )
        .toList();

    if (components.isNotEmpty) {
      return <DishSection>[DishSection(components: components)];
    }
  }

  return <DishSection>[];
}

String? _readMeasurementValue(dynamic value) {
  if (value == null) return null;
  final String result = value.toString().trim();
  return result.isEmpty ? null : result;
}

String? _readMeasurementUnit(dynamic value) {
  if (value is Map) {
    value = value['abbreviation'] ?? value['display_singular'] ?? value['name'];
  }
  return _readMeasurementValue(value);
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

int? _readOptionalInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

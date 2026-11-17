import 'package:json_annotation/json_annotation.dart';

import 'recipe_step.dart';

part 'dish.g.dart';

@JsonSerializable()
class DishIngredient {
  const DishIngredient({
    required this.name,
    this.displaySingular = '',
    this.displayPlural = '',
  });

  @JsonKey(defaultValue: '')
  final String name;
  @JsonKey(name: 'display_singular', defaultValue: '')
  final String displaySingular;
  @JsonKey(name: 'display_plural', defaultValue: '')
  final String displayPlural;

  factory DishIngredient.fromJson(Map<String, dynamic> json) =>
      _$DishIngredientFromJson(json);

  Map<String, dynamic> toJson() => _$DishIngredientToJson(this);
}

@JsonSerializable()
class DishComponent {
  const DishComponent({
    required this.ingredient,
    this.position = 0,
    this.name = '',
    this.displayName = '',
    this.rawText,
    this.extraComment,
    this.measurements = const <DishIngredientMeasurement>[],
  });

  @JsonKey(defaultValue: DishIngredient(name: ''))
  final DishIngredient ingredient;
  final int position;
  final String name;
  final String displayName;
  final String? rawText;
  final String? extraComment;
  final List<DishIngredientMeasurement> measurements;

  String get resolvedName {
    return <String>[
          displayName,
          ingredient.displaySingular,
          ingredient.displayPlural,
          name,
          ingredient.name,
        ]
        .map((String value) => value.trim())
        .firstWhere((String value) => value.isNotEmpty, orElse: () => '');
  }

  factory DishComponent.fromJson(Map<String, dynamic> json) =>
      _$DishComponentFromJson(json);

  Map<String, dynamic> toJson() => _$DishComponentToJson(this);
}

@JsonSerializable()
class DishSection {
  const DishSection({
    required this.components,
    this.name = '',
    this.position = 0,
  });

  @JsonKey(defaultValue: <DishComponent>[])
  final List<DishComponent> components;
  final String name;
  final int position;

  factory DishSection.fromJson(Map<String, dynamic> json) =>
      _$DishSectionFromJson(json);

  Map<String, dynamic> toJson() => _$DishSectionToJson(this);
}

@JsonSerializable()
class DishIngredientMeasurement {
  const DishIngredientMeasurement({this.quantity, this.unit, this.system});

  final String? quantity;
  final String? unit;
  final String? system;

  factory DishIngredientMeasurement.fromJson(Map<String, dynamic> json) =>
      _$DishIngredientMeasurementFromJson(json);

  Map<String, dynamic> toJson() => _$DishIngredientMeasurementToJson(this);
}

@JsonSerializable()
class DishNutrition {
  const DishNutrition({this.calories, this.estimated = false});

  final int? calories;
  @JsonKey(defaultValue: false)
  final bool estimated;

  factory DishNutrition.fromJson(Map<String, dynamic> json) =>
      _$DishNutritionFromJson(json);

  Map<String, dynamic> toJson() => _$DishNutritionToJson(this);
}

@JsonSerializable()
class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    this.imagePublicId,
    required this.cuisine,
    required this.type,
    required this.mood,
    this.dishRegister = '',
    this.spiceLevel = '',
    this.isCustom = false,
    required this.diet,
    required this.ingredients,
    required this.cookTime,
    this.prepTimeMinutes = 0, this.cookTimeMinutes = 0, this.totalTimeMinutes = 0, this.totalTimeTier = '',
    required this.calories,
    required this.effort,
    required this.source,
    required this.servings,
    required this.season,
    required this.popular,
    required this.steps,
    this.qualityScore = 0,
    this.tags = const <String>[],
    this.sections = const <DishSection>[],
    this.nutrition,
    this.contentTranslations = const {},
  });

  @JsonKey(defaultValue: '')
  final String id;
  @JsonKey(defaultValue: '')
  final String name;
  @JsonKey(defaultValue: '')
  final String description;
  @JsonKey(defaultValue: '')
  final String imageUrl;
  final String? imagePublicId;
  @JsonKey(defaultValue: '')
  final String cuisine;
  @JsonKey(defaultValue: '')
  final String type;
  @JsonKey(defaultValue: <String>[])
  final List<String> mood;
  @JsonKey(defaultValue: '')
  final String dishRegister;
  @JsonKey(defaultValue: '')
  final String spiceLevel;
  @JsonKey(defaultValue: false)
  final bool isCustom;
  @JsonKey(defaultValue: <String>[])
  final List<String> diet;
  @JsonKey(defaultValue: <String>[])
  final List<String> ingredients;
  @JsonKey(defaultValue: 0)
  final int cookTime;
  final int prepTimeMinutes, cookTimeMinutes, totalTimeMinutes;
  final String totalTimeTier;
  int get resolvedTotalTimeMinutes => totalTimeMinutes > 0 ? totalTimeMinutes : cookTime > 0 ? cookTime : prepTimeMinutes + cookTimeMinutes;
  bool get hasTime => resolvedTotalTimeMinutes > 0 || totalTimeTier.isNotEmpty;
  String get totalTimeDisplay {
    final minutes = resolvedTotalTimeMinutes;
    if (minutes <= 0) return totalTimeTier;
    final hours = minutes ~/ 60, remainder = minutes % 60;
    return hours == 0 ? '$minutes min' : remainder == 0 ? '$hours hr' : '$hours hr $remainder min';
  }
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
  @JsonKey(defaultValue: 0)
  final num qualityScore;
  @JsonKey(defaultValue: <String>[])
  final List<String> tags;
  @JsonKey(defaultValue: <DishSection>[])
  final List<DishSection> sections;
  final DishNutrition? nutrition;

  @JsonKey(fromJson: _readContentTranslations)
  final Map<String, Map<String, String>> contentTranslations;

  String contentText(String text, String languageCode) =>
      !isCustom && languageCode == 'de'
          ? contentTranslations['de']?[text] ?? text
          : text;

  static final Expando<Dish> _germanDisplay = Expando<Dish>();

  /// A display projection only. Keep the original dish for persistence/actions.
  Dish displayForLanguage(String languageCode) {
    if (isCustom || languageCode != 'de' || contentTranslations['de'] == null) {
      return this;
    }
    final cached = _germanDisplay[this];
    if (cached != null) return cached;
    String tr(String text) => contentText(text, languageCode);
    final display = Dish(
      id: id, name: tr(name), description: tr(description), imageUrl: imageUrl,
      imagePublicId: imagePublicId, cuisine: cuisine, type: type, mood: mood,
      dishRegister: dishRegister, spiceLevel: spiceLevel, isCustom: isCustom,
      diet: diet, ingredients: ingredients.map(tr).toList(), cookTime: cookTime,
      prepTimeMinutes: prepTimeMinutes, cookTimeMinutes: cookTimeMinutes,
      totalTimeMinutes: totalTimeMinutes, totalTimeTier: totalTimeTier,
      calories: calories, effort: effort, source: source, servings: servings,
      season: season, popular: popular, qualityScore: qualityScore, tags: tags,
      nutrition: nutrition, contentTranslations: contentTranslations,
      steps: steps.map((s) => RecipeStep(step: s.step, text: tr(s.text))).toList(),
      sections: sections.map((s) => DishSection(name: tr(s.name), position: s.position,
        components: s.components.map((c) => DishComponent(
          ingredient: DishIngredient(name: tr(c.ingredient.name),
            displaySingular: tr(c.ingredient.displaySingular),
            displayPlural: tr(c.ingredient.displayPlural)),
          position: c.position, name: tr(c.name), displayName: tr(c.displayName),
          rawText: c.rawText == null ? null : tr(c.rawText!),
          extraComment: c.extraComment == null ? null : tr(c.extraComment!),
          measurements: c.measurements,
        )).toList(),
      )).toList(),
    );
    _germanDisplay[this] = display;
    return display;
  }

  factory Dish.fromJson(Map<String, dynamic> json) => _$DishFromJson(json);

  Map<String, dynamic> toJson() => _$DishToJson(this);
}

Map<String, Map<String, String>> _readContentTranslations(dynamic value) {
  if (value is! Map || value['de'] is! Map) return const {};
  return {'de': {
    for (final entry in (value['de'] as Map).entries)
      if (entry.key is String && entry.value is String &&
          (entry.value as String).trim().isNotEmpty)
        entry.key as String: entry.value as String,
  }};
}

class FilterConfig {
  const FilterConfig({
    this.dishRegisters = const <String>[],
    this.includeCustomDishesFirst = false,
    required this.cuisines,
    required this.moods,
    required this.blocked,
    required this.diet,
    this.maxCookTime,
  });

  final List<String> cuisines;
  final List<String> dishRegisters;
  List<String> get selectedCategories => dishRegisters;
  final bool includeCustomDishesFirst;
  final List<String> moods;
  final List<String> blocked;
  final List<String> diet;
  final int? maxCookTime;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'cuisines': cuisines,
    'dishRegisters': dishRegisters,
    'selectedCategories': dishRegisters,
    'includeCustomDishesFirst': includeCustomDishesFirst,
    'moods': moods,
    'blocked': blocked,
    'diet': diet,
    'maxCookTime': maxCookTime,
  };

  factory FilterConfig.fromJson(Map<dynamic, dynamic> json) => FilterConfig(
    dishRegisters: List<String>.from(
      json['selectedCategories'] as List<dynamic>? ??
          json['dishRegisters'] as List<dynamic>? ??
          (json['category'] == null
              ? <dynamic>[]
              : <dynamic>[json['category']]),
    ),
    includeCustomDishesFirst: json['includeCustomDishesFirst'] == true,
    cuisines: List<String>.from(
      json['cuisines'] as List<dynamic>? ?? <dynamic>[],
    ),
    moods: List<String>.from(json['moods'] as List<dynamic>? ?? <dynamic>[]),
    blocked: List<String>.from(
      json['blocked'] as List<dynamic>? ?? <dynamic>[],
    ),
    diet: List<String>.from(json['diet'] as List<dynamic>? ?? <dynamic>[]),
    maxCookTime: json['maxCookTime'] as int?,
  );
}

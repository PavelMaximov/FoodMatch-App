class CoupleFilterChoices {
  const CoupleFilterChoices({
    this.dishRegisters = const <String>[],
    this.includeCustomDishesFirst = false,
    this.cuisines = const <String>[],
    this.moods = const <String>[],
    this.diet = const <String>[],
    this.exclusions = const <String>[],
    this.confirmed = false,
    this.updatedAt,
  });

  final List<String> cuisines;
  final List<String> dishRegisters;
  List<String> get selectedCategories => dishRegisters;
  final bool includeCustomDishesFirst;
  final List<String> moods;
  final List<String> diet;
  final List<String> exclusions;
  final bool confirmed;
  final DateTime? updatedAt;

  factory CoupleFilterChoices.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CoupleFilterChoices();
    return CoupleFilterChoices(
      dishRegisters:
          (json['selectedCategories'] as List<dynamic>? ??
                  json['dishRegisters'] as List<dynamic>? ??
                  (json['category'] == null
                      ? const <dynamic>[]
                      : <dynamic>[json['category']]))
              .map((e) => e.toString())
              .toList(),
      includeCustomDishesFirst: json['includeCustomDishesFirst'] == true,
      cuisines: (json['cuisines'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      moods: (json['moods'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      diet: (json['diet'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      exclusions: (json['exclusions'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      confirmed: json['confirmed'] == true,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'cuisines': cuisines,
    'selectedCuisines': cuisines,
    'dishRegisters': dishRegisters,
    'selectedCategories': dishRegisters,
    'includeCustomDishesFirst': includeCustomDishesFirst,
    'moods': moods,
    'diet': diet,
    'exclusions': exclusions,
  };
}

class CoupleFilterState {
  const CoupleFilterState({
    required this.myChoices,
    this.partnerChoices,
    required this.bothConfirmed,
    required this.compatibility,
    required this.status,
  });

  final CoupleFilterChoices myChoices;
  final CoupleFilterChoices? partnerChoices;
  final bool bothConfirmed;
  final int compatibility;
  final String status;

  factory CoupleFilterState.fromJson(Map<String, dynamic> json) =>
      CoupleFilterState(
        myChoices: CoupleFilterChoices.fromJson(
          json['myChoices'] as Map<String, dynamic>?,
        ),
        partnerChoices: json['partnerChoices'] is Map<String, dynamic>
            ? CoupleFilterChoices.fromJson(
                json['partnerChoices'] as Map<String, dynamic>,
              )
            : null,
        bothConfirmed: json['bothConfirmed'] == true,
        compatibility: (json['compatibility'] as num?)?.toInt() ?? 0,
        status: json['status']?.toString() ?? 'draft',
      );
}

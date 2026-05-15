import 'swipe_record.dart';

class UserProfile {
  const UserProfile({
    required this.favoriteCuisines,
    required this.dislikedIngredients,
    required this.dietaryRestrictions,
    required this.swipeHistory,
    required this.matchHistory,
    required this.sessionCuisines,
    required this.sessionMoods,
    required this.sessionBlocked,
    required this.cuisineWeights,
    required this.sessionCount,
    required this.preferredEffort,
  });

  final List<String> favoriteCuisines;
  final List<String> dislikedIngredients;
  final List<String> dietaryRestrictions;
  final List<SwipeRecord> swipeHistory;
  final List<String> matchHistory;
  final List<String> sessionCuisines;
  final List<String> sessionMoods;
  final List<String> sessionBlocked;
  final Map<String, int> cuisineWeights;
  final int sessionCount;
  final String preferredEffort;

  factory UserProfile.empty() => const UserProfile(
        favoriteCuisines: <String>[],
        dislikedIngredients: <String>[],
        dietaryRestrictions: <String>[],
        swipeHistory: <SwipeRecord>[],
        matchHistory: <String>[],
        sessionCuisines: <String>[],
        sessionMoods: <String>[],
        sessionBlocked: <String>[],
        cuisineWeights: <String, int>{},
        sessionCount: 0,
        preferredEffort: '',
      );

  UserProfile copyWith({
    List<String>? favoriteCuisines,
    List<String>? dislikedIngredients,
    List<String>? dietaryRestrictions,
    List<SwipeRecord>? swipeHistory,
    List<String>? matchHistory,
    List<String>? sessionCuisines,
    List<String>? sessionMoods,
    List<String>? sessionBlocked,
    Map<String, int>? cuisineWeights,
    int? sessionCount,
    String? preferredEffort,
  }) {
    return UserProfile(
      favoriteCuisines: favoriteCuisines ?? this.favoriteCuisines,
      dislikedIngredients: dislikedIngredients ?? this.dislikedIngredients,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      swipeHistory: swipeHistory ?? this.swipeHistory,
      matchHistory: matchHistory ?? this.matchHistory,
      sessionCuisines: sessionCuisines ?? this.sessionCuisines,
      sessionMoods: sessionMoods ?? this.sessionMoods,
      sessionBlocked: sessionBlocked ?? this.sessionBlocked,
      cuisineWeights: cuisineWeights ?? this.cuisineWeights,
      sessionCount: sessionCount ?? this.sessionCount,
      preferredEffort: preferredEffort ?? this.preferredEffort,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'favoriteCuisines': favoriteCuisines,
        'dislikedIngredients': dislikedIngredients,
        'dietaryRestrictions': dietaryRestrictions,
        'swipeHistory': swipeHistory.map((SwipeRecord record) => record.toJson()).toList(),
        'matchHistory': matchHistory,
        'sessionCuisines': sessionCuisines,
        'sessionMoods': sessionMoods,
        'sessionBlocked': sessionBlocked,
        'cuisineWeights': cuisineWeights,
        'sessionCount': sessionCount,
        'preferredEffort': preferredEffort,
      };

  factory UserProfile.fromJson(Map<dynamic, dynamic> json) => UserProfile(
        favoriteCuisines: List<String>.from(json['favoriteCuisines'] as List<dynamic>? ?? <dynamic>[]),
        dislikedIngredients:
            List<String>.from(json['dislikedIngredients'] as List<dynamic>? ?? <dynamic>[]),
        dietaryRestrictions:
            List<String>.from(json['dietaryRestrictions'] as List<dynamic>? ?? <dynamic>[]),
        swipeHistory: (json['swipeHistory'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => SwipeRecord.fromJson(e as Map<dynamic, dynamic>))
            .toList(),
        matchHistory: List<String>.from(json['matchHistory'] as List<dynamic>? ?? <dynamic>[]),
        sessionCuisines: List<String>.from(json['sessionCuisines'] as List<dynamic>? ?? <dynamic>[]),
        sessionMoods: List<String>.from(json['sessionMoods'] as List<dynamic>? ?? <dynamic>[]),
        sessionBlocked: List<String>.from(json['sessionBlocked'] as List<dynamic>? ?? <dynamic>[]),
        cuisineWeights: Map<String, int>.from(
          (json['cuisineWeights'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
              .map((dynamic key, dynamic value) => MapEntry(key.toString(), (value as num).toInt())),
        ),
        sessionCount: (json['sessionCount'] as num?)?.toInt() ?? 0,
        preferredEffort: json['preferredEffort']?.toString() ?? '',
      );
}

import '../../core/constants/api_constants.dart';
import '../models/dish.dart';
import '../services/api_service.dart';

class DishRepository {
  DishRepository(this._apiService);

  final ApiService _apiService;

  Future<List<Dish>> getDishes({String? cuisine}) async {
    final endpoint = cuisine == null
        ? ApiConstants.dishes
        : '${ApiConstants.dishes}?q=${Uri.encodeQueryComponent(cuisine)}';
    final data = await _apiService.get(endpoint);
    final List<dynamic> list = data is Map<String, dynamic>
        ? (data['dishes'] as List<dynamic>? ?? <dynamic>[])
        : <dynamic>[];

    return list
        .map((item) => Dish.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<Dish>> getMyCustomDishes() async {
    final data = await _apiService.get(ApiConstants.dishesMy);
    final List<dynamic> list = data is Map<String, dynamic>
        ? (data['dishes'] as List<dynamic>? ?? <dynamic>[])
        : <dynamic>[];

    return list
        .map((item) => Dish.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }


  Future<List<String>> searchIngredients(String query) async {
    final String endpoint =
        '${ApiConstants.ingredientsSearch}?q=${Uri.encodeQueryComponent(query)}';
    final data = await _apiService.get(endpoint);
    final List<dynamic> list = data is Map<String, dynamic>
        ? (data['ingredients'] as List<dynamic>? ?? <dynamic>[])
        : <dynamic>[];

    return list.map((item) => item.toString()).toList();
  }

  Future<Dish> getDishById(String dishId) async {
    final data = await _apiService.get('${ApiConstants.dishes}/$dishId');
    if (data is Map<String, dynamic>) {
      final dynamic raw = data['dish'] ?? data;
      if (raw is Map<String, dynamic>) {
        return Dish.fromJson(raw);
      }
    }
    throw const FormatException('Unexpected dish response format.');
  }

  Future<Dish> createCustomDish({
    required String title,
    required String cuisine,
    required String mood,
    required List<Map<String, String>> ingredients,
    required int cookTime,
    required int servings,
    required List<String> instructions,
    required String imageUrl,
    String? imageKey,
    String? imageMimeType,
    int? imageSize,
  }) async {
    final data = await _apiService.post(ApiConstants.dishesCustom, {
      'name': title,
      'cuisine': cuisine,
      'mood': mood,
      'ingredients': ingredients,
      'cookTime': cookTime,
      'servings': servings.toString(),
      'steps': instructions
          .asMap()
          .entries
          .where((entry) => entry.value.trim().isNotEmpty)
          .map((entry) => <String, dynamic>{
                'step': entry.key + 1,
                'text': entry.value.trim(),
              })
          .toList(),
      'imageUrl': imageUrl,
      'imageKey': imageKey,
      'imageMimeType': imageMimeType,
      'imageSize': imageSize,
    });

    if (data is Map<String, dynamic>) {
      final dynamic raw = data['dish'] ?? data;
      if (raw is Map<String, dynamic>) {
        return Dish.fromJson(raw);
      }
    }

    throw const FormatException('Unexpected create dish response format.');
  }

  Future<void> deleteMyDish(String dishId) async {
    await _apiService.delete('${ApiConstants.dishes}/$dishId');
  }
}

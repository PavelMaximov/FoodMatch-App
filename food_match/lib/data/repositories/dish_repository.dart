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

  Future<Dish> createDish({
    required String title,
    required String description,
    required String imageUrl,
    required String cuisine,
    required List<String> tags,
  }) async {
    final data = await _apiService.post(ApiConstants.dishes, {
      'name': title,
      'description': description,
      'imageUrl': imageUrl,
      'cuisine': cuisine,
      'mood': tags,
    });

    if (data is Map<String, dynamic>) {
      final dynamic raw = data['dish'] ?? data;
      if (raw is Map<String, dynamic>) {
        return Dish.fromJson(raw);
      }
    }

    throw const FormatException('Unexpected create dish response format.');
  }
}

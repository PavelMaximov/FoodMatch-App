import '../../core/constants/api_constants.dart';
import '../models/dish.dart';
import '../services/api_service.dart';

class DishRepository {
  DishRepository(this._apiService);

  final ApiService _apiService;

  Future<List<Dish>> getDishes({String? cuisine}) async {
    final endpoint = cuisine == null
        ? ApiConstants.dishes
        : '${ApiConstants.dishes}?cuisine=${Uri.encodeQueryComponent(cuisine)}';
    final data = await _apiService.get(endpoint);
    return (data as List<dynamic>)
        .map((item) => Dish.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<Dish> createDish({
    required String title,
    required String description,
    required String imageUrl,
    required String cuisine,
    required List<String> tags,
  }) async {
    final data = await _apiService.post(ApiConstants.dishes, {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'cuisine': cuisine,
      'tags': tags,
    });
    return Dish.fromJson(Map<String, dynamic>.from(data));
  }
}

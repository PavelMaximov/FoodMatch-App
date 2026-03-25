import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
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
    final List<dynamic> list = data is Map<String, dynamic>
        ? (data['dishes'] as List<dynamic>? ?? <dynamic>[])
        : <dynamic>[];

    return list
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
    final dishJson = _extractMap(data, fallbackKey: 'dish');
    return Dish.fromJson(dishJson);
  }

  Map<String, dynamic> _extractMap(dynamic data, {required String fallbackKey}) {
    if (data is Map<String, dynamic>) {
      final raw = data[fallbackKey];
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      AppLogger.info('Response data: $data');
      return data;
    }
    throw const FormatException('Unexpected dish response format.');
  }
}

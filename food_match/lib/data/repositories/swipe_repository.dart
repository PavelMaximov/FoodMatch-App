import '../../core/constants/api_constants.dart';
import '../models/dish.dart';
import '../models/swipe_stats.dart';
import '../services/api_service.dart';

class SwipeRepository {
  SwipeRepository(this._apiService);

  final ApiService _apiService;

  Future<void> sendSwipe({required String dishId, required String action}) async {
    await _apiService.post(ApiConstants.swipes, {
      'dishId': dishId,
      'action': action,
    });
  }

  Future<SwipeStats> getMyStats() async {
    final data = await _apiService.get(ApiConstants.swipeStats);
    return SwipeStats.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<Dish>> getMatches() async {
    final data = await _apiService.get(ApiConstants.swipeMatches);
    return (data as List<dynamic>)
        .map((item) => Dish.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}

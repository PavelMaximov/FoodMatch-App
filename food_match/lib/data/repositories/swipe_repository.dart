import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../models/dish.dart';
import '../models/swipe_stats.dart';
import '../services/api_service.dart';

class SwipeRepository {
  SwipeRepository(this._apiService);

  final ApiService _apiService;

  Future<dynamic> sendSwipe({required String dishId, required String action}) async {
    return _apiService.post(ApiConstants.swipes, {
      'dishId': dishId,
      'action': action,
    });
  }

  Future<SwipeStats> getMyStats() async {
    final data = await _apiService.get(ApiConstants.swipeStats);
    AppLogger.info('Response data: $data');
    return SwipeStats.fromJson(_extractMap(data, fallbackKey: 'stats'));
  }

  Future<List<Dish>> getMatches() async {
    final data = await _apiService.get(ApiConstants.swipeMatches);
    final List<dynamic> list = data is Map<String, dynamic>
        ? (data['matches'] as List<dynamic>? ?? <dynamic>[])
        : <dynamic>[];

    return list
        .map((item) => Dish.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Map<String, dynamic> _extractMap(dynamic data, {required String fallbackKey}) {
    if (data is Map<String, dynamic>) {
      final raw = data[fallbackKey];
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      return data;
    }
    throw const FormatException('Unexpected map response format.');
  }
}

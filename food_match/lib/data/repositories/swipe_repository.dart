import '../../core/constants/api_constants.dart';
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
    return SwipeStats.fromJson(_extractMap(data, fallbackKey: 'stats'));
  }

  Future<List<Dish>> getMatches() async {
    final data = await _apiService.get(ApiConstants.swipeMatches);
    final list = _extractList(data, fallbackKey: 'matches');

    return list
        .map((item) => Dish.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  List<dynamic> _extractList(dynamic data, {required String fallbackKey}) {
    if (data is List<dynamic>) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final raw = data[fallbackKey] ?? data['data'];
      if (raw is List<dynamic>) {
        return raw;
      }
    }
    throw const FormatException('Unexpected list response format.');
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

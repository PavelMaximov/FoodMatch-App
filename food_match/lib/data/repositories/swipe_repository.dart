import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../models/dish.dart';
import '../models/swipe_stats.dart';
import '../services/api_service.dart';

class SwipeRepository {
  SwipeRepository(this._apiService);

  final ApiService _apiService;

  Future<dynamic> sendSwipe({required String dishId, required String direction, String? soloSessionId}) async {
    if (soloSessionId != null) {
      return _apiService.post(ApiConstants.soloSwipe(soloSessionId), {
        'dishId': dishId,
        'direction': direction,
      });
    }
    return _apiService.post(ApiConstants.swipes, {
      'dishId': dishId,
      'direction': direction,
    });
  }

  Future<dynamic> getActiveSoloSession() => _apiService.get(ApiConstants.soloSwipesActive);

  Future<dynamic> createSoloSession({required Map<String, dynamic> filter}) =>
      _apiService.post(ApiConstants.soloSwipesSession, {'filter': filter});

  Future<dynamic> abandonActiveSoloSession() =>
      _apiService.post(ApiConstants.soloSwipesAbandon, <String, dynamic>{});

  Future<dynamic> getLastFilterPreset(String mode) =>
      _apiService.get('${ApiConstants.filtersLast}?mode=$mode');

  Future<SwipeStats> getMyStats() async {
    final data = await _apiService.get(ApiConstants.swipeStats);
    AppLogger.info('Response data: $data');
    return SwipeStats.fromJson(_extractMap(data, fallbackKey: 'stats'));
  }

  Future<List<Dish>> getMatches({String mode = 'all'}) async {
    final data = await _apiService.get('${ApiConstants.swipeMatches}?mode=$mode');
    final List<dynamic> list = data is Map<String, dynamic>
        ? (data['matches'] as List<dynamic>? ?? <dynamic>[])
        : <dynamic>[];

    return list.map((dynamic item) {
      final Map<String, dynamic> matchJson = Map<String, dynamic>.from(item as Map);
      final dynamic dish = matchJson['dish'];
      if (dish is Map<String, dynamic>) {
        return Dish.fromJson(dish);
      }
      return Dish.fromJson(matchJson);
    }).toList();
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

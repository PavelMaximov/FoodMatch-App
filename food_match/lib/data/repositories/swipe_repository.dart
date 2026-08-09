import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../models/match_item.dart';
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

  Future<dynamic> undoSoloSwipe(String sessionId) =>
      _apiService.post(ApiConstants.soloSwipeUndo(sessionId), <String, dynamic>{});

  Future<dynamic> createSoloSession({required Map<String, dynamic> filter}) =>
      _apiService.post(ApiConstants.soloSwipesSession, {'filter': filter});

  Future<dynamic> updateActiveSoloFilter({required Map<String, dynamic> filter}) =>
      _apiService.patch(ApiConstants.soloSwipesActiveFilter, {'filter': filter});

  Future<dynamic> abandonActiveSoloSession() =>
      _apiService.post(ApiConstants.soloSwipesAbandon, <String, dynamic>{});

  Future<dynamic> getLastFilterPreset(String mode) =>
      _apiService.get('${ApiConstants.filtersLast}?mode=$mode');

  Future<dynamic> saveLastFilterPreset({
    required List<String> dishRegisters,
    required String mode,
    required List<String> cuisines,
    required List<String> moods,
    required List<String> diet,
    required List<String> exclusions,
    required int matchedLastTime,
  }) =>
      _apiService.put(ApiConstants.filtersLast, <String, dynamic>{
        'mode': mode,
        'dishRegisters': dishRegisters,
        'cuisines': cuisines,
        'moods': moods,
        'diet': diet,
        'exclusions': exclusions,
        'matchedLastTime': matchedLastTime,
      });

  Future<SwipeStats> getMyStats() async {
    final data = await _apiService.get(ApiConstants.swipeStats);
    AppLogger.info('Response data: $data');
    return SwipeStats.fromJson(_extractMap(data, fallbackKey: 'stats'));
  }

  Future<List<MatchItem>> getMatches({
    String mode = 'all',
    String? scope,
    String? soloSessionId,
  }) async {
    final List<String> query = <String>['mode=$mode'];
    if (scope != null && scope.isNotEmpty) {
      query.add('scope=$scope');
    }
    if (soloSessionId != null && soloSessionId.isNotEmpty) {
      query.add('sessionId=$soloSessionId');
    }
    final data = await _apiService.get('${ApiConstants.swipeMatches}?${query.join('&')}');
    final List<dynamic> list = data is Map<String, dynamic>
        ? (data['matches'] as List<dynamic>? ?? <dynamic>[])
        : <dynamic>[];

    return list.map((dynamic item) {
      final Map<String, dynamic> matchJson = Map<String, dynamic>.from(item as Map);
      return MatchItem.fromJson(matchJson);
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

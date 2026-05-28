import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../models/couple.dart';
import '../models/couple_filter_state.dart';
import '../services/api_service.dart';

class CoupleRepository {
  CoupleRepository(this._apiService);

  final ApiService _apiService;

  Future<Couple> create() async {
    final data = await _apiService.post(ApiConstants.coupleCreate, {});
    return Couple.fromJson(_extractSessionMap(data));
  }

  Future<Couple> join(String inviteCode) async {
    final data = await _apiService.post(ApiConstants.coupleJoin, {'inviteCode': inviteCode});
    return Couple.fromJson(_extractSessionMap(data));
  }

  Future<Couple?> getMyCouple() async {
    final data = await _apiService.get(ApiConstants.coupleMe);
    if (data is Map<String, dynamic>) {
      final dynamic session = data['session'] ?? data['couple'];
      if (session == null) return null;
      if (session is Map<String, dynamic>) return Couple.fromJson(session);
    }
    AppLogger.info('Unexpected couple/me response data: $data');
    return Couple.fromJson(_extractSessionMap(data));
  }

  Future<void> reset() async => _apiService.post(ApiConstants.coupleReset, {});
  Future<void> leave() async => _apiService.post(ApiConstants.coupleLeave, {});

  Future<CoupleFilterState> getFilterState() async => CoupleFilterState.fromJson(await _apiService.get(ApiConstants.coupleFilterState) as Map<String, dynamic>);
  Future<CoupleFilterState> updateMyFilterState(CoupleFilterChoices choices) async => CoupleFilterState.fromJson(await _apiService.put(ApiConstants.coupleFilterStateMe, choices.toJson()) as Map<String, dynamic>);
  Future<CoupleFilterState> confirmMyFilterState() async => CoupleFilterState.fromJson(await _apiService.post(ApiConstants.coupleFilterStateConfirm, {}) as Map<String, dynamic>);
  Future<CoupleFilterState> resetFilterState() async => CoupleFilterState.fromJson(await _apiService.post(ApiConstants.coupleFilterStateReset, {}) as Map<String, dynamic>);

  Map<String, dynamic> _extractSessionMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final dynamic raw = data['session'] ?? data['couple'];
      if (raw is Map<String, dynamic>) return raw;
      return data;
    }
    throw const FormatException('Unexpected couple response format.');
  }
}

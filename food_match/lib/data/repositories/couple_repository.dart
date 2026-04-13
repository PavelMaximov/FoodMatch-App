import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../models/couple.dart';
import '../services/api_service.dart';

class CoupleRepository {
  CoupleRepository(this._apiService);

  final ApiService _apiService;

  Future<Couple> create() async {
    final data = await _apiService.post(ApiConstants.coupleCreate, {});
    return Couple.fromJson(_extractSessionMap(data));
  }

  Future<Couple> join(String inviteCode) async {
    final data = await _apiService.post(ApiConstants.coupleJoin, {
      'inviteCode': inviteCode,
    });
    return Couple.fromJson(_extractSessionMap(data));
  }

  Future<Couple?> getMyCouple() async {
    final data = await _apiService.get(ApiConstants.coupleMe);
    if (data is Map<String, dynamic>) {
      final dynamic session = data['session'] ?? data['couple'];
      if (session == null) {
        return null;
      }

      if (session is Map<String, dynamic>) {
        return Couple.fromJson(session);
      }
    }

    AppLogger.info('Unexpected couple/me response data: $data');
    return Couple.fromJson(_extractSessionMap(data));
  }

  Future<void> reset() async {
    await _apiService.post(ApiConstants.coupleReset, {});
  }

  Future<void> leave() async {
    await _apiService.post(ApiConstants.coupleLeave, {});
  }

  Map<String, dynamic> _extractSessionMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final dynamic raw = data['session'] ?? data['couple'];
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      return data;
    }
    throw const FormatException('Unexpected couple response format.');
  }
}

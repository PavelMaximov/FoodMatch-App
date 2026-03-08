import '../../core/constants/api_constants.dart';
import '../models/couple.dart';
import '../services/api_service.dart';

class CoupleRepository {
  CoupleRepository(this._apiService);

  final ApiService _apiService;

  Future<Couple> create() async {
    final data = await _apiService.post(ApiConstants.coupleCreate, {});
    return Couple.fromJson(_extractMap(data, fallbackKey: 'couple'));
  }

  Future<Couple> join(String inviteCode) async {
    final data = await _apiService.post(ApiConstants.coupleJoin, {
      'inviteCode': inviteCode,
    });
    return Couple.fromJson(_extractMap(data, fallbackKey: 'couple'));
  }

  Future<Couple> getMyCouple() async {
    final data = await _apiService.get(ApiConstants.coupleMe);
    return Couple.fromJson(_extractMap(data, fallbackKey: 'couple'));
  }

  Future<void> reset() async {
    await _apiService.post(ApiConstants.coupleReset, {});
  }

  Future<void> leave() async {
    await _apiService.post(ApiConstants.coupleLeave, {});
  }

  Map<String, dynamic> _extractMap(dynamic data, {required String fallbackKey}) {
    if (data is Map<String, dynamic>) {
      final raw = data[fallbackKey];
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      return data;
    }
    throw const FormatException('Unexpected couple response format.');
  }
}

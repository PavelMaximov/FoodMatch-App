import '../../core/constants/api_constants.dart';
import '../models/match_history.dart';
import '../services/api_service.dart';

class MatchHistoryRepository {
  MatchHistoryRepository(this._apiService);
  final ApiService _apiService;

  Future<MatchHistory> getHistory() async {
    final dynamic response = await _apiService.get(ApiConstants.matchHistory);
    if (response is! Map) {
      throw const FormatException('Unexpected match history response.');
    }
    return MatchHistory.fromJson(Map<String, dynamic>.from(response));
  }

  Future<MatchHistorySession?> getSession(String sessionId) async {
    final dynamic response = await _apiService.get('${ApiConstants.matchHistory}/$sessionId');
    if (response is! Map || response['session'] is! Map) return null;
    final json = Map<String, dynamic>.from(response['session'] as Map);
    return MatchHistorySession.fromJson(json, json['mode'] == 'pair' ? MatchHistoryMode.pair : MatchHistoryMode.solo);
  }
}

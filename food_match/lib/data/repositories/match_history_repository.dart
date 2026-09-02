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
    final MatchHistory history = await getHistory();
    for (final MatchHistorySession session in <MatchHistorySession>[
      ...history.solo,
      ...history.pair,
    ]) {
      if (session.sessionId == sessionId) return session;
    }
    return null;
  }
}

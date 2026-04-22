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

  Future<SessionFilterState?> getFilterState() async {
    final dynamic data = await _apiService.get(ApiConstants.coupleFilterState);
    if (data is Map<String, dynamic>) {
      final dynamic raw = data['filterState'];
      if (raw is Map<String, dynamic>) {
        return SessionFilterState.fromJson(raw);
      }
    }
    return null;
  }

  Future<SessionFilterState> updateFilterState({
    required int step,
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
    required List<String> diet,
    required bool confirmed,
  }) async {
    final dynamic data = await _apiService.post(ApiConstants.coupleFilterState, <String, dynamic>{
      'step': step,
      'cuisines': cuisines,
      'moods': moods,
      'blocked': blocked,
      'diet': diet,
      'confirmed': confirmed,
    });
    if (data is Map<String, dynamic> && data['filterState'] is Map<String, dynamic>) {
      return SessionFilterState.fromJson(data['filterState'] as Map<String, dynamic>);
    }
    throw const FormatException('Unexpected filter state response format.');
  }

  Future<void> clearFilterState() async {
    await _apiService.delete(ApiConstants.coupleFilterState);
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

class SessionFilterDraft {
  const SessionFilterDraft({
    required this.userId,
    this.cuisines = const <String>[],
    this.moods = const <String>[],
    this.blocked = const <String>[],
    this.diet = const <String>[],
    this.confirmed = false,
  });

  final String userId;
  final List<String> cuisines;
  final List<String> moods;
  final List<String> blocked;
  final List<String> diet;
  final bool confirmed;

  factory SessionFilterDraft.fromJson(Map<String, dynamic> json) => SessionFilterDraft(
        userId: json['userId']?.toString() ?? '',
        cuisines: (json['cuisines'] as List<dynamic>? ?? const <dynamic>[]).map((dynamic e) => e.toString()).toList(),
        moods: (json['moods'] as List<dynamic>? ?? const <dynamic>[]).map((dynamic e) => e.toString()).toList(),
        blocked: (json['blocked'] as List<dynamic>? ?? const <dynamic>[]).map((dynamic e) => e.toString()).toList(),
        diet: (json['diet'] as List<dynamic>? ?? const <dynamic>[]).map((dynamic e) => e.toString()).toList(),
        confirmed: json['confirmed'] == true,
      );
}

class SessionFilterState {
  const SessionFilterState({
    required this.step,
    this.drafts = const <SessionFilterDraft>[],
    this.compatibility = 0,
  });

  final int step;
  final List<SessionFilterDraft> drafts;
  final int compatibility;

  factory SessionFilterState.fromJson(Map<String, dynamic> json) => SessionFilterState(
        step: (json['step'] as num?)?.toInt() ?? 1,
        drafts: (json['drafts'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(SessionFilterDraft.fromJson)
            .toList(),
        compatibility: (json['compatibility'] as num?)?.toInt() ?? 0,
      );
}

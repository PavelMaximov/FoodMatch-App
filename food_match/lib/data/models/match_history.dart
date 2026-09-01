import 'dish.dart';

enum MatchHistoryMode { solo, pair }

class MatchHistorySession {
  const MatchHistorySession({
    required this.sessionId,
    required this.mode,
    required this.startedAt,
    required this.completedAt,
    required this.partnerName,
    required this.dishCount,
    required this.previewDishes,
    required this.dishes,
  });

  final String sessionId;
  final MatchHistoryMode mode;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? partnerName;
  final int dishCount;
  final List<Dish> previewDishes;
  final List<Dish> dishes;

  factory MatchHistorySession.fromJson(
    Map<String, dynamic> json,
    MatchHistoryMode mode,
  ) {
    List<Dish> readDishes(String key) =>
        (json[key] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((Map value) => Dish.fromJson(Map<String, dynamic>.from(value)))
            .toList();
    return MatchHistorySession(
      sessionId: json['sessionId'] as String? ?? '',
      mode: mode,
      startedAt:
          DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime(0),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      partnerName: json['partnerName'] as String?,
      dishCount: (json['dishCount'] as num?)?.toInt() ?? 0,
      previewDishes: readDishes('previewDishes'),
      dishes: readDishes('dishes'),
    );
  }
}

class MatchHistory {
  const MatchHistory({required this.solo, required this.pair});
  final List<MatchHistorySession> solo;
  final List<MatchHistorySession> pair;

  factory MatchHistory.fromJson(Map<String, dynamic> json) {
    List<MatchHistorySession> read(String key, MatchHistoryMode mode) =>
        (json[key] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (Map value) => MatchHistorySession.fromJson(
                Map<String, dynamic>.from(value),
                mode,
              ),
            )
            .toList();
    return MatchHistory(
      solo: read('solo', MatchHistoryMode.solo),
      pair: read('pair', MatchHistoryMode.pair),
    );
  }
}

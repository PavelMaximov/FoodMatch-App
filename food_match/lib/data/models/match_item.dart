import 'dish.dart';

class MatchItem {
  const MatchItem({
    required this.dish,
    required this.mode,
    required this.matchType,
    this.id,
    this.sessionId,
    this.coupleId,
    this.createdAt,
  });

  final String? id;
  final Dish dish;
  final String mode;
  final String matchType;
  final String? sessionId;
  final String? coupleId;
  final DateTime? createdAt;

  factory MatchItem.fromJson(Map<String, dynamic> json) {
    final dynamic rawDish = json['dish'];
    final Map<String, dynamic> dishJson = rawDish is Map
        ? Map<String, dynamic>.from(rawDish)
        : Map<String, dynamic>.from(json);
    final String mode = json['mode']?.toString() == 'paired' ? 'paired' : 'solo';
    final String matchType = json['matchType']?.toString() ??
        (mode == 'paired' ? 'pair_match' : 'solo_pick');
    return MatchItem(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      dish: Dish.fromJson(dishJson),
      mode: mode,
      matchType: matchType,
      sessionId: json['sessionId']?.toString(),
      coupleId: json['coupleId']?.toString(),
      createdAt: _parseDate(json['createdAt']),
    );
  }

  factory MatchItem.fromCachedDish(Dish dish, String mode) {
    final String normalizedMode = mode == 'paired' ? 'paired' : 'solo';
    return MatchItem(
      dish: dish,
      mode: normalizedMode,
      matchType: normalizedMode == 'paired' ? 'pair_match' : 'solo_pick',
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

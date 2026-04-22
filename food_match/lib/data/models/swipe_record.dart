class SwipeRecord {
  const SwipeRecord({
    required this.dishId,
    required this.direction,
    required this.timestamp,
  });

  final String dishId;
  final String direction;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'dishId': dishId,
        'direction': direction,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SwipeRecord.fromJson(Map<dynamic, dynamic> json) => SwipeRecord(
        dishId: json['dishId']?.toString() ?? '',
        direction: json['direction']?.toString() ?? '',
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      );
}

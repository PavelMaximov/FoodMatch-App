import 'dish.dart';

class PreparedDeck {
  const PreparedDeck({
    required this.status,
    required this.dishes,
    required this.meta,
  });

  final String status;
  final List<Dish> dishes;
  final PreparedDeckMeta meta;

  bool get isReady => status == 'ready';

  factory PreparedDeck.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawDishes = json['dishes'] is List<dynamic>
        ? json['dishes'] as List<dynamic>
        : <dynamic>[];
    final Map<String, dynamic> rawMeta = json['meta'] is Map
        ? Map<String, dynamic>.from(json['meta'] as Map)
        : <String, dynamic>{};

    return PreparedDeck(
      status: (json['status'] ?? 'idle').toString(),
      dishes: rawDishes
          .whereType<Map>()
          .map((Map item) => Dish.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      meta: PreparedDeckMeta.fromJson(rawMeta),
    );
  }
}

class PreparedDeckMeta {
  const PreparedDeckMeta({
    required this.totalCatalogCount,
    required this.candidateCount,
    required this.finalCount,
    this.filtersHash,
    this.generatedAt,
    this.fallbackReason,
    required this.usedPartnerChoices,
    required this.bothConfirmed,
    this.expansionApplied = false,
    this.expansionLevel = 'none',
  });

  final int totalCatalogCount;
  final int candidateCount;
  final int finalCount;
  final String? filtersHash;
  final DateTime? generatedAt;
  final String? fallbackReason;
  final bool usedPartnerChoices;
  final bool bothConfirmed;
  final bool expansionApplied;
  final String expansionLevel;

  factory PreparedDeckMeta.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> recommendation = json['recommendationMeta'] is Map
        ? Map<String, dynamic>.from(json['recommendationMeta'] as Map)
        : const <String, dynamic>{};
    return PreparedDeckMeta(
      totalCatalogCount: _readInt(json['totalCatalogCount']),
      candidateCount: _readInt(json['candidateCount']),
      finalCount: _readInt(json['finalCount']),
      filtersHash: _readNullableString(json['filtersHash']),
      generatedAt: DateTime.tryParse(_readNullableString(json['generatedAt']) ?? ''),
      fallbackReason: _readNullableString(json['fallbackReason']),
      usedPartnerChoices: json['usedPartnerChoices'] == true,
      bothConfirmed: json['bothConfirmed'] == true,
      expansionApplied: json['expansionApplied'] == true || recommendation['expansionApplied'] == true,
      expansionLevel: (json['expansionLevel'] ?? recommendation['expansionLevel'] ?? 'none').toString(),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _readNullableString(dynamic value) {
    final String text = (value ?? '').toString();
    return text.isEmpty ? null : text;
  }
}

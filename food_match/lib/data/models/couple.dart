class Couple {
  const Couple({
    required this.id,
    required this.inviteCode,
    required this.members,
  });

  final String id;
  final String inviteCode;
  final List<String> members;

  factory Couple.fromJson(Map<String, dynamic> json) {
    final dynamic idRaw = json['_id'] ?? json['id'];
    final List<String> parsedMembers = (json['members'] as List<dynamic>? ?? <dynamic>[])
        .map(_parseMemberId)
        .whereType<String>()
        .toList();

    return Couple(
      id: idRaw?.toString() ?? '',
      inviteCode: json['inviteCode']?.toString() ?? '',
      members: parsedMembers,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        '_id': id,
        'inviteCode': inviteCode,
        'members': members,
      };

  static String? _parseMemberId(dynamic rawMember) {
    if (rawMember == null) {
      return null;
    }

    if (rawMember is String) {
      return rawMember;
    }

    if (rawMember is Map<String, dynamic>) {
      final dynamic idRaw = rawMember['_id'] ?? rawMember['id'];
      return idRaw?.toString();
    }

    if (rawMember is Map) {
      final dynamic idRaw = rawMember['_id'] ?? rawMember['id'];
      return idRaw?.toString();
    }

    return rawMember.toString();
  }
}

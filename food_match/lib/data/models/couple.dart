class Couple {
  const Couple({
    required this.id,
    required this.inviteCode,
    required this.members,
    required this.memberProfiles,
  });

  final String id;
  final String inviteCode;
  final List<String> members;
  final List<CoupleMemberProfile> memberProfiles;

  factory Couple.fromJson(Map<String, dynamic> json) {
    final dynamic idRaw = json['_id'] ?? json['id'];
    final List<dynamic> rawMembers = json['members'] as List<dynamic>? ?? <dynamic>[];
    final List<CoupleMemberProfile> parsedProfiles = rawMembers
        .map(CoupleMemberProfile.fromRaw)
        .whereType<CoupleMemberProfile>()
        .toList();

    final List<String> parsedMembers = parsedProfiles
        .map((CoupleMemberProfile member) => member.id)
        .where((String id) => id.isNotEmpty)
        .toList();

    return Couple(
      id: idRaw?.toString() ?? '',
      inviteCode: json['inviteCode']?.toString() ?? '',
      members: parsedMembers,
      memberProfiles: parsedProfiles,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        '_id': id,
        'inviteCode': inviteCode,
        'members': members,
        'memberProfiles': memberProfiles.map((CoupleMemberProfile p) => p.toJson()).toList(),
      };
}

class CoupleMemberProfile {
  const CoupleMemberProfile({
    required this.id,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String? displayName;
  final String? avatarUrl;

  static CoupleMemberProfile? fromRaw(dynamic rawMember) {
    if (rawMember == null) {
      return null;
    }

    if (rawMember is String) {
      return CoupleMemberProfile(id: rawMember);
    }

    if (rawMember is Map<String, dynamic>) {
      final dynamic idRaw = rawMember['_id'] ?? rawMember['id'];
      return CoupleMemberProfile(
        id: idRaw?.toString() ?? '',
        displayName: rawMember['displayName']?.toString(),
        avatarUrl: rawMember['avatarUrl']?.toString(),
      );
    }

    if (rawMember is Map) {
      final dynamic idRaw = rawMember['_id'] ?? rawMember['id'];
      return CoupleMemberProfile(
        id: idRaw?.toString() ?? '',
        displayName: rawMember['displayName']?.toString(),
        avatarUrl: rawMember['avatarUrl']?.toString(),
      );
    }

    return CoupleMemberProfile(id: rawMember.toString());
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
      };
}

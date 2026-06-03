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
    this.name,
    this.username,
    this.email,
    this.avatarUrl,
  });

  final String id;
  final String? displayName;
  final String? name;
  final String? username;
  final String? email;
  final String? avatarUrl;

  static CoupleMemberProfile? fromRaw(dynamic rawMember) {
    if (rawMember == null) {
      return null;
    }

    if (rawMember is String) {
      return CoupleMemberProfile(id: rawMember);
    }

    if (rawMember is Map<String, dynamic>) {
      return _fromMap(rawMember);
    }

    if (rawMember is Map) {
      return _fromMap(Map<String, dynamic>.from(rawMember));
    }

    return CoupleMemberProfile(id: rawMember.toString());
  }

  static CoupleMemberProfile _fromMap(Map<String, dynamic> rawMember) {
    final dynamic idRaw = rawMember['_id'] ?? rawMember['id'] ?? rawMember['userId'];
    return CoupleMemberProfile(
      id: idRaw?.toString() ?? '',
      displayName: rawMember['displayName']?.toString(),
      name: rawMember['name']?.toString(),
      username: rawMember['username']?.toString(),
      email: rawMember['email']?.toString(),
      avatarUrl: rawMember['avatarUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'displayName': displayName,
        'name': name,
        'username': username,
        'email': email,
        'avatarUrl': avatarUrl,
      };
}

CoupleMemberProfile? resolvePartnerProfile({
  required Couple? couple,
  required String? currentUserId,
}) {
  final List<CoupleMemberProfile> profiles = couple?.memberProfiles ?? const <CoupleMemberProfile>[];
  if (profiles.isEmpty) {
    return null;
  }

  final String normalizedCurrentUserId = currentUserId?.trim() ?? '';
  for (final CoupleMemberProfile member in profiles) {
    final String memberId = member.id.trim();
    if (memberId.isEmpty) {
      continue;
    }
    if (normalizedCurrentUserId.isNotEmpty && memberId == normalizedCurrentUserId) {
      continue;
    }
    return member;
  }

  return null;
}

String resolvePartnerDisplayName({
  required Couple? couple,
  required String? currentUserId,
  String fallback = 'your partner',
}) {
  final CoupleMemberProfile? partner = resolvePartnerProfile(
    couple: couple,
    currentUserId: currentUserId,
  );
  if (partner == null) {
    return fallback;
  }

  final List<String?> candidates = <String?>[
    partner.displayName,
    partner.name,
    partner.username,
    _emailPrefix(partner.email),
  ];

  for (final String? candidate in candidates) {
    final String value = candidate?.trim() ?? '';
    if (value.isNotEmpty && !_looksLikeRawId(value)) {
      return value;
    }
  }

  return fallback;
}

String? _emailPrefix(String? email) {
  final String value = email?.trim() ?? '';
  if (value.isEmpty || !value.contains('@')) {
    return null;
  }
  return value.split('@').first;
}

bool _looksLikeRawId(String value) {
  final String trimmed = value.trim();
  if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(trimmed)) {
    return true;
  }
  if (RegExp(r'^[0-9]+$').hasMatch(trimmed) && trimmed.length >= 12) {
    return true;
  }
  return false;
}

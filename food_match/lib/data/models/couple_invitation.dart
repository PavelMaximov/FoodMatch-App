class CoupleInvitationUser {
  const CoupleInvitationUser({required this.id, required this.displayName, this.avatarUrl});

  final String id;
  final String displayName;
  final String? avatarUrl;

  factory CoupleInvitationUser.fromJson(Map<String, dynamic>? json) => CoupleInvitationUser(
        id: json?['id']?.toString() ?? '',
        displayName: json?['displayName']?.toString() ?? 'Partner',
        avatarUrl: json?['avatarUrl']?.toString(),
      );
}

class CoupleInvitation {
  const CoupleInvitation({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.direction,
    required this.status,
    required this.mode,
    required this.fromUser,
    required this.toUser,
    this.matchedLastTime,
    this.mutualMatchCount,
    this.expiresAt,
    this.sessionActive = false,
  });

  final String id;
  final String fromUserId;
  final String toUserId;
  final String direction;
  final String status;
  final String mode;
  final CoupleInvitationUser fromUser;
  final CoupleInvitationUser toUser;
  final int? matchedLastTime;
  final int? mutualMatchCount;
  final DateTime? expiresAt;
  final bool sessionActive;

  bool get isIncoming => direction == 'incoming';
  bool get isOutgoing => direction == 'outgoing';
  bool get isPending => status == 'pending';

  factory CoupleInvitation.fromJson(Map<String, dynamic> json) => CoupleInvitation(
        id: json['id']?.toString() ?? '',
        fromUserId: json['fromUserId']?.toString() ?? '',
        toUserId: json['toUserId']?.toString() ?? '',
        direction: json['direction']?.toString() ?? 'incoming',
        status: json['status']?.toString() ?? 'pending',
        mode: json['mode']?.toString() ?? 'paired',
        fromUser: CoupleInvitationUser.fromJson(json['fromUser'] is Map<String, dynamic> ? json['fromUser'] as Map<String, dynamic> : null),
        toUser: CoupleInvitationUser.fromJson(json['toUser'] is Map<String, dynamic> ? json['toUser'] as Map<String, dynamic> : null),
        matchedLastTime: (json['matchedLastTime'] as num?)?.toInt(),
        mutualMatchCount: (json['mutualMatchCount'] as num?)?.toInt(),
        expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
        sessionActive: json['sessionActive'] == true,
      );
}

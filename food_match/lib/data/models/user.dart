import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    this.coupleId,
    this.avatarUrl,
    this.avatarPublicId,
    this.emailVerified = true,
  });

  @JsonKey(name: '_id', readValue: _readId)
  final String id;
  final String email;
  final String displayName;
  @JsonKey(name: 'coupleId')
  final String? coupleId;
  final String? avatarUrl;
  final String? avatarPublicId;
  final bool emailVerified;

  static Object? _readId(Map<dynamic, dynamic> json, String _) {
    return json['_id'] ?? json['id'];
  }

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? coupleId,
    String? avatarUrl,
    String? avatarPublicId,
    bool? emailVerified,
    bool clearAvatar = false,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      coupleId: coupleId ?? this.coupleId,
      avatarUrl: clearAvatar ? null : avatarUrl ?? this.avatarUrl,
      avatarPublicId: clearAvatar ? null : avatarPublicId ?? this.avatarPublicId,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
}

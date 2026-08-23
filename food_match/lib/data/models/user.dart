import 'package:json_annotation/json_annotation.dart';
import 'measurement_system.dart';

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
    this.measurementSystemPreference = MeasurementSystemPreference.auto,
  });

  @JsonKey(name: '_id', readValue: _readId)
  final String id;
  final String email;
  @JsonKey(readValue: _readCamelOrSnake)
  final String displayName;
  @JsonKey(name: 'coupleId')
  final String? coupleId;
  @JsonKey(readValue: _readCamelOrSnake)
  final String? avatarUrl;
  @JsonKey(readValue: _readCamelOrSnake)
  final String? avatarPublicId;
  @JsonKey(readValue: _readCamelOrSnake)
  final bool emailVerified;
  @JsonKey(readValue: _readCamelOrSnake)
  final MeasurementSystemPreference measurementSystemPreference;

  static Object? _readId(Map<dynamic, dynamic> json, String _) {
    return json['_id'] ?? json['id'];
  }

  static Object? _readCamelOrSnake(Map<dynamic, dynamic> json, String key) {
    final String snake = key.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (Match match) => '_${match.group(0)!.toLowerCase()}',
    );
    return json[key] ?? json[snake];
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
    MeasurementSystemPreference? measurementSystemPreference,
    bool clearAvatar = false,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      coupleId: coupleId ?? this.coupleId,
      avatarUrl: clearAvatar ? null : avatarUrl ?? this.avatarUrl,
      avatarPublicId: clearAvatar
          ? null
          : avatarPublicId ?? this.avatarPublicId,
      emailVerified: emailVerified ?? this.emailVerified,
      measurementSystemPreference:
          measurementSystemPreference ?? this.measurementSystemPreference,
    );
  }
}

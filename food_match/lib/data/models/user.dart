import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    this.coupleId,
  });

  @JsonKey(name: '_id', readValue: _readId)
  final String id;
  final String email;
  final String displayName;
  final String? coupleId;

  static Object? _readId(Map<dynamic, dynamic> json, String _) {
    return json['_id'] ?? json['id'];
  }

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);
}

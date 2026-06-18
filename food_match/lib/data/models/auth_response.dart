import 'package:json_annotation/json_annotation.dart';

import 'user.dart';

part 'auth_response.g.dart';

@JsonSerializable()
class AuthResponse {
  const AuthResponse({
    required this.token,
    this.accessToken,
    this.refreshToken,
    this.user,
    this.requireEmailVerification = false,
  });

  final String token;
  final String? accessToken;
  final String? refreshToken;
  final User? user;
  final bool requireEmailVerification;

  String get effectiveAccessToken => accessToken ?? token;

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}

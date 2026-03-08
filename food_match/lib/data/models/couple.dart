import 'package:json_annotation/json_annotation.dart';

part 'couple.g.dart';

@JsonSerializable()
class Couple {
  const Couple({
    required this.id,
    required this.inviteCode,
    required this.members,
  });

  @JsonKey(name: '_id')
  final String id;
  final String inviteCode;
  final List<String> members;

  factory Couple.fromJson(Map<String, dynamic> json) => _$CoupleFromJson(json);

  Map<String, dynamic> toJson() => _$CoupleToJson(this);
}

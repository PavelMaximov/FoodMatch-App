import 'package:json_annotation/json_annotation.dart';

part 'swipe.g.dart';

@JsonSerializable()
class Swipe {
  const Swipe({
    required this.id,
    required this.userId,
    required this.coupleId,
    required this.dishId,
    required this.action,
  });

  @JsonKey(name: '_id')
  final String id;
  final String userId;
  final String coupleId;
  final String dishId;
  final String action;

  factory Swipe.fromJson(Map<String, dynamic> json) => _$SwipeFromJson(json);

  Map<String, dynamic> toJson() => _$SwipeToJson(this);
}

import 'package:json_annotation/json_annotation.dart';

part 'swipe_stats.g.dart';

@JsonSerializable()
class SwipeStats {
  const SwipeStats({required this.likes, required this.dislikes});

  final int likes;
  final int dislikes;

  factory SwipeStats.fromJson(Map<String, dynamic> json) =>
      _$SwipeStatsFromJson(json);

  Map<String, dynamic> toJson() => _$SwipeStatsToJson(this);
}

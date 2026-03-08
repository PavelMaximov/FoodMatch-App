// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'swipe_stats.dart';

SwipeStats _$SwipeStatsFromJson(Map<String, dynamic> json) => SwipeStats(
      likes: (json['likes'] as num).toInt(),
      dislikes: (json['dislikes'] as num).toInt(),
    );

Map<String, dynamic> _$SwipeStatsToJson(SwipeStats instance) =>
    <String, dynamic>{
      'likes': instance.likes,
      'dislikes': instance.dislikes,
    };

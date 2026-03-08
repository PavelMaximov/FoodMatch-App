// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'swipe.dart';

Swipe _$SwipeFromJson(Map<String, dynamic> json) => Swipe(
      id: json['_id'] as String,
      userId: json['userId'] as String,
      coupleId: json['coupleId'] as String,
      dishId: json['dishId'] as String,
      action: json['action'] as String,
    );

Map<String, dynamic> _$SwipeToJson(Swipe instance) => <String, dynamic>{
      '_id': instance.id,
      'userId': instance.userId,
      'coupleId': instance.coupleId,
      'dishId': instance.dishId,
      'action': instance.action,
    };

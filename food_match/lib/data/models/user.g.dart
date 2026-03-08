// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: User._readId(json, '_id') as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      coupleId: json['coupleId'] as String?,
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      '_id': instance.id,
      'email': instance.email,
      'displayName': instance.displayName,
      'coupleId': instance.coupleId,
    };

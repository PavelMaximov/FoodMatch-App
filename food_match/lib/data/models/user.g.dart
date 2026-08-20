// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: User._readId(json, '_id') as String,
      email: json['email'] as String,
      displayName: User._readCamelOrSnake(json, 'displayName') as String,
      coupleId: json['coupleId'] as String?,
      avatarUrl: User._readCamelOrSnake(json, 'avatarUrl') as String?,
      avatarPublicId: User._readCamelOrSnake(json, 'avatarPublicId') as String?,
      emailVerified: User._readCamelOrSnake(json, 'emailVerified') as bool? ?? true,
      measurementSystemPreference: MeasurementSystemPreferenceValue.parse(User._readCamelOrSnake(json, 'measurementSystemPreference')),
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      '_id': instance.id,
      'email': instance.email,
      'displayName': instance.displayName,
      'coupleId': instance.coupleId,
      'avatarUrl': instance.avatarUrl,
      'avatarPublicId': instance.avatarPublicId,
      'emailVerified': instance.emailVerified,
      'measurementSystemPreference': instance.measurementSystemPreference.value,
    };

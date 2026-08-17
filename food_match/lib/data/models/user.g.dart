// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: User._readId(json, '_id') as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      coupleId: json['coupleId'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      avatarPublicId: json['avatarPublicId'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? true,
      measurementSystemPreference: MeasurementSystemPreferenceValue.parse(json['measurementSystemPreference']),
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

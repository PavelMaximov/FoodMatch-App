// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'couple.dart';

Couple _$CoupleFromJson(Map<String, dynamic> json) => Couple(
      id: json['_id'] as String,
      inviteCode: json['inviteCode'] as String,
      members:
          (json['members'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$CoupleToJson(Couple instance) => <String, dynamic>{
      '_id': instance.id,
      'inviteCode': instance.inviteCode,
      'members': instance.members,
    };

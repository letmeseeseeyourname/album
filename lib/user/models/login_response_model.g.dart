// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_response_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginResponseModel _$LoginResponseModelFromJson(Map<String, dynamic> json) =>
    LoginResponseModel(
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      tokenType: json['tokenType'] as String?,
      expiresIn: (json['expiresIn'] as num?)?.toInt(),
      user: json['user'] == null
          ? null
          : User.fromJson(json['user'] as Map<String, dynamic>),
      groupDeviceUser: json['groupDeviceUser'],
      groupMemberCount: (json['groupMemberCount'] as num?)?.toInt(),
      p2pUsername: json['p2pUsername'] as String?,
      mgroupDeviceUsers: json['mgroupDeviceUsers'] as List<dynamic>?,
      firstLogin: json['firstLogin'] as bool?,
    );

Map<String, dynamic> _$LoginResponseModelToJson(LoginResponseModel instance) =>
    <String, dynamic>{
      'accessToken': instance.accessToken,
      'refreshToken': instance.refreshToken,
      'tokenType': instance.tokenType,
      'expiresIn': instance.expiresIn,
      'user': instance.user,
      'groupDeviceUser': instance.groupDeviceUser,
      'groupMemberCount': instance.groupMemberCount,
      'p2pUsername': instance.p2pUsername,
      'mgroupDeviceUsers': instance.mgroupDeviceUsers,
      'firstLogin': instance.firstLogin,
    };

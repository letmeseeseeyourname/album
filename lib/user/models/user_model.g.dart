// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
      UserInfo.fromJson(json['userInfo'] as Map<String, dynamic>),
      json['json'] as String,
      (json['regFlag'] as num).toInt(),
    );

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
      'userInfo': instance.userInfo,
      'json': instance.json,
      'regFlag': instance.regFlag,
    };

UserInfo _$UserInfoFromJson(Map<String, dynamic> json) => UserInfo(
      (json['userId'] as num).toInt(),
      json['nickName'] as String,
      json['mobile'] as String,
      json['email'] as String,
      json['password'] as String,
      (json['configCodeId'] as num).toInt(),
      json['birthDate'] as String,
      json['sex'] as String,
      json['countryCode'] as String,
      json['countryName'] as String,
      json['provinceCode'] as String,
      json['provinceName'] as String,
      json['cityCode'] as String,
      json['cityName'] as String,
      json['districtCode'] as String,
      json['districtName'] as String,
      json['address'] as String,
      json['headUrl'] as String,
      json['createdDate'] as String,
      json['updatedDate'] as String,
      (json['roleId'] as num).toInt(),
      json['roleName'] as String,
    );

Map<String, dynamic> _$UserInfoToJson(UserInfo instance) => <String, dynamic>{
      'userId': instance.userId,
      'nickName': instance.nickName,
      'mobile': instance.mobile,
      'email': instance.email,
      'password': instance.password,
      'configCodeId': instance.configCodeId,
      'birthDate': instance.birthDate,
      'sex': instance.sex,
      'countryCode': instance.countryCode,
      'countryName': instance.countryName,
      'provinceCode': instance.provinceCode,
      'provinceName': instance.provinceName,
      'cityCode': instance.cityCode,
      'cityName': instance.cityName,
      'districtCode': instance.districtCode,
      'districtName': instance.districtName,
      'address': instance.address,
      'headUrl': instance.headUrl,
      'createdDate': instance.createdDate,
      'updatedDate': instance.updatedDate,
      'roleId': instance.roleId,
      'roleName': instance.roleName,
    };

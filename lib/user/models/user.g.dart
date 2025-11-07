// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: (json['id'] as num?)?.toInt(),
      nickName: json['nickName'] as String?,
      mobile: json['mobile'] as String?,
      email: json['email'],
      password: json['password'] as String?,
      configCodeId: json['configCodeId'],
      birthDate: json['birthDate'] as String?,
      sex: json['sex'] as String?,
      countryCode: json['countryCode'] as String?,
      provinceCode: json['provinceCode'] as String?,
      cityCode: json['cityCode'] as String?,
      districtCode: json['districtCode'] as String?,
      deviceCode: json['deviceCode'] as String?,
      address: json['address'] as String?,
      headUrl: json['headUrl'],
      createdDate: json['createdDate'] as String?,
      updatedDate: json['updatedDate'] as String?,
      createdBy: json['createdBy'],
      updatedBy: json['updatedBy'],
      deletedFlag: json['deletedFlag'],
      username: json['username'] as String?,
      status: (json['status'] as num?)?.toInt(),
      enabled: json['enabled'] as bool?,
      authorities: json['authorities'] as List<dynamic>?,
      accountNonExpired: json['accountNonExpired'] as bool?,
      accountNonLocked: json['accountNonLocked'] as bool?,
      credentialsNonExpired: json['credentialsNonExpired'] as bool?,
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'nickName': instance.nickName,
      'mobile': instance.mobile,
      'email': instance.email,
      'password': instance.password,
      'configCodeId': instance.configCodeId,
      'birthDate': instance.birthDate,
      'sex': instance.sex,
      'countryCode': instance.countryCode,
      'provinceCode': instance.provinceCode,
      'cityCode': instance.cityCode,
      'districtCode': instance.districtCode,
      'deviceCode': instance.deviceCode,
      'address': instance.address,
      'headUrl': instance.headUrl,
      'createdDate': instance.createdDate,
      'updatedDate': instance.updatedDate,
      'createdBy': instance.createdBy,
      'updatedBy': instance.updatedBy,
      'deletedFlag': instance.deletedFlag,
      'username': instance.username,
      'status': instance.status,
      'enabled': instance.enabled,
      'authorities': instance.authorities,
      'accountNonExpired': instance.accountNonExpired,
      'accountNonLocked': instance.accountNonLocked,
      'credentialsNonExpired': instance.credentialsNonExpired,
    };

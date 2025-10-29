// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceUser _$DeviceUserFromJson(Map<String, dynamic> json) => DeviceUser(
      id: (json['id'] as num?)?.toInt(),
      groupId: (json['groupId'] as num?)?.toInt(),
      userId: (json['userId'] as num?)?.toInt(),
      roleId: (json['roleId'] as num?)?.toInt(),
      configCodeId: (json['configCodeId'] as num?)?.toInt(),
      bindStatus: json['bindStatus'] as String?,
      createdDate: json['createdDate'] as String?,
      updatedDate: json['updatedDate'] as String?,
      createdBy: json['createdBy'] as String?,
      updatedBy: json['updatedBy'] as String?,
      deletedFlag: json['deletedFlag'] as String?,
      deviceCode: json['deviceCode'] as String?,
      deviceId: (json['deviceId'] as num?)?.toInt(),
      membershipName: json['membershipName'],
      shipStatus: (json['shipStatus'] as num?)?.toInt(),
      userName: json['userName'] as String?,
      menufacturerId: json['menufacturerId'],
      address: json['address'],
      headUrl: json['headUrl'] as String?,
      nickName: json['nickName'] as String?,
      groupName: json['groupName'] as String?,
      menufacturerName: json['menufacturerName'],
    );

Map<String, dynamic> _$DeviceUserToJson(DeviceUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'groupId': instance.groupId,
      'userId': instance.userId,
      'roleId': instance.roleId,
      'configCodeId': instance.configCodeId,
      'bindStatus': instance.bindStatus,
      'createdDate': instance.createdDate,
      'updatedDate': instance.updatedDate,
      'createdBy': instance.createdBy,
      'updatedBy': instance.updatedBy,
      'deletedFlag': instance.deletedFlag,
      'deviceCode': instance.deviceCode,
      'deviceId': instance.deviceId,
      'membershipName': instance.membershipName,
      'shipStatus': instance.shipStatus,
      'userName': instance.userName,
      'menufacturerId': instance.menufacturerId,
      'address': instance.address,
      'headUrl': instance.headUrl,
      'nickName': instance.nickName,
      'groupName': instance.groupName,
      'menufacturerName': instance.menufacturerName,
    };

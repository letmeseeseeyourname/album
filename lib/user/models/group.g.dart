// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Group _$GroupFromJson(Map<String, dynamic> json) => Group(
  groupName: json['groupName'] as String?,
  groupId: (json['groupId'] as num?)?.toInt(),
  deviceCode: json['deviceCode'] as String?,
  users: (json['users'] as List<dynamic>?)
      ?.map((e) => DeviceUser.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$GroupToJson(Group instance) => <String, dynamic>{
  'groupName': instance.groupName,
  'groupId': instance.groupId,
  'deviceCode': instance.deviceCode,
  'users': instance.users,
};

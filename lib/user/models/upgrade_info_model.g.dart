// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upgrade_info_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpgradeInfoModel _$UpgradeInfoModelFromJson(Map<String, dynamic> json) =>
    UpgradeInfoModel(
      id: (json['id'] as num).toInt(),
      upgradeName: json['upgradeName'] as String,
      targetVersion: json['targetVersion'] as String,
      status: (json['status'] as num).toInt(),
      packageUrl: json['packageUrl'] as String,
      packageSize: (json['packageSize'] as num).toDouble(),
      releaseNotes: json['releaseNotes'] as String,
      createDate: json['createDate'] as String,
      updateDate: json['updateDate'] as String,
      createBy: json['createBy'] as String,
      packetType: (json['packetType'] as num).toInt(),
      versionCode: (json['versionCode'] as num).toInt(),
      packageChecksum: json['packageChecksum'] as String?,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      updateBy: json['updateBy'] as String?,
      strategyStatus: (json['strategyStatus'] as num?)?.toInt(),
    );

Map<String, dynamic> _$UpgradeInfoModelToJson(UpgradeInfoModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'upgradeName': instance.upgradeName,
      'targetVersion': instance.targetVersion,
      'status': instance.status,
      'packageUrl': instance.packageUrl,
      'packageSize': instance.packageSize,
      'releaseNotes': instance.releaseNotes,
      'createDate': instance.createDate,
      'updateDate': instance.updateDate,
      'createBy': instance.createBy,
      'packetType': instance.packetType,
      'versionCode': instance.versionCode,
      'packageChecksum': instance.packageChecksum,
      'startTime': instance.startTime,
      'endTime': instance.endTime,
      'updateBy': instance.updateBy,
      'strategyStatus': instance.strategyStatus,
    };

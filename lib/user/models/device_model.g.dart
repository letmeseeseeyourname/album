// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceModel _$DeviceModelFromJson(Map<String, dynamic> json) => DeviceModel(
  id: (json['id'] as num?)?.toInt(),
  deviceCode: json['deviceCode'] as String?,
  deviceName: json['deviceName'] as String?,
  deviceBrand: json['deviceBrand'] as String?,
  deviceModel: json['deviceModel'] as String?,
  activedState: json['activedState'] as String?,
  createdDate: json['createdDate'] as String?,
  updatedDate: json['updatedDate'] as String?,
  createdBy: json['createdBy'] as String?,
  updatedBy: json['updatedBy'] as String?,
  deletedFlag: json['deletedFlag'] as String?,
  lisenceKey: json['lisenceKey'] as String?,
  menufacturerId: (json['menufacturerId'] as num?)?.toInt(),
  p2pAddress: json['p2pAddress'] as String?,
  p2pName: json['p2pName'],
  status: (json['status'] as num?)?.toInt(),
  ram: json['ram'] as String?,
  rom: json['rom'] as String?,
  storage: (json['storage'] as num?)?.toInt(),
  cpu: json['cpu'] as String?,
  screenResolution: json['screenResolution'] as String?,
  screenSize: json['screenSize'] as String?,
  dateProduction: json['dateProduction'],
  address: json['address'] as String?,
);

Map<String, dynamic> _$DeviceModelToJson(DeviceModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'deviceCode': instance.deviceCode,
      'deviceName': instance.deviceName,
      'deviceBrand': instance.deviceBrand,
      'deviceModel': instance.deviceModel,
      'activedState': instance.activedState,
      'createdDate': instance.createdDate,
      'updatedDate': instance.updatedDate,
      'createdBy': instance.createdBy,
      'updatedBy': instance.updatedBy,
      'deletedFlag': instance.deletedFlag,
      'lisenceKey': instance.lisenceKey,
      'menufacturerId': instance.menufacturerId,
      'p2pAddress': instance.p2pAddress,
      'p2pName': instance.p2pName,
      'status': instance.status,
      'ram': instance.ram,
      'rom': instance.rom,
      'storage': instance.storage,
      'cpu': instance.cpu,
      'screenResolution': instance.screenResolution,
      'screenSize': instance.screenSize,
      'dateProduction': instance.dateProduction,
      'address': instance.address,
    };

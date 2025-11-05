// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'p6device_info_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

P6DeviceInfoModel _$P6DeviceInfoModelFromJson(Map<String, dynamic> json) =>
    P6DeviceInfoModel(
      itemCount: (json['itemCount'] as num?)?.toInt(),
      p6itemList: (json['itemList'] as List<dynamic>?)
          ?.map((e) => P6itemList.fromJson(e as Map<String, dynamic>))
          .toList(),
      ttlAll: (json['ttlAll'] as num?)?.toDouble(),
      ttlPhoto: (json['ttlPhoto'] as num?)?.toInt(),
      ttlUsed: (json['ttlUsed'] as num?)?.toDouble(),
      ttlVideo: (json['ttlVideo'] as num?)?.toInt(),
    );

Map<String, dynamic> _$P6DeviceInfoModelToJson(P6DeviceInfoModel instance) =>
    <String, dynamic>{
      'itemCount': instance.itemCount,
      'itemList': instance.p6itemList,
      'ttlAll': instance.ttlAll,
      'ttlPhoto': instance.ttlPhoto,
      'ttlUsed': instance.ttlUsed,
      'ttlVideo': instance.ttlVideo,
    };

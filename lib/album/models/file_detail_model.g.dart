// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_detail_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FileDetailModel _$FileDetailModelFromJson(Map<String, dynamic> json) =>
    FileDetailModel(
      fileCode: json['fileCode'] as String?,
      metaPath: json['metaPath'] as String?,
      middlePath: json['middlePath'] as String?,
      snailPath: json['snailPath'] as String?,
      fileName: json['fileName'] as String?,
      fileType: json['fileType'] as String?,
      duration: (json['duration'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      size: (json['size'] as num?)?.toInt(),
      fmt: json['fmt'] as String?,
      photoDate: json['photoDate'] as String?,
      latitude: json['latitude'] as String?,
      longitude: json['longitude'] as String?,
    );

Map<String, dynamic> _$FileDetailModelToJson(FileDetailModel instance) =>
    <String, dynamic>{
      'fileCode': instance.fileCode,
      'metaPath': instance.metaPath,
      'middlePath': instance.middlePath,
      'snailPath': instance.snailPath,
      'fileName': instance.fileName,
      'fileType': instance.fileType,
      'duration': instance.duration,
      'width': instance.width,
      'height': instance.height,
      'size': instance.size,
      'fmt': instance.fmt,
      'photoDate': instance.photoDate,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };

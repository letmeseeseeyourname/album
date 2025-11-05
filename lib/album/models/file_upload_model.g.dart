// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_upload_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FileUploadModel _$FileUploadModelFromJson(Map<String, dynamic> json) =>
    FileUploadModel(
      fileCode: json['fileCode'] as String?,
      filePath: json['filePath'] as String?,
      fileName: json['fileName'] as String?,
      fileType: json['fileType'] as String?,
      storageSpace: (json['storageSpace'] as num?)?.toInt(),
    );

Map<String, dynamic> _$FileUploadModelToJson(FileUploadModel instance) =>
    <String, dynamic>{
      'fileCode': instance.fileCode,
      'filePath': instance.filePath,
      'fileName': instance.fileName,
      'fileType': instance.fileType,
      'storageSpace': instance.storageSpace,
    };

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_upload_response_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FileUploadResponseModel _$FileUploadResponseModelFromJson(
  Map<String, dynamic> json,
) => FileUploadResponseModel(
  taskId: (json['taskId'] as num?)?.toInt(),
  uploadPath: json['uploadPath'] as String?,
  okCount: (json['okCount'] as num?)?.toInt(),
  failedCount: (json['failedCount'] as num?)?.toInt(),
  failedFileList: (json['failedFileList'] as List<dynamic>?)
      ?.map((e) => FailedFileList.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$FileUploadResponseModelToJson(
  FileUploadResponseModel instance,
) => <String, dynamic>{
  'taskId': instance.taskId,
  'uploadPath': instance.uploadPath,
  'okCount': instance.okCount,
  'failedCount': instance.failedCount,
  'failedFileList': instance.failedFileList,
};

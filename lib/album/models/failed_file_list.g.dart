// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'failed_file_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FailedFileList _$FailedFileListFromJson(Map<String, dynamic> json) =>
    FailedFileList(
      fileCode: json['fileCode'] as String?,
      failedReason: json['failedReason'] as String?,
    );

Map<String, dynamic> _$FailedFileListToJson(FailedFileList instance) =>
    <String, dynamic>{
      'fileCode': instance.fileCode,
      'failedReason': instance.failedReason,
    };

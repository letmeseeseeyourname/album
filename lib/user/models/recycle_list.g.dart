// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recycle_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecycleList _$RecycleListFromJson(Map<String, dynamic> json) => RecycleList(
      createDate: json['createDate'] as String?,
      mediumPath: json['mediumPath'] as String?,
      originPath: json['originPath'] as String?,
      resId: json['resId'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
    );

Map<String, dynamic> _$RecycleListToJson(RecycleList instance) =>
    <String, dynamic>{
      'createDate': instance.createDate,
      'mediumPath': instance.mediumPath,
      'originPath': instance.originPath,
      'resId': instance.resId,
      'thumbnailPath': instance.thumbnailPath,
    };

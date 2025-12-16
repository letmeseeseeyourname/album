// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recycle_resource_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecycleResourceModel _$RecycleResourceModelFromJson(
        Map<String, dynamic> json) =>
    RecycleResourceModel(
      recycleCount: (json['recycleCount'] as num?)?.toInt(),
      recycleList: (json['recycleList'] as List<dynamic>?)
          ?.map((e) => RecycleList.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RecycleResourceModelToJson(
        RecycleResourceModel instance) =>
    <String, dynamic>{
      'recycleCount': instance.recycleCount,
      'recycleList': instance.recycleList,
    };

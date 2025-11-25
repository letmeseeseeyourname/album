// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_all_groups_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MyAllGroupsModel _$MyAllGroupsModelFromJson(Map<String, dynamic> json) =>
    MyAllGroupsModel(
      groups: (json['groups'] as List<dynamic>?)
          ?.map((e) => Group.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MyAllGroupsModelToJson(MyAllGroupsModel instance) =>
    <String, dynamic>{'groups': instance.groups, 'total': instance.total};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resource_list_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResourceListModel _$ResourceListModelFromJson(Map<String, dynamic> json) =>
    ResourceListModel(
      (json['resList'] as List<dynamic>)
          .map((e) => ResList.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ResourceListModelToJson(ResourceListModel instance) =>
    <String, dynamic>{'resList': instance.resList};

PersonLabel _$PersonLabelFromJson(Map<String, dynamic> json) => PersonLabel(
  tagId: (json['tagId'] as num?)?.toInt(),
  tagName: json['tagName'] as String?,
);

Map<String, dynamic> _$PersonLabelToJson(PersonLabel instance) =>
    <String, dynamic>{'tagId': instance.tagId, 'tagName': instance.tagName};

Locate _$LocateFromJson(Map<String, dynamic> json) => Locate(
  tagId: (json['tagId'] as num?)?.toInt(),
  tagName: json['tagName'] as String?,
);

Map<String, dynamic> _$LocateToJson(Locate instance) => <String, dynamic>{
  'tagId': instance.tagId,
  'tagName': instance.tagName,
};

Scence _$ScenceFromJson(Map<String, dynamic> json) => Scence(
  tagId: (json['tagId'] as num?)?.toInt(),
  tagName: json['tagName'] as String?,
);

Map<String, dynamic> _$ScenceToJson(Scence instance) => <String, dynamic>{
  'tagId': instance.tagId,
  'tagName': instance.tagName,
};

ResList _$ResListFromJson(Map<String, dynamic> json) => ResList(
  resId: json['resId'] as String?,
  thumbnailPath: json['thumbnailPath'] as String?,
  mediumPath: json['mediumPath'] as String?,
  originPath: json['originPath'] as String?,
  resType: json['resType'] as String?,
  fileType: json['fileType'] as String?,
  fileName: json['fileName'] as String?,
  createDate: json['createDate'] == null
      ? null
      : DateTime.parse(json['createDate'] as String),
  updateDate: json['updateDate'] == null
      ? null
      : DateTime.parse(json['updateDate'] as String),
  photoDate: json['photoDate'] == null
      ? null
      : DateTime.parse(json['photoDate'] as String),
  fileSize: (json['fileSize'] as num?)?.toInt(),
  duration: (json['duration'] as num?)?.toInt(),
  width: (json['width'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
  shareUserId: (json['shareUserId'] as num?)?.toInt(),
  shareUserName: json['shareUserName'] as String?,
  shareUserHeadUrl: json['shareUserHeadUrl'] as String?,
  personLabels: (json['personLabels'] as List<dynamic>?)
      ?.map((e) => PersonLabel.fromJson(e as Map<String, dynamic>))
      .toList(),
  deviceName: json['deviceName'] as String?,
  locate: (json['locate'] as List<dynamic>?)
      ?.map((e) => Locate.fromJson(e as Map<String, dynamic>))
      .toList(),
  scence: (json['scence'] as List<dynamic>?)
      ?.map((e) => Scence.fromJson(e as Map<String, dynamic>))
      .toList(),
  address: json['address'] as String?,
  storeContent: json['storeContent'] as String?,
  isPrivate: json['isPrivate'] as String?,
);

Map<String, dynamic> _$ResListToJson(ResList instance) => <String, dynamic>{
  'resId': instance.resId,
  'thumbnailPath': instance.thumbnailPath,
  'mediumPath': instance.mediumPath,
  'originPath': instance.originPath,
  'resType': instance.resType,
  'fileType': instance.fileType,
  'fileName': instance.fileName,
  'createDate': instance.createDate?.toIso8601String(),
  'updateDate': instance.updateDate?.toIso8601String(),
  'photoDate': instance.photoDate?.toIso8601String(),
  'fileSize': instance.fileSize,
  'duration': instance.duration,
  'width': instance.width,
  'height': instance.height,
  'shareUserId': instance.shareUserId,
  'shareUserName': instance.shareUserName,
  'shareUserHeadUrl': instance.shareUserHeadUrl,
  'personLabels': instance.personLabels,
  'deviceName': instance.deviceName,
  'locate': instance.locate,
  'scence': instance.scence,
  'address': instance.address,
  'storeContent': instance.storeContent,
  'isPrivate': instance.isPrivate,
};

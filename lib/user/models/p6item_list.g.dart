// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'p6item_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

P6itemList _$P6itemListFromJson(Map<String, dynamic> json) => P6itemList(
      headUrl: json['headUrl'] as String?,
      nickName: json['nickName'] as String?,
      photoCount: (json['photoCount'] as num?)?.toInt(),
      photoUseStorage: (json['photoUseStorage'] as num?)?.toDouble(),
      sharePhotoCount: (json['sharePhotoCount'] as num?)?.toInt(),
      shareVideoCount: (json['shareVideoCount'] as num?)?.toInt(),
      useStorage: (json['useStorage'] as num?)?.toDouble(),
      userId: (json['userId'] as num?)?.toInt(),
      videoCount: (json['videoCount'] as num?)?.toInt(),
      videoUseStorage: (json['videoUseStorage'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$P6itemListToJson(P6itemList instance) =>
    <String, dynamic>{
      'headUrl': instance.headUrl,
      'nickName': instance.nickName,
      'photoCount': instance.photoCount,
      'photoUseStorage': instance.photoUseStorage,
      'sharePhotoCount': instance.sharePhotoCount,
      'shareVideoCount': instance.shareVideoCount,
      'useStorage': instance.useStorage,
      'userId': instance.userId,
      'videoCount': instance.videoCount,
      'videoUseStorage': instance.videoUseStorage,
    };

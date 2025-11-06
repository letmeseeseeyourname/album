
import 'package:json_annotation/json_annotation.dart';
import 'package:intl/intl.dart';

import '../datetime_parse.dart';
part 'resource_list_model.g.dart';

@JsonSerializable()
class ResourceListModel extends Object {
  @JsonKey(name: 'resList')
  List<ResList> resList;

  ResourceListModel(
    this.resList,
  );

  factory ResourceListModel.fromJson(Map<String, dynamic> srcJson) =>
      _$ResourceListModelFromJson(srcJson);

  Map<String, dynamic> toJson() => _$ResourceListModelToJson(this);
}

@JsonSerializable()
class PersonLabel {
  final int? tagId;
  final String? tagName;

  const PersonLabel({
    required this.tagId,
    required this.tagName,
  });

  factory PersonLabel.fromJson(Map<String, dynamic> json) =>
      _$PersonLabelFromJson(json);

  Map<String, dynamic> toJson() => _$PersonLabelToJson(this);

  PersonLabel copyWith({
    int? tagId,
    String? tagName,
  }) {
    return PersonLabel(
      tagId: tagId ?? this.tagId,
      tagName: tagName ?? this.tagName,
    );
  }
}

@JsonSerializable()
class Locate {
  final int? tagId;
  final String? tagName;

  const Locate({
    required this.tagId,
    required this.tagName,
  });

  factory Locate.fromJson(Map<String, dynamic> json) => _$LocateFromJson(json);

  Map<String, dynamic> toJson() => _$LocateToJson(this);

  Locate copyWith({
    int? tagId,
    String? tagName,
  }) {
    return Locate(
      tagId: tagId ?? this.tagId,
      tagName: tagName ?? this.tagName,
    );
  }
}

@JsonSerializable()
class Scence {
  final int? tagId;
  final String? tagName;

  const Scence({
    required this.tagId,
    required this.tagName,
  });

  factory Scence.fromJson(Map<String, dynamic> json) => _$ScenceFromJson(json);

  Map<String, dynamic> toJson() => _$ScenceToJson(this);

  Scence copyWith({
    int? tagId,
    String? tagName,
  }) {
    return Scence(
      tagId: tagId ?? this.tagId,
      tagName: tagName ?? this.tagName,
    );
  }
}

@JsonSerializable()
class ResList {
  final String? resId;
  final String? thumbnailPath;
  final String? mediumPath;
  final String? originPath;
  final String? resType;
  final String? fileType;
  final String? fileName;
  final DateTime? createDate;
  final DateTime? updateDate;
  final DateTime? photoDate;
  final int? fileSize;
  final int? duration;
  final int? width;
  final int? height;
  final int? shareUserId;
  final String? shareUserName;
  final String? shareUserHeadUrl;
  final List<PersonLabel>? personLabels;
  final String? deviceName;
  final List<Locate>? locate;
  final List<Scence>? scence;
  final String? address;
  final String? storeContent;
  String? isPrivate;

  ResList({
    required this.resId,
    required this.thumbnailPath,
    required this.mediumPath,
    required this.originPath,
    required this.resType,
    required this.fileType,
    required this.fileName,
    required this.createDate,
    required this.updateDate,
    required this.photoDate,
    required this.fileSize,
    required this.duration,
    required this.width,
    required this.height,
    required this.shareUserId,
    required this.shareUserName,
    required this.shareUserHeadUrl,
    required this.personLabels,
    required this.deviceName,
    required this.locate,
    required this.scence,
    required this.address,
    required this.storeContent,
    required this.isPrivate,
  });

  factory ResList.fromJson(Map<String, dynamic> json) => ResList(
        resId: json['resId'] as String?,
        thumbnailPath: json['thumbnailPath'] as String?,
        mediumPath: json['mediumPath'] as String?,
        originPath: json['originPath'] as String?,
        resType: json['resType'] as String?,
        fileType: json['fileType'] as String?,
        fileName: json['fileName'] as String?,
        createDate: (json['createDate'] == null || (json['createDate'] as String).isEmpty)
            ? null
            : DateTime.parse(DateFormaterManager.pad(json['createDate'] as String)),
        updateDate: (json['updateDate'] == null || (json['updateDate'] as String).isEmpty)
            ? null
            : DateTime.parse(DateFormaterManager.pad(json['updateDate'] as String)),
        photoDate: ( json['photoDate'] == null || (json['photoDate'] as String).isEmpty)
            ? null
            : DateTime.parse(DateFormaterManager.pad(json['photoDate'] as String)),
        fileSize: (json['fileSize'] as num?)?.toInt(),
        duration: (json['duration'] as num?)?.toInt(),
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        shareUserId: (json['shareUserId'] as num?)?.toInt(),
        shareUserName: json['shareUserName'] as String?,
        shareUserHeadUrl: json['shareUserHeadUrl'] as String?,
        personLabels:
            ((json['personLabels'] ?? json['personLabel']) as List<dynamic>?)
                ?.map((e) => PersonLabel.fromJson(e as Map<String, dynamic>))
                .toList(),
        deviceName: json['deviceName'] as String?,
        locate: ((json['locate'] ?? json['locateLabels']) as List<dynamic>?)
            ?.map((e) => Locate.fromJson(e as Map<String, dynamic>))
            .toList(),
        scence: (json['scence'] as List<dynamic>?)
            ?.map((e) => Scence.fromJson(e as Map<String, dynamic>))
            .toList(),
        address: json['address'] as String?,
        storeContent: json['storeContent'] as String?,
        isPrivate: json['isPrivate'] as String?,
      );

  Map<String, dynamic> toJson() => _$ResListToJson(this);

  ResList copyWith({
    String? resId,
    String? thumbnailPath,
    String? mediumPath,
    String? originPath,
    String? resType,
    String? fileType,
    String? fileName,
    DateTime? createDate,
    DateTime? updateDate,
    DateTime? photoDate,
    int? fileSize,
    int? duration,
    int? width,
    int? height,
    int? shareUserId,
    String? shareUserName,
    String? shareUserHeadUrl,
    List<PersonLabel>? personLabels,
    String? deviceName,
    List<Locate>? locate,
    List<Scence>? scence,
    String? address,
    String? storeContent,
    String? isPrivate,
  }) {
    return ResList(
      resId: resId ?? this.resId,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      mediumPath: mediumPath ?? this.mediumPath,
      originPath: originPath ?? this.originPath,
      resType: resType ?? this.resType,
      fileType: fileType ?? this.fileType,
      fileName: fileName ?? this.fileName,
      createDate: createDate ?? this.createDate,
      updateDate: updateDate ?? this.updateDate,
      photoDate: photoDate ?? this.photoDate,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      shareUserId: shareUserId ?? this.shareUserId,
      shareUserName: shareUserName ?? this.shareUserName,
      shareUserHeadUrl: shareUserHeadUrl ?? this.shareUserHeadUrl,
      personLabels: personLabels ?? this.personLabels,
      deviceName: deviceName ?? this.deviceName,
      locate: locate ?? this.locate,
      scence: scence ?? this.scence,
      address: address ?? this.address,
      storeContent: storeContent ?? this.storeContent,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }
}

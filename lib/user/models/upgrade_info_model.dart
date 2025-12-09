// upgrade_info_model.dart
import 'package:json_annotation/json_annotation.dart';

// 此处的文件名需要与您实际创建的文件名一致，例如：'upgrade_info_model.g.dart'
part 'upgrade_info_model.g.dart';

@JsonSerializable()
class UpgradeInfoModel {
  // 必填字段 (非空)
  @JsonKey(name: 'id')
  final int id;

  @JsonKey(name: 'upgradeName')
  final String upgradeName;

  @JsonKey(name: 'targetVersion')
  final String targetVersion;

  @JsonKey(name: 'status')
  final int status;

  @JsonKey(name: 'packageUrl')
  final String packageUrl;

  @JsonKey(name: 'packageSize')
  final double packageSize;

  @JsonKey(name: 'releaseNotes')
  final String releaseNotes;

  @JsonKey(name: 'createDate')
  final String createDate;

  @JsonKey(name: 'updateDate')
  final String updateDate;

  @JsonKey(name: 'createBy')
  final String createBy;

  @JsonKey(name: 'packetType')
  final int packetType;

  @JsonKey(name: 'versionCode')
  final int versionCode;

  // 可空字段 (对应 JSON 中的 null 值)
  @JsonKey(name: 'packageChecksum')
  final String? packageChecksum;

  @JsonKey(name: 'startTime')
  final String? startTime;

  @JsonKey(name: 'endTime')
  final String? endTime;

  @JsonKey(name: 'updateBy')
  final String? updateBy;

  @JsonKey(name: 'strategyStatus')
  final int? strategyStatus;

  UpgradeInfoModel({
    required this.id,
    required this.upgradeName,
    required this.targetVersion,
    required this.status,
    required this.packageUrl,
    required this.packageSize,
    required this.releaseNotes,
    required this.createDate,
    required this.updateDate,
    required this.createBy,
    required this.packetType,
    required this.versionCode,
    this.packageChecksum,
    this.startTime,
    this.endTime,
    this.updateBy,
    this.strategyStatus,
  });

  /// 从 JSON Map 创建实例的工厂方法
  factory UpgradeInfoModel.fromJson(Map<String, dynamic> json) =>
      _$UpgradeInfoModelFromJson(json);

  /// 将实例转换为 JSON Map 的方法
  Map<String, dynamic> toJson() => _$UpgradeInfoModelToJson(this);
}

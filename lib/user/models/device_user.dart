import 'package:json_annotation/json_annotation.dart';

part 'device_user.g.dart';

@JsonSerializable()
class DeviceUser {
    final int? id;
    final int? groupId;
    final int? userId;
    final int? roleId;
    final int? configCodeId;
    final String? bindStatus;
    final String? createdDate;
    final String? updatedDate;
    final String? createdBy;
    final String? updatedBy;
    final String? deletedFlag;
    final String? deviceCode;
    final int? deviceId;
    final dynamic? membershipName;
    final int? shipStatus;
    final String? userName;
    final dynamic? menufacturerId;
    final dynamic? address;
    final String? headUrl;
    final String? nickName;
    final String? groupName;
    final dynamic? menufacturerName;

    const DeviceUser({
        required this.id,
        required this.groupId,
        required this.userId,
        required this.roleId,
        required this.configCodeId,
        required this.bindStatus,
        required this.createdDate,
        required this.updatedDate,
        required this.createdBy,
        required this.updatedBy,
        required this.deletedFlag,
        required this.deviceCode,
        required this.deviceId,
        this.membershipName,
        required this.shipStatus,
        required this.userName,
        this.menufacturerId,
        this.address,
        required this.headUrl,
        required this.nickName,
        required this.groupName,
        this.menufacturerName,
    });

    factory DeviceUser.fromJson(Map<String, dynamic> json) => _$DeviceUserFromJson(json);

    Map<String, dynamic> toJson() => _$DeviceUserToJson(this);

    DeviceUser copyWith({
        int? id,
        int? groupId,
        int? userId,
        int? roleId,
        int? configCodeId,
        String? bindStatus,
        String? createdDate,
        String? updatedDate,
        String? createdBy,
        String? updatedBy,
        String? deletedFlag,
        String? deviceCode,
        int? deviceId,
        dynamic? membershipName,
        int? shipStatus,
        String? userName,
        dynamic? menufacturerId,
        dynamic? address,
        String? headUrl,
        String? nickName,
        String? groupName,
        dynamic? menufacturerName,
    }) {
        return DeviceUser(
            id: id ?? this.id,
            groupId: groupId ?? this.groupId,
            userId: userId ?? this.userId,
            roleId: roleId ?? this.roleId,
            configCodeId: configCodeId ?? this.configCodeId,
            bindStatus: bindStatus ?? this.bindStatus,
            createdDate: createdDate ?? this.createdDate,
            updatedDate: updatedDate ?? this.updatedDate,
            createdBy: createdBy ?? this.createdBy,
            updatedBy: updatedBy ?? this.updatedBy,
            deletedFlag: deletedFlag ?? this.deletedFlag,
            deviceCode: deviceCode ?? this.deviceCode,
            deviceId: deviceId ?? this.deviceId,
            membershipName: membershipName ?? this.membershipName,
            shipStatus: shipStatus ?? this.shipStatus,
            userName: userName ?? this.userName,
            menufacturerId: menufacturerId ?? this.menufacturerId,
            address: address ?? this.address,
            headUrl: headUrl ?? this.headUrl,
            nickName: nickName ?? this.nickName,
            groupName: groupName ?? this.groupName,
            menufacturerName: menufacturerName ?? this.menufacturerName,
        );
    }
}

// Run this command to generate the required code:
// flutter pub run build_runner build --delete-conflicting-outputs

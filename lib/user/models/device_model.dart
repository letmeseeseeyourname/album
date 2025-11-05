import 'package:json_annotation/json_annotation.dart';

part 'device_model.g.dart';

@JsonSerializable()
class DeviceModel {
    final int? id;
    final String? deviceCode;
    final String? deviceName;
    final String? deviceBrand;
    final String? deviceModel;
    final String? activedState;
    final String? createdDate;
    final String? updatedDate;
    final String? createdBy;
    final String? updatedBy;
    final String? deletedFlag;
    final String? lisenceKey;
    final int? menufacturerId;
    final String? p2pAddress;
    final dynamic? p2pName;
    final int? status;
    final String? ram;
    final String? rom;
    final int? storage;
    final String? cpu;
    final String? screenResolution;
    final String? screenSize;
    final dynamic? dateProduction;
    final String? address;

    const DeviceModel({
        required this.id,
        required this.deviceCode,
        required this.deviceName,
        required this.deviceBrand,
        required this.deviceModel,
        required this.activedState,
        required this.createdDate,
        required this.updatedDate,
        required this.createdBy,
        required this.updatedBy,
        required this.deletedFlag,
        required this.lisenceKey,
        required this.menufacturerId,
        required this.p2pAddress,
        this.p2pName,
        required this.status,
        required this.ram,
        required this.rom,
        required this.storage,
        required this.cpu,
        required this.screenResolution,
        required this.screenSize,
        this.dateProduction,
        required this.address,
    });

    factory DeviceModel.fromJson(Map<String, dynamic> json) => _$DeviceModelFromJson(json);

    Map<String, dynamic> toJson() => _$DeviceModelToJson(this);

    DeviceModel copyWith({
        int? id,
        String? deviceCode,
        String? deviceName,
        String? deviceBrand,
        String? deviceModel,
        String? activedState,
        String? createdDate,
        String? updatedDate,
        String? createdBy,
        String? updatedBy,
        String? deletedFlag,
        String? lisenceKey,
        int? menufacturerId,
        String? p2pAddress,
        dynamic? p2pName,
        int? status,
        String? ram,
        String? rom,
        int? storage,
        String? cpu,
        String? screenResolution,
        String? screenSize,
        dynamic? dateProduction,
        String? address,
    }) {
        return DeviceModel(
            id: id ?? this.id,
            deviceCode: deviceCode ?? this.deviceCode,
            deviceName: deviceName ?? this.deviceName,
            deviceBrand: deviceBrand ?? this.deviceBrand,
            deviceModel: deviceModel ?? this.deviceModel,
            activedState: activedState ?? this.activedState,
            createdDate: createdDate ?? this.createdDate,
            updatedDate: updatedDate ?? this.updatedDate,
            createdBy: createdBy ?? this.createdBy,
            updatedBy: updatedBy ?? this.updatedBy,
            deletedFlag: deletedFlag ?? this.deletedFlag,
            lisenceKey: lisenceKey ?? this.lisenceKey,
            menufacturerId: menufacturerId ?? this.menufacturerId,
            p2pAddress: p2pAddress ?? this.p2pAddress,
            p2pName: p2pName ?? this.p2pName,
            status: status ?? this.status,
            ram: ram ?? this.ram,
            rom: rom ?? this.rom,
            storage: storage ?? this.storage,
            cpu: cpu ?? this.cpu,
            screenResolution: screenResolution ?? this.screenResolution,
            screenSize: screenSize ?? this.screenSize,
            dateProduction: dateProduction ?? this.dateProduction,
            address: address ?? this.address,
        );
    }
}

// Run this command to generate the required code:
// flutter pub run build_runner build --delete-conflicting-outputs

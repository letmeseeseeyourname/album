
import 'package:json_annotation/json_annotation.dart';
import 'device_user.dart';

part 'group.g.dart';

@JsonSerializable()
class Group {
    final String? groupName;
    final int? groupId;
    final String? deviceCode;
    final List<DeviceUser>? users;

    const Group({
        required this.groupName,
        required this.groupId,
        required this.deviceCode,
        required this.users,
    });

    factory Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);

    Map<String, dynamic> toJson() => _$GroupToJson(this);

    Group copyWith({
        String? name,
        int? groupId,
        String? deviceCode,
        List<DeviceUser>? users,
    }) {
        return Group(
            groupName: name ?? this.groupName,
            groupId: groupId ?? this.groupId,
            deviceCode: deviceCode ?? this.deviceCode,
            users: users ?? this.users,
        );
    }
}

// Run this command to generate the required code:
// flutter pub run build_runner build --delete-conflicting-outputs

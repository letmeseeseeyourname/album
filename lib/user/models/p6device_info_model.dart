import 'package:json_annotation/json_annotation.dart';
import 'p6item_list.dart';

part 'p6device_info_model.g.dart';

@JsonSerializable()
class P6DeviceInfoModel {
    @JsonKey(name: 'itemCount')
    final int? itemCount;
    @JsonKey(name: 'itemList')
    final List<P6itemList>? p6itemList;
    @JsonKey(name: 'ttlAll')
    final double? ttlAll;
    @JsonKey(name: 'ttlPhoto')
    final int? ttlPhoto;
    @JsonKey(name: 'ttlUsed')
    final double? ttlUsed;
    @JsonKey(name: 'ttlVideo')
    final int? ttlVideo;

    const P6DeviceInfoModel({
        required this.itemCount,
        required this.p6itemList,
        required this.ttlAll,
        required this.ttlPhoto,
        required this.ttlUsed,
        required this.ttlVideo,
    });

    factory P6DeviceInfoModel.fromJson(Map<String, dynamic> json) => _$P6DeviceInfoModelFromJson(json);

    Map<String, dynamic> toJson() => _$P6DeviceInfoModelToJson(this);

    P6DeviceInfoModel copyWith({
        int? itemCount,
        List<P6itemList>? p6itemList,
        double? ttlAll,
        int? ttlPhoto,
        double? ttlUsed,
        int? ttlVideo,
    }) {
        return P6DeviceInfoModel(
            itemCount: itemCount ?? this.itemCount,
            p6itemList: p6itemList ?? this.p6itemList,
            ttlAll: ttlAll ?? this.ttlAll,
            ttlPhoto: ttlPhoto ?? this.ttlPhoto,
            ttlUsed: ttlUsed ?? this.ttlUsed,
            ttlVideo: ttlVideo ?? this.ttlVideo,
        );
    }
}

// Run this command to generate the required code:
// flutter pub run build_runner build --delete-conflicting-outputs

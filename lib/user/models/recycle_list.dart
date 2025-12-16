import 'package:json_annotation/json_annotation.dart';

part 'recycle_list.g.dart';

@JsonSerializable()
class RecycleList {
    final String? createDate;
    final String? mediumPath;
    final String? originPath;
    final String? resId;
    final String? thumbnailPath;

    const RecycleList({
        required this.createDate,
        required this.mediumPath,
        required this.originPath,
        required this.resId,
        required this.thumbnailPath,
    });

    factory RecycleList.fromJson(Map<String, dynamic> json) => _$RecycleListFromJson(json);

    Map<String, dynamic> toJson() => _$RecycleListToJson(this);

    RecycleList copyWith({
        String? createDate,
        String? mediumPath,
        String? originPath,
        String? resId,
        String? thumbnailPath,
    }) {
        return RecycleList(
            createDate: createDate ?? this.createDate,
            mediumPath: mediumPath ?? this.mediumPath,
            originPath: originPath ?? this.originPath,
            resId: resId ?? this.resId,
            thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        );
    }
}

// Run this command to generate the required code:
// flutter pub run build_runner build --delete-conflicting-outputs

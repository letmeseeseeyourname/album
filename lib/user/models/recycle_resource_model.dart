import 'package:ablumwin/user/models/recycle_list.dart';
import 'package:json_annotation/json_annotation.dart';

part 'recycle_resource_model.g.dart';

@JsonSerializable()
class RecycleResourceModel {
    final int? recycleCount;
    final List<RecycleList>? recycleList;

    const RecycleResourceModel({
        required this.recycleCount,
        required this.recycleList,
    });

    factory RecycleResourceModel.fromJson(Map<String, dynamic> json) => _$RecycleResourceModelFromJson(json);

    Map<String, dynamic> toJson() => _$RecycleResourceModelToJson(this);

    RecycleResourceModel copyWith({
        int? recycleCount,
        List<RecycleList>? recycleList,
    }) {
        return RecycleResourceModel(
            recycleCount: recycleCount ?? this.recycleCount,
            recycleList: recycleList ?? this.recycleList,
        );
    }
}

// Run this command to generate the required code:
// flutter pub run build_runner build --delete-conflicting-outputs

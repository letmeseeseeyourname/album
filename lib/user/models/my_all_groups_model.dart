import 'package:json_annotation/json_annotation.dart';
import 'group.dart';
part 'my_all_groups_model.g.dart';

@JsonSerializable()
class MyAllGroupsModel {
    final List<Group>? groups;
    final int? total;

    const MyAllGroupsModel({
        required this.groups,
        required this.total,
    });

    factory MyAllGroupsModel.fromJson(Map<String, dynamic> json) => _$MyAllGroupsModelFromJson(json);

    Map<String, dynamic> toJson() => _$MyAllGroupsModelToJson(this);

    MyAllGroupsModel copyWith({
        List<Group>? groups,
        int? total,
    }) {
        return MyAllGroupsModel(
            groups: groups ?? this.groups,
            total: total ?? this.total,
        );
    }
}

// Run this command to generate the required code:
// flutter pub run build_runner build --delete-conflicting-outputs
